import {
  AIProvider,
  AIProviderResult,
  DeterministicAIProvider,
} from "./ai_provider";
import {
  AssistantContext,
  AssistantIntent,
  AssistantPromptMode,
  DreamAnalysis,
  InterferenceFactor,
  InterferenceSnapshotDoc,
  MorningReviewResult,
  RecommendedAction,
  SleepCaptureDraft,
  SleepCaptureKind,
  StructuredAssistantReply,
  SurfaceId,
  TurnInsightExtraction,
  TonightPlan,
} from "../shared/types";

type JsonMap = Record<string, unknown>;

function asMap(value: unknown): JsonMap {
  return value && typeof value === "object" && !Array.isArray(value)
    ? ({ ...(value as JsonMap) } as JsonMap)
    : {};
}

function asString(value: unknown, fallback = ""): string {
  return typeof value === "string" ? value : fallback;
}

function asBoolean(value: unknown, fallback = false): boolean {
  return typeof value === "boolean" ? value : fallback;
}

function asNumber(value: unknown, fallback = 0): number {
  return typeof value === "number" ? value : fallback;
}

function asStringArray(value: unknown, fallback: string[] = []): string[] {
  if (!Array.isArray(value)) {
    return fallback;
  }
  return value
    .map((item) => String(item).trim())
    .filter((item) => item.length > 0);
}

function errorMessageOf(error: unknown): string {
  if (error instanceof Error) {
    const cause = asMap((error as Error & { cause?: unknown }).cause);
    const causeCode = asString(cause.code);
    const causeMessage = asString(cause.message);
    const details = [causeCode, causeMessage].filter(
      (item) => item.trim().length > 0,
    );
    return details.length > 0
      ? `${error.message}: ${details.join(" ")}`
      : error.message;
  }
  return String(error ?? "Unknown AI provider error.");
}

function extractOpenAICompatibleTextContent(value: unknown): string {
  if (typeof value === "string") {
    return value;
  }
  if (!Array.isArray(value)) {
    return "";
  }
  return value
    .map((item) => {
      const itemMap = asMap(item);
      return asString(itemMap.text);
    })
    .join("");
}

function extractOpenAICompatibleMessageContent(payloadMap: JsonMap): string {
  const choices = Array.isArray(payloadMap.choices) ? payloadMap.choices : [];
  const firstChoice = asMap(choices[0]);
  const message = asMap(firstChoice.message);
  const delta = asMap(firstChoice.delta);
  return (
    extractOpenAICompatibleTextContent(delta.content) ||
    extractOpenAICompatibleTextContent(message.content)
  );
}

async function consumeOpenAICompatibleSseTextStream(params: {
  response: Response;
  onDelta?: (delta: string) => Promise<void> | void;
}): Promise<string> {
  if (!params.response.body) {
    return "";
  }

  const reader = params.response.body.getReader();
  const decoder = new TextDecoder();
  const dataLines: string[] = [];
  let reply = "";
  let buffer = "";

  const flushFrame = async (): Promise<void> => {
    if (dataLines.length == 0) {
      return;
    }
    const data = dataLines.join("\n").trim();
    dataLines.length = 0;
    if (!data || data === "[DONE]") {
      return;
    }
    const payloadMap = asMap(JSON.parse(data));
    const delta = extractOpenAICompatibleMessageContent(payloadMap);
    if (!delta) {
      return;
    }
    reply += delta;
    if (params.onDelta) {
      await params.onDelta(delta);
    }
  };

  while (true) {
    const { done, value } = await reader.read();
    buffer += decoder.decode(value, { stream: !done });
    buffer = buffer.replace(/\r\n/g, "\n");

    while (true) {
      const newlineIndex = buffer.indexOf("\n");
      if (newlineIndex == -1) {
        break;
      }
      const line = buffer.slice(0, newlineIndex);
      buffer = buffer.slice(newlineIndex + 1);
      if (!line) {
        await flushFrame();
        continue;
      }
      if (line.startsWith("data:")) {
        dataLines.push(line.slice("data:".length).trimStart());
      }
    }

    if (done) {
      break;
    }
  }

  if (buffer.startsWith("data:")) {
    dataLines.push(buffer.slice("data:".length).trimStart());
  }
  await flushFrame();
  return reply;
}

function normalizeSurfaceIds(
  value: unknown,
  fallback: SurfaceId[],
): SurfaceId[] {
  const allowed: SurfaceId[] = [
    "home_pre_sleep",
    "sleep_mode",
    "morning_feedback",
    "profile_report",
    "assistant_context",
  ];
  if (!Array.isArray(value)) {
    return fallback;
  }
  const next = value
    .map((item) => String(item))
    .filter((item): item is SurfaceId => allowed.includes(item as SurfaceId));
  return next.length > 0 ? next : fallback;
}

function normalizeActions(
  value: unknown,
  fallback: RecommendedAction[],
): RecommendedAction[] {
  if (!Array.isArray(value)) {
    return fallback;
  }

  const next: RecommendedAction[] = [];
  for (const [index, item] of value.entries()) {
    const data = asMap(item);
    const fallbackItem = fallback[index] ?? fallback[0];
    if (!fallbackItem) {
      continue;
    }
    const trackId = asString(data.trackId, fallbackItem.trackId ?? "");
    next.push({
      id: asString(data.id, fallbackItem.id),
      title: asString(data.title, fallbackItem.title),
      subtitle: asString(data.subtitle, fallbackItem.subtitle),
      type: data.type === "audio" ? "audio" : fallbackItem.type,
      priority: asNumber(data.priority, fallbackItem.priority),
      reason: asString(data.reason, fallbackItem.reason),
      route: asString(data.route, fallbackItem.route),
      trackId: trackId.length === 0 ? null : trackId,
      tags: asStringArray(data.tags, fallbackItem.tags),
    });
  }
  return next.length > 0 ? next : fallback;
}

function normalizeFactors(
  value: unknown,
  fallback: InterferenceFactor[],
): InterferenceFactor[] {
  if (!Array.isArray(value)) {
    return fallback;
  }

  const next = value
    .map((item, index) => {
      const data = asMap(item);
      const fallbackItem = fallback[index] ?? fallback[0];
      if (!fallbackItem) {
        return null;
      }
      return {
        key: asString(data.key, fallbackItem.key),
        label: asString(data.label, fallbackItem.label),
        score: asNumber(data.score, fallbackItem.score),
        evidence: asString(data.evidence, fallbackItem.evidence),
        sourceRefs: asStringArray(data.sourceRefs, fallbackItem.sourceRefs),
      } satisfies InterferenceFactor;
    })
    .filter((item): item is InterferenceFactor => item !== null);

  return next.length > 0 ? next : fallback;
}

function normalizeStructuredReply(
  value: unknown,
  fallback: StructuredAssistantReply,
): StructuredAssistantReply {
  const data = asMap(value);
  return {
    reply: asString(data.reply, fallback.reply),
    intent: asString(data.intent, fallback.intent) as AssistantIntent,
    recommendedActions: normalizeActions(
      data.recommendedActions,
      fallback.recommendedActions,
    ),
    updateTonightPlan: asBoolean(
      data.updateTonightPlan,
      fallback.updateTonightPlan,
    ),
    updatedSurfaces: normalizeSurfaceIds(
      data.updatedSurfaces,
      fallback.updatedSurfaces,
    ),
  };
}

function normalizeTonightPlan(
  value: unknown,
  fallback: TonightPlan,
): TonightPlan {
  const data = asMap(value);
  const riskLevel = asString(data.riskLevel, fallback.riskLevel);
  return {
    dateKey: asString(data.dateKey, fallback.dateKey),
    coachSummary: asString(data.coachSummary, fallback.coachSummary),
    riskLevel:
      riskLevel === "high" || riskLevel === "medium" || riskLevel === "low"
        ? riskLevel
        : fallback.riskLevel,
    topFactors: normalizeFactors(data.topFactors, fallback.topFactors),
    recommendedActions: normalizeActions(
      data.recommendedActions,
      fallback.recommendedActions,
    ),
    generatedAt: asString(data.generatedAt, fallback.generatedAt),
    sourceRunId: asString(data.sourceRunId, fallback.sourceRunId),
  };
}

function normalizeDreamAnalysis(
  value: unknown,
  fallback: DreamAnalysis,
): DreamAnalysis {
  const data = asMap(value);
  return {
    summary: asString(data.summary, fallback.summary),
    dominantEmotion: asString(data.dominantEmotion, fallback.dominantEmotion),
    suggestedFocus: asString(data.suggestedFocus, fallback.suggestedFocus),
    sourceRefs: asStringArray(data.sourceRefs, fallback.sourceRefs),
  };
}

function normalizeMorningReview(
  value: unknown,
  fallback: MorningReviewResult,
): MorningReviewResult {
  const data = asMap(value);
  const profileSummary = asMap(data.profileSummary);
  return {
    reviewSummary: asString(data.reviewSummary, fallback.reviewSummary),
    effectiveActions: asStringArray(
      data.effectiveActions,
      fallback.effectiveActions,
    ),
    ineffectiveActions: asStringArray(
      data.ineffectiveActions,
      fallback.ineffectiveActions,
    ),
    profileSummary: {
      sleepPatternSummary: asString(
        profileSummary.sleepPatternSummary,
        fallback.profileSummary.sleepPatternSummary,
      ),
      highRiskFactors: asStringArray(
        profileSummary.highRiskFactors,
        fallback.profileSummary.highRiskFactors,
      ),
      effectiveActions: asStringArray(
        profileSummary.effectiveActions,
        fallback.profileSummary.effectiveActions,
      ),
      dreamTrendSummary: asString(
        profileSummary.dreamTrendSummary,
        fallback.profileSummary.dreamTrendSummary,
      ),
      emotionTrendSummary: asString(
        profileSummary.emotionTrendSummary,
        fallback.profileSummary.emotionTrendSummary,
      ),
      lastUpdatedAt: asString(
        profileSummary.lastUpdatedAt,
        fallback.profileSummary.lastUpdatedAt,
      ),
    },
  };
}

