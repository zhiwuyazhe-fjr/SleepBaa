import {
  AssistantContext,
  AssistantMemoryCandidate,
  AssistantIntent,
  DreamAnalysis,
  InterferenceSnapshotDoc,
  MorningReviewResult,
  ProfileSummary,
  SleepCaptureDraft,
  SleepCaptureKind,
  StructuredAssistantReply,
  TurnInsightExtraction,
  TonightPlan,
} from "../shared/types";
import { rankInterferenceFactors } from "../services/rank_interference_factors";
import { pickRecommendedActions } from "../services/tonight_action_plan";

function summarizeSleepPattern(context: AssistantContext): string {
  const completed = context.recentSessions.filter(
    (item) => typeof item.totalSleepHours === "number",
  );
  const averageSleep =
    completed.length === 0
      ? 0
      : completed.reduce((sum, item) => sum + (item.totalSleepHours ?? 0), 0) /
        completed.length;
  if (completed.length === 0) {
    return "AI 助手还在积累你的睡眠反馈，完成几次夜间记录后，画像会更稳定。";
  }
  return `最近几晚平均睡眠 ${averageSleep.toFixed(
    1,
  )} 小时，今晚更适合优先稳住节奏，而不是一次塞进太多动作。`;
}

function summarizeDreamTrend(context: AssistantContext): string {
  if (context.recentDreams.length === 0) {
    return "梦境记录还比较少，起床后尽量用一句话记下最强烈的画面和情绪。";
  }
  const lastEmotion = context.recentDreams[0]?.emotionLabel || "混合";
  return `最近的梦境情绪偏向 ${lastEmotion}，建议继续结合晨间恢复感一起观察。`;
}

function summarizeEmotionTrend(context: AssistantContext): string {
  const mood = context.settings.selectedNightMood || "未设置";
  return `今晚心情是 ${mood}，建议保持低压力、低刺激、容易完成的建议风格。`;
}

function buildProfileSummary(context: AssistantContext): ProfileSummary {
  const factors = rankInterferenceFactors(context);
  return {
    sleepPatternSummary: summarizeSleepPattern(context),
    highRiskFactors: factors.slice(0, 3).map((item) => item.label),
    effectiveActions: pickRecommendedActions(context)
      .slice(0, 2)
      .map((item) => item.title),
    dreamTrendSummary: summarizeDreamTrend(context),
    emotionTrendSummary: summarizeEmotionTrend(context),
    lastUpdatedAt: new Date().toISOString(),
  };
}

function clampScore(score: number): number {
  return Math.max(0, Math.min(100, Math.round(score)));
}

function gradeLabelFromScore(score: number): string {
  if (score >= 75) {
    return "high";
  }
  if (score >= 45) {
    return "medium";
  }
  return "low";
}

function extractMemoryCandidates(params: {
  threadId: string;
  prompt: string;
  sourceMessageId?: string;
}): AssistantMemoryCandidate[] {
  const normalized = params.prompt.trim();
  if (!normalized) {
    return [];
  }
  const compact = normalized.replace(/\s+/g, " ");
  const lowered = compact.toLowerCase();
  const keywords = Array.from(
    new Set((lowered.match(/[a-z0-9\u4e00-\u9fff]+/g) ?? []).slice(0, 8)),
  );
  const next: AssistantMemoryCandidate[] = [];

  const maybePush = (
    kind: string,
    prefix: string,
    test: boolean,
    confidence = 0.72,
  ) => {
    if (!test) {
      return;
    }
    next.push({
      kind,
      content: compact,
      canonicalKey: `${prefix}:${lowered.slice(0, 64)}`,
      keywords,
      confidence,
      salience: confidence,
      sourceThreadId: params.threadId,
      sourceMessageId: params.sourceMessageId ?? null,
      sourceRefs: ["assistant_messages"],
    });
  };

  maybePush(
    "preference",
    "pref",
    /喜欢|不喜欢|偏好|讨厌|prefer|favorite/i.test(compact),
    0.76,
  );
  maybePush(
    "goal",
    "goal",
    /目标|希望|想要|计划|goal|want to/i.test(compact),
    0.8,
  );
  maybePush(
    "dorm_context",
    "dorm",
    /宿舍|室友|寝室|roommate|dorm/i.test(compact),
    0.74,
  );
  maybePush(
    "sleep_pattern",
    "sleep",
    /睡不着|失眠|作息|晚睡|早起|经常|总是|sleep/i.test(compact),
    0.78,
  );
  maybePush(
    "profile",
    "profile",
    /我是|我叫|身份|角色|i am|my name/i.test(compact),
    0.7,
  );
  return next.slice(0, 3);
}

