import { AssistantContext, RecommendedAction, TonightPlan } from "../shared/types";
import { rankInterferenceFactors } from "./rank_interference_factors";

export const TONIGHT_ACTION_COUNT = 6;

type ActionId =
  | "earplug"
  | "eye-mask"
  | "dorm-quiet"
  | "phone-down"
  | "breath-reset"
  | "thought-clean"
  | "audio-ocean"
  | "audio-rain"
  | "audio-breeze"
  | "water"
  | "screen-dim"
  | "stretch-release"
  | "muscle-relax"
  | "bed-tidy"
  | "curtain-gap"
  | "alarm-ready"
  | "safe-place"
  | "cool-room";

type ActionGroup =
  | "audio"
  | "body"
  | "dorm"
  | "emotion"
  | "light"
  | "noise"
  | "phone"
  | "prep";

interface CatalogAction extends RecommendedAction {
  id: ActionId;
  group: ActionGroup;
  baseScore: number;
  signalWeights: Partial<Record<string, number>>;
  aliases: RegExp[];
}

export const TONIGHT_ACTION_CATALOG: CatalogAction[] = [
  {
    id: "earplug",
    group: "noise",
    title: "佩戴隔音耳塞",
    subtitle: "先把随机噪声压下去，减少被室友或走动声打断的概率。",
    type: "quickAction",
    priority: 1,
    reason: "噪声是今晚更直接的入睡干扰，先做最小降噪动作。",
    route: "/intervention/task",
    trackId: null,
    tags: ["1 分钟", "降噪"],
    baseScore: 18,
    signalWeights: { noise: 90 },
    aliases: [/耳塞|隔音|降噪|噪声|噪音|吵|earplug|noise/i],
  },
  {
    id: "eye-mask",
    group: "light",
    title: "压暗光线或戴眼罩",
    subtitle: "把灯光刺激降到最低，让身体更容易进入睡前节奏。",
    type: "quickAction",
    priority: 2,
    reason: "光线会延迟放松节奏，今晚适合先把视觉刺激收下来。",
    route: "/intervention/task",
    trackId: null,
    tags: ["1 分钟", "降光"],
    baseScore: 16,
    signalWeights: { light: 94 },
    aliases: [/眼罩|关灯|灯光|光线|太亮|暗|light|bright|mask/i],
  },
  {
    id: "dorm-quiet",
    group: "dorm",
    title: "轻声同步宿舍状态",
    subtitle: "用一句低压力提醒，和室友对齐关灯、降声或减少走动。",
    type: "quickAction",
    priority: 3,
    reason: "宿舍状态来自多人环境，温和沟通比硬扛更适合答辩演示里的联动场景。",
    route: "/dorm/status",
    trackId: null,
    tags: ["2 分钟", "宿舍"],
    baseScore: 14,
    signalWeights: { noise: 66, light: 70, emotion: 24 },
    aliases: [/宿舍|室友|舍友|寝室|沟通|关灯|小声|roommate|dorm/i],
  },
  {
    id: "phone-down",
    group: "phone",
    title: "把手机放到桌面充电",
    subtitle: "减少屏幕光和消息提醒，让入睡节奏更稳定。",
    type: "quickAction",
    priority: 4,
    reason: "手机使用会持续拉住注意力，先切断最常见的临睡刺激。",
    route: "/intervention/task",
    trackId: null,
    tags: ["立刻执行", "降刺激"],
    baseScore: 20,
    signalWeights: { phone_usage: 96, light: 30 },
    aliases: [/手机|屏幕|消息|刷|放远|充电|phone|screen/i],
  },
  {
    id: "breath-reset",
    group: "emotion",
    title: "做 3 轮慢呼吸",
    subtitle: "把注意力放在呼气变长，先让情绪强度降一点。",
    type: "quickAction",
    priority: 5,
    reason: "今晚情绪负担偏高时，低门槛呼吸练习比复杂任务更稳。",
    route: "/intervention/task",
    trackId: null,
    tags: ["2 分钟", "安抚"],
    baseScore: 22,
    signalWeights: { emotion: 92, phone_usage: 18 },
    aliases: [/呼吸|放松|焦虑|压力|烦|紧张|breath|anx|stress/i],
  },
  {
    id: "thought-clean",
    group: "emotion",
    title: "睡前思绪清理",
    subtitle: "记下一件今晚最想放下的事，让脑子先轻一点。",
    type: "quickAction",
    priority: 6,
    reason: "思绪占用明显时，把念头外置能减少反复内耗。",
    route: "/assistant?flow=sleep_capture&mode=memo",
    trackId: null,
    tags: ["5 分钟", "情绪整理"],
    baseScore: 19,
    signalWeights: { emotion: 72, phone_usage: 42 },
    aliases: [/思绪|念头|记录|写下|清理|难过|memo|journal|thought/i],
  },
  {
    id: "audio-ocean",
    group: "audio",
    title: "播放睡前放松音频",
    subtitle: "用低刺激海浪白噪音托住环境波动，让身体慢慢降速。",
    type: "audio",
    priority: 7,
    reason: "稳定背景音适合作为兜底，也能缓冲宿舍随机声响。",
    route: "/intervention/task",
    trackId: "deep-ocean",
    tags: ["15 分钟", "放松"],
    baseScore: 34,
    signalWeights: { noise: 40, emotion: 34, light: 8 },
    aliases: [/音频|音乐|白噪音|海浪|放松|audio|music|ocean/i],
  },
  {
    id: "audio-rain",
    group: "audio",
    title: "切到夜雨白噪音",
    subtitle: "用连续雨声盖掉走廊和翻身的零碎声，让环境更像一整块背景。",
    type: "audio",
    priority: 8,
    reason: "随机噪声偏多时，雨声比纯安静更容易遮住突发声响。",
    route: "/intervention/task",
    trackId: "rain-mist",
    tags: ["20 分钟", "雨声"],
    baseScore: 26,
    signalWeights: { noise: 58, emotion: 18 },
    aliases: [/雨声|夜雨|白噪音|走廊|杂音|rain|mist/i],
  },
  {
    id: "audio-breeze",
    group: "audio",
    title: "播放午夜微风",
    subtitle: "把背景音调得更轻，适合心里还绷着但不想被强节奏打扰的夜晚。",
    type: "audio",
    priority: 9,
    reason: "情绪紧绷但环境不算吵时，轻风声更像低压陪伴。",
    route: "/intervention/task",
    trackId: "midnight-breeze",
    tags: ["25 分钟", "轻风"],
    baseScore: 23,
    signalWeights: { emotion: 45, noise: 20 },
    aliases: [/微风|风声|轻风|陪伴|breeze|wind/i],
  },
  {
    id: "water",
    group: "prep",
    title: "床边准备一杯温水",
    subtitle: "避免半夜口渴起身，打断已经形成的困意。",
    type: "quickAction",
    priority: 8,
    reason: "先移除小中断，能让整晚状态更稳定。",
    route: "/intervention/task",
    trackId: null,
    tags: ["30 秒", "准备"],
    baseScore: 13,
    signalWeights: {},
    aliases: [/温水|喝水|口渴|water/i],
  },
  {
    id: "screen-dim",
    group: "phone",
    title: "开启勿扰并压低亮度",
    subtitle: "把通知、亮度和蓝光一起降下来，减少继续刷下去的入口。",
    type: "quickAction",
    priority: 11,
    reason: "手机和灯光同时偏高时，先处理屏幕刺激会更快见效。",
    route: "/intervention/task",
    trackId: null,
    tags: ["1 分钟", "熄屏"],
    baseScore: 16,
    signalWeights: { phone_usage: 82, light: 48 },
    aliases: [/勿扰|低亮度|亮度|蓝光|熄屏|通知|do not disturb|dim/i],
  },
  {
    id: "stretch-release",
    group: "body",
    title: "做 90 秒肩颈放松",
    subtitle: "放下肩膀，慢慢转动脖颈，让身体先从紧绷里退出来。",
    type: "quickAction",
    priority: 12,
    reason: "情绪压力常会落在肩颈和下颌，短拉伸能给身体一个结束信号。",
    route: "/intervention/task",
    trackId: null,
    tags: ["90 秒", "身体放松"],
    baseScore: 17,
    signalWeights: { emotion: 58, phone_usage: 18 },
    aliases: [/拉伸|肩颈|脖子|身体|僵|酸|stretch|neck/i],
  },
  {
    id: "muscle-relax",
    group: "body",
    title: "从脚趾开始放松肌肉",
    subtitle: "按脚趾、小腿、肩膀的顺序轻轻收紧再放开，帮助身体降档。",
    type: "quickAction",
    priority: 13,
    reason: "焦虑或烦躁偏高时，渐进式肌肉放松比继续讲道理更容易落地。",
    route: "/intervention/task",
    trackId: null,
    tags: ["3 分钟", "放松"],
    baseScore: 16,
    signalWeights: { emotion: 72 },
    aliases: [/肌肉|身体扫描|脚趾|小腿|放松身体|progressive|muscle/i],
  },
  {
    id: "bed-tidy",
    group: "prep",
    title: "整理床面和枕头",
    subtitle: "把被角、枕头和床边小物归位，减少躺下后的细碎不适。",
    type: "quickAction",
    priority: 14,
    reason: "当主要干扰不强时，微整理能给入睡一个清晰的开始动作。",
    route: "/intervention/task",
    trackId: null,
    tags: ["2 分钟", "准备"],
    baseScore: 12,
    signalWeights: { emotion: 16 },
    aliases: [/床|枕头|被子|床面|收拾|整理|pillow|bed/i],
  },
  {
    id: "curtain-gap",
    group: "light",
    title: "拉好床帘或窗帘缝隙",
    subtitle: "挡住走廊光、台灯余光和屏幕反光，让眼睛少接收一点刺激。",
    type: "quickAction",
    priority: 15,
    reason: "光线问题不一定只靠眼罩，先把外部漏光处理掉更自然。",
    route: "/dorm/status",
    trackId: null,
    tags: ["1 分钟", "遮光"],
    baseScore: 15,
    signalWeights: { light: 78, dorm: 18 },
    aliases: [/床帘|窗帘|帘子|漏光|遮光|curtain/i],
  },
  {
    id: "alarm-ready",
    group: "prep",
    title: "确认明早闹钟和充电",
    subtitle: "把闹钟、充电和明早第一件事一次确认完，减少临睡前反复检查。",
    type: "quickAction",
    priority: 16,
    reason: "如果脑子还在惦记明天，先把可确认的事收口。",
    route: "/intervention/task",
    trackId: null,
    tags: ["1 分钟", "收口"],
    baseScore: 13,
    signalWeights: { phone_usage: 48, emotion: 28 },
    aliases: [/闹钟|明早|明天|充电|检查|alarm|tomorrow/i],
  },
  {
    id: "safe-place",
    group: "emotion",
    title: "想象一个安全场景",
    subtitle: "选一个熟悉、安静、没有任务感的地方，在脑中停留一分钟。",
    type: "quickAction",
    priority: 17,
    reason: "烦躁和焦虑比较高时，安全场景能比继续分析更快降低警觉。",
    route: "/assistant?flow=sleep_capture&mode=memo",
    trackId: null,
    tags: ["1 分钟", "安抚"],
    baseScore: 14,
    signalWeights: { emotion: 76 },
    aliases: [/安全|想象|场景|画面|安心|safe|visual/i],
  },
  {
    id: "cool-room",
    group: "prep",
    title: "给床边留一点通风",
    subtitle: "如果觉得闷热，留出一点空气流动，避免刚躺下就反复翻身。",
    type: "quickAction",
    priority: 18,
    reason: "温度和闷热不是核心检测项，但常会成为最后一点入睡阻力。",
    route: "/dorm/status",
    trackId: null,
    tags: ["30 秒", "环境"],
    baseScore: 11,
    signalWeights: { emotion: 8 },
    aliases: [/闷|热|通风|空调|温度|cool|air/i],
  },
];

