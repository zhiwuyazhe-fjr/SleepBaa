import { randomUUID } from "node:crypto";
import {
  AIProvider,
  buildDeterministicProfileSummary,
} from "../providers/ai_provider";
import { AssistantDataRepository } from "../repositories/firestore_repositories";
import { buildCardSnapshots } from "../services/materialize_card_snapshots";
import {
  handleSleepSessionChange,
  prepareTonightPlan,
} from "../orchestrators/assistant_orchestrator";
import {
  AgentToolDefinitionDoc,
  AgentToolRisk,
  AssistantContext,
  AssistantMemoryItem,
  InterferenceSnapshotDoc,
  SleepCaptureKind,
  SurfaceId,
  TonightInterferenceStateDoc,
  UserStateDoc,
} from "../shared/types";

type JsonMap = Record<string, unknown>;

const SURFACE_IDS = new Set<SurfaceId>([
  "home_pre_sleep",
  "sleep_mode",
  "morning_feedback",
  "profile_report",
  "assistant_context",
]);

export interface AgentToolResult {
  output: JsonMap;
  updatedSurfaces?: SurfaceId[];
  undoPayload?: JsonMap | null;
  memorySyncedCount?: number;
  committed?: boolean;
}

export interface AgentToolRuntimeState {
  repo: AssistantDataRepository;
  provider: AIProvider;
  uid: string;
  threadId?: string | null;
  prompt: string;
  runId: string;
  planId: string;
  context?: AssistantContext;
}

export interface AgentTool {
  definition: AgentToolDefinitionDoc;
  execute(
    input: JsonMap,
    state: AgentToolRuntimeState,
  ): Promise<AgentToolResult>;
}

function nowIso(): string {
  return new Date().toISOString();
}

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

function asList(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function asNumber(value: unknown, fallback = 0): number {
  return typeof value === "number" && Number.isFinite(value) ? value : fallback;
}

function clampScore(value: number): number {
  return Math.max(0, Math.min(100, Math.round(value)));
}

async function ensureContext(
  state: AgentToolRuntimeState,
): Promise<AssistantContext> {
  if (state.context) {
    return state.context;
  }
  state.context = await state.repo.buildAssistantContext(
    state.uid,
    state.threadId ?? undefined,
    {
      profile: "insight_full",
      recentSessionCount: 5,
      recentDreamCount: 5,
      messageCount: 10,
      memoryLimit: 10,
      memoryQuery: state.prompt,
    },
  );
  return state.context;
}

function normalizeSurfaces(
  value: unknown,
  fallback: SurfaceId[] = ["assistant_context"],
): SurfaceId[] {
  const surfaces = asStringArray(value)
    .map((item) => item.trim() as SurfaceId)
    .filter((item) => SURFACE_IDS.has(item));
  return surfaces.length > 0 ? Array.from(new Set(surfaces)) : fallback;
}

function buildFallbackUserState(context: AssistantContext): UserStateDoc {
  return {
    currentPhase: "assistant",
    activeSessionId: null,
    latestThreadId: null,
    latestNightMood: context.settings.selectedNightMood ?? null,
    profileSummary: buildDeterministicProfileSummary(context),
    tonightPlan: null,
    tonightInterference: null,
    feedbackLoop: null,
    updatedAt: nowIso(),
  };
}

function sleepDayKeyFromIso(value: string): string {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return nowIso().slice(0, 10);
  }
  return date.toISOString().slice(0, 10);
}

function activeSessionId(context: AssistantContext): string {
  return (
    context.userState?.activeSessionId ||
    context.recentSessions.find((session) => session.status === "active")?.id ||
    ""
  );
}

function closeSleepSegments(
  value: unknown,
  fallbackStartedAt: string,
  endedAt: string,
): JsonMap[] {
  const segments = asList(value).map((item) => asMap(item));
  const normalized =
    segments.length > 0 ? segments : [{ startedAt: fallbackStartedAt }];
  return normalized.map((segment, index) => {
    const isLast = index === normalized.length - 1;
    return {
      ...segment,
      endedAt: asString(segment.endedAt, isLast ? endedAt : ""),
    };
  });
}

function trackedDurationMinutes(startedAt: string, endedAt: string): number {
  const start = Date.parse(startedAt);
  const end = Date.parse(endedAt);
  if (Number.isNaN(start) || Number.isNaN(end) || end <= start) {
    return 0;
  }
  return Math.max(0, Math.round((end - start) / 60000));
}