function buildDeterministicReplyText(params: {
  context: AssistantContext;
  intent: AssistantIntent;
  prompt: string;
  plan: TonightPlan;
}): string {
  const assistantName = params.context.assistantProfile.assistantName || "小眠";
  if (params.intent === "noise_issue") {
    return `${assistantName}注意到你在提宿舍噪声，先不用逼自己马上睡着，先做一件最小的降噪动作，再把身体节奏慢慢收回来。`;
  }
  if (params.intent === "sleep_difficulty") {
    return `${assistantName}先别和清醒对抗，先把刺激降下来，不看时间，只做一件最容易完成的放松动作就够了。`;
  }
  if (params.intent === "dream_reflection") {
    return `${assistantName}会把这条梦当作恢复信号来理解。你先记下最强烈的画面和情绪，我们再一起看它和今晚状态之间的联系。`;
  }
  if (params.intent === "plan_review") {
    return `${assistantName}会先围绕 ${params.plan.topFactors[0]?.label || "节奏稳定"} 来安排今晚建议，再用两三个低负担动作收尾。`;
  }
  if (params.prompt.trim().length > 0) {
    return `${assistantName}已经记下你刚刚说的内容了。今晚先把节奏稳住，比一次性做很多更重要。`;
  }
  return `${assistantName}在，我会继续用温和、低压、可执行的小步骤陪你往前走。`;
}

function buildSignal(params: {
  type: InterferenceSnapshotDoc["type"];
  title: string;
  detail: string;
  score: number;
  source: string;
  value?: string;
}): InterferenceSnapshotDoc {
  const score = clampScore(params.score);
  return {
    type: params.type,
    title: params.title,
    value: params.value ?? "对话提及",
    gradeLabel: gradeLabelFromScore(score),
    status: "ready",
    detail: params.detail,
    source: params.source,
    measuredAt: new Date().toISOString(),
    numericValue: null,
    score,
  };
}

