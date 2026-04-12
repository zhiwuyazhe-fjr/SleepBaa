import { randomUUID } from "node:crypto";
import {
  AIProvider,
  AIProviderSourceMode,
  buildSystemIdentityReply,
  buildDeterministicProfileSummary,
  classifyIntent,
} from "../providers/ai_provider";
import { AssistantDataRepository } from "../repositories/firestore_repositories";
import { buildCardSnapshots } from "../services/materialize_card_snapshots";
import {
  AssistantContext,
  AssistantIntent,
  AssistantMemoryItem,
  AssistantRunDoc,
  AssistantRunSourceMode,
  AssistantThreadSummaryDoc,
  DreamAnalysis,
  MorningReviewResult,
  SleepCaptureKind,
  SurfaceId,
  UserStateDoc,
} from "../shared/types";

function nowIso(): string {
  return new Date().toISOString();
}

function buildEmptyUserState(): UserStateDoc {
  return {
    currentPhase: "home_pre_sleep",
    activeSessionId: null,
    latestThreadId: null,
    latestNightMood: null,
    profileSummary: {
      sleepPatternSummary:
        "The assistant is collecting the first few nights of structured feedback.",
      highRiskFactors: [],
      effectiveActions: [],
      dreamTrendSummary: "Dream trend data is still sparse.",
      emotionTrendSummary: "Night mood data is still sparse.",
      lastUpdatedAt: nowIso(),
    },
    tonightPlan: null,
    tonightInterference: null,
    feedbackLoop: null,
    updatedAt: nowIso(),
  };
}

function summarizeConversationWindow(
  context: AssistantContext,
  prompt: string,
  reply: string,
): string {
  const parts = [
    ...context.recentMessages
        .slice(-4)
        .map((message) => `${message.role}: ${message.content}`),
    `user: ${prompt}`,
    `assistant: ${reply}`,
  ];
  const window = parts.join(" | ");
  return window.length > 320 ? `${window.slice(0, 317)}...` : window;
}

function extractKeywords(prompt: string, reply: string): string[] {
  const source = `${prompt} ${reply}`;
  const candidates = [
    "宿舍",
    "室友",
    "睡不着",
    "作息",
    "偏好",
    "计划",
    "目标",
    "情绪",
    "noise",
    "sleep",
    "routine",
  ];
  return candidates.filter((item) => source.toLowerCase().includes(item.toLowerCase()));
}

function buildThreadSummaryDoc(
  context: AssistantContext,
  threadId: string,
  prompt: string,
  reply: string,
): AssistantThreadSummaryDoc {
  return {
    threadId,
    summary: summarizeConversationWindow(context, prompt, reply),
    keywords: extractKeywords(prompt, reply),
    updatedAt: nowIso(),
  };
}

function buildMemoryItem(
  uid: string,
  threadId: string,
  kind: string,
  content: string,
): AssistantMemoryItem {
  const timestamp = nowIso();
  return {
    id: `${uid}:${kind}`,
    kind,
    content,
    sourceThreadId: threadId,
    salience: 0.82,
    lastUsedAt: timestamp,
    sourceRefs: ["assistant_messages", `thread:${threadId}`],
    createdAt: timestamp,
    updatedAt: timestamp,
  };
}

function extractLongTermMemory(
  uid: string,
  threadId: string,
  prompt: string,
): AssistantMemoryItem[] {
  const normalized = prompt.trim();
  if (!normalized) {
    return [];
  }
  const matches: AssistantMemoryItem[] = [];
  const maybePush = (kind: string, test: boolean) => {
    if (test) {
      matches.push(buildMemoryItem(uid, threadId, kind, normalized));
    }
  };
  maybePush(
    "preference",
    /喜欢|不喜欢|偏好|prefer|favorite/i.test(normalized),
  );
  maybePush(
    "profile",
    /我是|我叫|身份|角色|i am|my name/i.test(normalized),
  );
  maybePush(
    "goal",
    /目标|希望|想要|计划|goal|want to/i.test(normalized),
  );
  maybePush(
    "dorm_context",
    /宿舍|室友|寝室|roommate|dorm/i.test(normalized),
  );
  maybePush(
    "sleep_pattern",
    /睡不着|失眠|作息|早起|晚睡|经常|总是|sleep/i.test(normalized),
  );
  return matches.slice(0, 3);
}

async function persistRun(
  repo: AssistantDataRepository,
  uid: string,
  runId: string,
  run: AssistantRunDoc,
): Promise<void> {
  await repo.writeAssistantRun(uid, runId, run);
}