function normalizeSleepCaptureDraft(
  value: unknown,
  fallback: SleepCaptureDraft,
): SleepCaptureDraft {
  const data = asMap(value);
  const type = asString(data.type, fallback.type);
  return {
    type: type === "dream" || type === "memo" ? type : fallback.type,
    title: asString(data.title, fallback.title),
    outline: asString(data.outline, fallback.outline),
    content: asString(data.content, fallback.content),
    reply: asString(data.reply, fallback.reply),
  };
}

function normalizeInterferenceSignals(
  value: unknown,
  fallback: InterferenceSnapshotDoc[] = [],
): InterferenceSnapshotDoc[] {
  if (!Array.isArray(value)) {
    return fallback;
  }
  const next: InterferenceSnapshotDoc[] = [];
  for (const [index, item] of value.entries()) {
    const data = asMap(item);
    const fallbackItem = fallback[index];
    const type = asString(data.type, fallbackItem?.type ?? "emotion");
    if (
      type !== "noise" &&
      type !== "light" &&
      type !== "phoneUsage" &&
      type !== "emotion"
    ) {
      continue;
    }
    next.push({
      type,
      title: asString(data.title, fallbackItem?.title ?? ""),
      value: asString(data.value, fallbackItem?.value ?? ""),
      gradeLabel: asString(data.gradeLabel, fallbackItem?.gradeLabel ?? "low"),
      status: asString(
        data.status,
        fallbackItem?.status ?? "ready",
      ) as InterferenceSnapshotDoc["status"],
      detail: asString(data.detail, fallbackItem?.detail ?? ""),
      source: asString(
        data.source,
        fallbackItem?.source ?? "assistant_turn_extract",
      ),
      measuredAt:
        asString(data.measuredAt, fallbackItem?.measuredAt ?? "") || null,
      numericValue:
        typeof data.numericValue === "number"
          ? data.numericValue
          : (fallbackItem?.numericValue ?? null),
      score:
        typeof data.score === "number"
          ? data.score
          : (fallbackItem?.score ?? null),
    });
  }
  return next;
}

function normalizeMemoryCandidates(
  value: unknown,
  fallback: TurnInsightExtraction["memoryCandidates"] = [],
): TurnInsightExtraction["memoryCandidates"] {
  if (!Array.isArray(value)) {
    return fallback;
  }
  const next: TurnInsightExtraction["memoryCandidates"] = [];
  for (const [index, item] of value.entries()) {
    const data = asMap(item);
    const fallbackItem = fallback[index];
    const kind = asString(data.kind, fallbackItem?.kind ?? "");
    const content = asString(data.content, fallbackItem?.content ?? "");
    const canonicalKey = asString(
      data.canonicalKey,
      fallbackItem?.canonicalKey ?? "",
    );
    if (!kind || !content || !canonicalKey) {
      continue;
    }
    next.push({
      kind,
      content,
      canonicalKey,
      keywords: asStringArray(data.keywords, fallbackItem?.keywords ?? []),
      confidence: asNumber(data.confidence, fallbackItem?.confidence ?? 0.7),
      salience: asNumber(data.salience, fallbackItem?.salience ?? 0.7),
      sourceThreadId:
        asString(data.sourceThreadId, fallbackItem?.sourceThreadId ?? "") ||
        null,
      sourceMessageId:
        asString(data.sourceMessageId, fallbackItem?.sourceMessageId ?? "") ||
        null,
      sourceRefs: asStringArray(
        data.sourceRefs,
        fallbackItem?.sourceRefs ?? [],
      ),
    });
  }
  return next;
}

function normalizeTurnInsightExtraction(
  value: unknown,
  fallback: TurnInsightExtraction,
): TurnInsightExtraction {
  const data = asMap(value);
  return {
    interferenceSignals: normalizeInterferenceSignals(
      data.interferenceSignals,
      fallback.interferenceSignals,
    ),
    actionSuggestions: normalizeActions(
      data.actionSuggestions,
      fallback.actionSuggestions,
    ),
    memoryCandidates: normalizeMemoryCandidates(
      data.memoryCandidates,
      fallback.memoryCandidates,
    ),
    shouldRefreshPlan: asBoolean(
      data.shouldRefreshPlan,
      fallback.shouldRefreshPlan,
    ),
    updatedSurfaces: normalizeSurfaceIds(
      data.updatedSurfaces,
      fallback.updatedSurfaces,
    ),
  };
}

const ASSISTANT_INTENTS: AssistantIntent[] = [
  "general_support",
  "sleep_difficulty",
  "noise_issue",
  "dream_reflection",
  "plan_review",
  "system_identity",
];

function nonEmptyString(value: unknown): boolean {
  return typeof value === "string" && value.trim().length > 0;
}

function missingStructuredReplyFields(data: JsonMap): string[] {
  const missing: string[] = [];
  if (!nonEmptyString(data.reply)) {
    missing.push("reply");
  }
  if (!ASSISTANT_INTENTS.includes(asString(data.intent) as AssistantIntent)) {
    missing.push("intent");
  }
  if (typeof data.updateTonightPlan !== "boolean") {
    missing.push("updateTonightPlan");
  }
  if (!Array.isArray(data.updatedSurfaces)) {
    missing.push("updatedSurfaces");
  }
  if (!Array.isArray(data.recommendedActions)) {
    missing.push("recommendedActions");
  }
  return missing;
}

function missingTonightPlanFields(data: JsonMap): string[] {
  const missing: string[] = [];
  if (!nonEmptyString(data.dateKey)) {
    missing.push("dateKey");
  }
  if (!nonEmptyString(data.coachSummary)) {
    missing.push("coachSummary");
  }
  const riskLevel = asString(data.riskLevel);
  if (riskLevel !== "low" && riskLevel !== "medium" && riskLevel !== "high") {
    missing.push("riskLevel");
  }
  if (!Array.isArray(data.topFactors)) {
    missing.push("topFactors");
  }
  if (!Array.isArray(data.recommendedActions)) {
    missing.push("recommendedActions");
  }
  if (!nonEmptyString(data.generatedAt)) {
    missing.push("generatedAt");
  }
  if (!nonEmptyString(data.sourceRunId)) {
    missing.push("sourceRunId");
  }
  return missing;
}

function missingDreamAnalysisFields(data: JsonMap): string[] {
  const missing: string[] = [];
  if (!nonEmptyString(data.summary)) {
    missing.push("summary");
  }
  if (!nonEmptyString(data.dominantEmotion)) {
    missing.push("dominantEmotion");
  }
  if (!nonEmptyString(data.suggestedFocus)) {
    missing.push("suggestedFocus");
  }
  if (!Array.isArray(data.sourceRefs)) {
    missing.push("sourceRefs");
  }
  return missing;
}

function missingProfileSummaryFields(data: JsonMap): string[] {
  const missing: string[] = [];
  if (!nonEmptyString(data.sleepPatternSummary)) {
    missing.push("profileSummary.sleepPatternSummary");
  }
  if (!Array.isArray(data.highRiskFactors)) {
    missing.push("profileSummary.highRiskFactors");
  }
  if (!Array.isArray(data.effectiveActions)) {
    missing.push("profileSummary.effectiveActions");
  }
  if (!nonEmptyString(data.dreamTrendSummary)) {
    missing.push("profileSummary.dreamTrendSummary");
  }
  if (!nonEmptyString(data.emotionTrendSummary)) {
    missing.push("profileSummary.emotionTrendSummary");
  }
  if (!nonEmptyString(data.lastUpdatedAt)) {
    missing.push("profileSummary.lastUpdatedAt");
  }
  return missing;
}

function missingMorningReviewFields(data: JsonMap): string[] {
  const missing: string[] = [];
  if (!nonEmptyString(data.reviewSummary)) {
    missing.push("reviewSummary");
  }
  if (!Array.isArray(data.effectiveActions)) {
    missing.push("effectiveActions");
  }
  if (!Array.isArray(data.ineffectiveActions)) {
    missing.push("ineffectiveActions");
  }
  missing.push(...missingProfileSummaryFields(asMap(data.profileSummary)));
  return missing;
}

function missingSleepCaptureDraftFields(data: JsonMap): string[] {
  const missing: string[] = [];
  const type = asString(data.type);
  if (type !== "dream" && type !== "memo") {
    missing.push("type");
  }
  if (!nonEmptyString(data.title)) {
    missing.push("title");
  }
  if (!nonEmptyString(data.outline)) {
    missing.push("outline");
  }
  if (!nonEmptyString(data.content)) {
    missing.push("content");
  }
  if (!nonEmptyString(data.reply)) {
    missing.push("reply");
  }
  return missing;
}

function missingTurnInsightFields(data: JsonMap): string[] {
  const missing: string[] = [];
  if (!Array.isArray(data.interferenceSignals)) {
    missing.push("interferenceSignals");
  }
  if (!Array.isArray(data.actionSuggestions)) {
    missing.push("actionSuggestions");
  }
  if (!Array.isArray(data.memoryCandidates)) {
    missing.push("memoryCandidates");
  }
  if (typeof data.shouldRefreshPlan !== "boolean") {
    missing.push("shouldRefreshPlan");
  }
  if (!Array.isArray(data.updatedSurfaces)) {
    missing.push("updatedSurfaces");
  }
  return missing;
}