function buildDeterministicTurnInsights(params: {
  context: AssistantContext;
  threadId: string;
  prompt: string;
  reply: string;
  intent: AssistantIntent;
  sourceMessageId?: string;
}): TurnInsightExtraction {
  const source = `${params.prompt} ${params.reply}`.toLowerCase();
  const signals: InterferenceSnapshotDoc[] = [];

  if (/noise|loud|roommate|宿舍|室友|噪音|吵/.test(source)) {
    signals.push(
      buildSignal({
        type: "noise",
        title: "宿舍噪声",
        detail: "本轮对话里反复提到宿舍噪声或室友活动，今晚需要先处理外部声音干扰。",
        score: 78,
        source: "assistant_turn_extract",
        value: "高关注",
      }),
    );
  }
  if (/light|bright|灯|灯光|亮/.test(source)) {
    signals.push(
      buildSignal({
        type: "light",
        title: "灯光环境",
        detail: "这轮对话提到了光线刺激，建议把睡前环境继续压暗。",
        score: 60,
        source: "assistant_turn_extract",
        value: "需降光",
      }),
    );
  }
  if (/phone|screen|刷手机|手机|屏幕/.test(source)) {
    signals.push(
      buildSignal({
        type: "phoneUsage",
        title: "手机使用",
        detail: "对话显示睡前仍可能被手机或屏幕牵住注意力，适合先把设备放远。",
        score: 58,
        source: "assistant_turn_extract",
        value: "需降刺激",
      }),
    );
  }
  if (/anx|stress|panic|sad|烦|焦虑|压力|崩|难过|紧张/.test(source)) {
    signals.push(
      buildSignal({
        type: "emotion",
        title: "情绪压力",
        detail: "这轮对话里有明显的情绪负担信号，建议优先做低负担、可快速完成的安抚动作。",
        score: 70,
        source: "assistant_turn_extract",
        value: "情绪偏高",
      }),
    );
  }

  const nextContext: AssistantContext =
    signals.length == 0
      ? params.context
      : {
          ...params.context,
          userState: {
            ...(params.context.userState ?? {
              currentPhase: "assistant",
              profileSummary: buildProfileSummary(params.context),
              updatedAt: new Date().toISOString(),
            }),
            tonightInterference: {
              noise:
                signals.find((item) => item.type === "noise") ??
                params.context.userState?.tonightInterference?.noise ??
                buildSignal({
                  type: "noise",
                  title: "宿舍噪声",
                  detail: "暂无新的噪声对话信号。",
                  score: params.context.dorm.noiseDb,
                  source: "context",
                }),
              light:
                signals.find((item) => item.type === "light") ??
                params.context.userState?.tonightInterference?.light ??
                buildSignal({
                  type: "light",
                  title: "灯光环境",
                  detail: "暂无新的灯光对话信号。",
                  score: 28,
                  source: "context",
                }),
              phoneUsage:
                signals.find((item) => item.type === "phoneUsage") ??
                params.context.userState?.tonightInterference?.phoneUsage ??
                buildSignal({
                  type: "phoneUsage",
                  title: "手机使用",
                  detail: "暂无新的手机使用对话信号。",
                  score: 26,
                  source: "context",
                }),
              emotion:
                signals.find((item) => item.type === "emotion") ??
                params.context.userState?.tonightInterference?.emotion ??
                buildSignal({
                  type: "emotion",
                  title: "情绪压力",
                  detail: "暂无新的情绪对话信号。",
                  score: 30,
                  source: "context",
                }),
              updatedAt: new Date().toISOString(),
            },
          },
        };

  const shouldRefreshPlan =
    signals.length > 0 ||
    params.intent === "plan_review" ||
    /今晚|建议|计划|plan|suggest/i.test(params.prompt);

  return {
    interferenceSignals: signals,
    actionSuggestions: pickRecommendedActions(nextContext).slice(0, 3),
    memoryCandidates: extractMemoryCandidates({
      threadId: params.threadId,
      prompt: params.prompt,
      sourceMessageId: params.sourceMessageId,
    }),
    shouldRefreshPlan,
    updatedSurfaces:
      signals.length > 0 || shouldRefreshPlan
        ? ["assistant_context", "home_pre_sleep"]
        : ["assistant_context"],
  };
}

export type AIProviderSourceMode = "remoteSuccess" | "fallbackSuccess";

export interface AIProviderResult<T> {
  value: T;
  providerName: string;
  modelName: string;
  sourceMode: AIProviderSourceMode;
  errorMessage?: string | null;
}

export interface AIProvider {
  readonly providerName: string;
  readonly modelName: string;

  streamReplyText(
    context: AssistantContext,
    intent: AssistantIntent,
    prompt: string,
    onDelta?: (delta: string) => Promise<void> | void,
  ): Promise<AIProviderResult<string>>;

  extractTurnInsights(
    context: AssistantContext,
    params: {
      threadId: string;
      prompt: string;
      reply: string;
      intent: AssistantIntent;
      sourceMessageId?: string;
    },
  ): Promise<AIProviderResult<TurnInsightExtraction>>;

  generateStructuredReply(
    context: AssistantContext,
    intent: AssistantIntent,
    prompt: string,
  ): Promise<AIProviderResult<StructuredAssistantReply>>;

  generateConversationTitle(
    context: AssistantContext,
    params: {
      prompt: string;
      reply: string;
    },
  ): Promise<AIProviderResult<string>>;

  generateTonightPlan(
    context: AssistantContext,
    runId: string,
  ): Promise<AIProviderResult<TonightPlan>>;