function runStatusFromSourceMode(
  sourceMode: AssistantRunSourceMode,
): AssistantRunDoc["status"] {
  return sourceMode === "remoteSuccess"
    ? "success"
    : sourceMode === "error"
      ? "error"
      : "fallback";
}

function combineSourceModes(
  sourceModes: AIProviderSourceMode[],
): AIProviderSourceMode {
  return sourceModes.every((item) => item === "remoteSuccess")
    ? "remoteSuccess"
    : "fallbackSuccess";
}

function combineErrorMessages(
  ...messages: Array<string | null | undefined>
): string | null {
  const next = messages
    .map((item) => item?.trim() || "")
    .filter((item) => item.length > 0);
  return next.length > 0 ? next.join(" | ") : null;
}

export async function prepareTonightPlan(
  repo: AssistantDataRepository,
  provider: AIProvider,
  uid: string,
  _source: string,
  threadId?: string,
): Promise<{
  runId: string;
  userState: UserStateDoc;
  updatedSurfaces: SurfaceId[];
  provider: string;
  model: string;
  sourceMode: AIProviderSourceMode;
  errorMessage: string | null;
}> {
  const runId = randomUUID();
  const context = await repo.buildAssistantContext(uid, threadId);
  const previous = context.userState ?? buildEmptyUserState();
  const tonightPlanResult = await provider.generateTonightPlan(context, runId);
  const tonightPlan = tonightPlanResult.value;
  const userState: UserStateDoc = {
    ...previous,
    currentPhase: "home_pre_sleep",
    latestNightMood: context.settings.selectedNightMood ?? null,
    latestThreadId: threadId ?? previous.latestThreadId ?? null,
    profileSummary: buildDeterministicProfileSummary(context),
    tonightPlan,
    updatedAt: nowIso(),
  };

  await repo.writeUserState(uid, userState);
  const updatedSurfaces: SurfaceId[] = ["home_pre_sleep", "assistant_context"];
  const snapshots = buildCardSnapshots(context, userState, updatedSurfaces);
  for (const snapshot of snapshots) {
    await repo.writeCardSnapshot(uid, snapshot);
  }

  await persistRun(repo, uid, runId, {
    eventType: "prepare_tonight_plan",
    threadId: threadId ?? null,
    provider: tonightPlanResult.providerName,
    model: tonightPlanResult.modelName,
    status: runStatusFromSourceMode(tonightPlanResult.sourceMode),
    sourceMode: tonightPlanResult.sourceMode,
    inputRefs: [
      "users",
      "user_settings",
      "dorms",
      "sleep_sessions",
      "dream_entries",
    ],
    outputRefs: ["user_state", "users.card_snapshots.home_pre_sleep"],
    error: tonightPlanResult.errorMessage ?? null,
    createdAt: nowIso(),
  });

  return {
    runId,
    userState,
    updatedSurfaces,
    provider: tonightPlanResult.providerName,
    model: tonightPlanResult.modelName,
    sourceMode: tonightPlanResult.sourceMode,
    errorMessage: tonightPlanResult.errorMessage ?? null,
  };
}