function ensureStructuredReplyCandidate(value: unknown): JsonMap {
  const data = asMap(value);
  const missing = missingStructuredReplyFields(data);
  if (missing.length > 0) {
    throw new Error(
      `Remote structured assistant reply missing required fields: ${missing.join(", ")}`,
    );
  }
  return data;
}

function ensureTonightPlanCandidate(value: unknown): JsonMap {
  const data = asMap(value);
  const missing = missingTonightPlanFields(data);
  if (missing.length > 0) {
    throw new Error(
      `Remote tonight plan missing required fields: ${missing.join(", ")}`,
    );
  }
  return data;
}

function ensureDreamAnalysisCandidate(value: unknown): JsonMap {
  const data = asMap(value);
  const missing = missingDreamAnalysisFields(data);
  if (missing.length > 0) {
    throw new Error(
      `Remote dream analysis missing required fields: ${missing.join(", ")}`,
    );
  }
  return data;
}

function ensureMorningReviewCandidate(value: unknown): JsonMap {
  const data = asMap(value);
  const missing = missingMorningReviewFields(data);
  if (missing.length > 0) {
    throw new Error(
      `Remote morning review missing required fields: ${missing.join(", ")}`,
    );
  }
  return data;
}

function ensureSleepCaptureCandidate(value: unknown): JsonMap {
  const data = asMap(value);
  const missing = missingSleepCaptureDraftFields(data);
  if (missing.length > 0) {
    throw new Error(
      `Remote sleep capture draft missing required fields: ${missing.join(", ")}`,
    );
  }
  return data;
}

function ensureTurnInsightCandidate(value: unknown): JsonMap {
  const data = asMap(value);
  const missing = missingTurnInsightFields(data);
  if (missing.length > 0) {
    throw new Error(
      `Remote turn insight extraction missing required fields: ${missing.join(", ")}`,
    );
  }
  return data;
}

function extractJsonObject(text: string): JsonMap {
  const trimmed = text.trim();
  if (!trimmed) {
    return {};
  }

  try {
    return asMap(JSON.parse(trimmed));
  } catch {
    const start = trimmed.indexOf("{");
    const end = trimmed.lastIndexOf("}");
    if (start >= 0 && end > start) {
      try {
        return asMap(JSON.parse(trimmed.slice(start, end + 1)));
      } catch {
        return {};
      }
    }
    return {};
  }
}

function ensureStructuredJson(text: string): JsonMap {
  const value = extractJsonObject(text);
  if (Object.keys(value).length === 0) {
    throw new Error("Remote model did not return a valid JSON object.");
  }
  return value;
}

function stripMarkdownFences(text: string): string {
  const trimmed = text.trim();
  if (!trimmed.startsWith("```")) {
    return trimmed;
  }
  return trimmed
    .replace(/^```(?:json)?/i, "")
    .replace(/```$/i, "")
    .trim();
}

function plainReplyText(text: string): string {
  const cleaned = stripMarkdownFences(text)
    .replace(/^json\s*/i, "")
    .trim();
  if (!cleaned) {
    return "";
  }
  if (cleaned.startsWith("{") && cleaned.endsWith("}")) {
    return "";
  }
  return cleaned;
}

function buildCompactRuntimeContext(context: AssistantContext): JsonMap {
  return {
    user: {
      displayName: context.user.displayName,
      role: context.user.role,
      dormId: context.user.dormId ?? null,
    },
    settings: {
      sleepGoalHours: context.settings.sleepGoalHours,
      bedtimeReminderEnabled: context.settings.bedtimeReminderEnabled,
      bedtimeReminder: context.settings.bedtimeReminder,
      preferredTrackTitle: context.settings.preferredTrackTitle,
      selectedNightMood: context.settings.selectedNightMood ?? null,
    },
    dorm: {
      name: context.dorm.name,
      noiseDb: context.dorm.noiseDb,
      lightLabel: context.dorm.lightLabel,
      quietLabel: context.dorm.quietLabel,
      members: context.dorm.members.slice(0, 4).map((member) => ({
        name: member.name,
        status: member.status,
        sleepModeActive: member.sleepModeActive,
      })),
    },
    recentSessions: context.recentSessions.slice(-5),
    recentDreams: context.recentDreams.slice(-3),
    recentMessages: context.recentMessages.slice(-8),
    threadSummary: context.threadSummary ?? null,
    longTermMemory: (context.longTermMemory ?? []).slice(0, 6).map((item) => ({
      kind: item.kind,
      content: item.content,
      canonicalKey: item.canonicalKey ?? null,
      keywords: item.keywords ?? [],
      confidence: item.confidence ?? null,
      updatedAt: item.updatedAt,
    })),
    userState:
      context.userState == null
        ? null
        : {
            currentPhase: context.userState.currentPhase,
            latestNightMood: context.userState.latestNightMood ?? null,
            profileSummary: context.userState.profileSummary,
            tonightPlan: context.userState.tonightPlan ?? null,
          },
  };
}

function truncatePromptText(value: string, maxLength: number): string {
  const normalized = value.trim().replace(/\s+/g, " ");
  if (normalized.length <= maxLength) {
    return normalized;
  }
  return `${normalized.slice(0, Math.max(0, maxLength - 3))}...`;
}

function buildReplyRuntimeContext(params: {
  context: AssistantContext;
  intent: AssistantIntent;
}): JsonMap {
  const { context, intent } = params;
  const latestSession = context.recentSessions[0];
  const latestDream = context.recentDreams[0];
  const tonightPlan = context.userState?.tonightPlan;
  return {
    user: {
      displayName: context.user.displayName,
      role: context.user.role,
    },
    settings: {
      sleepGoalHours: context.settings.sleepGoalHours,
      selectedNightMood: context.settings.selectedNightMood ?? null,
      preferredTrackTitle: context.settings.preferredTrackTitle,
    },
    dorm: {
      name: context.dorm.name,
      noiseDb: context.dorm.noiseDb,
      lightLabel: context.dorm.lightLabel,
      quietLabel: context.dorm.quietLabel,
      activeMemberCount:
        context.dorm.activeMemberCount ??
        context.dorm.members.filter(
          (member) => member.status !== "quiet" || member.sleepModeActive,
        ).length,
    },
    phase: context.userState?.currentPhase ?? null,
    latestSession:
      latestSession == null
        ? null
        : {
            sleepDayKey: latestSession.sleepDayKey,
            status: latestSession.status,
            totalSleepHours: latestSession.totalSleepHours ?? null,
            sleepGoalMet: latestSession.sleepGoalMet ?? null,
          },
    recentMessages: context.recentMessages.slice(-4).map((message) => ({
      role: message.role,
      content: truncatePromptText(message.content, 140),
    })),
    threadSummary:
      context.threadSummary == null
        ? null
        : {
            summary: truncatePromptText(context.threadSummary.summary, 180),
            keywords: context.threadSummary.keywords.slice(0, 6),
          },
    longTermMemory: (context.longTermMemory ?? []).slice(0, 2).map((item) => ({
      kind: item.kind,
      content: truncatePromptText(item.content, 100),
      confidence: item.confidence ?? null,
    })),
    latestDream:
      intent === "dream_reflection" && latestDream != null
        ? {
            title: truncatePromptText(latestDream.title, 40),
            emotionLabel: latestDream.emotionLabel,
            body: truncatePromptText(latestDream.body, 120),
          }
        : null,
    tonightPlan:
      intent === "plan_review" && tonightPlan != null
        ? {
            riskLevel: tonightPlan.riskLevel,
            topFactors: tonightPlan.topFactors
              .slice(0, 2)
              .map((factor) => factor.label),
            recommendedActions: tonightPlan.recommendedActions
              .slice(0, 2)
              .map((action) => action.title),
          }
        : null,
  };
}

function buildModePolicy(mode: AssistantPromptMode): string {
  switch (mode) {
    case "chat_reply":
      return [
        "Mode: chat_reply.",
        "Respond in plain text only.",
        "Prioritize low-pressure, concise, emotionally steady companionship.",
        "Use short paragraphs and avoid rigid checklists unless the user asks.",
      ].join("\n");
    case "turn_insight_extract":
      return [
        "Mode: turn_insight_extract.",
        "Return strict JSON only.",
        "Extract structured interference signals, action suggestions, memory candidates, and whether tonight plan should refresh.",
      ].join("\n");
    case "sleep_capture_dream":
      return [
        "Mode: sleep_capture_dream.",
        "Return strict JSON only.",
        "Organize the user's dream capture faithfully with a gentle, brief reply.",
      ].join("\n");
    case "sleep_capture_memo":
      return [
        "Mode: sleep_capture_memo.",
        "Return strict JSON only.",
        "Organize the user's memo faithfully with a gentle, brief reply.",
      ].join("\n");
  }
}

function buildStaticPersonaPrompt(context: AssistantContext): string {
  return [
    "Static persona:",
    "You are a dorm sleep companion assistant focused on helping the user settle before sleep.",
    "You are warm, calm, non-judgmental, and practical.",
    "You should protect the user's emotional safety, avoid pressure, and prefer small actionable steps.",
    "You can remember stable user preferences and patterns, but you should not fabricate facts.",
    `Assistant display name: ${context.assistantProfile.assistantName}.`,
    `Relationship role: ${context.assistantProfile.relationshipRole}.`,
    `Tone override: ${context.assistantProfile.tone}.`,
    `User override persona note: ${context.assistantProfile.identityPrompt}.`,
  ].join("\n");
}