  summarizeDream(
    body: string,
    context: AssistantContext,
  ): Promise<AIProviderResult<DreamAnalysis>>;

  generateSleepCapture(
    context: AssistantContext,
    params: {
      prompt: string;
      captureType: SleepCaptureKind;
      sessionId: string;
    },
  ): Promise<AIProviderResult<SleepCaptureDraft>>;

  analyzeFeedback(
    context: AssistantContext,
    sessionId: string,
  ): Promise<AIProviderResult<MorningReviewResult>>;
}

export function buildSystemIdentityReply(params: {
  assistantName: string;
  providerName: string;
  modelName: string;
  sourceMode: AIProviderSourceMode;
  errorMessage?: string | null;
}): StructuredAssistantReply {
  void params;

  return {
    reply:
      "我是小眠，是你的睡前陪伴助手。我会根据你的心情、宿舍状态和睡前记录，帮你整理今晚更适合的低负担行动。",
    intent: "system_identity",
    recommendedActions: [],
    updateTonightPlan: false,
    updatedSurfaces: ["assistant_context"],
  };
}

function deterministicResult<T>(value: T): AIProviderResult<T> {
  return {
    value,
    providerName: "deterministic",
    modelName: "rules-v1",
    sourceMode: "fallbackSuccess",
    errorMessage: null,
  };
}