export async function handleAssistantReply(
  repo: AssistantDataRepository,
  provider: AIProvider,
  uid: string,
  prompt: string,
  threadId: string,
): Promise<{
  runId: string;
  reply: string;
  intent: AssistantIntent;
  updatedSurfaces: SurfaceId[];
  userState: UserStateDoc;
  provider: string;
  model: string;
  sourceMode: AIProviderSourceMode;
  errorMessage: string | null;
}> {
  const runId = randomUUID();
  const context = await repo.buildAssistantContext(uid, threadId);
  const intent = classifyIntent(prompt);
  const previous = context.userState ?? buildEmptyUserState();
  const replyResult =
    intent === "system_identity"
      ? {
          value: buildSystemIdentityReply({
            assistantName: context.assistantProfile.assistantName,
            providerName: provider.providerName,
            modelName: provider.modelName,
            sourceMode: "fallbackSuccess",
          }),
          providerName: provider.providerName,
          modelName: provider.modelName,
          sourceMode: "fallbackSuccess" as AIProviderSourceMode,
          errorMessage: null,
        }
      : await provider.generateStructuredReply(context, intent, prompt);
  const reply = replyResult.value;
  let planResult:
    | Awaited<ReturnType<AIProvider["generateTonightPlan"]>>
    | null = null;

  let nextState: UserStateDoc = {
    ...previous,
    currentPhase: "assistant",
    latestThreadId: threadId,
    profileSummary: buildDeterministicProfileSummary(context),
    updatedAt: nowIso(),
  };

  if (reply.updateTonightPlan) {
    planResult = await provider.generateTonightPlan(context, runId);
    nextState = {
      ...nextState,
      tonightPlan: planResult.value,
    };
  }

  await repo.writeUserState(uid, nextState);
  const snapshots = buildCardSnapshots(context, nextState, reply.updatedSurfaces);
  for (const snapshot of snapshots) {
    await repo.writeCardSnapshot(uid, snapshot);
  }

  await persistRun(repo, uid, runId, {
    eventType: "assistant_reply",
    threadId,
    provider: replyResult.providerName,
    model: replyResult.modelName,
    status: runStatusFromSourceMode(
      combineSourceModes([
        replyResult.sourceMode,
        ...(planResult ? [planResult.sourceMode] : []),
      ]),
    ),
    sourceMode: combineSourceModes([
      replyResult.sourceMode,
      ...(planResult ? [planResult.sourceMode] : []),
    ]),
    inputRefs: ["assistant_threads.messages", "user_state", "sleep_sessions"],
    outputRefs: ["users.assistant_runs", "user_state", ...reply.updatedSurfaces],
    error: combineErrorMessages(
      replyResult.errorMessage,
      planResult?.errorMessage,
    ),
    createdAt: nowIso(),
  });

  const threadSummary = buildThreadSummaryDoc(
    context,
    threadId,
    prompt,
    reply.reply,
  );
  await repo.writeAssistantThreadSummary(uid, threadSummary);
  const longTermMemory = extractLongTermMemory(uid, threadId, prompt);
  if (longTermMemory.length > 0) {
    await repo.upsertAssistantMemoryItems(uid, longTermMemory);
  }

  return {
    runId,
    reply: reply.reply,
    intent: reply.intent,
    updatedSurfaces: reply.updatedSurfaces,
    userState: nextState,
    provider: replyResult.providerName,
    model: replyResult.modelName,
    sourceMode: replyResult.sourceMode,
    errorMessage: replyResult.errorMessage ?? null,
  };
}

export async function handleAssistantCapture(
  repo: AssistantDataRepository,
  provider: AIProvider,
  uid: string,
  prompt: string,
  threadId: string,
  captureType: SleepCaptureKind,
  sessionId: string,
): Promise<{
  runId: string;
  reply: string;
  updatedSurfaces: SurfaceId[];
  userState: UserStateDoc;
  provider: string;
  model: string;
  sourceMode: AIProviderSourceMode;
  errorMessage: string | null;
  record: Record<string, unknown>;
}> {
  const runId = randomUUID();
  const context = await repo.buildAssistantContext(uid, threadId);
  const previous = context.userState ?? buildEmptyUserState();
  const captureResult = await provider.generateSleepCapture(context, {
    prompt,
    captureType,
    sessionId,
  });
  const draft = captureResult.value;
  const record = await repo.saveSleepCaptureRecord(uid, {
    type: draft.type,
    sessionId,
    createdAt: nowIso(),
    title: draft.title,
    outline: draft.outline,
    content: draft.content,
  });
  const nextState: UserStateDoc = {
    ...previous,
    latestThreadId: threadId,
    updatedAt: nowIso(),
  };

  await repo.writeUserState(uid, nextState);
  await persistRun(repo, uid, runId, {
    eventType: "assistant_capture",
    threadId,
    provider: captureResult.providerName,
    model: captureResult.modelName,
    status: runStatusFromSourceMode(captureResult.sourceMode),
    sourceMode: captureResult.sourceMode,
    inputRefs: ["assistant_threads.messages", "sleep_sessions"],
    outputRefs: ["sleep_capture_records", "assistant_context"],
    error: captureResult.errorMessage ?? null,
    createdAt: nowIso(),
  });

  const threadSummary = buildThreadSummaryDoc(
    context,
    threadId,
    prompt,
    draft.reply,
  );
  await repo.writeAssistantThreadSummary(uid, threadSummary);
  const longTermMemory = extractLongTermMemory(uid, threadId, prompt);
  if (longTermMemory.length > 0) {
    await repo.upsertAssistantMemoryItems(uid, longTermMemory);
  }

  return {
    runId,
    reply: draft.reply,
    updatedSurfaces: ["assistant_context"],
    userState: nextState,
    provider: captureResult.providerName,
    model: captureResult.modelName,
    sourceMode: captureResult.sourceMode,
    errorMessage: captureResult.errorMessage ?? null,
    record,
  };
}

