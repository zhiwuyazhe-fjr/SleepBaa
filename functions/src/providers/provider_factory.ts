import {
  AIProvider,
  DeterministicAIProvider,
} from "./ai_provider";
import {
  AssistantContext,
  AssistantIntent,
  DreamAnalysis,
  InterferenceFactor,
  MorningReviewResult,
  RecommendedAction,
  StructuredAssistantReply,
  SurfaceId,
  TonightPlan,
} from "../shared/types";

type JsonMap = Record<string, unknown>;

function asMap(value: unknown): JsonMap {
  return value && typeof value === "object" ? (value as JsonMap) : {};
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
    dominantEmotion: asString(
      data.dominantEmotion,
      fallback.dominantEmotion,
    ),
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

function extractJsonObject(text: string): JsonMap {
  const trimmed = text.trim();
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

interface HttpProviderConfig {
  baseUrl: string;
  apiKey?: string;
  providerName: string;
  modelName: string;
  timeoutMs: number;
}

class HttpAIProvider implements AIProvider {
  constructor(private readonly config: HttpProviderConfig) {}

  get providerName(): string {
    return this.config.providerName;
  }

  get modelName(): string {
    return this.config.modelName;
  }

  private readonly fallback = new DeterministicAIProvider();

  async generateStructuredReply(
    context: AssistantContext,
    intent: AssistantIntent,
    prompt: string,
  ): Promise<StructuredAssistantReply> {
    const fallback = await this.fallback.generateStructuredReply(
      context,
      intent,
      prompt,
    );
    try {
      const value = await this.request("generateStructuredReply", {
        context,
        intent,
        prompt,
      });
      return normalizeStructuredReply(value, fallback);
    } catch {
      return fallback;
    }
  }

  async generateTonightPlan(
    context: AssistantContext,
    runId: string,
  ): Promise<TonightPlan> {
    const fallback = await this.fallback.generateTonightPlan(context, runId);
    try {
      const value = await this.request("generateTonightPlan", {
        context,
        runId,
      });
      return normalizeTonightPlan(value, fallback);
    } catch {
      return fallback;
    }
  }

  async summarizeDream(
    body: string,
    context: AssistantContext,
  ): Promise<DreamAnalysis> {
    const fallback = await this.fallback.summarizeDream(body, context);
    try {
      const value = await this.request("summarizeDream", {
        body,
        context,
      });
      return normalizeDreamAnalysis(value, fallback);
    } catch {
      return fallback;
    }
  }

  async analyzeFeedback(
    context: AssistantContext,
    sessionId: string,
  ): Promise<MorningReviewResult> {
    const fallback = await this.fallback.analyzeFeedback(context, sessionId);
    try {
      const value = await this.request("analyzeFeedback", {
        context,
        sessionId,
      });
      return normalizeMorningReview(value, fallback);
    } catch {
      return fallback;
    }
  }

  private async request(operation: string, input: JsonMap): Promise<unknown> {
    const fetchFn = (globalThis as { fetch?: unknown }).fetch;
    if (typeof fetchFn !== "function") {
      throw new Error("Global fetch is not available in this runtime.");
    }
    const response = await (
      fetchFn as (
        url: string,
        init?: Record<string, unknown>,
      ) => Promise<{ ok: boolean; status: number; json(): Promise<unknown> }>
    )(this.config.baseUrl, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        ...(this.config.apiKey
          ? { authorization: `Bearer ${this.config.apiKey}` }
          : {}),
      },
      body: JSON.stringify({
        operation,
        model: this.config.modelName,
        input,
      }),
      signal: AbortSignal.timeout(this.config.timeoutMs) as unknown,
    });
    if (!response.ok) {
      throw new Error(
        `External AI provider request failed with status ${response.status}.`,
      );
    }
    const payload = asMap(await response.json());
    return payload.output ?? payload.data ?? payload;
  }
}

interface CloudBaseAIProviderConfig {
  envId: string;
  providerName: string;
  modelName: string;
}

class CloudBaseAIProvider implements AIProvider {
  constructor(private readonly config: CloudBaseAIProviderConfig) {
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
    this.model = app.ai().createModel("hunyuan-exp");
  }

  readonly model: any;
  private readonly fallback = new DeterministicAIProvider();

  get providerName(): string {
    return this.config.providerName;
  }

