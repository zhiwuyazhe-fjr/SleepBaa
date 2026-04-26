import { createHash, randomUUID } from "node:crypto";
import {
  AIProvider,
  AIProviderSourceMode,
  DeterministicAIProvider,
  buildDeterministicProfileSummary,
  buildSystemIdentityReply,
  classifyIntent,
} from "../providers/ai_provider";
import { AssistantDataRepository } from "../repositories/firestore_repositories";
import { buildCardSnapshots } from "../services/materialize_card_snapshots";
import {
  AssistantContext,
  AssistantIntent,
  AssistantMemoryCandidate,
  AssistantMemoryItem,
  AssistantRunDoc,
  AssistantRunSourceMode,
  AssistantSurfacePatchDoc,
  AssistantThreadSummaryDoc,
  DreamAnalysis,
  InterferenceSnapshotDoc,
  MorningReviewResult,
  SleepCaptureKind,
  SleepCaptureRecordDoc,
  SurfaceId,
  TurnInsightExtraction,
  UserStateDoc,
} from "../shared/types";

function nowIso(): string {
  return new Date().toISOString();
}

type JsonMap = Record<string, unknown>;

function asMap(value: unknown): JsonMap {
  return value && typeof value === "object" && !Array.isArray(value)
    ? ({ ...(value as JsonMap) } as JsonMap)
    : {};
}

function asString(value: unknown, fallback = ""): string {
  return typeof value === "string" ? value : fallback;
}

function asStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.map((item) => String(item));
}

function sourceBodyHash(body: string): string {
  return createHash("sha256").update(body.trim(), "utf8").digest("hex");
}

function dreamAnalysisFromAi(value: unknown): DreamAnalysis | null {
  const ai = asMap(value);
  const summary = asString(ai.summary).trim();
  const dominantEmotion = asString(ai.dominantEmotion).trim();
  const suggestedFocus = asString(ai.suggestedFocus).trim();
  if (!summary || !dominantEmotion || !suggestedFocus) {
    return null;
  }
  return {
    summary,
    dominantEmotion,
    suggestedFocus,
    sourceRefs: asStringArray(ai.sourceRefs),
  };
}

const AUTO_TITLE_DEFAULTS = new Set<string>([
  "新对话",
  "新建对话",
  "新的助眠对话",
  "新的睡前陪伴对话",
  "今晚睡前聊聊",
  "梦记收纳",
  "事记收纳",
]);

function shouldAutoTitleThread(title: string): boolean {
  const normalized = title.trim();
  return normalized.length === 0 || AUTO_TITLE_DEFAULTS.has(normalized);
}