function buildSystemPrompt(
  context: AssistantContext,
  mode: AssistantPromptMode = "turn_insight_extract",
): string {
  const profile = context.assistantProfile;
  return [
    buildStaticPersonaPrompt(context),
    buildModePolicy(mode),
    `Current assistant name: ${profile.assistantName}.`,
    `Current relationship role: ${profile.relationshipRole}.`,
    `Current tone: ${profile.tone}.`,
    "Use the supplied runtime context carefully.",
    mode === "chat_reply"
      ? "Do not output JSON, markdown fences, or role labels."
      : "Return strict JSON only and do not include markdown fences or extra explanation.",
  ].join("\n");
}

function buildChatReplyUserPrompt(params: {
  context: AssistantContext;
  prompt: string;
  intent: AssistantIntent;
}): string {
  return [
    "User asks for a sleep companion reply.",
    `Intent: ${params.intent}`,
    `Runtime context: ${JSON.stringify(
      buildReplyRuntimeContext({
        context: params.context,
        intent: params.intent,
      }),
    )}`,
    `User message: ${params.prompt}`,
    "Reply directly to the user in natural language.",
    "Keep it grounded, emotionally steady, and actionable.",
  ].join("\n");
}

function buildUserPayloadPrompt(instruction: string, payload: JsonMap): string {
  return `${instruction}\n${JSON.stringify(payload)}`;
}

function buildSchemaAwareUserPayloadPrompt(params: {
  instruction: string;
  payload: JsonMap;
  schemaName: string;
  schema: JsonMap;
  example: JsonMap;
}): string {
  return [
    params.instruction,
    `Return exactly one JSON object for schema "${params.schemaName}".`,
    "Do not output markdown fences, labels, or explanations.",
    "Every required field must be present even when the value is empty or false.",
    `Schema: ${JSON.stringify(params.schema)}`,
    `Example JSON shape: ${JSON.stringify(params.example)}`,
    `Task payload: ${JSON.stringify(params.payload)}`,
  ].join("\n");
}

const ACTION_SCHEMA: JsonMap = {
  type: "object",
  additionalProperties: false,
  required: [
    "id",
    "title",
    "subtitle",
    "type",
    "priority",
    "reason",
    "route",
    "trackId",
    "tags",
  ],
  properties: {
    id: { type: "string" },
    title: { type: "string" },
    subtitle: { type: "string" },
    type: { type: "string", enum: ["audio", "quickAction"] },
    priority: { type: "number" },
    reason: { type: "string" },
    route: { type: "string" },
    trackId: { type: ["string", "null"] },
    tags: {
      type: "array",
      items: { type: "string" },
    },
  },
};

const FACTOR_SCHEMA: JsonMap = {
  type: "object",
  additionalProperties: false,
  required: ["key", "label", "score", "evidence", "sourceRefs"],
  properties: {
    key: { type: "string" },
    label: { type: "string" },
    score: { type: "number" },
    evidence: { type: "string" },
    sourceRefs: {
      type: "array",
      items: { type: "string" },
    },
  },
};

const PROFILE_SUMMARY_SCHEMA: JsonMap = {
  type: "object",
  additionalProperties: false,
  required: [
    "sleepPatternSummary",
    "highRiskFactors",
    "effectiveActions",
    "dreamTrendSummary",
    "emotionTrendSummary",
    "lastUpdatedAt",
  ],
  properties: {
    sleepPatternSummary: { type: "string" },
    highRiskFactors: {
      type: "array",
      items: { type: "string" },
    },
    effectiveActions: {
      type: "array",
      items: { type: "string" },
    },
    dreamTrendSummary: { type: "string" },
    emotionTrendSummary: { type: "string" },
    lastUpdatedAt: { type: "string" },
  },
};

const STRUCTURED_REPLY_SCHEMA: JsonMap = {
  type: "object",
  additionalProperties: false,
  required: [
    "reply",
    "intent",
    "recommendedActions",
    "updateTonightPlan",
    "updatedSurfaces",
  ],
  properties: {
    reply: { type: "string" },
    intent: {
      type: "string",
      enum: [
        "general_support",
        "sleep_difficulty",
        "noise_issue",
        "dream_reflection",
        "plan_review",
      ],
    },
    recommendedActions: {
      type: "array",
      items: ACTION_SCHEMA,
    },
    updateTonightPlan: { type: "boolean" },
    updatedSurfaces: {
      type: "array",
      items: {
        type: "string",
        enum: [
          "home_pre_sleep",
          "sleep_mode",
          "morning_feedback",
          "profile_report",
          "assistant_context",
        ],
      },
    },
  },
};

const TONIGHT_PLAN_SCHEMA: JsonMap = {
  type: "object",
  additionalProperties: false,
  required: [
    "dateKey",
    "coachSummary",
    "riskLevel",
    "topFactors",
    "recommendedActions",
    "generatedAt",
    "sourceRunId",
  ],
  properties: {
    dateKey: { type: "string" },
    coachSummary: { type: "string" },
    riskLevel: {
      type: "string",
      enum: ["low", "medium", "high"],
    },
    topFactors: {
      type: "array",
      items: FACTOR_SCHEMA,
    },
    recommendedActions: {
      type: "array",
      items: ACTION_SCHEMA,
    },
    generatedAt: { type: "string" },
    sourceRunId: { type: "string" },
  },
};

const DREAM_ANALYSIS_SCHEMA: JsonMap = {
  type: "object",
  additionalProperties: false,
  required: ["summary", "dominantEmotion", "suggestedFocus", "sourceRefs"],
  properties: {
    summary: { type: "string" },
    dominantEmotion: { type: "string" },
    suggestedFocus: { type: "string" },
    sourceRefs: {
      type: "array",
      items: { type: "string" },
    },
  },
};

const MORNING_REVIEW_SCHEMA: JsonMap = {
  type: "object",
  additionalProperties: false,
  required: [
    "reviewSummary",
    "effectiveActions",
    "ineffectiveActions",
    "profileSummary",
  ],
  properties: {
    reviewSummary: { type: "string" },
    effectiveActions: {
      type: "array",
      items: { type: "string" },
    },
    ineffectiveActions: {
      type: "array",
      items: { type: "string" },
    },
    profileSummary: PROFILE_SUMMARY_SCHEMA,
  },
};

const SLEEP_CAPTURE_SCHEMA: JsonMap = {
  type: "object",
  additionalProperties: false,
  required: ["type", "title", "outline", "content", "reply"],
  properties: {
    type: {
      type: "string",
      enum: ["dream", "memo"],
    },
    title: { type: "string" },
    outline: { type: "string" },
    content: { type: "string" },
    reply: { type: "string" },
  },
};

const INTERFERENCE_SIGNAL_SCHEMA: JsonMap = {
  type: "object",
  additionalProperties: false,
  required: [
    "type",
    "title",
    "value",
    "gradeLabel",
    "status",
    "detail",
    "source",
    "measuredAt",
    "numericValue",
    "score",
  ],
  properties: {
    type: {
      type: "string",
      enum: ["noise", "light", "phoneUsage", "emotion"],
    },
    title: { type: "string" },
    value: { type: "string" },
    gradeLabel: { type: "string" },
    status: {
      type: "string",
      enum: [
        "idle",
        "measuring",
        "ready",
        "denied",
        "unavailable",
        "unsupported",
        "error",
      ],
    },
    detail: { type: "string" },
    source: { type: "string" },
    measuredAt: { type: ["string", "null"] },
    numericValue: { type: ["number", "null"] },
    score: { type: ["number", "null"] },
  },
};

const MEMORY_CANDIDATE_SCHEMA: JsonMap = {
  type: "object",
  additionalProperties: false,
  required: [
    "kind",
    "content",
    "canonicalKey",
    "keywords",
    "confidence",
    "salience",
    "sourceThreadId",
    "sourceMessageId",
    "sourceRefs",
  ],
  properties: {
    kind: { type: "string" },
    content: { type: "string" },
    canonicalKey: { type: "string" },
    keywords: {
      type: "array",
      items: { type: "string" },
    },
    confidence: { type: "number" },
    salience: { type: "number" },
    sourceThreadId: { type: ["string", "null"] },
    sourceMessageId: { type: ["string", "null"] },
    sourceRefs: {
      type: "array",
      items: { type: "string" },
    },
  },
};

const TURN_INSIGHT_SCHEMA: JsonMap = {
  type: "object",
  additionalProperties: false,
  required: [
    "interferenceSignals",
    "actionSuggestions",
    "memoryCandidates",
    "shouldRefreshPlan",
    "updatedSurfaces",
  ],
  properties: {
    interferenceSignals: {
      type: "array",
      items: INTERFERENCE_SIGNAL_SCHEMA,
    },
    actionSuggestions: {
      type: "array",
      items: ACTION_SCHEMA,
    },
    memoryCandidates: {
      type: "array",
      items: MEMORY_CANDIDATE_SCHEMA,
    },
    shouldRefreshPlan: { type: "boolean" },
    updatedSurfaces: {
      type: "array",
      items: {
        type: "string",
        enum: [
          "home_pre_sleep",
          "sleep_mode",
          "morning_feedback",
          "profile_report",
          "assistant_context",
        ],
      },
    },
  },
};

const STRUCTURED_REPLY_EXAMPLE: JsonMap = {
  reply: "先把注意力放回今晚最小、最容易完成的一步。",
  intent: "general_support",
  recommendedActions: [],
  updateTonightPlan: false,
  updatedSurfaces: ["assistant_context"],
};