const CATALOG_BY_ID = new Map<ActionId, CatalogAction>(
  TONIGHT_ACTION_CATALOG.map((action) => [action.id, action]),
);

function cloneCatalogAction(action: CatalogAction): RecommendedAction {
  return {
    id: action.id,
    title: action.title,
    subtitle: action.subtitle,
    type: action.type,
    priority: action.priority,
    reason: action.reason,
    route: action.route,
    trackId: action.trackId ?? null,
    tags: [...action.tags],
  };
}

function actionText(action: Partial<RecommendedAction>): string {
  return [action.id, action.title, action.subtitle, action.reason, ...(action.tags ?? [])]
    .filter((item): item is string => typeof item === "string")
    .join(" ");
}

function canonicalActionId(action: Partial<RecommendedAction>): ActionId | null {
  const rawId = typeof action.id === "string" ? action.id.trim() : "";
  if (CATALOG_BY_ID.has(rawId as ActionId)) {
    return rawId as ActionId;
  }
  const text = actionText(action);
  if (/室友|宿舍|舍友|寝室|roommate|dorm/i.test(text)) {
    return "dorm-quiet";
  }
  if (/床帘|窗帘|帘子|漏光|遮光|curtain/i.test(text)) {
    return "curtain-gap";
  }
  if (/勿扰|低亮度|蓝光|熄屏|通知|do not disturb|dim/i.test(text)) {
    return "screen-dim";
  }
  if (/雨声|夜雨|rain|mist/i.test(text)) {
    return "audio-rain";
  }
  if (/微风|风声|轻风|breeze|wind/i.test(text)) {
    return "audio-breeze";
  }
  for (const catalogAction of TONIGHT_ACTION_CATALOG) {
    if (catalogAction.aliases.some((alias) => alias.test(text))) {
      return catalogAction.id;
    }
  }
  return null;
}