function snapshot(params: {
  type: InterferenceSnapshotDoc["type"];
  title: string;
  detail: string;
  source: string;
  score: number;
  value?: string;
  numericValue?: number | null;
}): InterferenceSnapshotDoc {
  const score = clampScore(params.score);
  return {
    type: params.type,
    title: params.title,
    value: params.value ?? "agent",
    gradeLabel: score >= 75 ? "high" : score >= 45 ? "medium" : "low",
    status: "ready",
    detail: params.detail,
    source: params.source,
    measuredAt: nowIso(),
    numericValue: params.numericValue ?? null,
    score,
  };
}

function defaultInterference(
  context: AssistantContext,
): TonightInterferenceStateDoc {
  return {
    noise: snapshot({
      type: "noise",
      title: "宿舍噪音",
      detail: `当前宿舍噪音约 ${context.dorm.noiseDb} dB。`,
      source: "agent_context",
      score: context.dorm.noiseDb * 1.6,
      value: `${context.dorm.noiseDb} dB`,
      numericValue: context.dorm.noiseDb,
    }),
    light: snapshot({
      type: "light",
      title: "灯光环境",
      detail: `当前灯光记录为 ${context.dorm.lightLabel || "未设置"}。`,
      source: "agent_context",
      score: 30,
      value: context.dorm.lightLabel || "未设置",
    }),
    phoneUsage: snapshot({
      type: "phoneUsage",
      title: "手机使用",
      detail: "暂未收到新的手机使用信号，按中等以下干扰处理。",
      source: "agent_context",
      score: 30,
      value: "未测量",
    }),
    emotion: snapshot({
      type: "emotion",
      title: "情绪压力",
      detail: `当前夜间心情为 ${context.settings.selectedNightMood || "未设置"}。`,
      source: "agent_context",
      score: 32,
      value: context.settings.selectedNightMood || "未设置",
    }),
    updatedAt: nowIso(),
  };
}

function buildInterferenceFromPrompt(
  context: AssistantContext,
  prompt: string,
): TonightInterferenceStateDoc {
  const existing =
    context.userState?.tonightInterference ?? defaultInterference(context);
  const lowered = prompt.toLowerCase();
  const noiseMentioned =
    /noise|loud|roommate|dorm|吵|噪|室友|宿舍|声音/.test(lowered);
  const phoneMentioned = /phone|screen|手机|屏幕|刷/.test(lowered);
  const emotionMentioned = /stress|anx|烦|焦虑|压力|紧张|难受/.test(lowered);
  const lightMentioned = /light|bright|灯|亮|光/.test(lowered);

  return {
    noise: noiseMentioned
      ? snapshot({
          type: "noise",
          title: "宿舍噪音",
          detail:
            "本轮对话提到室友、宿舍或噪音干扰，今晚优先按高关注处理。",
          source: "agent_prompt",
          score: Math.max(76, context.dorm.noiseDb * 1.8),
          value: "高关注",
          numericValue: context.dorm.noiseDb,
        })
      : existing.noise,
    light: lightMentioned
      ? snapshot({
          type: "light",
          title: "灯光环境",
          detail: "本轮对话提到光线刺激，建议先压暗环境。",
          source: "agent_prompt",
          score: 62,
          value: "需降光",
        })
      : existing.light,
    phoneUsage: phoneMentioned
      ? snapshot({
          type: "phoneUsage",
          title: "手机使用",
          detail: "本轮对话提到手机或屏幕，建议把设备放远并降低提醒。",
          source: "agent_prompt",
          score: 60,
          value: "需降刺激",
        })
      : existing.phoneUsage,
    emotion: emotionMentioned
      ? snapshot({
          type: "emotion",
          title: "情绪压力",
          detail: "本轮对话出现明显情绪负担信号，今晚建议低负担安抚。",
          source: "agent_prompt",
          score: 70,
          value: "偏高",
        })
      : existing.emotion,
    updatedAt: nowIso(),
  };
}

function summarizeContext(context: AssistantContext): JsonMap {
  return {
    displayName: context.user.displayName,
    phase: context.userState?.currentPhase ?? "assistant",
    dorm: {
      id: context.dorm.id,
      name: context.dorm.name,
      noiseDb: context.dorm.noiseDb,
      quietLabel: context.dorm.quietLabel,
      memberCount: context.dorm.members.length,
    },
    recentSessionCount: context.recentSessions.length,
    recentDreamCount: context.recentDreams.length,
    memoryCount: context.longTermMemory?.length ?? 0,
    hasTonightPlan: Boolean(context.userState?.tonightPlan),
  };
}