function sanitizeConversationTitle(input: string): string {
  const cleaned = input
    .replace(/[\p{Emoji_Presentation}\p{Extended_Pictographic}]/gu, "")
    .replace(/[\r\n\t]+/g, " ")
    .replace(/[“”"'`*_#>~]/g, "")
    .trim();
  const firstPhrase = cleaned
    .split(/[。！？!?，,；;、]/)
    .map((item) => item.trim())
    .find((item) => item.length > 0);
  const title = firstPhrase || cleaned || "睡前对话";
  return title.length <= 12 ? title : title.slice(0, 12);
}

export class DeterministicAIProvider implements AIProvider {
  readonly providerName = "deterministic";
  readonly modelName = "rules-v1";

  async streamReplyText(
    context: AssistantContext,
    intent: AssistantIntent,
    prompt: string,
    onDelta?: (delta: string) => Promise<void> | void,
  ): Promise<AIProviderResult<string>> {
    const plan = (
      await this.generateTonightPlan(context, `reply-${Date.now()}`)
    ).value;
    const reply = buildDeterministicReplyText({
      context,
      intent,
      prompt,
      plan,
    });
    if (onDelta) {
      await onDelta(reply);
    }
    return deterministicResult<string>(reply);
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
    return deterministicResult<TurnInsightExtraction>(
      buildDeterministicTurnInsights({
        context,
        threadId: params.threadId,
        prompt: params.prompt,
        reply: params.reply,
        intent: params.intent,
        sourceMessageId: params.sourceMessageId,
      }),
    );
  }

  async generateStructuredReply(
    context: AssistantContext,
    intent: AssistantIntent,
    prompt: string,
  ): Promise<AIProviderResult<StructuredAssistantReply>> {
    const assistantName = context.assistantProfile.assistantName || "小眠";
    const planResult = await this.generateTonightPlan(
      context,
      `reply-${Date.now()}`,
    );
    const plan = planResult.value;

    let reply = `${assistantName}在，我会继续用温和、低压、可执行的小步骤陪你慢慢往前走。`;
    if (intent === "noise_issue") {
      reply = `${assistantName}注意到现在宿舍噪声大约 ${
        context.dorm.noiseDb
      } dB，先做一点降噪，再慢慢把身体节奏收回来，不用逼自己立刻睡着。`;
    } else if (intent === "sleep_difficulty") {
      reply = `${assistantName}建议你先别和失眠对抗，先把刺激降下来，不看时间，从今晚建议里挑一个最小动作开始就够了。`;
    } else if (intent === "dream_reflection") {
      reply = `${assistantName}会把这条梦当作一个恢复信号来理解。你先记下最强烈的画面和情绪，我们再一起看它和今晚状态之间的联系。`;
    } else if (intent === "plan_review") {
      reply = `${assistantName}会先围绕 ${
        plan.topFactors[0]?.label || "状态稳定"
      } 来安排今晚建议，再用 2 到 3 个低负担动作收尾。`;
    } else if (prompt.trim().length > 0) {
      reply = `${assistantName}已经记下“${prompt.trim()}”，也结合了你最近的睡眠、宿舍和梦境记录。今晚先把节奏稳住，比额外加码更重要。`;
    }

    return deterministicResult<StructuredAssistantReply>({
      reply,
      intent,
      recommendedActions: plan.recommendedActions,
      updateTonightPlan: intent !== "general_support",
      updatedSurfaces: ["assistant_context", "home_pre_sleep"],
    });
  }

  async generateConversationTitle(
    _context: AssistantContext,
    params: {
      prompt: string;
      reply: string;
    },
  ): Promise<AIProviderResult<string>> {
    return deterministicResult<string>(
      sanitizeConversationTitle(params.prompt || params.reply),
    );
  }

  async generateTonightPlan(
    context: AssistantContext,
    runId: string,
  ): Promise<AIProviderResult<TonightPlan>> {
    const topFactors = rankInterferenceFactors(context).slice(0, 3);
    const topScore = topFactors[0]?.score ?? 0;
    const riskLevel =
      topScore >= 70 ? "high" : topScore >= 40 ? "medium" : "low";

    return deterministicResult<TonightPlan>({
      dateKey: new Date().toISOString().slice(0, 10),
      coachSummary: `今晚先处理 ${
        topFactors[0]?.label || "节奏稳定"
      }，其余动作尽量保持安静、简单、可重复。`,
      riskLevel,
      topFactors,
      recommendedActions: pickRecommendedActions(context, [], runId),
      generatedAt: new Date().toISOString(),
      sourceRunId: runId,
    });
  }

  async summarizeDream(
    body: string,
    context: AssistantContext,
  ): Promise<AIProviderResult<DreamAnalysis>> {
    const normalized = body.toLowerCase();
    const dominantEmotion =
      normalized.includes("run") ||
      normalized.includes("chase") ||
      normalized.includes("考试") ||
      normalized.includes("迟到") ||
      normalized.includes("追赶") ||
      normalized.includes("panic")
        ? "不安"
        : normalized.includes("water") ||
            normalized.includes("light") ||
            normalized.includes("海") ||
            normalized.includes("水") ||
            normalized.includes("光")
          ? "平静"
          : normalized.includes("home") ||
              normalized.includes("family") ||
              normalized.includes("朋友") ||
              normalized.includes("家")
            ? "温暖"
            : "混合";

    return deterministicResult<DreamAnalysis>({
      summary: `这条梦更像是一次“${dominantEmotion}”情绪投射，建议和今晚心情、明早恢复感放在一起看。`,
      dominantEmotion,
      suggestedFocus: context.dorm.noiseDb > 35 ? "noise" : "phone_usage",
      sourceRefs: ["dream_entries.body", "user_settings.selectedNightMood"],
    });
  }

  async generateSleepCapture(
    _context: AssistantContext,
    params: {
      prompt: string;
      captureType: SleepCaptureKind;
      sessionId: string;
    },
  ): Promise<AIProviderResult<SleepCaptureDraft>> {
    const now = new Date();
    const hh = String(now.getHours()).padStart(2, "0");
    const mm = String(now.getMinutes()).padStart(2, "0");
    const fragments = params.prompt
      .split(/[，。！？\n]/)
      .map((item) => item.trim())
      .filter((item) => item.length > 0);
    const seed = fragments[0] ?? "";
    const shortSeed = seed.length <= 10 ? seed : `${seed.slice(0, 10)}...`;
    const lead = seed.length <= 22 ? seed : `${seed.slice(0, 22)}...`;
    return deterministicResult<SleepCaptureDraft>({
      type: params.captureType,
      title: `${params.captureType === "dream" ? "梦记" : "事记"} ${hh}:${mm} · ${
        shortSeed || "新的记录"
      }`,
      outline:
        params.captureType === "dream"
          ? `AI整理：梦里重点出现了“${lead || "一段待补充的画面"}”，适合稍后回看情绪和场景。`
          : `AI整理：这段事记主要围绕“${lead || "一段待整理的念头"}”，可在清醒后继续展开。`,
      content: params.prompt.trim(),
      reply:
        params.captureType === "dream"
          ? "我轻轻帮你收好了这段梦境，等你清醒些时可以再回来补充。"
          : "这段事记我先替你稳稳放好了，之后可以去事记仓库继续整理。",
    });
  }

  async analyzeFeedback(
    context: AssistantContext,
    sessionId: string,
  ): Promise<AIProviderResult<MorningReviewResult>> {
    const lastPlan = context.userState?.tonightPlan;
    const effectiveActions = lastPlan?.recommendedActions
      .slice(0, 2)
      .map((item) => item.title) ?? ["播放睡前放松音频"];
    const ineffectiveActions = lastPlan?.recommendedActions
      .slice(2)
      .map((item) => item.title) ?? ["把手机放远一点"];

    return deterministicResult<MorningReviewResult>({
      reviewSummary:
        "这次晨间反馈已经并入画像，下一轮建议会优先保留有效动作，减少低信号建议。",
      effectiveActions,
      ineffectiveActions,
      profileSummary: buildProfileSummary(context),
    });
  }
}

export function classifyIntent(prompt: string): AssistantIntent {
  const normalized = prompt.toLowerCase();

  if (
    normalized.includes("what model") ||
    normalized.includes("which model") ||
    normalized.includes("provider") ||
    normalized.includes("model name") ||
    normalized.includes("base model") ||
    normalized.includes("system prompt") ||
    normalized.includes("developer prompt") ||
    normalized.includes("hidden instruction") ||
    normalized.includes("chain of thought") ||
    normalized.includes("openai") ||
    normalized.includes("gpt") ||
    normalized.includes("claude") ||
    normalized.includes("deepseek") ||
    normalized.includes("hunyuan") ||
    normalized.includes("are you online") ||
    normalized.includes("联网") ||
    normalized.includes("在线") ||
    normalized.includes("什么模型") ||
    normalized.includes("哪个模型") ||
    normalized.includes("模型名") ||
    normalized.includes("底层模型") ||
    normalized.includes("大模型") ||
    normalized.includes("系统提示词") ||
    normalized.includes("开发者提示词") ||
    normalized.includes("隐藏指令") ||
    normalized.includes("后台接口") ||
    normalized.includes("底层接口") ||
    normalized.includes("供应商") ||
    normalized.includes("服务商") ||
    normalized.includes("混元") ||
    normalized.includes("智谱") ||
    normalized.includes("通义") ||
    normalized.includes("豆包") ||
    normalized.includes("文心") ||
    normalized.includes("是不是ai") ||
    normalized.includes("你是ai") ||
    normalized.includes("你是什么模型")
  ) {
    return "system_identity";
  }

  if (
    normalized.includes("noise") ||
    normalized.includes("loud") ||
    normalized.includes("roommate") ||
    normalized.includes("舍友") ||
    normalized.includes("宿舍") ||
    normalized.includes("吵") ||
    normalized.includes("噪音")
  ) {
    return "noise_issue";
  }

  if (
    normalized.includes("can't sleep") ||
    normalized.includes("awake") ||
    normalized.includes("fall asleep") ||
    normalized.includes("sleep mode") ||
    normalized.includes("睡不着") ||
    normalized.includes("失眠") ||
    normalized.includes("醒了")
  ) {
    return "sleep_difficulty";
  }

  if (normalized.includes("dream") || normalized.includes("梦")) {
    return "dream_reflection";
  }

  if (
    normalized.includes("plan") ||
    normalized.includes("tonight") ||
    normalized.includes("suggest") ||
    normalized.includes("建议") ||
    normalized.includes("今晚") ||
    normalized.includes("计划")
  ) {
    return "plan_review";
  }

  return "general_support";
}

export function buildDeterministicProfileSummary(
  context: AssistantContext,
): ProfileSummary {
  return buildProfileSummary(context);
}