function feedbackScore(context: AssistantContext, action: CatalogAction): number {
  const loop = context.userState?.feedbackLoop;
  const effective =
    loop?.effectiveActions.some(
      (item) => item === action.id || item.includes(action.title),
    ) ?? false;
  const ineffective =
    loop?.ineffectiveActions.some(
      (item) => item === action.id || item.includes(action.title),
    ) ?? false;
  const memoryScore = (context.longTermMemory ?? []).reduce((sum, item) => {
    if (item.kind !== "intervention_effect" && item.kind !== "strategy_weight") {
      return sum;
    }
    const haystack = [
      item.content,
      item.canonicalKey ?? "",
      item.sourceActionId ?? "",
      ...(item.keywords ?? []),
    ]
      .join(" ")
      .toLowerCase();
    const actionText = `${action.id} ${action.title} ${action.subtitle}`.toLowerCase();
    const matches =
      haystack.includes(action.id.toLowerCase()) ||
      haystack.includes(action.title.toLowerCase()) ||
      action.aliases.some((alias) => alias.test(haystack)) ||
      actionText
        .split(/\s+/)
        .filter((token) => token.length >= 2)
        .some((token) => haystack.includes(token));
    if (!matches) {
      return sum;
    }
    const effect = item.effectivenessScore ?? 0;
    if (effect > 0) {
      return sum + Math.min(12, effect * 12);
    }
    if (effect < 0) {
      return sum - Math.min(16, Math.abs(effect) * 16);
    }
    return sum;
  }, 0);
  return (effective ? 10 : 0) + (ineffective ? -14 : 0) + memoryScore;
}