  get modelName(): string {
    return this.config.modelName;
  }

  async generateStructuredReply(
    context: AssistantContext,
    intent: AssistantIntent,
    prompt: string,
  ): Promise<StructuredAssistantReply> {
    const fallback = await this.fallback.generateStructuredReply(
      context,
      intent,
      prompt,
    );
    try {
      const value = await this.generateJson(
        "Return a JSON object for the assistant reply.",
        {
          schema: {
            reply: "string",
            intent: "string",
            recommendedActions: "array",
            updateTonightPlan: "boolean",
            updatedSurfaces: "array",
          },
          context,
          intent,
          prompt,
        },
      );
      return normalizeStructuredReply(value, fallback);
    } catch {
      return fallback;
    }
  }

  async generateTonightPlan(
    context: AssistantContext,
    runId: string,
  ): Promise<TonightPlan> {
    const fallback = await this.fallback.generateTonightPlan(context, runId);
    try {
      const value = await this.generateJson(
        "Return a JSON object for tonight's plan.",
        {
          schema: {
            dateKey: "string",
            coachSummary: "string",
            riskLevel: "low|medium|high",
            topFactors: "array",
            recommendedActions: "array",
            generatedAt: "string",
            sourceRunId: "string",
          },
          context,
          runId,
        },
      );
      return normalizeTonightPlan(value, fallback);
    } catch {
      return fallback;
    }
  }

  async summarizeDream(
    body: string,
    context: AssistantContext,
  ): Promise<DreamAnalysis> {
    const fallback = await this.fallback.summarizeDream(body, context);
    try {
      const value = await this.generateJson(
        "Return a JSON object for dream analysis.",
        {
          schema: {
            summary: "string",
            dominantEmotion: "string",
            suggestedFocus: "string",
            sourceRefs: "array",
          },
          body,
          context,
        },
      );
      return normalizeDreamAnalysis(value, fallback);
    } catch {
      return fallback;
    }
  }

  async analyzeFeedback(
    context: AssistantContext,
    sessionId: string,
  ): Promise<MorningReviewResult> {
    const fallback = await this.fallback.analyzeFeedback(context, sessionId);
    try {
      const value = await this.generateJson(
        "Return a JSON object for morning feedback analysis.",
        {
          schema: {
            reviewSummary: "string",
            effectiveActions: "array",
            ineffectiveActions: "array",
            profileSummary: "object",
          },
          context,
          sessionId,
        },
      );
      return normalizeMorningReview(value, fallback);
    } catch {
      return fallback;
    }
  }

  private async generateJson(
    instruction: string,
    payload: JsonMap,
  ): Promise<JsonMap> {
    const result = await this.model.generateText({
      model: this.config.modelName,
      messages: [
        {
          role: "system",
          content:
            "You are the backend orchestration model for a university dorm sleep intervention app. Always return valid JSON only.",
        },
        {
          role: "user",
          content: `${instruction}\n${JSON.stringify(payload)}`,
        },
      ],
    });
    return extractJsonObject(asString(result?.text));
  }
}

export function createAIProviderFromEnv(
  env: NodeJS.ProcessEnv = process.env,
): AIProvider {
  const mode = env.AI_PROVIDER_MODE?.trim() || "";
  const envId =
    env.CLOUDBASE_ENV_ID?.trim() ||
    env.TCB_ENV?.trim() ||
    env.SCF_NAMESPACE?.trim() ||
    "";
  if (mode === "cloudbase_ai" && envId) {
    return new CloudBaseAIProvider({
      envId,
      providerName: env.AI_PROVIDER_NAME?.trim() || "cloudbase_ai",
      modelName:
        env.AI_PROVIDER_MODEL?.trim() || "hunyuan-2.0-instruct-20251111",
    });
  }
  const baseUrl = env.AI_PROVIDER_BASE_URL?.trim();
  if (baseUrl) {
    return new HttpAIProvider({
      baseUrl,
      apiKey: env.AI_PROVIDER_API_KEY?.trim(),
      providerName: env.AI_PROVIDER_NAME?.trim() || "external_http",
      modelName: env.AI_PROVIDER_MODEL?.trim() || "structured-v1",
      timeoutMs: Number(env.AI_PROVIDER_TIMEOUT_MS ?? "12000") || 12000,
    });
  }
  return new DeterministicAIProvider();
}