function memoryItem(params: {
  uid: string;
  runId: string;
  callId?: string | null;
  threadId?: string | null;
  kind: string;
  content: string;
  canonicalKey: string;
  keywords: string[];
  confidence?: number;
  salience?: number;
  effectivenessScore?: number | null;
}): AssistantMemoryItem {
  const timestamp = nowIso();
  const confidence = params.confidence ?? 0.72;
  return {
    id: `${params.uid}:${params.kind}:${params.canonicalKey
      .replace(/[^a-z0-9\u4e00-\u9fff]+/gi, "-")
      .replace(/^-+|-+$/g, "")
      .slice(0, 64)}`,
    kind: params.kind,
    content: params.content,
    canonicalKey: params.canonicalKey,
    keywords: params.keywords,
    confidence,
    sourceThreadId: params.threadId ?? null,
    sourceMessageId: null,
    salience: params.salience ?? confidence,
    decayScore: 1,
    contradictionGroup: `${params.kind}:${params.canonicalKey}`,
    evidenceRefs: [
      `agent_runs:${params.runId}`,
      ...(params.callId ? [`agent_tool_calls:${params.callId}`] : []),
    ],
    sourceActionId: params.callId ?? null,
    sourceAgentRunId: params.runId,
    effectivenessScore: params.effectivenessScore ?? null,
    lastUsedAt: timestamp,
    sourceRefs: ["agent_runtime", `agent_runs:${params.runId}`],
    createdAt: timestamp,
    updatedAt: timestamp,
  };
}

function stringSchema(description: string): JsonMap {
  return { type: "string", description };
}

function objectSchema(properties: JsonMap = {}, required: string[] = []): JsonMap {
  return {
    type: "object",
    properties,
    required,
    additionalProperties: true,
  };
}

function definition(params: {
  name: string;
  title: string;
  description: string;
  risk: AgentToolRisk;
  inputSchema?: JsonMap;
  undoable?: boolean;
  requiresHardConfirm?: boolean;
}): AgentToolDefinitionDoc {
  return {
    name: params.name,
    title: params.title,
    description: params.description,
    risk: params.risk,
    inputSchema: params.inputSchema ?? objectSchema(),
    undoable: params.undoable ?? false,
    requiresHardConfirm: params.requiresHardConfirm ?? false,
  };
}