const TONIGHT_PLAN_EXAMPLE: JsonMap = {
  dateKey: "2026-04-08",
  coachSummary: "今晚先稳住节奏，再做最小干预。",
  riskLevel: "medium",
  topFactors: [],
  recommendedActions: [],
  generatedAt: "2026-04-08T12:00:00.000Z",
  sourceRunId: "run-example",
};

const DREAM_ANALYSIS_EXAMPLE: JsonMap = {
  summary: "这段梦境更像是近期情绪张力的投射。",
  dominantEmotion: "紧张",
  suggestedFocus: "记录醒来后的第一感受并观察白天触发点。",
  sourceRefs: [],
};

const MORNING_REVIEW_EXAMPLE: JsonMap = {
  reviewSummary: "昨晚的关键影响因素已经逐渐清晰。",
  effectiveActions: [],
  ineffectiveActions: [],
  profileSummary: {
    sleepPatternSummary: "最近作息仍在波动。",
    highRiskFactors: [],
    effectiveActions: [],
    dreamTrendSummary: "梦境记录还在积累中。",
    emotionTrendSummary: "临睡前情绪需要继续观察。",
    lastUpdatedAt: "2026-04-08T12:00:00.000Z",
  },
};

const SLEEP_CAPTURE_EXAMPLE: JsonMap = {
  type: "dream",
  title: "梦记 02:13 · 桥上的风",
  outline:
    "AI整理：梦里重点出现了“高桥、冷风与不害怕的感觉”，适合稍后回看情绪和场景。",
  content: "我梦见自己站在很高的桥上，风很冷，但并不害怕。",
  reply: "我轻轻帮你收好了这段梦境，等你清醒些时可以再回来补充。",
};

const TURN_INSIGHT_EXAMPLE: JsonMap = {
  interferenceSignals: [],
  actionSuggestions: [],
  memoryCandidates: [],
  shouldRefreshPlan: false,
  updatedSurfaces: ["assistant_context"],
};

abstract class BaseRemoteProvider implements AIProvider {
  protected readonly fallback = new DeterministicAIProvider();

  constructor(
    readonly providerName: string,
    readonly modelName: string,
  ) {}

  protected async withFallback<T>(params: {
    fallback: Promise<AIProviderResult<T>>;
    remoteCall: () => Promise<T>;
    modelName?: string;
  }): Promise<AIProviderResult<T>> {
    const fallbackResult = await params.fallback;
    try {
      const value = await params.remoteCall();
      return {
        value,
        providerName: this.providerName,
        modelName: params.modelName ?? this.modelName,
        sourceMode: "remoteSuccess",
        errorMessage: null,
      };
    } catch (error) {
      return {
        ...fallbackResult,
        providerName: this.providerName,
        modelName: params.modelName ?? this.modelName,
        sourceMode: "fallbackSuccess",
        errorMessage: errorMessageOf(error),
      };
    }
  }

  abstract generateStructuredReply(
    context: AssistantContext,
    intent: AssistantIntent,
    prompt: string,
  ): Promise<AIProviderResult<StructuredAssistantReply>>;

  abstract streamReplyText(
    context: AssistantContext,
    intent: AssistantIntent,
    prompt: string,
    onDelta?: (delta: string) => Promise<void> | void,
  ): Promise<AIProviderResult<string>>;

  abstract extractTurnInsights(
    context: AssistantContext,
    params: {
      threadId: string;
      prompt: string;
      reply: string;
      intent: AssistantIntent;
      sourceMessageId?: string;
    },
  ): Promise<AIProviderResult<TurnInsightExtraction>>;

  abstract generateTonightPlan(
    context: AssistantContext,
    runId: string,
  ): Promise<AIProviderResult<TonightPlan>>;

  abstract summarizeDream(
    body: string,
    context: AssistantContext,
  ): Promise<AIProviderResult<DreamAnalysis>>;

  abstract generateSleepCapture(
    context: AssistantContext,
    params: {
      prompt: string;
      captureType: SleepCaptureKind;
      sessionId: string;
    },
  ): Promise<AIProviderResult<SleepCaptureDraft>>;

  abstract analyzeFeedback(
    context: AssistantContext,
    sessionId: string,
  ): Promise<AIProviderResult<MorningReviewResult>>;
}

interface XAIResponsesProviderConfig {
  baseUrl: string;
  apiKey?: string;
  providerName: string;
  modelName: string;
  timeoutMs: number;
  replyModelName?: string;
  structuredModelName?: string;
  replyTimeoutMs?: number;
  structuredTimeoutMs?: number;
}

class XAIResponsesProvider extends BaseRemoteProvider {
  constructor(private readonly config: XAIResponsesProviderConfig) {
    super(config.providerName, config.modelName);
  }

  private replyModelName(): string {
    return this.config.replyModelName?.trim() || this.config.modelName;
  }

  private structuredModelName(): string {
    return this.config.structuredModelName?.trim() || this.config.modelName;
  }

  private replyTimeoutMs(): number {
    return this.config.replyTimeoutMs ?? this.config.timeoutMs;
  }

  private structuredTimeoutMs(): number {
    return this.config.structuredTimeoutMs ?? this.config.timeoutMs;
  }

  private fallbackRegionalBaseUrl(): string | null {
    if (!this.config.baseUrl.startsWith("https://api.x.ai/")) {
      return null;
    }
    return this.config.baseUrl.replace(
      "https://api.x.ai/",
      "https://us-east-1.api.x.ai/",
    );
  }