function moodScore(context: AssistantContext, action: CatalogAction): number {
  const mood = (context.settings.selectedNightMood ?? "").toLowerCase();
  if (mood === "sad") {
    if (
      action.id === "breath-reset" ||
      action.id === "thought-clean" ||
      action.id === "muscle-relax" ||
      action.id === "safe-place"
    ) {
      return 14;
    }
    if (action.id === "audio-ocean" || action.id === "audio-breeze") {
      return 8;
    }
  }
  if (mood === "happy") {
    if (action.id === "phone-down" || action.id === "alarm-ready") {
      return 8;
    }
    if (action.id === "bed-tidy") {
      return 5;
    }
  }
  if (mood === "calm") {
    if (
      action.id === "audio-ocean" ||
      action.id === "audio-breeze" ||
      action.id === "water" ||
      action.id === "bed-tidy"
    ) {
      return 6;
    }
  }
  return 0;
}

function dormScore(context: AssistantContext, action: CatalogAction): number {
  const activeMembers =
    context.dorm.activeMemberCount ??
    context.dorm.members.filter(
      (member) => member.status !== "quiet" || !member.sleepModeActive,
    ).length;
  if (activeMembers <= 1) {
    return 0;
  }
  if (action.id === "dorm-quiet") {
    return 12;
  }
  if (action.id === "earplug" || action.group === "audio") {
    return 6;
  }
  if (action.id === "curtain-gap" || action.id === "cool-room") {
    return 5;
  }
  return 0;
}