const TOOLS: AgentTool[] = [
  {
    definition: definition({
      name: "context.read",
      title: "读取用户上下文",
      description: "读取睡眠、宿舍、梦记、消息和长期记忆摘要。",
      risk: "read",
    }),
    async execute(_input, state) {
      const context = await ensureContext(state);
      return { output: summarizeContext(context) };
    },
  },
  {
    definition: definition({
      name: "sleep.records.read",
      title: "读取睡眠记录",
      description: "返回最近睡眠记录摘要。",
      risk: "read",
    }),
    async execute(_input, state) {
      const context = await ensureContext(state);
      return {
        output: {
          records: context.recentSessions,
          count: context.recentSessions.length,
        },
      };
    },
  },
  {
    definition: definition({
      name: "sleep.mode.enter",
      title: "进入睡眠模式",
      description: "创建或复用当前睡眠会话，并同步宿舍睡眠状态。",
      risk: "write",
      undoable: true,
    }),
    async execute(input, state) {
      const context = await ensureContext(state);
      const existingActiveId = activeSessionId(context);
      if (existingActiveId) {
        return {
          output: {
            sessionId: existingActiveId,
            status: "active",
            reused: true,
          },
          updatedSurfaces: ["sleep_mode", "assistant_context"],
        };
      }
      const startedAt = nowIso();
      const sessionId = asString(input.sessionId, randomUUID());
      const session = {
        id: sessionId,
        uid: state.uid,
        startedAt,
        endedAt: null,
        sleepDayKey: sleepDayKeyFromIso(startedAt),
        status: "active",
        sleepModeActive: true,
        dormId: context.dorm.id,
        recommendations: context.userState?.tonightPlan?.recommendedActions ?? [],
        selectedRecommendationIds: [],
        segments: [{ startedAt, endedAt: null }],
        trackedDurationMinutes: 0,
        awakenings: [],
        feedback: [],
        summary: null,
        updatedAt: startedAt,
      };
      await state.repo.saveSleepSession(session);
      await state.repo.updateDormMemberStatus(state.uid, {
        status: "sleeping",
        sleepModeActive: true,
        note: asString(input.note, "Agent started sleep mode."),
      });
      await handleSleepSessionChange(
        state.repo,
        state.provider,
        state.uid,
        sessionId,
        null,
        "active",
      );
      state.context = await state.repo.buildAssistantContext(
        state.uid,
        state.threadId ?? undefined,
        { profile: "insight_full", memoryQuery: state.prompt },
      );
      return {
        output: { sessionId, status: "active" },
        updatedSurfaces: ["sleep_mode", "assistant_context"],
        undoPayload: {
          compensation: "Use sleep.mode.exit with this sessionId if needed.",
          sessionId,
        },
        committed: true,
      };
    },
  },
  {
    definition: definition({
      name: "sleep.mode.exit",
      title: "退出睡眠模式",
      description: "结束当前睡眠模式并进入晨间反馈或报告刷新链路。",
      risk: "write",
      undoable: true,
      inputSchema: objectSchema({
        sessionId: stringSchema("Sleep session id. Optional when active."),
        status: stringSchema("completed or awaitingFeedback."),
      }),
    }),
    async execute(input, state) {
      const context = await ensureContext(state);
      const sessionId = asString(input.sessionId, activeSessionId(context));
      if (!sessionId) {
        return {
          output: {
            skipped: true,
            reason: "missing_active_sleep_session",
            route: "/assistant?flow=sleep_capture&mode=memo",
          },
        };
      }
      const existing = await state.repo.getSleepSession(sessionId);
      if (!existing) {
        return {
          output: {
            skipped: true,
            reason: "sleep_session_not_found",
            sessionId,
          },
        };
      }
      const endedAt = nowIso();
      const startedAt = asString(existing.startedAt, endedAt);
      const completed = asString(input.status) === "completed";
      const nextStatus = completed ? "completed" : "awaitingFeedback";
      const session = {
        ...existing,
        id: sessionId,
        uid: state.uid,
        endedAt,
        status: nextStatus,
        sleepModeActive: false,
        segments: closeSleepSegments(existing.segments, startedAt, endedAt),
        trackedDurationMinutes: asNumber(
          existing.trackedDurationMinutes,
          trackedDurationMinutes(startedAt, endedAt),
        ),
        updatedAt: endedAt,
      };
      await state.repo.saveSleepSession(session);
      await state.repo.updateDormMemberStatus(state.uid, {
        sleepModeActive: false,
        status: "quiet",
        note: "Agent exited sleep mode.",
      });
      await handleSleepSessionChange(
        state.repo,
        state.provider,
        state.uid,
        sessionId,
        asString(existing.status) || null,
        nextStatus,
      );
      state.context = await state.repo.buildAssistantContext(
        state.uid,
        state.threadId ?? undefined,
        { profile: "insight_full", memoryQuery: state.prompt },
      );
      return {
        output: { sessionId, status: nextStatus },
        updatedSurfaces: [
          "morning_feedback",
          "profile_report",
          "assistant_context",
        ],
        undoPayload: { previous: existing },
        committed: true,
      };
    },
  },
  {
    definition: definition({
      name: "dream.records.read",
      title: "读取梦记",
      description: "返回最近梦记摘要。",
      risk: "read",
    }),
    async execute(_input, state) {
      const context = await ensureContext(state);
      return {
        output: {
          records: context.recentDreams,
          count: context.recentDreams.length,
        },
      };
    },
  },
  {
    definition: definition({
      name: "audio.catalog.read",
      title: "读取音频目录",
      description: "读取可用睡眠音频目录。",
      risk: "read",
    }),
    async execute(_input, state) {
      return {
        output: await state.repo.getAudioTrackCatalog(state.uid),
      };
    },
  },
  {
    definition: definition({
      name: "audio.recommend",
      title: "推荐睡眠音频",
      description: "读取音频目录并返回适合当前夜间状态的音频入口。",
      risk: "read",
    }),
    async execute(_input, state) {
      const catalog = await state.repo.getAudioTrackCatalog(state.uid);
      const tracks = asList((catalog as JsonMap).tracks).map((item) =>
        asMap(item),
      );
      const track =
        tracks.find((item) =>
          /rain|ocean|breeze|wind|雨|海|风/i.test(asString(item.title)),
        ) ??
        tracks[0] ??
        null;
      return {
        output: {
          track,
          route: "/sleep/audio_catalog",
          count: tracks.length,
        },
      };
    },
  },
  {
    definition: definition({
      name: "report.profile.read",
      title: "读取睡眠报告摘要",
      description: "汇总最近睡眠、梦记和长期记忆，用于报告解读与后续行动。",
      risk: "read",
    }),
    async execute(_input, state) {
      const context = await ensureContext(state);
      const completed = context.recentSessions.filter(
        (session) => session.totalSleepHours != null,
      );
      const averageSleepHours =
        completed.length === 0
          ? null
          : completed.reduce(
              (sum, session) => sum + (session.totalSleepHours ?? 0),
              0,
            ) / completed.length;
      return {
        output: {
          recentSessionCount: context.recentSessions.length,
          completedSessionCount: completed.length,
          averageSleepHours,
          dreamCount: context.recentDreams.length,
          memoryCount: context.longTermMemory?.length ?? 0,
          latestSession: context.recentSessions[0] ?? null,
        },
      };
    },
  },
  {
    definition: definition({
      name: "interference.save_tonight",
      title: "保存今晚干扰因素",
      description: "根据对话和上下文写入今晚干扰因素。",
      risk: "write",
      undoable: true,
    }),
    async execute(input, state) {
      const context = await ensureContext(state);
      const previous = context.userState?.tonightInterference ?? null;
      const sourceText = asString(input.prompt, state.prompt);
      const next = buildInterferenceFromPrompt(context, sourceText);
      const saved = await state.repo.saveTonightInterference(
        state.uid,
        next as unknown as JsonMap,
      );
      state.context = await state.repo.buildAssistantContext(
        state.uid,
        state.threadId ?? undefined,
        { profile: "insight_full", memoryQuery: state.prompt },
      );
      return {
        output: { interference: saved },
        updatedSurfaces: ["home_pre_sleep", "assistant_context"],
        undoPayload: { previous },
        committed: true,
      };
    },
  },
  {
    definition: definition({
      name: "plan.generate_tonight",
      title: "生成今晚计划",
      description: "调用现有 TonightPlan 链路生成建议并刷新卡片。",
      risk: "low",
    }),
    async execute(input, state) {
      const result = await prepareTonightPlan(
        state.repo,
        state.provider,
        state.uid,
        asString(input.source, "agent"),
        state.threadId ?? undefined,
      );
      state.context = await state.repo.buildAssistantContext(
        state.uid,
        state.threadId ?? undefined,
        { profile: "insight_full", memoryQuery: state.prompt },
      );
      return {
        output: {
          planRunId: result.runId,
          riskLevel: result.userState.tonightPlan?.riskLevel ?? "low",
          coachSummary: result.userState.tonightPlan?.coachSummary ?? "",
          actionCount:
            result.userState.tonightPlan?.recommendedActions.length ?? 0,
          sourceMode: result.sourceMode,
          errorMessage: result.errorMessage,
        },
        updatedSurfaces: result.updatedSurfaces,
        committed: true,
      };
    },
  },
  {
    definition: definition({
      name: "cards.refresh",
      title: "刷新页面卡片",
      description: "重新生成指定 surface 的卡片快照。",
      risk: "low",
      inputSchema: objectSchema({
        surfaces: {
          type: "array",
          items: { type: "string" },
          description: "Surface id 列表。",
        },
      }),
    }),
    async execute(input, state) {
      const context = await ensureContext(state);
      const surfaces = normalizeSurfaces(input.surfaces, [
        "home_pre_sleep",
        "assistant_context",
      ]);
      const userState = context.userState ?? buildFallbackUserState(context);
      const snapshots = buildCardSnapshots(context, userState, surfaces);
      await Promise.all(
        snapshots.map((snapshotDoc) =>
          state.repo.writeCardSnapshot(state.uid, snapshotDoc),
        ),
      );
      return {
        output: {
          surfaces,
          cardVersions: snapshots.map((item) => ({
            surfaceId: item.surfaceId,
            version: item.version,
          })),
        },
        updatedSurfaces: surfaces,
        committed: true,
      };
    },
  },
  {
    definition: definition({
      name: "dorm.reminder.send",
      title: "发送宿舍温和提醒",
      description: "向可推断的室友发送一条低压力站内提醒。",
      risk: "write",
      inputSchema: objectSchema({
        targetUid: stringSchema("目标室友 uid，可省略让 Agent 推断。"),
        message: stringSchema("提醒正文。"),
        anonymous: { type: "boolean" },
      }),
    }),
    async execute(input, state) {
      const context = await ensureContext(state);
      const explicitTargetUid = asString(input.targetUid).trim();
      const target =
        explicitTargetUid ||
        context.dorm.members.find(
          (member) =>
            member.uid !== state.uid &&
            (member.appOnline ||
              member.status !== "quiet" ||
              !member.sleepModeActive),
        )?.uid ||
        context.dorm.members.find((member) => member.uid !== state.uid)?.uid ||
        "";
      if (!target) {
        return {
          output: {
            skipped: true,
            reason: "no_roommate_target",
            message: "未找到可提醒的室友。",
          },
        };
      }
      const message =
        asString(input.message).trim() ||
        "我准备睡了，能不能稍微放轻一点声音？谢谢你。";
      const result = await state.repo.sendGentleDormReminder(
        state.uid,
        target,
        input.anonymous === false ? false : true,
        message,
      );
      return {
        output: result,
        updatedSurfaces: ["assistant_context"],
        undoPayload: {
          compensation: "已发送站内通知，无法直接撤回；可追加解释通知。",
        },
        committed: true,
      };
    },
  },
  {
    definition: definition({
      name: "dorm.status.update",
      title: "更新宿舍状态",
      description: "更新当前用户宿舍状态，例如 quiet 或 studying。",
      risk: "write",
      inputSchema: objectSchema({
        status: stringSchema("宿舍状态。"),
        note: stringSchema("状态说明。"),
      }),
      undoable: true,
    }),
    async execute(input, state) {
      const result = await state.repo.updateDormMemberStatus(state.uid, {
        status: asString(input.status, "quiet"),
        note: asString(input.note, "Agent 已同步当前状态。"),
      });
      return {
        output: result,
        updatedSurfaces: ["assistant_context"],
        undoPayload: { previousUnknown: true },
        committed: true,
      };
    },
  },
  {
    definition: definition({
      name: "dorm.rules.save",
      title: "保存宿舍公约",
      description: "保存或提交宿舍公约草案。",
      risk: "write",
      inputSchema: objectSchema({
        rulesSettings: {
          type: "object",
          description: "宿舍公约设置。",
        },
      }),
      undoable: true,
    }),
    async execute(input, state) {
      const settings = {
        routineTags: ["安静入睡", "灯光提前降低", "温和提醒"],
        quietStartMinutes: 23 * 60,
        quietEndMinutes: 7 * 60,
        reminderTone: "gentle",
        ...asMap(input.rulesSettings),
      };
      const result = await state.repo.saveDormRules(state.uid, settings);
      return {
        output: {
          dormId: asString(result.id),
          hasPendingProposal: Boolean(result.pendingRuleProposal),
        },
        updatedSurfaces: ["assistant_context"],
        undoPayload: {
          compensation: "若产生待确认公约，可在宿舍公约页拒绝或重新提交。",
        },
        committed: true,
      };
    },
  },
  {
    definition: definition({
      name: "dorm.invite.create",
      title: "创建宿舍邀请",
      description: "创建一个可分享给室友的宿舍邀请码。",
      risk: "write",
      inputSchema: objectSchema({
        expiresInHours: { type: "number", description: "Invite expiry hours." },
      }),
    }),
    async execute(input, state) {
      const result = await state.repo.createDormInvite(
        state.uid,
        asNumber(input.expiresInHours, 72),
      );
      return {
        output: result,
        updatedSurfaces: ["assistant_context"],
        undoPayload: {
          compensation: "Invite cannot be deleted here; create a new invite if it expires.",
        },
        committed: true,
      };
    },
  },
  {
    definition: definition({
      name: "notification.write",
      title: "写入通知",
      description: "创建一条当前用户站内通知。",
      risk: "write",
      inputSchema: objectSchema({
        title: stringSchema("通知标题。"),
        body: stringSchema("通知正文。"),
        route: stringSchema("跳转路由。"),
      }),
    }),
    async execute(input, state) {
      const notificationId = asString(input.id, `agent-${randomUUID()}`);
      await state.repo.upsertNotification(state.uid, notificationId, {
        id: notificationId,
        category: asString(input.category, "assistant"),
        title: asString(input.title, "小眠已处理"),
        body: asString(input.body, "你的请求已由小眠处理。"),
        route: asString(input.route, "/assistant"),
        createdAt: nowIso(),
        readAt: null,
      });
      return {
        output: { notificationId },
        updatedSurfaces: ["assistant_context"],
        committed: true,
      };
    },
  },
  {
    definition: definition({
      name: "capture.save",
      title: "保存梦记或事记",
      description: "保存 sleep capture 记录；缺少 sessionId 时返回跳转建议。",
      risk: "write",
      inputSchema: objectSchema({
        type: stringSchema("dream 或 memo。"),
        sessionId: stringSchema("睡眠会话 id。"),
        content: stringSchema("记录正文。"),
      }),
    }),
    async execute(input, state) {
      const sessionId = asString(input.sessionId).trim();
      const type: SleepCaptureKind =
        asString(input.type) === "dream" ? "dream" : "memo";
      const content = asString(input.content, state.prompt).trim();
      if (!sessionId) {
        return {
          output: {
            skipped: true,
            reason: "missing_session_id",
            route:
              type === "dream"
                ? "/assistant?flow=sleep_capture&mode=dream"
                : "/assistant?flow=sleep_capture&mode=memo",
          },
        };
      }
      const record = await state.repo.saveSleepCaptureRecord(state.uid, {
        type,
        sessionId,
        title: type === "dream" ? "Agent 梦记" : "Agent 事记",
        outline: content.slice(0, 80),
        content,
        createdAt: nowIso(),
      });
      return {
        output: { record },
        updatedSurfaces: ["assistant_context"],
        committed: true,
      };
    },
  },
  {
    definition: definition({
      name: "navigation.suggest",
      title: "生成跳转建议",
      description: "返回前端可展示的下一步跳转。",
      risk: "read",
      inputSchema: objectSchema({
        route: stringSchema("目标路由。"),
        label: stringSchema("按钮文案。"),
      }),
    }),
    async execute(input) {
      return {
        output: {
          route: asString(input.route, "/assistant"),
          label: asString(input.label, "继续处理"),
        },
      };
    },
  },
  {
    definition: definition({
      name: "memory.upsert",
      title: "更新长期记忆",
      description: "写入带证据和行动归因的长期记忆。",
      risk: "low",
      inputSchema: objectSchema({
        kind: stringSchema("记忆类型。"),
        content: stringSchema("记忆正文。"),
        canonicalKey: stringSchema("稳定归并 key。"),
      }),
    }),
    async execute(input, state) {
      const content = asString(input.content, state.prompt).trim();
      if (!content) {
        return { output: { count: 0 }, memorySyncedCount: 0 };
      }
      const kind = asString(input.kind, "agent_action");
      const keywords = asStringArray(input.keywords);
      const item = memoryItem({
        uid: state.uid,
        runId: state.runId,
        callId: asString(input.callId) || null,
        threadId: state.threadId ?? null,
        kind,
        content,
        canonicalKey:
          asString(input.canonicalKey) ||
          `${kind}:${content.toLowerCase().slice(0, 64)}`,
        keywords:
          keywords.length > 0
            ? keywords
            : Array.from(
                new Set(
                  content
                    .toLowerCase()
                    .match(/[a-z0-9\u4e00-\u9fff]+/g) ?? [],
                ),
              ).slice(0, 8),
        confidence: asNumber(input.confidence, 0.72),
        salience: asNumber(input.salience, 0.72),
        effectivenessScore:
          input.effectivenessScore == null
            ? null
            : asNumber(input.effectivenessScore, 0),
      });
      await state.repo.upsertAssistantMemoryItems(state.uid, [item]);
      return {
        output: { count: 1, memoryId: item.id, kind },
        memorySyncedCount: 1,
        updatedSurfaces: ["assistant_context"],
        committed: true,
      };
    },
  },
];

export function listAgentTools(): AgentToolDefinitionDoc[] {
  return TOOLS.map((tool) => tool.definition);
}

export function getAgentToolRegistry(): AgentTool[] {
  return TOOLS;
}

export function findAgentTool(name: string): AgentTool | null {
  return TOOLS.find((tool) => tool.definition.name === name) ?? null;
}