  private async postResponses(
    fetchFn: typeof fetch,
    baseUrl: string,
    body: string,
    timeoutMs: number,
  ): Promise<Response> {
    return fetchFn(baseUrl, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${this.config.apiKey}`,
      },
      body,
      signal: AbortSignal.timeout(timeoutMs),
    });
  }

  async generateStructuredReply(
    context: AssistantContext,
    intent: AssistantIntent,
    prompt: string,
  ): Promise<AIProviderResult<StructuredAssistantReply>> {
    return this.withFallback({
      fallback: this.fallback.generateStructuredReply(context, intent, prompt),
      modelName: this.structuredModelName(),
      remoteCall: async () => {
        const value = await this.requestJson({
          schemaName: "structured_assistant_reply",
          schema: STRUCTURED_REPLY_SCHEMA,
          systemPrompt: buildSystemPrompt(context),
          userPrompt: buildUserPayloadPrompt(
            "Return a structured assistant reply as JSON that matches the schema.",
            { context, intent, prompt },
          ),
          modelName: this.structuredModelName(),
          timeoutMs: this.structuredTimeoutMs(),
        });
        return normalizeStructuredReply(
          ensureStructuredReplyCandidate(value),
          (await this.fallback.generateStructuredReply(context, intent, prompt))
            .value,
        );
      },
    });
  }

  async generateTonightPlan(
    context: AssistantContext,
    runId: string,
  ): Promise<AIProviderResult<TonightPlan>> {
    return this.withFallback({
      fallback: this.fallback.generateTonightPlan(context, runId),
      modelName: this.structuredModelName(),
      remoteCall: async () => {
        const value = await this.requestJson({
          schemaName: "tonight_plan",
          schema: TONIGHT_PLAN_SCHEMA,
          systemPrompt: buildSystemPrompt(context),
          userPrompt: buildUserPayloadPrompt(
            "Return tonight plan JSON that matches the schema.",
            { context, runId },
          ),
          modelName: this.structuredModelName(),
          timeoutMs: this.structuredTimeoutMs(),
        });
        return normalizeTonightPlan(
          ensureTonightPlanCandidate(value),
          (await this.fallback.generateTonightPlan(context, runId)).value,
        );
      },
    });
  }

  async summarizeDream(
    body: string,
    context: AssistantContext,
  ): Promise<AIProviderResult<DreamAnalysis>> {
    return this.withFallback({
      fallback: this.fallback.summarizeDream(body, context),
      modelName: this.structuredModelName(),
      remoteCall: async () => {
        const value = await this.requestJson({
          schemaName: "dream_analysis",
          schema: DREAM_ANALYSIS_SCHEMA,
          systemPrompt: buildSystemPrompt(context),
          userPrompt: buildUserPayloadPrompt(
            "Return dream analysis JSON that matches the schema.",
            { body, context },
          ),
          modelName: this.structuredModelName(),
          timeoutMs: this.structuredTimeoutMs(),
        });
        return normalizeDreamAnalysis(
          ensureDreamAnalysisCandidate(value),
          (await this.fallback.summarizeDream(body, context)).value,
        );
      },
    });
  }

  async streamReplyText(
    context: AssistantContext,
    intent: AssistantIntent,
    prompt: string,
    onDelta?: (delta: string) => Promise<void> | void,
  ): Promise<AIProviderResult<string>> {
    const modelName = this.replyModelName();
    const reply = await this.requestPlainText({
      systemPrompt: buildSystemPrompt(context, "chat_reply"),
      userPrompt: buildChatReplyUserPrompt({ context, prompt, intent }),
      modelName,
      timeoutMs: this.replyTimeoutMs(),
    });
    if (onDelta && reply.trim()) {
      await onDelta(reply);
    }
    return {
      value: reply,
      providerName: this.providerName,
      modelName,
      sourceMode: "remoteSuccess",
      errorMessage: null,
    };
  }

  async extractTurnInsights(
    context: AssistantContext,
    params: {
      threadId: string;
      prompt: string;
      reply: string;
      intent: AssistantIntent;
      sourceMessageId?: string;
    },
  ): Promise<AIProviderResult<TurnInsightExtraction>> {
    return this.withFallback({
      fallback: this.fallback.extractTurnInsights(context, params),
      modelName: this.structuredModelName(),
      remoteCall: async () => {
        const value = await this.requestJson({
          schemaName: "turn_insight_extract",
          schema: TURN_INSIGHT_SCHEMA,
          systemPrompt: buildSystemPrompt(context, "turn_insight_extract"),
          userPrompt: buildUserPayloadPrompt(
            "Return turn insight extraction JSON that matches the schema.",
            {
              context: buildCompactRuntimeContext(context),
              ...params,
            },
          ),
          modelName: this.structuredModelName(),
          timeoutMs: this.structuredTimeoutMs(),
        });
        return normalizeTurnInsightExtraction(
          ensureTurnInsightCandidate(value),
          (await this.fallback.extractTurnInsights(context, params)).value,
        );
      },
    });
  }

  async generateSleepCapture(
    context: AssistantContext,
    params: {
      prompt: string;
      captureType: SleepCaptureKind;
      sessionId: string;
    },
  ): Promise<AIProviderResult<SleepCaptureDraft>> {
    return this.withFallback({
      fallback: this.fallback.generateSleepCapture(context, params),
      modelName: this.structuredModelName(),
      remoteCall: async () => {
        const value = await this.requestJson({
          schemaName: "sleep_capture",
          schema: SLEEP_CAPTURE_SCHEMA,
          systemPrompt: buildSystemPrompt(
            context,
            params.captureType === "dream"
              ? "sleep_capture_dream"
              : "sleep_capture_memo",
          ),
          userPrompt: buildUserPayloadPrompt(
            "Return sleep capture JSON that matches the schema. Keep title concise, outline useful, content faithful to the user's input, and reply warm and brief.",
            params,
          ),
          modelName: this.structuredModelName(),
          timeoutMs: this.structuredTimeoutMs(),
        });
        return normalizeSleepCaptureDraft(
          ensureSleepCaptureCandidate(value),
          (await this.fallback.generateSleepCapture(context, params)).value,
        );
      },
    });
  }

  async analyzeFeedback(
    context: AssistantContext,
    sessionId: string,
  ): Promise<AIProviderResult<MorningReviewResult>> {
    return this.withFallback({
      fallback: this.fallback.analyzeFeedback(context, sessionId),
      modelName: this.structuredModelName(),
      remoteCall: async () => {
        const value = await this.requestJson({
          schemaName: "morning_review",
          schema: MORNING_REVIEW_SCHEMA,
          systemPrompt: buildSystemPrompt(context),
          userPrompt: buildUserPayloadPrompt(
            "Return morning review JSON that matches the schema.",
            { context, sessionId },
          ),
          modelName: this.structuredModelName(),
          timeoutMs: this.structuredTimeoutMs(),
        });
        return normalizeMorningReview(
          ensureMorningReviewCandidate(value),
          (await this.fallback.analyzeFeedback(context, sessionId)).value,
        );
      },
    });
  }

  private async requestJson(params: {
    schemaName: string;
    schema: JsonMap;
    systemPrompt: string;
    userPrompt: string;
    modelName: string;
    timeoutMs: number;
  }): Promise<JsonMap> {
    if (!this.config.apiKey?.trim()) {
      throw new Error("xAI API key is missing.");
    }

    const fetchFn = globalThis.fetch;
    if (typeof fetchFn !== "function") {
      throw new Error("Global fetch is not available in this runtime.");
    }

    const requestBody = JSON.stringify({
      model: params.modelName,
      store: false,
      input: [
        {
          role: "system",
          content: [
            {
              type: "input_text",
              text: params.systemPrompt,
            },
          ],
        },
        {
          role: "user",
          content: [
            {
              type: "input_text",
              text: params.userPrompt,
            },
          ],
        },
      ],
      text: {
        format: {
          type: "json_schema",
          name: params.schemaName,
          schema: params.schema,
          strict: true,
        },
      },
    });

    let response: Response;
    try {
      response = await this.postResponses(
        fetchFn,
        this.config.baseUrl,
        requestBody,
        params.timeoutMs,
      );
    } catch (error) {
      const regionalBaseUrl = this.fallbackRegionalBaseUrl();
      if (!regionalBaseUrl) {
        throw error;
      }
      try {
        response = await this.postResponses(
          fetchFn,
          regionalBaseUrl,
          requestBody,
          params.timeoutMs,
        );
      } catch (regionalError) {
        throw new Error(
          `xAI fetch failed on both global and regional endpoints. global=${errorMessageOf(
            error,
          )}; regional=${errorMessageOf(regionalError)}`,
        );
      }
    }

    const responseText = await response.text();
    if (!response.ok) {
      throw new Error(
        `xAI responses request failed with status ${
          response.status
        }: ${responseText.slice(0, 240)}`,
      );
    }

    const payload = asMap(responseText ? JSON.parse(responseText) : {});
    const outputText = this.extractText(payload);
    return ensureStructuredJson(outputText);
  }

  private async requestPlainText(params: {
    systemPrompt: string;
    userPrompt: string;
    modelName: string;
    timeoutMs: number;
  }): Promise<string> {
    if (!this.config.apiKey?.trim()) {
      throw new Error("xAI API key is missing.");
    }

    const fetchFn = globalThis.fetch;
    if (typeof fetchFn !== "function") {
      throw new Error("Global fetch is not available in this runtime.");
    }

    const requestBody = JSON.stringify({
      model: params.modelName,
      store: false,
      input: [
        {
          role: "system",
          content: [{ type: "input_text", text: params.systemPrompt }],
        },
        {
          role: "user",
          content: [{ type: "input_text", text: params.userPrompt }],
        },
      ],
    });

    let response: Response;
    try {
      response = await this.postResponses(
        fetchFn,
        this.config.baseUrl,
        requestBody,
        params.timeoutMs,
      );
    } catch (error) {
      const regionalBaseUrl = this.fallbackRegionalBaseUrl();
      if (!regionalBaseUrl) {
        throw error;
      }
      response = await this.postResponses(
        fetchFn,
        regionalBaseUrl,
        requestBody,
        params.timeoutMs,
      );
    }

    const responseText = await response.text();
    if (!response.ok) {
      throw new Error(
        `xAI responses request failed with status ${
          response.status
        }: ${responseText.slice(0, 240)}`,
      );
    }
    const payload = asMap(responseText ? JSON.parse(responseText) : {});
    const text = this.extractText(payload).trim();
    if (!text) {
      throw new Error(
        "xAI responses payload did not contain plain text output.",
      );
    }
    return text;
  }

  private extractText(payload: JsonMap): string {
    const direct = asString(payload.output_text);
    if (direct.trim()) {
      return direct;
    }

    const outputs = Array.isArray(payload.output) ? payload.output : [];
    for (const item of outputs) {
      const output = asMap(item);
      const outputText = asString(output.output_text);
      if (outputText.trim()) {
        return outputText;
      }
      const contents = Array.isArray(output.content) ? output.content : [];
      for (const content of contents) {
        const contentMap = asMap(content);
        const text = asString(contentMap.text);
        if (text.trim()) {
          return text;
        }
      }
    }

    const choiceMessage = asMap(
      asMap((Array.isArray(payload.choices) ? payload.choices[0] : null) ?? {})
        .message,
    );
    const choiceText = asString(choiceMessage.content);
    if (choiceText.trim()) {
      return choiceText;
    }

    throw new Error("xAI responses payload did not contain output_text.");
  }
}

interface CloudBaseAIProviderConfig {
  envId: string;
  providerName: string;
  modelName: string;
  providerGroup?: string;
  apiKey?: string;
  baseUrl?: string;
  timeoutMs: number;
  replyModelName?: string;
  structuredModelName?: string;
  replyTimeoutMs?: number;
  structuredTimeoutMs?: number;
}

function cloudbaseProviderGroup(
  modelName: string,
  explicitGroup?: string,
): string {
  if (explicitGroup?.trim()) {
    return explicitGroup.trim();
  }
  const normalized = modelName.trim().toLowerCase();
  if (normalized.startsWith("deepseek")) {
    return "deepseek";
  }
  return "hunyuan-exp";
}

function isBuiltInCloudBaseProviderGroup(providerGroup: string): boolean {
  return providerGroup === "hunyuan-exp" || providerGroup === "deepseek";
}

function cloudbaseGatewayProviderPath(providerGroup: string): string {
  if (providerGroup === "hunyuan-exp") {
    return "hunyuan";
  }
  return providerGroup;
}

class CloudBaseAIProvider extends BaseRemoteProvider {
  readonly model: any;
  readonly providerGroup: string;
  readonly gatewayBaseUrl: string | null;
  readonly apiKey: string;

  constructor(private readonly config: CloudBaseAIProviderConfig) {
    super(config.providerName, config.modelName);
    this.providerGroup = cloudbaseProviderGroup(
      config.modelName,
      config.providerGroup,
    );
    this.apiKey = config.apiKey?.trim() || "";

    if (
      isBuiltInCloudBaseProviderGroup(this.providerGroup) &&
      !this.apiKey &&
      !config.baseUrl?.trim()
    ) {
      const cloudbase = require("@cloudbase/node-sdk") as any;
      const secretId = process.env.TENCENTCLOUD_SECRETID?.trim() || "";
      const secretKey = process.env.TENCENTCLOUD_SECRETKEY?.trim() || "";
      const sessionToken =
        process.env.TENCENTCLOUD_SESSIONTOKEN?.trim() ||
        process.env.TCB_SESSIONTOKEN?.trim() ||
        "";
      const app =
        secretId && secretKey
          ? cloudbase.init({
              env: config.envId,
              secretId,
              secretKey,
              ...(sessionToken ? { sessionToken } : {}),
            })
          : cloudbase.init({ env: config.envId });
      this.model = app.ai().createModel(this.providerGroup);
      this.gatewayBaseUrl = null;
      return;
    }

    this.model = null;
    this.gatewayBaseUrl =
      config.baseUrl?.trim() ||
      `https://${config.envId}.api.tcloudbasegateway.com/v1/ai/${cloudbaseGatewayProviderPath(
        this.providerGroup,
      )}/v1`;
  }

  private replyModelName(): string {
    return this.config.replyModelName?.trim() || this.config.modelName;
  }

  private structuredModelName(): string {
    return this.config.structuredModelName?.trim() || this.config.modelName;
  }

  private replyTimeoutMs(): number {
    return this.config.replyTimeoutMs ?? this.config.timeoutMs;
  }

  private structuredTimeoutMs(): number {
    return this.config.structuredTimeoutMs ?? this.config.timeoutMs;
  }

  private async withSdkTimeout<T>(
    operation: () => Promise<T>,
    timeoutMs: number,
    label: string,
  ): Promise<T> {
    let timer: NodeJS.Timeout | null = null;
    try {
      return await Promise.race<T>([
        operation(),
        new Promise<T>((_resolve, reject) => {
          timer = setTimeout(() => {
            reject(new Error(`CloudBase AI ${label} timeout after ${timeoutMs}ms.`));
          }, timeoutMs);
        }),
      ]);
    } finally {
      if (timer) {
        clearTimeout(timer);
      }
    }
  }

  async streamReplyText(
    context: AssistantContext,
    intent: AssistantIntent,
    prompt: string,
    onDelta?: (delta: string) => Promise<void> | void,
  ): Promise<AIProviderResult<string>> {
    const modelName = this.replyModelName();
    const reply = await this.streamPlainText(
      context,
      "chat_reply",
      buildChatReplyUserPrompt({ context, prompt, intent }),
      modelName,
      this.replyTimeoutMs(),
      onDelta,
    );
    return {
      value: reply,
      providerName: this.providerName,
      modelName,
      sourceMode: "remoteSuccess",
      errorMessage: null,
    };
  }

  async extractTurnInsights(
    context: AssistantContext,
    params: {
      threadId: string;
      prompt: string;
      reply: string;
      intent: AssistantIntent;
      sourceMessageId?: string;
    },
  ): Promise<AIProviderResult<TurnInsightExtraction>> {
    return this.withFallback({
      fallback: this.fallback.extractTurnInsights(context, params),
      modelName: this.structuredModelName(),
      remoteCall: async () => {
        const value = await this.generateJson(
          context,
          "Return turn insight extraction JSON that matches the schema.",
          {
            context: buildCompactRuntimeContext(context),
            ...params,
          },
          "turn_insight_extract",
          TURN_INSIGHT_SCHEMA,
          TURN_INSIGHT_EXAMPLE,
          "turn_insight_extract",
          this.structuredModelName(),
          this.structuredTimeoutMs(),
        );
        return normalizeTurnInsightExtraction(
          ensureTurnInsightCandidate(value),
          (await this.fallback.extractTurnInsights(context, params)).value,
        );
      },
    });
  }

  async generateStructuredReply(
    context: AssistantContext,
    intent: AssistantIntent,
    prompt: string,
  ): Promise<AIProviderResult<StructuredAssistantReply>> {
    const modelName = this.structuredModelName();
    const fallbackResult = await this.fallback.generateStructuredReply(
      context,
      intent,
      prompt,
    );
    try {
      const rawText = await this.generateText(
        context,
        "Return a structured assistant reply as JSON that matches the schema.",
        { context, intent, prompt },
        "structured_assistant_reply",
        STRUCTURED_REPLY_SCHEMA,
        STRUCTURED_REPLY_EXAMPLE,
        "turn_insight_extract",
        modelName,
        this.structuredTimeoutMs(),
      );
      const candidate = extractJsonObject(rawText);
      const remoteReply =
        asString(candidate.reply).trim() || plainReplyText(rawText);
      if (remoteReply) {
        candidate.reply = remoteReply;
      }
      const missing = missingStructuredReplyFields(candidate);
      if (missing.length === 0) {
        return {
          value: normalizeStructuredReply(candidate, fallbackResult.value),
          providerName: this.providerName,
          modelName,
          sourceMode: "remoteSuccess",
          errorMessage: null,
        };
      }
      if (remoteReply) {
        return {
          value: normalizeStructuredReply(candidate, fallbackResult.value),
          providerName: this.providerName,
          modelName,
          sourceMode: "fallbackSuccess",
          errorMessage: `Remote structured assistant reply missing required fields: ${missing.join(
            ", ",
          )}`,
        };
      }
      throw new Error(
        `Remote structured assistant reply missing required fields: ${missing.join(
          ", ",
        )}`,
      );
    } catch (error) {
      return {
        ...fallbackResult,
        providerName: this.providerName,
        modelName,
        sourceMode: "fallbackSuccess",
        errorMessage: errorMessageOf(error),
      };
    }
  }

  async generateTonightPlan(
    context: AssistantContext,
    runId: string,
  ): Promise<AIProviderResult<TonightPlan>> {
    return this.withFallback({
      fallback: this.fallback.generateTonightPlan(context, runId),
      modelName: this.structuredModelName(),
      remoteCall: async () => {
        const value = await this.generateJson(
          context,
          "Return tonight plan JSON that matches the schema.",
          { context, runId },
          "tonight_plan",
          TONIGHT_PLAN_SCHEMA,
          TONIGHT_PLAN_EXAMPLE,
          "turn_insight_extract",
          this.structuredModelName(),
          this.structuredTimeoutMs(),
        );
        return normalizeTonightPlan(
          ensureTonightPlanCandidate(value),
          (await this.fallback.generateTonightPlan(context, runId)).value,
        );
      },
    });
  }

  async summarizeDream(
    body: string,
    context: AssistantContext,
  ): Promise<AIProviderResult<DreamAnalysis>> {
    return this.withFallback({
      fallback: this.fallback.summarizeDream(body, context),
      modelName: this.structuredModelName(),
      remoteCall: async () => {
        const value = await this.generateJson(
          context,
          "Return dream analysis JSON that matches the schema.",
          { body, context },
          "dream_analysis",
          DREAM_ANALYSIS_SCHEMA,
          DREAM_ANALYSIS_EXAMPLE,
          "turn_insight_extract",
          this.structuredModelName(),
          this.structuredTimeoutMs(),
        );
        return normalizeDreamAnalysis(
          ensureDreamAnalysisCandidate(value),
          (await this.fallback.summarizeDream(body, context)).value,
        );
      },
    });
  }

  async generateSleepCapture(
    context: AssistantContext,
    params: {
      prompt: string;
      captureType: SleepCaptureKind;
      sessionId: string;
    },
  ): Promise<AIProviderResult<SleepCaptureDraft>> {
    return this.withFallback({
      fallback: this.fallback.generateSleepCapture(context, params),
      modelName: this.structuredModelName(),
      remoteCall: async () => {
        const value = await this.generateJson(
          context,
          "Return sleep capture JSON that matches the schema. Keep title concise, outline useful, content faithful to the user's input, and reply warm and brief.",
          params,
          "sleep_capture",
          SLEEP_CAPTURE_SCHEMA,
          SLEEP_CAPTURE_EXAMPLE,
          params.captureType === "dream"
            ? "sleep_capture_dream"
            : "sleep_capture_memo",
          this.structuredModelName(),
          this.structuredTimeoutMs(),
        );
        return normalizeSleepCaptureDraft(
          ensureSleepCaptureCandidate(value),
          (await this.fallback.generateSleepCapture(context, params)).value,
        );
      },
    });
  }

  async analyzeFeedback(
    context: AssistantContext,
    sessionId: string,
  ): Promise<AIProviderResult<MorningReviewResult>> {
    return this.withFallback({
      fallback: this.fallback.analyzeFeedback(context, sessionId),
      modelName: this.structuredModelName(),
      remoteCall: async () => {
        const value = await this.generateJson(
          context,
          "Return morning review JSON that matches the schema.",
          { context, sessionId },
          "morning_review",
          MORNING_REVIEW_SCHEMA,
          MORNING_REVIEW_EXAMPLE,
          "turn_insight_extract",
          this.structuredModelName(),
          this.structuredTimeoutMs(),
        );
        return normalizeMorningReview(
          ensureMorningReviewCandidate(value),
          (await this.fallback.analyzeFeedback(context, sessionId)).value,
        );
      },
    });
  }

  private async generateJson(
    context: AssistantContext,
    instruction: string,
    payload: JsonMap,
    schemaName: string,
    schema: JsonMap,
    example: JsonMap,
    mode: AssistantPromptMode = "turn_insight_extract",
    modelName = this.structuredModelName(),
    timeoutMs = this.structuredTimeoutMs(),
  ): Promise<JsonMap> {
    return ensureStructuredJson(
      await this.generateText(
        context,
        instruction,
        payload,
        schemaName,
        schema,
        example,
        mode,
        modelName,
        timeoutMs,
      ),
    );
  }

  private async generateText(
    context: AssistantContext,
    instruction: string,
    payload: JsonMap,
    schemaName: string,
    schema: JsonMap,
    example: JsonMap,
    mode: AssistantPromptMode = "turn_insight_extract",
    modelName = this.structuredModelName(),
    timeoutMs = this.structuredTimeoutMs(),
  ): Promise<string> {
    if (this.model) {
      const result = await this.withSdkTimeout(
        () =>
          this.model.generateText({
            model: modelName,
            temperature: 0.1,
            response_format: { type: "json_object" },
            messages: [
              {
                role: "system",
                content: buildSystemPrompt(context, mode),
              },
              {
                role: "user",
                content: buildSchemaAwareUserPayloadPrompt({
                  instruction,
                  payload,
                  schemaName,
                  schema,
                  example,
                }),
              },
            ],
          }),
        timeoutMs,
        "generateText",
      );

      return asString((result as { text?: unknown } | null)?.text);
    }

    if (!this.gatewayBaseUrl) {
      throw new Error("CloudBase AI gateway base URL is missing.");
    }
    if (!this.apiKey) {
      throw new Error(
        `CloudBase API key is missing for provider group "${this.providerGroup}". Custom provider groups must use the OpenAI-compatible CloudBase gateway with API key auth.`,
      );
    }

    const fetchFn = globalThis.fetch;
    if (typeof fetchFn !== "function") {
      throw new Error("Global fetch is not available in this runtime.");
    }

    const requestBody = JSON.stringify({
      model: modelName,
      temperature: 0.1,
      response_format: { type: "json_object" },
      messages: [
        {
          role: "system",
          content: buildSystemPrompt(context, mode),
        },
        {
          role: "user",
          content: buildSchemaAwareUserPayloadPrompt({
            instruction,
            payload,
            schemaName,
            schema,
            example,
          }),
        },
      ],
    });

    let response: Response;
    try {
      response = await fetchFn(`${this.gatewayBaseUrl}/chat/completions`, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          authorization: `Bearer ${this.apiKey}`,
        },
        body: requestBody,
        signal: AbortSignal.timeout(timeoutMs),
      });
    } catch (error) {
      const message = errorMessageOf(error);
      if (
        message.includes("TimeoutError") ||
        message.includes("The operation was aborted") ||
        message.toLowerCase().includes("timeout")
      ) {
        throw new Error(
          `CloudBase OpenAI-compatible request timeout after ${timeoutMs}ms.`,
        );
      }
      throw error;
    }

    const responseText = await response.text();
    if (!response.ok) {
      throw new Error(
        `CloudBase OpenAI-compatible request failed with status ${
          response.status
        }: ${responseText.slice(0, 240)}`,
      );
    }

    const payloadMap = asMap(responseText ? JSON.parse(responseText) : {});
    const content = extractOpenAICompatibleMessageContent(payloadMap).trim();
    if (content) {
      return content;
    }

    throw new Error(
      "CloudBase OpenAI-compatible payload did not contain choices[0].message.content.",
    );
  }

  private async streamPlainText(
    context: AssistantContext,
    mode: AssistantPromptMode,
    userPrompt: string,
    modelName: string,
    timeoutMs: number,
    onDelta?: (delta: string) => Promise<void> | void,
  ): Promise<string> {
    if (this.model && typeof this.model.streamText === "function") {
      const streamedReply = await this.withSdkTimeout(async () => {
        const result = await this.model.streamText({
          model: modelName,
          temperature: 0.35,
          messages: [
            {
              role: "system",
              content: buildSystemPrompt(context, mode),
            },
            {
              role: "user",
              content: userPrompt,
            },
          ],
        });

        let reply = "";
        for await (const chunk of result.textStream) {
          const delta = asString(chunk);
          if (!delta) {
            continue;
          }
          reply += delta;
          if (onDelta) {
            await onDelta(delta);
          }
        }
        return reply;
      }, timeoutMs, "streamText");
      if (streamedReply.trim()) {
        return streamedReply;
      }
    }

    if (this.model) {
      const result = await this.withSdkTimeout(
        () =>
          this.model.generateText({
            model: modelName,
            temperature: 0.35,
            messages: [
              {
                role: "system",
                content: buildSystemPrompt(context, mode),
              },
              {
                role: "user",
                content: userPrompt,
              },
            ],
          }),
        timeoutMs,
        "generateText",
      );
      const reply = asString((result as { text?: unknown } | null)?.text).trim();
      if (!reply) {
        throw new Error("CloudBase AI model returned empty plain text.");
      }
      if (onDelta) {
        await onDelta(reply);
      }
      return reply;
    }

    if (!this.gatewayBaseUrl) {
      throw new Error("CloudBase AI gateway base URL is missing.");
    }
    if (!this.apiKey) {
      throw new Error(
        `CloudBase API key is missing for provider group "${this.providerGroup}". Custom provider groups must use the OpenAI-compatible CloudBase gateway with API key auth.`,
      );
    }

    const fetchFn = globalThis.fetch;
    if (typeof fetchFn !== "function") {
      throw new Error("Global fetch is not available in this runtime.");
    }

    const requestBody = JSON.stringify({
      model: modelName,
      temperature: 0.35,
      stream: true,
      messages: [
        {
          role: "system",
          content: buildSystemPrompt(context, mode),
        },
        {
          role: "user",
          content: userPrompt,
        },
      ],
    });

    const response = await fetchFn(`${this.gatewayBaseUrl}/chat/completions`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${this.apiKey}`,
        accept: "text/event-stream, application/json",
      },
      body: requestBody,
      signal: AbortSignal.timeout(timeoutMs),
    });
    if (!response.ok) {
      const responseText = await response.text();
      throw new Error(
        `CloudBase OpenAI-compatible request failed with status ${
          response.status
        }: ${responseText.slice(0, 240)}`,
      );
    }

    const contentType =
      response.headers.get("content-type")?.toLowerCase() || "";
    if (response.body && contentType.includes("text/event-stream")) {
      const streamedReply = await consumeOpenAICompatibleSseTextStream({
        response,
        onDelta,
      });
      if (streamedReply.trim()) {
        return streamedReply;
      }
      throw new Error(
        "CloudBase OpenAI-compatible SSE payload did not contain plain message content.",
      );
    }

    const responseText = await response.text();
    const payloadMap = asMap(responseText ? JSON.parse(responseText) : {});
    const reply = extractOpenAICompatibleMessageContent(payloadMap).trim();
    if (reply) {
      if (onDelta) {
        await onDelta(reply);
      }
      return reply;
    }
    throw new Error(
      "CloudBase OpenAI-compatible payload did not contain plain message content.",
    );
  }
}