async function maybeAutoTitleAssistantThread(params: {
  repo: AssistantDataRepository;
  provider: AIProvider;
  uid: string;
  threadId: string;
  context: AssistantContext;
  prompt: string;
  reply: string;
}): Promise<string | null> {
  try {
    const thread = await params.repo.getAssistantThread(
      params.uid,
      params.threadId,
    );
    if (!thread || !shouldAutoTitleThread(asString(thread.title))) {
      return null;
    }
    const titleResult = await params.provider.generateConversationTitle(
      params.context,
      {
        prompt: params.prompt,
        reply: params.reply,
      },
    );
    const title = titleResult.value.trim();
    if (!title || title === asString(thread.title).trim()) {
      return null;
    }
    await params.repo.renameAssistantThread(params.uid, params.threadId, title);
    return title;
  } catch {
    return null;
  }
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
  return candidates.filter((item) =>
    source.toLowerCase().includes(item.toLowerCase()),
  );
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

function buildLegacyMemoryItems(
  uid: string,
  threadId: string,
  prompt: string,
): AssistantMemoryItem[] {
  const normalized = prompt.trim();
  if (!normalized) {
    return [];
  }

  const timestamp = nowIso();
  const keywords = extractKeywords(prompt, "");
  const candidates: Array<{ kind: string; test: boolean; confidence: number }> =
    [
      {
        kind: "preference",
        test: /喜欢|不喜欢|偏好|prefer|favorite/i.test(normalized),
        confidence: 0.76,
      },
      {
        kind: "profile",
        test: /我是|我叫|身份|角色|i am|my name/i.test(normalized),
        confidence: 0.7,
      },
      {
        kind: "goal",
        test: /目标|希望|想要|计划|goal|want to/i.test(normalized),
        confidence: 0.8,
      },
      {
        kind: "dorm_context",
        test: /宿舍|室友|寝室|roommate|dorm/i.test(normalized),
        confidence: 0.74,
      },
      {
        kind: "sleep_pattern",
        test: /睡不着|失眠|作息|早起|晚睡|经常|总是|sleep/i.test(normalized),
        confidence: 0.78,
      },
    ];

  return candidates
    .filter((item) => item.test)
    .slice(0, 3)
    .map((item) => ({
      id: `${uid}:${item.kind}:${normalized.toLowerCase().slice(0, 32)}`,
      kind: item.kind,
      content: normalized,
      canonicalKey: `${item.kind}:${normalized.toLowerCase().slice(0, 64)}`,
      keywords,
      confidence: item.confidence,
      sourceThreadId: threadId,
      sourceMessageId: null,
      salience: item.confidence,
      lastUsedAt: timestamp,
      sourceRefs: ["assistant_messages", `thread:${threadId}`],
      createdAt: timestamp,
      updatedAt: timestamp,
    }));
}

type FastPathKind =
  | "greeting"
  | "thanks"
  | "goodnight"
  | "acknowledge"
  | "emoji";

function normalizeFastPathText(prompt: string): string {
  return prompt.trim().toLowerCase().replace(/\s+/g, "");
}

function detectFastPathKind(prompt: string): FastPathKind | null {
  const normalized = normalizeFastPathText(prompt);
  if (!normalized || normalized.length > 24) {
    return null;
  }

  if (
    /^(hi+|hello+|hey+|yo+|你好+|您好+|嗨+|哈喽+|哈囉+|在吗|在嗎)$/.test(
      normalized,
    )
  ) {
    return "greeting";
  }
  if (
    /^(谢谢+|謝謝+|thanks+|thankyou+|3q+|thx+)$/.test(normalized)
  ) {
    return "thanks";
  }
  if (/^(晚安+|goodnight+|gn+|睡了|先睡了)$/.test(normalized)) {
    return "goodnight";
  }
  if (/^(好+|好的+|ok+|okay+|嗯+|恩+|收到+|行+)$/.test(normalized)) {
    return "acknowledge";
  }
  if (
    normalized.length <= 8 &&
    prompt.trim().length > 0 &&
    prompt.replace(/[\s\p{P}\p{S}]/gu, "").length === 0
  ) {
    return "emoji";
  }
  return null;
}

function buildFastPathReply(kind: FastPathKind): string {
  switch (kind) {
    case "greeting":
      return "在，我在这儿。你想随便聊聊，还是直接说说今晚哪里不舒服？";
    case "thanks":
      return "收到。不急，你继续说，我会帮你一起理清。";
    case "goodnight":
      return "晚安。先别急着逼自己马上睡着，慢慢放松下来就好。";
    case "acknowledge":
      return "好，我接着陪你。你要是愿意，可以继续补一句现在最在意的事。";
    case "emoji":
      return "我看到啦。你如果想继续说，我会接着听。";
  }
}

function shouldRunInsight(params: {
  intent: AssistantIntent;
  prompt: string;
}): boolean {
  if (params.intent === "system_identity") {
    return false;
  }
  if (
    params.intent === "sleep_difficulty" ||
    params.intent === "noise_issue" ||
    params.intent === "dream_reflection" ||
    params.intent === "plan_review"
  ) {
    return true;
  }

  const normalized = params.prompt.trim().toLowerCase();
  if (normalized.length < 8) {
    return false;
  }

  return /睡不着|失眠|宿舍|舍友|吵|噪音|灯|灯光|手机|屏幕|梦到|做梦|梦见|计划|复盘|焦虑|压力|难受|崩溃|情绪|建议|影响|作息|sleep|dream|plan|noise|stress|anx/i.test(
    normalized,
  );
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

function ensureUpdatedSurfaces(
  surfaces: SurfaceId[] | undefined,
  fallback: SurfaceId[] = ["assistant_context"],
): SurfaceId[] {
  const next = (surfaces ?? fallback).filter(Boolean);
  return Array.from(new Set(next.length > 0 ? next : fallback));
}

function mergeInterferenceSignals(
  current: UserStateDoc["tonightInterference"] | null | undefined,
  signals: InterferenceSnapshotDoc[],
): UserStateDoc["tonightInterference"] | null {
  if (signals.length === 0) {
    return current ?? null;
  }

  const byType = new Map<
    InterferenceSnapshotDoc["type"],
    InterferenceSnapshotDoc
  >();
  for (const item of [
    current?.noise,
    current?.light,
    current?.phoneUsage,
    current?.emotion,
  ]) {
    if (item) {
      byType.set(item.type, item);
    }
  }
  for (const item of signals) {
    byType.set(item.type, item);
  }

  return {
    noise:
      byType.get("noise") ??
      byType.values().next().value ??
      ({
        type: "noise",
        title: "宿舍噪声",
        value: "未更新",
        gradeLabel: "low",
        status: "idle",
        detail: "暂无新的噪声线索。",
        source: "assistant_turn_extract",
        measuredAt: null,
        numericValue: null,
        score: null,
      } satisfies InterferenceSnapshotDoc),
    light:
      byType.get("light") ??
      ({
        type: "light",
        title: "灯光环境",
        value: "未更新",
        gradeLabel: "low",
        status: "idle",
        detail: "暂无新的灯光线索。",
        source: "assistant_turn_extract",
        measuredAt: null,
        numericValue: null,
        score: null,
      } satisfies InterferenceSnapshotDoc),
    phoneUsage:
      byType.get("phoneUsage") ??
      ({
        type: "phoneUsage",
        title: "手机使用",
        value: "未更新",
        gradeLabel: "low",
        status: "idle",
        detail: "暂无新的手机使用线索。",
        source: "assistant_turn_extract",
        measuredAt: null,
        numericValue: null,
        score: null,
      } satisfies InterferenceSnapshotDoc),
    emotion:
      byType.get("emotion") ??
      ({
        type: "emotion",
        title: "情绪压力",
        value: "未更新",
        gradeLabel: "low",
        status: "idle",
        detail: "暂无新的情绪线索。",
        source: "assistant_turn_extract",
        measuredAt: null,
        numericValue: null,
        score: null,
      } satisfies InterferenceSnapshotDoc),
    updatedAt: nowIso(),
  };
}

function buildMemoryItemsFromCandidates(
  uid: string,
  candidates: AssistantMemoryCandidate[],
): AssistantMemoryItem[] {
  const timestamp = nowIso();
  return candidates.map((item) => {
    const canonicalKey = item.canonicalKey.trim();
    const safeKey = canonicalKey
      .replace(/[^a-z0-9\u4e00-\u9fff]+/gi, "-")
      .replace(/^-+|-+$/g, "")
      .slice(0, 64);
    return {
      id: `${uid}:${item.kind}:${safeKey || randomUUID()}`,
      kind: item.kind,
      content: item.content,
      canonicalKey,
      keywords: item.keywords,
      confidence: item.confidence,
      sourceThreadId: item.sourceThreadId ?? null,
      sourceMessageId: item.sourceMessageId ?? null,
      salience: item.salience,
      lastUsedAt: timestamp,
      sourceRefs: item.sourceRefs,
      createdAt: timestamp,
      updatedAt: timestamp,
    };
  });
}

function emptyInsightExtraction(): TurnInsightExtraction {
  return {
    interferenceSignals: [],
    actionSuggestions: [],
    memoryCandidates: [],
    shouldRefreshPlan: false,
    updatedSurfaces: ["assistant_context"],
  };
}

function buildSurfacePatch(params: {
  context: AssistantContext;
  userState: UserStateDoc;
  surfaces: SurfaceId[];
  extraRecords?: SleepCaptureRecordDoc[];
}): {
  snapshots: ReturnType<typeof buildCardSnapshots>;
  patch: AssistantSurfacePatchDoc;
} {
  const nextContext: AssistantContext = {
    ...params.context,
    userState: params.userState,
  };
  const snapshots = buildCardSnapshots(
    nextContext,
    params.userState,
    params.surfaces,
  );
  const snapshotMap = Object.fromEntries(
    snapshots.map((snapshot) => [snapshot.surfaceId, snapshot]),
  ) as AssistantSurfacePatchDoc["cardSnapshots"];
  return {
    snapshots,
    patch: {
      userState: params.userState,
      cardSnapshots: snapshotMap,
      ...(params.extraRecords && params.extraRecords.length > 0
        ? { sleepCaptureRecords: params.extraRecords }
        : {}),
    },
  };
}

async function writeSnapshots(
  repo: AssistantDataRepository,
  uid: string,
  snapshots: ReturnType<typeof buildCardSnapshots>,
): Promise<void> {
  for (const snapshot of snapshots) {
    await repo.writeCardSnapshot(uid, snapshot);
  }
}

function buildReplyContextOptions(
  intent: AssistantIntent,
  prompt: string,
): {
  profile: "reply_lite";
  recentSessionCount: number;
  recentDreamCount: number;
  messageCount: number;
  memoryLimit: number;
  memoryQuery: string;
} {
  return {
    profile: "reply_lite",
    recentSessionCount:
      intent === "sleep_difficulty" || intent === "plan_review" ? 2 : 1,
    recentDreamCount: intent === "dream_reflection" ? 1 : 0,
    messageCount: intent === "plan_review" ? 6 : 4,
    memoryLimit: intent === "plan_review" ? 3 : 2,
    memoryQuery: prompt,
  };
}

function buildInsightContextOptions(prompt: string): {
  profile: "insight_full";
  recentSessionCount: number;
  recentDreamCount: number;
  messageCount: number;
  memoryLimit: number;
  memoryQuery: string;
} {
  return {
    profile: "insight_full",
    recentSessionCount: 5,
    recentDreamCount: 3,
    messageCount: 8,
    memoryLimit: 6,
    memoryQuery: prompt,
  };
}

function buildAssistantUserStatePatch(params: {
  threadId: string;
  latestNightMood?: string | null;
  currentPhase?: UserStateDoc["currentPhase"];
}): Partial<UserStateDoc> {
  return {
    currentPhase: params.currentPhase ?? "assistant",
    latestThreadId: params.threadId,
    latestNightMood: params.latestNightMood ?? null,
    updatedAt: nowIso(),
  };
}

interface AssistantReplyPhaseResult {
  runId: string;
  prompt: string;
  threadId: string;
  intent: AssistantIntent;
  reply: string;
  provider: string;
  model: string;
  sourceMode: AIProviderSourceMode;
  errorMessage: string | null;
  replyContext: AssistantContext;
  previousUserState: UserStateDoc;
  shouldRunInsight: boolean;
  metrics: {
    startedAt: number;
    replyContextMs: number;
    firstDeltaMs: number | null;
    replyCompletedMs: number;
  };
}

export async function prepareAssistantReplyPhase(params: {
  repo: AssistantDataRepository;
  provider: AIProvider;
  uid: string;
  prompt: string;
  threadId: string;
  onDelta?: (delta: string) => Promise<void> | void;
}): Promise<AssistantReplyPhaseResult> {
  const startedAt = Date.now();
  const runId = randomUUID();
  const intent = classifyIntent(params.prompt);
  let firstDeltaMs: number | null = null;
  const emitDelta = async (delta: string): Promise<void> => {
    if (firstDeltaMs == null) {
      firstDeltaMs = Date.now() - startedAt;
    }
    if (params.onDelta) {
      await params.onDelta(delta);
    }
  };

  const replyContextStartedAt = Date.now();
  const replyContext = await params.repo.buildAssistantContext(
    params.uid,
    params.threadId,
    buildReplyContextOptions(intent, params.prompt),
  );
  const replyContextMs = Date.now() - replyContextStartedAt;
  const previousUserState = replyContext.userState ?? buildEmptyUserState();

  const replyResult =
    intent === "system_identity"
      ? {
          value: buildSystemIdentityReply({
            assistantName: replyContext.assistantProfile.assistantName,
            providerName: params.provider.providerName,
            modelName: params.provider.modelName,
            sourceMode: "fallbackSuccess",
          }).reply,
          providerName: params.provider.providerName,
          modelName: params.provider.modelName,
          sourceMode: "fallbackSuccess" as AIProviderSourceMode,
          errorMessage: null,
        }
      : await params.provider.streamReplyText(
          replyContext,
          intent,
          params.prompt,
          emitDelta,
        );

  if (intent === "system_identity") {
    await emitDelta(replyResult.value);
  }

  return {
    runId,
    prompt: params.prompt,
    threadId: params.threadId,
    intent,
    reply: replyResult.value,
    provider: replyResult.providerName,
    model: replyResult.modelName,
    sourceMode: replyResult.sourceMode,
    errorMessage: replyResult.errorMessage ?? null,
    replyContext,
    previousUserState,
    shouldRunInsight: shouldRunInsight({ intent, prompt: params.prompt }),
    metrics: {
      startedAt,
      replyContextMs,
      firstDeltaMs,
      replyCompletedMs: Date.now() - startedAt,
    },
  };
}

export async function finalizeAssistantReplyPostprocess(params: {
  repo: AssistantDataRepository;
  provider: AIProvider;
  uid: string;
  turnId: string;
  phase: AssistantReplyPhaseResult;
}): Promise<{
  updatedSurfaces: SurfaceId[];
  memorySyncedCount: number;
  skippedProjection: boolean;
}> {
  const threadSummary = buildThreadSummaryDoc(
    params.phase.replyContext,
    params.phase.threadId,
    params.phase.prompt,
    params.phase.reply,
  );
  await params.repo.writeAssistantThreadSummary(params.uid, threadSummary);
  await maybeAutoTitleAssistantThread({
    repo: params.repo,
    provider: params.provider,
    uid: params.uid,
    threadId: params.phase.threadId,
    context: params.phase.replyContext,
    prompt: params.phase.prompt,
    reply: params.phase.reply,
  });

  const statePatch = buildAssistantUserStatePatch({
    threadId: params.phase.threadId,
    latestNightMood:
      params.phase.replyContext.settings.selectedNightMood ??
      params.phase.previousUserState.latestNightMood,
  });

  const persistRunForPhase = async (input: {
    sourceMode: AIProviderSourceMode;
    errorMessage: string | null;
    updatedSurfaces: SurfaceId[];
    memorySyncedCount: number;
    insightMs: number;
    skippedProjection: boolean;
  }): Promise<void> => {
    await persistRun(params.repo, params.uid, params.phase.runId, {
      eventType: "assistant_reply",
      threadId: params.phase.threadId,
      provider: params.phase.provider,
      model: params.phase.model,
      status: runStatusFromSourceMode(input.sourceMode),
      sourceMode: input.sourceMode,
      inputRefs: ["assistant_threads.messages", "user_state", "sleep_sessions"],
      outputRefs: [
        "assistant_runs",
        "assistant_thread_summaries",
        ...(input.memorySyncedCount > 0 ? ["assistant_memory_items"] : []),
        ...(!input.skippedProjection ? ["user_state", ...input.updatedSurfaces] : []),
      ],
      error: input.errorMessage,
      createdAt: nowIso(),
      fastPath: false,
      replyContextMs: params.phase.metrics.replyContextMs,
      firstDeltaMs: params.phase.metrics.firstDeltaMs,
      replyCompletedMs: params.phase.metrics.replyCompletedMs,
      insightMs: input.insightMs,
      totalMs: Date.now() - params.phase.metrics.startedAt,
    });
  };

  const isCurrentCommittedTurn = () =>
    params.repo.isAssistantThreadCommittedTurn({
      uid: params.uid,
      threadId: params.phase.threadId,
      turnId: params.turnId,
    });

  if (!params.phase.shouldRunInsight) {
    const shouldProject = await isCurrentCommittedTurn();
    if (shouldProject) {
      await params.repo.writeUserState(params.uid, statePatch);
    }
    await persistRunForPhase({
      sourceMode: params.phase.sourceMode,
      errorMessage: params.phase.errorMessage,
      updatedSurfaces: shouldProject ? ["assistant_context"] : [],
      memorySyncedCount: 0,
      insightMs: 0,
      skippedProjection: !shouldProject,
    });
    return {
      updatedSurfaces: shouldProject ? ["assistant_context"] : [],
      memorySyncedCount: 0,
      skippedProjection: !shouldProject,
    };
  }

  if (!(await isCurrentCommittedTurn())) {
    const staleMemory = buildLegacyMemoryItems(
      params.uid,
      params.phase.threadId,
      params.phase.prompt,
    );
    if (staleMemory.length > 0) {
      await params.repo.upsertAssistantMemoryItems(params.uid, staleMemory);
    }
    await persistRunForPhase({
      sourceMode: params.phase.sourceMode,
      errorMessage: params.phase.errorMessage,
      updatedSurfaces: [],
      memorySyncedCount: staleMemory.length,
      insightMs: 0,
      skippedProjection: true,
    });
    return {
      updatedSurfaces: [],
      memorySyncedCount: staleMemory.length,
      skippedProjection: true,
    };
  }

  const insightStartedAt = Date.now();
  const insightContext = await params.repo.buildAssistantContext(
    params.uid,
    params.phase.threadId,
    buildInsightContextOptions(params.phase.prompt),
  );
  const baseState = insightContext.userState ?? params.phase.previousUserState;
  const insightResult = await params.provider.extractTurnInsights(insightContext, {
    threadId: params.phase.threadId,
    prompt: params.phase.prompt,
    reply: params.phase.reply,
    intent: params.phase.intent,
  });

  const mergedInterference = mergeInterferenceSignals(
    baseState.tonightInterference ?? insightContext.userState?.tonightInterference,
    insightResult.value.interferenceSignals,
  );

  let nextState: UserStateDoc = {
    ...baseState,
    currentPhase: "assistant",
    latestThreadId: params.phase.threadId,
    latestNightMood:
      insightContext.settings.selectedNightMood ??
      baseState.latestNightMood ??
      null,
    tonightInterference: mergedInterference,
    updatedAt: nowIso(),
    profileSummary: buildDeterministicProfileSummary({
      ...insightContext,
      userState: {
        ...baseState,
        currentPhase: "assistant",
        latestThreadId: params.phase.threadId,
        latestNightMood:
          insightContext.settings.selectedNightMood ??
          baseState.latestNightMood ??
          null,
        tonightInterference: mergedInterference,
        updatedAt: nowIso(),
      },
    }),
  };

  let planResult: Awaited<
    ReturnType<AIProvider["generateTonightPlan"]>
  > | null = null;
  if (insightResult.value.shouldRefreshPlan) {
    const planner = new DeterministicAIProvider();
    planResult = await planner.generateTonightPlan(
      { ...insightContext, userState: nextState },
      params.phase.runId,
    );
    nextState = {
      ...nextState,
      tonightPlan: planResult.value,
      updatedAt: nowIso(),
      profileSummary: buildDeterministicProfileSummary({
        ...insightContext,
        userState: {
          ...nextState,
          tonightPlan: planResult.value,
        },
      }),
    };
  }
  const insightMs = Date.now() - insightStartedAt;

  const updatedSurfaces = ensureUpdatedSurfaces(
    insightResult.value.updatedSurfaces,
    ["assistant_context"],
  );
  const memoryItems = buildMemoryItemsFromCandidates(
    params.uid,
    insightResult.value.memoryCandidates,
  );
  const fallbackMemory =
    memoryItems.length > 0
      ? memoryItems
      : buildLegacyMemoryItems(params.uid, params.phase.threadId, params.phase.prompt);
  if (fallbackMemory.length > 0) {
    await params.repo.upsertAssistantMemoryItems(params.uid, fallbackMemory);
  }

  const shouldProject = await isCurrentCommittedTurn();
  if (shouldProject) {
    await params.repo.writeUserState(params.uid, nextState);
    const { snapshots } = buildSurfacePatch({
      context: insightContext,
      userState: nextState,
      surfaces: updatedSurfaces,
    });
    await writeSnapshots(params.repo, params.uid, snapshots);
  }

  const combinedSourceMode = combineSourceModes([
    params.phase.sourceMode,
    insightResult.sourceMode,
    ...(planResult ? [planResult.sourceMode] : []),
  ]);
  const combinedError = combineErrorMessages(
    params.phase.errorMessage,
    insightResult.errorMessage,
    planResult?.errorMessage,
  );

  await persistRunForPhase({
    sourceMode: combinedSourceMode,
    errorMessage: combinedError,
    updatedSurfaces: shouldProject ? updatedSurfaces : [],
    memorySyncedCount: fallbackMemory.length,
    insightMs,
    skippedProjection: !shouldProject,
  });

  return {
    updatedSurfaces: shouldProject ? updatedSurfaces : [],
    memorySyncedCount: fallbackMemory.length,
    skippedProjection: !shouldProject,
  };
}

async function buildReplyOutcome(params: {
  repo: AssistantDataRepository;
  provider: AIProvider;
  uid: string;
  prompt: string;
  threadId: string;
  onDelta?: (delta: string) => Promise<void> | void;
  onReplyReady?: (payload: {
    reply: string;
    intent: AssistantIntent;
    provider: string;
    model: string;
    sourceMode: AIProviderSourceMode;
    errorMessage: string | null;
  }) => Promise<void> | void;
}): Promise<{
  runId: string;
  reply: string;
  intent: AssistantIntent;
  updatedSurfaces: SurfaceId[];
  userState: UserStateDoc;
  provider: string;
  model: string;
  sourceMode: AIProviderSourceMode;
  errorMessage: string | null;
  surfacePatch: AssistantSurfacePatchDoc;
  memorySyncedCount: number;
}> {
  const startedAt = Date.now();
  const runId = randomUUID();
  const intent = classifyIntent(params.prompt);
  let firstDeltaMs: number | null = null;
  const emitDelta = async (delta: string): Promise<void> => {
    if (firstDeltaMs == null) {
      firstDeltaMs = Date.now() - startedAt;
    }
    if (params.onDelta) {
      await params.onDelta(delta);
    }
  };
  const emitReplyReady = async (payload: {
    reply: string;
    intent: AssistantIntent;
    provider: string;
    model: string;
    sourceMode: AIProviderSourceMode;
    errorMessage: string | null;
  }): Promise<void> => {
    if (params.onReplyReady) {
      await params.onReplyReady(payload);
    }
  };

  const replyContextStartedAt = Date.now();
  const replyContext = await params.repo.buildAssistantContext(
    params.uid,
    params.threadId,
    buildReplyContextOptions(intent, params.prompt),
  );
  const replyContextMs = Date.now() - replyContextStartedAt;
  const previous = replyContext.userState ?? buildEmptyUserState();
  const planner = new DeterministicAIProvider();

  const replyResult =
    intent === "system_identity"
      ? {
          value: buildSystemIdentityReply({
            assistantName: replyContext.assistantProfile.assistantName,
            providerName: params.provider.providerName,
            modelName: params.provider.modelName,
            sourceMode: "fallbackSuccess",
          }).reply,
          providerName: params.provider.providerName,
          modelName: params.provider.modelName,
          sourceMode: "fallbackSuccess" as AIProviderSourceMode,
          errorMessage: null,
        }
      : await params.provider.streamReplyText(
          replyContext,
          intent,
          params.prompt,
          emitDelta,
        );

  if (intent === "system_identity") {
    await emitDelta(replyResult.value);
  }
  const replyCompletedMs = Date.now() - startedAt;
  await emitReplyReady({
    reply: replyResult.value,
    intent,
    provider: replyResult.providerName,
    model: replyResult.modelName,
    sourceMode: replyResult.sourceMode,
    errorMessage: replyResult.errorMessage ?? null,
  });

  const lightweightState = {
    ...previous,
    ...buildAssistantUserStatePatch({
      threadId: params.threadId,
      latestNightMood:
        replyContext.settings.selectedNightMood ?? previous.latestNightMood,
    }),
  } satisfies UserStateDoc;

  if (!shouldRunInsight({ intent, prompt: params.prompt })) {
    const statePatch = buildAssistantUserStatePatch({
      threadId: params.threadId,
      latestNightMood:
        replyContext.settings.selectedNightMood ?? previous.latestNightMood,
    });
    await params.repo.writeUserState(params.uid, statePatch);
    await params.repo.writeAssistantThreadSummary(
      params.uid,
      buildThreadSummaryDoc(
        replyContext,
        params.threadId,
        params.prompt,
        replyResult.value,
      ),
    );
    await maybeAutoTitleAssistantThread({
      repo: params.repo,
      provider: params.provider,
      uid: params.uid,
      threadId: params.threadId,
      context: replyContext,
      prompt: params.prompt,
      reply: replyResult.value,
    });
    await persistRun(params.repo, params.uid, runId, {
      eventType: "assistant_reply",
      threadId: params.threadId,
      provider: replyResult.providerName,
      model: replyResult.modelName,
      status: runStatusFromSourceMode(replyResult.sourceMode),
      sourceMode: replyResult.sourceMode,
      inputRefs: ["assistant_threads.messages", "user_state", "sleep_sessions"],
      outputRefs: ["assistant_runs", "user_state"],
      error: replyResult.errorMessage ?? null,
      createdAt: nowIso(),
      fastPath: false,
      replyContextMs,
      firstDeltaMs,
      replyCompletedMs,
      insightMs: 0,
      totalMs: Date.now() - startedAt,
    });
    return {
      runId,
      reply: replyResult.value,
      intent,
      updatedSurfaces: ["assistant_context"],
      userState: lightweightState,
      provider: replyResult.providerName,
      model: replyResult.modelName,
      sourceMode: replyResult.sourceMode,
      errorMessage: replyResult.errorMessage ?? null,
      surfacePatch: {
        userState: statePatch,
      },
      memorySyncedCount: 0,
    };
  }

  const insightStartedAt = Date.now();
  const insightContext =
    intent === "system_identity"
      ? replyContext
      : await params.repo.buildAssistantContext(
          params.uid,
          params.threadId,
          buildInsightContextOptions(params.prompt),
        );
  const baseState = insightContext.userState ?? previous;

  const insightResult =
    intent === "system_identity"
      ? {
          value: emptyInsightExtraction(),
          providerName: params.provider.providerName,
          modelName: params.provider.modelName,
          sourceMode: "fallbackSuccess" as AIProviderSourceMode,
          errorMessage: null,
        }
      : await params.provider.extractTurnInsights(insightContext, {
          threadId: params.threadId,
          prompt: params.prompt,
          reply: replyResult.value,
          intent,
        });

  const mergedInterference = mergeInterferenceSignals(
    baseState.tonightInterference ??
      insightContext.userState?.tonightInterference,
    insightResult.value.interferenceSignals,
  );

  let nextState: UserStateDoc = {
    ...baseState,
    currentPhase: "assistant",
    latestThreadId: params.threadId,
    latestNightMood:
      insightContext.settings.selectedNightMood ??
      baseState.latestNightMood ??
      null,
    tonightInterference: mergedInterference,
    updatedAt: nowIso(),
    profileSummary: buildDeterministicProfileSummary({
      ...insightContext,
      userState: {
        ...baseState,
        currentPhase: "assistant",
        latestThreadId: params.threadId,
        latestNightMood:
          insightContext.settings.selectedNightMood ??
          baseState.latestNightMood ??
          null,
        tonightInterference: mergedInterference,
        updatedAt: nowIso(),
      },
    }),
  };

  let planResult: Awaited<
    ReturnType<AIProvider["generateTonightPlan"]>
  > | null = null;
  if (insightResult.value.shouldRefreshPlan) {
    planResult = await planner.generateTonightPlan(
      { ...insightContext, userState: nextState },
      runId,
    );
    nextState = {
      ...nextState,
      tonightPlan: planResult.value,
      updatedAt: nowIso(),
      profileSummary: buildDeterministicProfileSummary({
        ...insightContext,
        userState: {
          ...nextState,
          tonightPlan: planResult.value,
        },
      }),
    };
  }
  const insightMs = Date.now() - insightStartedAt;

  await params.repo.writeUserState(params.uid, nextState);

  const updatedSurfaces = ensureUpdatedSurfaces(
    insightResult.value.updatedSurfaces,
    ["assistant_context"],
  );
  const { snapshots, patch } = buildSurfacePatch({
    context: insightContext,
    userState: nextState,
    surfaces: updatedSurfaces,
  });
  await writeSnapshots(params.repo, params.uid, snapshots);

  const combinedSourceMode = combineSourceModes([
    replyResult.sourceMode,
    insightResult.sourceMode,
    ...(planResult ? [planResult.sourceMode] : []),
  ]);
  const combinedError = combineErrorMessages(
    replyResult.errorMessage,
    insightResult.errorMessage,
    planResult?.errorMessage,
  );

  await persistRun(params.repo, params.uid, runId, {
    eventType: "assistant_reply",
    threadId: params.threadId,
    provider: replyResult.providerName,
    model: replyResult.modelName,
    status: runStatusFromSourceMode(combinedSourceMode),
    sourceMode: combinedSourceMode,
    inputRefs: ["assistant_threads.messages", "user_state", "sleep_sessions"],
    outputRefs: ["users.assistant_runs", "user_state", ...updatedSurfaces],
    error: combinedError,
    createdAt: nowIso(),
    fastPath: false,
    replyContextMs,
    firstDeltaMs,
    replyCompletedMs,
    insightMs,
    totalMs: Date.now() - startedAt,
  });

  await params.repo.writeAssistantThreadSummary(
    params.uid,
    buildThreadSummaryDoc(
      insightContext,
      params.threadId,
      params.prompt,
      replyResult.value,
    ),
  );
  await maybeAutoTitleAssistantThread({
    repo: params.repo,
    provider: params.provider,
    uid: params.uid,
    threadId: params.threadId,
    context: insightContext,
    prompt: params.prompt,
    reply: replyResult.value,
  });

  const memoryItems = buildMemoryItemsFromCandidates(
    params.uid,
    insightResult.value.memoryCandidates,
  );
  const fallbackMemory =
    memoryItems.length > 0
      ? memoryItems
      : buildLegacyMemoryItems(params.uid, params.threadId, params.prompt);
  if (fallbackMemory.length > 0) {
    await params.repo.upsertAssistantMemoryItems(params.uid, fallbackMemory);
  }

  return {
    runId,
    reply: replyResult.value,
    intent,
    updatedSurfaces,
    userState: nextState,
    provider: replyResult.providerName,
    model: replyResult.modelName,
    sourceMode: combinedSourceMode,
    errorMessage: combinedError,
    surfacePatch: patch,
    memorySyncedCount: fallbackMemory.length,
  };
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
  await writeSnapshots(
    repo,
    uid,
    buildCardSnapshots(context, userState, updatedSurfaces),
  );

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
  onDelta?: (delta: string) => Promise<void> | void,
  onReplyReady?: (payload: {
    reply: string;
    intent: AssistantIntent;
    provider: string;
    model: string;
    sourceMode: AIProviderSourceMode;
    errorMessage: string | null;
  }) => Promise<void> | void,
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
  surfacePatch: AssistantSurfacePatchDoc;
  memorySyncedCount: number;
}> {
  return buildReplyOutcome({
    repo,
    provider,
    uid,
    prompt,
    threadId,
    onDelta,
    onReplyReady,
  });
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
  record: SleepCaptureRecordDoc;
  surfacePatch: AssistantSurfacePatchDoc;
  memorySyncedCount: number;
}> {
  const runId = randomUUID();
  const context = await repo.buildAssistantContext(uid, threadId, {
    profile: "capture_full",
    recentSessionCount: 5,
    recentDreamCount: 3,
    messageCount: 8,
    memoryLimit: 6,
    memoryQuery: prompt,
  });
  const previous = context.userState ?? buildEmptyUserState();
  const captureResult = await provider.generateSleepCapture(context, {
    prompt,
    captureType,
    sessionId,
  });
  const draft = captureResult.value;
  const record = (await repo.saveSleepCaptureRecord(uid, {
    type: draft.type,
    sessionId,
    createdAt: nowIso(),
    title: draft.title,
    outline: draft.outline,
    content: draft.content,
  })) as unknown as SleepCaptureRecordDoc;

  const nextState: UserStateDoc = {
    ...previous,
    latestThreadId: threadId,
    updatedAt: nowIso(),
  };

  await repo.writeUserState(uid, nextState);
  const updatedSurfaces: SurfaceId[] = ["assistant_context"];
  const { snapshots, patch } = buildSurfacePatch({
    context,
    userState: nextState,
    surfaces: updatedSurfaces,
    extraRecords: [record],
  });
  await writeSnapshots(repo, uid, snapshots);

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

  await repo.writeAssistantThreadSummary(
    uid,
    buildThreadSummaryDoc(context, threadId, prompt, draft.reply),
  );
  const longTermMemory = buildLegacyMemoryItems(uid, threadId, prompt);
  if (longTermMemory.length > 0) {
    await repo.upsertAssistantMemoryItems(uid, longTermMemory);
  }
  await maybeAutoTitleAssistantThread({
    repo,
    provider,
    uid,
    threadId,
    context,
    prompt,
    reply: draft.reply,
  });

  return {
    runId,
    reply: draft.reply,
    updatedSurfaces,
    userState: nextState,
    provider: captureResult.providerName,
    model: captureResult.modelName,
    sourceMode: captureResult.sourceMode,
    errorMessage: captureResult.errorMessage ?? null,
    record,
    surfacePatch: patch,
    memorySyncedCount: longTermMemory.length,
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
  await writeSnapshots(repo, uid, snapshots);
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
    await writeSnapshots(
      repo,
      uid,
      buildCardSnapshots(context, nextState, ["sleep_mode"]),
    );
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
    await writeSnapshots(
      repo,
      uid,
      buildCardSnapshots(context, nextState, ["morning_feedback"]),
    );
    await repo.upsertNotification(uid, `feedback-${sessionId}`, {
      id: `feedback-${sessionId}`,
      category: "reminder",
      title: "晨间反馈待完成",
      body: "补完昨晚的晨间反馈后，AI 才能继续优化下一晚的睡眠建议。",
      route: `/feedback/morning?sessionId=${encodeURIComponent(sessionId)}`,
      createdAt: nowIso(),
      ownerUid: uid,
      readAt: null,
    });
    return;
  }

  if (afterStatus === "paused") {
    const nextState: UserStateDoc = {
      ...previous,
      currentPhase: "home_pre_sleep",
      activeSessionId: null,
      updatedAt: nowIso(),
    };
    await repo.writeUserState(uid, nextState);
    await writeSnapshots(
      repo,
      uid,
      buildCardSnapshots(context, nextState, [
        "home_pre_sleep",
        "profile_report",
      ]),
    );
    return;
  }

  if (afterStatus === "completed" && beforeStatus !== "completed") {
    const review: MorningReviewResult = (
      await provider.analyzeFeedback(context, sessionId)
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
    await writeSnapshots(
      repo,
      uid,
      buildCardSnapshots(context, nextState, [
        "profile_report",
        "morning_feedback",
        "assistant_context",
      ]),
    );
  }
}

export async function handleDreamEntryChange(
  repo: AssistantDataRepository,
  provider: AIProvider,
  uid: string,
  entryId: string,
  body: string,
): Promise<DreamAnalysis> {
  const bodyHash = sourceBodyHash(body);
  const existingEntry = await repo.getDreamEntry(entryId);
  const existingAi = asMap(existingEntry?.ai);
  if (asString(existingAi.sourceBodyHash) === bodyHash) {
    const existingAnalysis = dreamAnalysisFromAi(existingAi);
    if (existingAnalysis) {
      return existingAnalysis;
    }
  }

  const context = await repo.buildAssistantContext(uid);
  const previous = context.userState ?? buildEmptyUserState();
  const analysis = (await provider.summarizeDream(body, context)).value;
  await repo.setDreamAnalysis(entryId, analysis, bodyHash);

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
  await writeSnapshots(
    repo,
    uid,
    buildCardSnapshots(context, nextState, [
      "profile_report",
      "assistant_context",
    ]),
  );
  return analysis;
}