function hashString(value: string): number {
  let hash = 2166136261;
  for (let index = 0; index < value.length; index += 1) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

function varietyScore(
  context: AssistantContext,
  action: CatalogAction,
  salt = "",
): number {
  const interference = context.userState?.tonightInterference;
  const contextKey = [
    context.user.uid,
    context.settings.selectedNightMood ?? "",
    context.dorm.lightLabel,
    context.dorm.quietLabel,
    Math.round(context.dorm.noiseDb / 5) * 5,
    interference?.updatedAt?.slice(0, 13) ?? "",
    salt.slice(0, 18),
    action.id,
  ].join("|");
  return (hashString(contextKey) % 400) / 100;
}

function candidateBoosts(
  candidates: Partial<RecommendedAction>[],
): Map<ActionId, { score: number; reason?: string }> {
  const boosts = new Map<ActionId, { score: number; reason?: string }>();
  candidates.forEach((candidate, index) => {
    const id = canonicalActionId(candidate);
    if (!id) {
      return;
    }
    const previous = boosts.get(id);
    const score = 44 - index * 5;
    if (!previous || previous.score < score) {
      boosts.set(id, {
        score,
        reason:
          typeof candidate.reason === "string" && candidate.reason.trim()
            ? candidate.reason.trim()
            : undefined,
      });
    }
  });
  return boosts;
}

export function pickRecommendedActions(
  context: AssistantContext,
  candidates: Partial<RecommendedAction>[] = [],
  salt = "",
): RecommendedAction[] {
  const factors = rankInterferenceFactors(context).slice(0, 4);
  const boosts = candidateBoosts(candidates);
  const scored = TONIGHT_ACTION_CATALOG.map((action, catalogIndex) => {
    const factorScore = factors.reduce((sum, factor, factorIndex) => {
      const weight = action.signalWeights[factor.key] ?? 0;
      const rankWeight = factorIndex === 0 ? 1 : factorIndex === 1 ? 0.72 : 0.46;
      return sum + (factor.score / 100) * weight * rankWeight;
    }, 0);
    const boost = boosts.get(action.id);
    return {
      action,
      catalogIndex,
      reason: boost?.reason,
      score:
        action.baseScore +
        factorScore +
        (boost?.score ?? 0) +
        feedbackScore(context, action) +
        moodScore(context, action) +
        dormScore(context, action) +
        varietyScore(context, action, salt),
    };
  });

  const sorted = scored.sort(
    (a, b) => b.score - a.score || a.catalogIndex - b.catalogIndex,
  );
  let selected = sorted
    .reduce<typeof scored>((items, item) => {
      if (items.length >= TONIGHT_ACTION_COUNT) {
        return items;
      }
      if (
        item.action.type === "audio" &&
        items.some((selectedItem) => selectedItem.action.type === "audio")
      ) {
        return items;
      }
      const sameGroupCount = items.filter(
        (selectedItem) => selectedItem.action.group === item.action.group,
      ).length;
      if (sameGroupCount >= 2) {
        return items;
      }
      return [...items, item];
    }, []);

  if (!selected.some((item) => item.action.type === "audio")) {
    const bestAudio = sorted.find((item) => item.action.type === "audio");
    if (bestAudio != null) {
      selected = [...selected.slice(0, TONIGHT_ACTION_COUNT - 1), bestAudio];
    }
  }

  return selected
    .map((item, index) => ({
      ...cloneCatalogAction(item.action),
      reason: item.reason ?? item.action.reason,
      priority: index + 1,
    }));
}

export function normalizeTonightPlanForContext(
  context: AssistantContext,
  plan: TonightPlan,
): TonightPlan {
  return {
    ...plan,
    recommendedActions: pickRecommendedActions(
      context,
      plan.recommendedActions,
      plan.sourceRunId,
    ),
  };
}