export async function refreshUserCards(
  repo: AssistantDataRepository,
  provider: AIProvider,
  uid: string,
  surfaces: SurfaceId[],
): Promise<{
  version: string;
  updatedSurfaces: SurfaceId[];
}> {
  const context = await repo.buildAssistantContext(uid);
  const tonightPlanResult = await provider.generateTonightPlan(
    context,
    randomUUID(),
  );
  const userState = context.userState ?? {
    ...buildEmptyUserState(),
    profileSummary: buildDeterministicProfileSummary(context),
    tonightPlan: tonightPlanResult.value,
  };
  const snapshots = buildCardSnapshots(context, userState, surfaces);
  for (const snapshot of snapshots) {
    await repo.writeCardSnapshot(uid, snapshot);
  }
  return {
    version: snapshots[0]?.version ?? `v-${Date.now()}`,
    updatedSurfaces: surfaces,
  };
}

export async function handleSleepSessionChange(
  repo: AssistantDataRepository,
  provider: AIProvider,
  uid: string,
  sessionId: string,
  beforeStatus: string | null,
  afterStatus: string | null,
): Promise<void> {
  const context = await repo.buildAssistantContext(uid);
  const previous = context.userState ?? buildEmptyUserState();

  if (afterStatus === "active") {
    const nextState: UserStateDoc = {
      ...previous,
      currentPhase: "sleep_mode",
      activeSessionId: sessionId,
      updatedAt: nowIso(),
    };
    await repo.writeUserState(uid, nextState);
    for (const snapshot of buildCardSnapshots(context, nextState, ["sleep_mode"])) {
      await repo.writeCardSnapshot(uid, snapshot);
    }
    return;
  }

  if (afterStatus === "awaitingFeedback") {
    const nextState: UserStateDoc = {
      ...previous,
      currentPhase: "morning_feedback",
      activeSessionId: sessionId,
      updatedAt: nowIso(),
    };
    await repo.writeUserState(uid, nextState);
    for (const snapshot of buildCardSnapshots(context, nextState, ["morning_feedback"])) {
      await repo.writeCardSnapshot(uid, snapshot);
    }
    await repo.upsertNotification(uid, `feedback-${sessionId}`, {
      id: `feedback-${sessionId}`,
      category: "reminder",
      title: "晨间反馈待完成",
      body: "补完昨晚的晨间反馈后，AI 才能继续优化下一晚的睡眠建议。",
      route: "/feedback/morning",
      createdAt: nowIso(),
      ownerUid: uid,
      readAt: null,
    });
    return;
  }

  if (afterStatus === "completed" && beforeStatus !== "completed") {
    const review: MorningReviewResult = (
      await provider.analyzeFeedback(
        context,
        sessionId,
      )
    ).value;
    const nextState: UserStateDoc = {
      ...previous,
      currentPhase: "home_pre_sleep",
      activeSessionId: null,
      profileSummary: review.profileSummary,
      feedbackLoop: {
        lastSessionId: sessionId,
        lastReviewSummary: review.reviewSummary,
        effectiveActions: review.effectiveActions,
        ineffectiveActions: review.ineffectiveActions,
        updatedAt: nowIso(),
      },
      updatedAt: nowIso(),
    };
    await repo.writeUserState(uid, nextState);
    for (const snapshot of buildCardSnapshots(context, nextState, [
      "profile_report",
      "morning_feedback",
      "assistant_context",
    ])) {
      await repo.writeCardSnapshot(uid, snapshot);
    }
  }
}

export async function handleDreamEntryChange(
  repo: AssistantDataRepository,
  provider: AIProvider,
  uid: string,
  entryId: string,
  body: string,
): Promise<DreamAnalysis> {
  const context = await repo.buildAssistantContext(uid);
  const previous = context.userState ?? buildEmptyUserState();
  const analysis = (await provider.summarizeDream(body, context)).value;
  await repo.setDreamAnalysis(entryId, analysis);

  const nextState: UserStateDoc = {
    ...previous,
    profileSummary: {
      ...buildDeterministicProfileSummary(context),
      dreamTrendSummary: analysis.summary,
      lastUpdatedAt: nowIso(),
    },
    updatedAt: nowIso(),
  };
  await repo.writeUserState(uid, nextState);
  for (const snapshot of buildCardSnapshots(context, nextState, [
    "profile_report",
    "assistant_context",
  ])) {
    await repo.writeCardSnapshot(uid, snapshot);
  }
  return analysis;
}