function positiveTimeoutMsOrNull(value: unknown): number | null {
  const parsed = Number(value ?? "");
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}

function timeoutMsOf(env: NodeJS.ProcessEnv): number {
  return positiveTimeoutMsOrNull(env.AI_PROVIDER_TIMEOUT_MS) ?? 60000;
}

export function createAIProviderFromEnv(
  env: NodeJS.ProcessEnv = process.env,
): AIProvider {
  const mode = env.AI_PROVIDER_MODE?.trim() || "deterministic";
  const envId =
    env.CLOUDBASE_ENV_ID?.trim() ||
    env.TCB_ENV?.trim() ||
    env.SCF_NAMESPACE?.trim() ||
    "";
  const replyModelName = env.AI_PROVIDER_MODEL_REPLY?.trim() || undefined;
  const structuredModelName =
    env.AI_PROVIDER_MODEL_STRUCTURED?.trim() || undefined;
  const sharedTimeoutMs = positiveTimeoutMsOrNull(env.AI_PROVIDER_TIMEOUT_MS);
  const replyTimeoutMs =
    positiveTimeoutMsOrNull(env.AI_PROVIDER_TIMEOUT_MS_REPLY) ??
    sharedTimeoutMs ??
    20000;
  const structuredTimeoutMs =
    positiveTimeoutMsOrNull(env.AI_PROVIDER_TIMEOUT_MS_STRUCTURED) ??
    sharedTimeoutMs ??
    40000;

  switch (mode) {
    case "xai_responses":
      return new XAIResponsesProvider({
        baseUrl:
          env.AI_PROVIDER_BASE_URL?.trim() || "https://api.x.ai/v1/responses",
        apiKey: env.AI_PROVIDER_API_KEY?.trim(),
        providerName: env.AI_PROVIDER_NAME?.trim() || "xai_responses",
        modelName: env.AI_PROVIDER_MODEL?.trim() || "grok-4-1-fast-reasoning",
        timeoutMs: timeoutMsOf(env),
        replyModelName,
        structuredModelName,
        replyTimeoutMs,
        structuredTimeoutMs,
      });
    case "cloudbase_ai":
      if (envId) {
        return new CloudBaseAIProvider({
          envId,
          providerName: env.AI_PROVIDER_NAME?.trim() || "cloudbase_ai",
          providerGroup: env.AI_PROVIDER_GROUP?.trim() || undefined,
          apiKey: env.AI_PROVIDER_API_KEY?.trim(),
          baseUrl: env.AI_PROVIDER_BASE_URL?.trim(),
          modelName:
            env.AI_PROVIDER_MODEL?.trim() || "hunyuan-2.0-instruct-20251111",
          timeoutMs: timeoutMsOf(env),
          replyModelName,
          structuredModelName,
          replyTimeoutMs,
          structuredTimeoutMs,
        });
      }
      console.warn(
        "[ai-provider] AI_PROVIDER_MODE=cloudbase_ai but no CloudBase env was found. Falling back to deterministic mode.",
      );
      return new DeterministicAIProvider();
    case "deterministic":
      return new DeterministicAIProvider();
    default:
      console.warn(
        `[ai-provider] Unknown AI_PROVIDER_MODE="${mode}". Falling back to deterministic mode.`,
      );
      return new DeterministicAIProvider();
  }
}
