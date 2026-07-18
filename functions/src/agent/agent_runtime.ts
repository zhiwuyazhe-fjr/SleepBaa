import { randomUUID } from "node:crypto";
import { AIProvider, classifyIntent } from "../providers/ai_provider";
import { AssistantDataRepository } from "../repositories/firestore_repositories";
import {
  AgentExecutionResult,
  AgentGoalDoc,
  AgentPlanDoc,
  AgentRunDoc,
  AgentRunStatus,
  AgentStepDoc,
  AgentStepStatus,
  AgentToolCallDoc,
  AgentToolRisk,
  AssistantContext,
  AssistantIntent,
  AssistantRunSourceMode,
  AssistantRunStatus,
  AssistantSseEventName,
  SurfaceId,
} from "../shared/types";
import {
  AgentToolResult,
  AgentToolRuntimeState,
  findAgentTool,
  listAgentTools,
} from "./agent_tools";
import { buildAgentExecutionMemoryItems } from "../services/assistant_memory_governance";

type JsonMap = Record<string, unknown>;

export interface AgentRuntimeEvent {
  event: AssistantSseEventName;
  data: JsonMap;
}

export interface RunAgentParams {
  repo: AssistantDataRepository;
  provider: AIProvider;
  uid: string;
  threadId?: string | null;
  prompt: string;
  onDelta?: (delta: string) => Promise<void> | void;
  emitEvent?: (event: AgentRuntimeEvent) => Promise<void> | void;
}

function nowIso(): string {
  return new Date().toISOString();
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

function uniqueSurfaces(values: Iterable<SurfaceId>): SurfaceId[] {
  return Array.from(new Set(values));
}

function asMap(value: unknown): JsonMap {
  return value && typeof value === "object" && !Array.isArray(value)
    ? ({ ...(value as JsonMap) } as JsonMap)
    : {};
}

function riskFromPrompt(prompt: string): AgentGoalDoc["riskLevel"] {
  const normalized = prompt.toLowerCase();
  if (
    /delete|remove account|reset password|password|leave dorm|退出宿舍|离开宿舍|删除账号|注销|密码|解绑|踢出/.test(
      normalized,
    )
  ) {
    return "high";
  }
  if (
    /发送|提醒|公约|保存|更新|处理|send|save|update|rules|remind/.test(
      normalized,
    )
  ) {
    return "medium";
  }
  return "low";
}

function parseGoal(prompt: string): AgentGoalDoc {
  const riskLevel = riskFromPrompt(prompt);
  return {
    id: randomUUID(),
    text: prompt.trim(),
    intent: detectAgentIntent(prompt),
    riskLevel,
    autonomyMode: riskLevel === "high" ? "confirm_required" : "full",
    createdAt: nowIso(),
  };
}

type ExtendedAgentIntent =
  | AssistantIntent
  | "dorm_rules"
  | "dorm_invite"
  | "sleep_mode_enter"
  | "sleep_mode_exit"
  | "report_review"
  | "audio_support";

function detectAgentIntent(prompt: string): ExtendedAgentIntent {
  const normalized = prompt.toLowerCase();
  if (/invite|join dorm|邀请码|邀请|加入宿舍|拉室友/.test(normalized)) {
    return "dorm_invite";
  }
  if (
    /exit sleep|finish sleep|end sleep|退出睡眠|结束睡眠|醒了|起床/.test(
      normalized,
    )
  ) {
    return "sleep_mode_exit";
  }
  if (
    /enter sleep|start sleep|sleep mode|开始睡眠|进入睡眠|睡眠模式/.test(
      normalized,
    )
  ) {
    return "sleep_mode_enter";
  }
  if (/report|weekly|summary|报告|复盘|趋势|画像/.test(normalized)) {
    return "report_review";
  }
  if (
    /audio|sound|rain|music|white noise|音频|白噪音|雨声|助眠/.test(normalized)
  ) {
    return "audio_support";
  }
  if (/公约|规则|约定|rules|agreement/.test(normalized)) {
    return "dorm_rules";
  }
  return classifyIntent(prompt);
}

function addStep(
  steps: AgentStepDoc[],
  params: {
    title: string;
    toolName: string;
    input?: JsonMap;
    dependsOn?: string[];
  },
): void {
  const tool = findAgentTool(params.toolName);
  if (!tool) {
    throw new Error(`Agent tool not registered: ${params.toolName}`);
  }
  steps.push({
    id: `step-${steps.length + 1}`,
    title: params.title,
    toolName: params.toolName,
    input: params.input ?? {},
    status: "pending",
    risk: tool.definition.risk,
    dependsOn: params.dependsOn ?? [],
  });
}

function addMemoryStep(
  steps: AgentStepDoc[],
  prompt: string,
  kind: string,
): void {
  const normalized = prompt.trim();
  if (normalized.length < 8) {
    return;
  }
  addStep(steps, {
    title: "更新长期记忆",
    toolName: "memory.upsert",
    input: {
      kind,
      content: normalized,
      canonicalKey: `${kind}:${normalized.toLowerCase().slice(0, 64)}`,
      keywords: Array.from(
        new Set(
          normalized.toLowerCase().match(/[a-z0-9\u4e00-\u9fff]+/g) ?? [],
        ),
      ).slice(0, 8),
      confidence: kind === "intervention_effect" ? 0.8 : 0.72,
      salience: kind === "intervention_effect" ? 0.82 : 0.72,
    },
  });
}

function buildPlan(params: {
  runId: string;
  uid: string;
  threadId?: string | null;
  goal: AgentGoalDoc;
  prompt: string;
}): AgentPlanDoc {
  const steps: AgentStepDoc[] = [];
  addStep(steps, {
    title: "读取睡眠与宿舍上下文",
    toolName: "context.read",
  });

  if (params.goal.riskLevel === "high") {
    addStep(steps, {
      title: "生成硬确认跳转建议",
      toolName: "navigation.suggest",
      input: {
        route: "/profile/settings",
        label: "需要你确认后再执行",
      },
    });
  } else if (params.goal.intent === "noise_issue") {
    addStep(steps, {
      title: "记录今晚噪音干扰",
      toolName: "interference.save_tonight",
      input: { prompt: params.prompt },
    });
    addStep(steps, {
      title: "同步宿舍安静状态",
      toolName: "dorm.status.update",
      input: {
        status: "quiet",
        note: "我准备睡了，希望保持安静。",
      },
    });
    addStep(steps, {
      title: "生成今晚睡前计划",
      toolName: "plan.generate_tonight",
      input: { source: "agent_noise_issue" },
    });
    addStep(steps, {
      title: "发送宿舍温和提醒",
      toolName: "dorm.reminder.send",
      input: {
        anonymous: true,
        message: "我准备睡了，能不能稍微放轻一点声音？谢谢你。",
      },
    });
    addStep(steps, {
      title: "刷新助手与首页卡片",
      toolName: "cards.refresh",
      input: { surfaces: ["home_pre_sleep", "assistant_context"] },
    });
    addMemoryStep(steps, params.prompt, "intervention_effect");
  } else if (params.goal.intent === "sleep_difficulty") {
    addStep(steps, {
      title: "记录今晚入睡困难信号",
      toolName: "interference.save_tonight",
      input: { prompt: params.prompt },
    });
    addStep(steps, {
      title: "同步宿舍安静状态",
      toolName: "dorm.status.update",
      input: {
        status: "quiet",
        note: "我正在准备入睡。",
      },
    });
    addStep(steps, {
      title: "生成今晚睡前计划",
      toolName: "plan.generate_tonight",
      input: { source: "agent_sleep_difficulty" },
    });
    addStep(steps, {
      title: "刷新睡前卡片",
      toolName: "cards.refresh",
      input: { surfaces: ["home_pre_sleep", "assistant_context"] },
    });
    addMemoryStep(steps, params.prompt, "sleep_pattern");
  } else if (params.goal.intent === "plan_review") {
    addStep(steps, {
      title: "生成今晚睡前计划",
      toolName: "plan.generate_tonight",
      input: { source: "agent_plan_review" },
    });
    addStep(steps, {
      title: "刷新睡前卡片",
      toolName: "cards.refresh",
      input: { surfaces: ["home_pre_sleep", "assistant_context"] },
    });
    addMemoryStep(steps, params.prompt, "agent_action");
  } else if (params.goal.intent === "sleep_mode_enter") {
    addStep(steps, {
      title: "进入睡眠模式",
      toolName: "sleep.mode.enter",
      input: { source: "agent_sleep_mode_enter" },
    });
    addStep(steps, {
      title: "刷新睡眠模式卡片",
      toolName: "cards.refresh",
      input: { surfaces: ["sleep_mode", "assistant_context"] },
    });
    addMemoryStep(steps, params.prompt, "agent_action");
  } else if (params.goal.intent === "sleep_mode_exit") {
    addStep(steps, {
      title: "退出睡眠模式",
      toolName: "sleep.mode.exit",
      input: { source: "agent_sleep_mode_exit" },
    });
    addStep(steps, {
      title: "刷新晨间反馈与报告",
      toolName: "cards.refresh",
      input: {
        surfaces: ["morning_feedback", "profile_report", "assistant_context"],
      },
    });
    addMemoryStep(steps, params.prompt, "agent_action");
  } else if (params.goal.intent === "report_review") {
    addStep(steps, {
      title: "读取睡眠报告摘要",
      toolName: "report.profile.read",
    });
    addStep(steps, {
      title: "刷新报告卡片",
      toolName: "cards.refresh",
      input: { surfaces: ["profile_report", "assistant_context"] },
    });
    addMemoryStep(steps, params.prompt, "sleep_pattern");
  } else if (params.goal.intent === "audio_support") {
    addStep(steps, {
      title: "推荐睡眠音频",
      toolName: "audio.recommend",
    });
    addStep(steps, {
      title: "给出音频页面入口",
      toolName: "navigation.suggest",
      input: { route: "/sleep/audio_catalog", label: "打开助眠音频" },
    });
    addMemoryStep(steps, params.prompt, "preference");
  } else if (params.goal.intent === "dream_reflection") {
    addStep(steps, {
      title: "读取最近梦记",
      toolName: "dream.records.read",
    });
    addStep(steps, {
      title: "建议进入梦记收纳",
      toolName: "navigation.suggest",
      input: {
        route: "/assistant?flow=sleep_capture&mode=dream",
        label: "继续写梦记",
      },
    });
    addMemoryStep(steps, params.prompt, "dorm_context");
  } else if (params.goal.intent === "dorm_rules") {
    addStep(steps, {
      title: "保存宿舍公约草案",
      toolName: "dorm.rules.save",
      input: {
        rulesSettings: {
          routineTags: ["安静入睡", "灯光提前降低", "温和提醒"],
          reminderTone: "gentle",
        },
      },
    });
    addStep(steps, {
      title: "刷新助手上下文",
      toolName: "cards.refresh",
      input: { surfaces: ["assistant_context"] },
    });
    addMemoryStep(steps, params.prompt, "dorm_context");
  } else if (params.goal.intent === "dorm_invite") {
    addStep(steps, {
      title: "创建宿舍邀请",
      toolName: "dorm.invite.create",
      input: { expiresInHours: 72 },
    });
    addStep(steps, {
      title: "刷新宿舍上下文",
      toolName: "cards.refresh",
      input: { surfaces: ["assistant_context"] },
    });
    addMemoryStep(steps, params.prompt, "dorm_context");
  } else {
    addStep(steps, {
      title: "刷新助手上下文",
      toolName: "cards.refresh",
      input: { surfaces: ["assistant_context"] },
    });
    addMemoryStep(steps, params.prompt, "agent_action");
  }

  const createdAt = nowIso();
  return {
    id: randomUUID(),
    runId: params.runId,
    userId: params.uid,
    threadId: params.threadId ?? null,
    goal: params.goal,
    steps,
    status: "planned",
    createdAt,
    updatedAt: createdAt,
  };
}

function assistantRunStatusFrom(
  status: AgentRunStatus,
  sourceMode: AssistantRunSourceMode,
): AssistantRunStatus {
  if (status === "failed" || sourceMode === "error") {
    return "error";
  }
  return sourceMode === "fallbackSuccess" ? "fallback" : "success";
}

function shouldSkipForHardConfirm(
  goal: AgentGoalDoc,
  risk: AgentToolRisk,
  requiresHardConfirm: boolean,
): boolean {
  return (
    goal.autonomyMode === "confirm_required" &&
    (risk === "high" || risk === "write" || requiresHardConfirm)
  );
}

function summarizeToolName(toolName: string): string {
  switch (toolName) {
    case "context.read":
      return "读取了你的睡眠与宿舍上下文";
    case "interference.save_tonight":
      return "更新了今晚干扰因素";
    case "plan.generate_tonight":
      return "生成了今晚睡前计划";
    case "dorm.reminder.send":
      return "尝试发送了宿舍温和提醒";
    case "dorm.status.update":
      return "同步了宿舍安静状态";
    case "dorm.rules.save":
      return "保存了宿舍公约草案";
    case "dorm.invite.create":
      return "创建了宿舍邀请";
    case "sleep.mode.enter":
      return "进入了睡眠模式";
    case "sleep.mode.exit":
      return "退出了睡眠模式";
    case "report.profile.read":
      return "读取了睡眠报告摘要";
    case "audio.recommend":
      return "准备了助眠音频建议";
    case "cards.refresh":
      return "刷新了页面卡片";
    case "memory.upsert":
      return "更新了长期记忆";
    case "navigation.suggest":
      return "准备了下一步跳转建议";
    default:
      return toolName;
  }
}

function buildAgentReply(params: {
  prompt: string;
  goal: AgentGoalDoc;
  context?: AssistantContext;
  toolCalls: AgentToolCallDoc[];
  baseReply: string;
  status: AgentRunStatus;
}): string {
  const assistantName =
    params.context?.assistantProfile.assistantName?.trim() || "小眠";
  const succeeded = params.toolCalls.filter(
    (call) => call.status === "success",
  );
  const failed = params.toolCalls.filter((call) => call.status === "failed");
  const skipped = params.toolCalls.filter((call) => call.status === "skipped");
  if (params.goal.autonomyMode === "confirm_required") {
    return `${assistantName}已经识别到这个请求涉及高风险操作，我不会自动执行。需要你在对应页面明确确认后再继续，我先保留了上下文和跳转建议。`;
  }

  const actions = succeeded
    .filter((call) => call.risk !== "read")
    .map((call) => summarizeToolName(call.toolName));
  const actionText =
    actions.length > 0
      ? `我已经${actions.slice(0, 4).join("、")}。`
      : "我已经检查了当前上下文。";
  const issueText =
    failed.length > 0
      ? `有 ${failed.length} 个动作没有完成，我已把失败原因写入审计记录。`
      : skipped.length > 0
        ? `有 ${skipped.length} 个动作因缺少目标或需要确认而跳过。`
        : "";
  if (params.goal.intent === "noise_issue") {
    return `${assistantName}先帮你把宿舍噪音这件事处理到可执行状态。${actionText}今晚先按“降低外部刺激 + 温和协同 + 低负担入睡”走，不需要你再自己拆步骤。${issueText}`;
  }
  if (params.goal.intent === "plan_review") {
    return `${assistantName}已经按你今晚的状态重新规划。${actionText}你可以从首页睡前卡片直接接着做最靠前的建议。${issueText}`;
  }
  if (params.goal.intent === "sleep_difficulty") {
    return `${assistantName}先不让你继续和“睡不着”硬扛。${actionText}现在优先做一个最小降刺激动作，再让节奏慢下来。${issueText}`;
  }
  if (params.goal.intent === "dorm_rules") {
    return `${assistantName}已经把宿舍协同请求转成可审计动作。${actionText}如果需要室友确认，你可以到宿舍公约页继续推进。${issueText}`;
  }
  return `${params.baseReply}\n\n${actionText}${issueText}`;
}

async function emit(
  params: RunAgentParams,
  event: AssistantSseEventName,
  data: JsonMap,
): Promise<void> {
  await params.emitEvent?.({ event, data });
}

async function writePlan(
  repo: AssistantDataRepository,
  uid: string,
  plan: AgentPlanDoc,
  status?: AgentRunStatus,
): Promise<void> {
  await repo.writeAgentPlan(uid, plan.id, {
    ...plan,
    status: status ?? plan.status,
    updatedAt: nowIso(),
  });
}

function schemaTypeMatches(value: unknown, type: string): boolean {
  if (value == null) {
    return true;
  }
  switch (type) {
    case "string":
      return typeof value === "string";
    case "number":
      return typeof value === "number" && Number.isFinite(value);
    case "integer":
      return typeof value === "number" && Number.isInteger(value);
    case "boolean":
      return typeof value === "boolean";
    case "array":
      return Array.isArray(value);
    case "object":
      return typeof value === "object" && !Array.isArray(value);
    default:
      return true;
  }
}

export function validateAgentToolInput(
  toolName: string,
  input: JsonMap,
  schema: Record<string, unknown>,
): string[] {
  const root = asMap(schema);
  const properties = asMap(root.properties);
  const required = asStringArray(root.required);
  const errors: string[] = [];
  for (const field of required) {
    const value = input[field];
    if (value == null || value === "") {
      errors.push(`${toolName}.${field} is required`);
    }
  }
  for (const [field, value] of Object.entries(input)) {
    const fieldSchema = asMap(properties[field]);
    const type = asString(fieldSchema.type);
    if (type && !schemaTypeMatches(value, type)) {
      errors.push(`${toolName}.${field} must be ${type}`);
    }
  }
  return errors;
}

export function shouldRoutePromptToAgent(prompt: string): boolean {
  const normalized = prompt.toLowerCase();
  return (
    /睡不着|失眠|室友|宿舍|吵|噪|今晚|规划|计划|建议|公约|规则|提醒|处理|帮我|邀请|报告|复盘|睡眠模式|助眠|音频|can't sleep|roommate|dorm|noise|tonight|plan|suggest|rules|remind|invite|report|sleep mode|audio/.test(
      normalized,
    ) || riskFromPrompt(prompt) !== "low"
  );
}

export { listAgentTools };

export async function runAgent(
  params: RunAgentParams,
): Promise<AgentExecutionResult> {
  const startedAt = Date.now();
  const runId = randomUUID();
  const goal = parseGoal(params.prompt);
  const plan = buildPlan({
    runId,
    uid: params.uid,
    threadId: params.threadId ?? null,
    goal,
    prompt: params.prompt,
  });
  const runtimeState: AgentToolRuntimeState = {
    repo: params.repo,
    provider: params.provider,
    uid: params.uid,
    threadId: params.threadId ?? null,
    prompt: params.prompt,
    runId,
    planId: plan.id,
  };
  const updatedSurfaces = new Set<SurfaceId>();
  const toolCalls: AgentToolCallDoc[] = [];
  let memorySyncedCount = 0;
  let sourceMode: AssistantRunSourceMode = "fallbackSuccess";
  let errorMessage: string | null = null;

  const initialRun: AgentRunDoc = {
    id: runId,
    userId: params.uid,
    threadId: params.threadId ?? null,
    goal,
    planId: plan.id,
    status: "running",
    autonomyMode: goal.autonomyMode,
    summary: null,
    provider: params.provider.providerName,
    model: params.provider.modelName,
    sourceMode,
    toolCallCount: 0,
    memorySyncedCount: 0,
    updatedSurfaces: [],
    error: null,
    startedAt: nowIso(),
    completedAt: null,
    durationMs: null,
  };

  await params.repo.writeAgentRun(params.uid, runId, initialRun);
  await params.repo.writeAgentPlan(params.uid, plan.id, plan);
  await emit(params, "planning_started", {
    runId,
    planId: plan.id,
    goal,
    tools: listAgentTools().map((tool) => tool.name),
    steps: plan.steps.map((step) => ({
      id: step.id,
      title: step.title,
      toolName: step.toolName,
      risk: step.risk,
    })),
  });

  for (const step of plan.steps) {
    const tool = findAgentTool(step.toolName);
    if (!tool) {
      step.status = "failed";
      errorMessage = `Agent tool not registered: ${step.toolName}`;
      continue;
    }

    const callId = randomUUID();
    const callStartedAt = Date.now();
    const callStartedIso = nowIso();
    const baseCall: AgentToolCallDoc = {
      id: callId,
      runId,
      planId: plan.id,
      stepId: step.id,
      userId: params.uid,
      threadId: params.threadId ?? null,
      toolName: step.toolName,
      risk: step.risk,
      status: "running",
      committed: false,
      input: step.input,
      output: null,
      error: null,
      undoPayload: null,
      startedAt: callStartedIso,
      finishedAt: null,
      durationMs: null,
    };

    if (
      shouldSkipForHardConfirm(
        goal,
        step.risk,
        tool.definition.requiresHardConfirm,
      )
    ) {
      const skippedCall: AgentToolCallDoc = {
        ...baseCall,
        status: "skipped",
        committed: false,
        output: { skipped: true, reason: "hard_confirm_required" },
        finishedAt: nowIso(),
        durationMs: Date.now() - callStartedAt,
      };
      step.status = "skipped";
      toolCalls.push(skippedCall);
      await params.repo.writeAgentToolCall(params.uid, callId, skippedCall);
      await emit(params, "tool_failed", {
        runId,
        planId: plan.id,
        callId,
        stepId: step.id,
        toolName: step.toolName,
        toolTitle: tool.definition.title,
        risk: step.risk,
        undoable: tool.definition.undoable,
        requiresHardConfirm: tool.definition.requiresHardConfirm,
        skipped: true,
        error: "hard_confirm_required",
      });
      await writePlan(params.repo, params.uid, plan, "running");
      continue;
    }

    const validationErrors = validateAgentToolInput(
      step.toolName,
      step.input,
      tool.definition.inputSchema,
    );
    if (validationErrors.length > 0) {
      const message = `invalid_tool_input: ${validationErrors.join("; ")}`;
      const failedCall: AgentToolCallDoc = {
        ...baseCall,
        status: "failed",
        committed: false,
        output: null,
        error: message,
        finishedAt: nowIso(),
        durationMs: Date.now() - callStartedAt,
      };
      step.status = "failed";
      errorMessage = errorMessage ? `${errorMessage}; ${message}` : message;
      toolCalls.push(failedCall);
      await params.repo.writeAgentToolCall(params.uid, callId, failedCall);
      await emit(params, "tool_failed", {
        runId,
        planId: plan.id,
        stepId: step.id,
        callId,
        toolName: step.toolName,
        toolTitle: tool.definition.title,
        risk: step.risk,
        undoable: tool.definition.undoable,
        error: message,
      });
      await writePlan(params.repo, params.uid, plan, "running");
      continue;
    }

    step.status = "running";
    await params.repo.writeAgentToolCall(params.uid, callId, baseCall);
    await writePlan(params.repo, params.uid, plan, "running");
    await emit(params, "tool_started", {
      runId,
      planId: plan.id,
      stepId: step.id,
      callId,
      toolName: step.toolName,
      toolTitle: tool.definition.title,
      risk: step.risk,
      undoable: tool.definition.undoable,
      requiresHardConfirm: tool.definition.requiresHardConfirm,
    });

    try {
      const result: AgentToolResult = await tool.execute(
        { ...step.input, callId },
        runtimeState,
      );
      for (const surface of result.updatedSurfaces ?? []) {
        updatedSurfaces.add(surface);
      }
      memorySyncedCount += result.memorySyncedCount ?? 0;
      step.status = "success";
      const completedCall: AgentToolCallDoc = {
        ...baseCall,
        status: "success",
        committed: result.committed ?? false,
        output: result.output,
        undoPayload: result.undoPayload ?? null,
        finishedAt: nowIso(),
        durationMs: Date.now() - callStartedAt,
      };
      toolCalls.push(completedCall);
      await params.repo.writeAgentToolCall(params.uid, callId, completedCall);
      await emit(params, "tool_completed", {
        runId,
        planId: plan.id,
        stepId: step.id,
        callId,
        toolName: step.toolName,
        toolTitle: tool.definition.title,
        output: result.output,
        updatedSurfaces: result.updatedSurfaces ?? [],
        committed: result.committed ?? false,
        undoable: tool.definition.undoable,
        undoPayload: result.undoPayload ?? null,
      });
      if (result.committed) {
        await emit(params, "action_committed", {
          runId,
          planId: plan.id,
          stepId: step.id,
          callId,
          toolName: step.toolName,
          toolTitle: tool.definition.title,
          output: result.output,
          updatedSurfaces: result.updatedSurfaces ?? [],
          undoable: tool.definition.undoable,
          undoPayload: result.undoPayload ?? null,
        });
      }
      if ((result.memorySyncedCount ?? 0) > 0) {
        await emit(params, "memory_updated", {
          runId,
          count: result.memorySyncedCount,
          callId,
        });
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      step.status = "failed";
      errorMessage = errorMessage ? `${errorMessage}; ${message}` : message;
      const failedCall: AgentToolCallDoc = {
        ...baseCall,
        status: "failed",
        committed: false,
        output: null,
        error: message,
        finishedAt: nowIso(),
        durationMs: Date.now() - callStartedAt,
      };
      toolCalls.push(failedCall);
      await params.repo.writeAgentToolCall(params.uid, callId, failedCall);
      await emit(params, "tool_failed", {
        runId,
        planId: plan.id,
        stepId: step.id,
        callId,
        toolName: step.toolName,
        toolTitle: tool.definition.title,
        risk: step.risk,
        undoable: tool.definition.undoable,
        error: message,
      });
    }
    await writePlan(params.repo, params.uid, plan, "running");
  }

  const hasFailure = toolCalls.some((call) => call.status === "failed");
  const hasSuccess = toolCalls.some((call) => call.status === "success");
  const finalStatus: AgentRunStatus = hasFailure
    ? hasSuccess
      ? "partial_success"
      : "failed"
    : "success";

  try {
    const executionMemoryItems = buildAgentExecutionMemoryItems({
      uid: params.uid,
      runId,
      threadId: params.threadId ?? null,
      prompt: params.prompt,
      goal,
      toolCalls,
    });
    if (executionMemoryItems.length > 0) {
      await params.repo.upsertAssistantMemoryItems(
        params.uid,
        executionMemoryItems,
      );
      memorySyncedCount += executionMemoryItems.length;
      await emit(params, "memory_updated", {
        runId,
        count: executionMemoryItems.length,
        source: "agent_execution_outcome",
      });
    }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    errorMessage = errorMessage ? `${errorMessage}; ${message}` : message;
  }

  let baseReply = "";
  try {
    const context =
      runtimeState.context ??
      (await params.repo.buildAssistantContext(
        params.uid,
        params.threadId ?? undefined,
        { profile: "reply_lite", memoryQuery: params.prompt },
      ));
    runtimeState.context = context;
    const replyIntent: AssistantIntent =
      goal.intent === "dorm_rules" ||
      goal.intent === "dorm_invite" ||
      goal.intent === "sleep_mode_enter" ||
      goal.intent === "sleep_mode_exit" ||
      goal.intent === "report_review" ||
      goal.intent === "audio_support"
        ? "general_support"
        : (goal.intent as AssistantIntent);
    const providerReply = await params.provider.generateStructuredReply(
      context,
      replyIntent,
      params.prompt,
    );
    sourceMode = providerReply.sourceMode;
    baseReply = providerReply.value.reply;
  } catch (error) {
    sourceMode = "error";
    const message = error instanceof Error ? error.message : String(error);
    errorMessage = errorMessage ? `${errorMessage}; ${message}` : message;
    baseReply = "小眠已经完成了可执行的检查，但生成总结时遇到问题。";
  }

  const reply = buildAgentReply({
    prompt: params.prompt,
    goal,
    context: runtimeState.context,
    toolCalls,
    baseReply,
    status: finalStatus,
  });
  await params.onDelta?.(reply);

  const finalSurfaces = uniqueSurfaces(
    updatedSurfaces.size > 0
      ? updatedSurfaces
      : (["assistant_context"] as SurfaceId[]),
  );
  const completedAt = nowIso();
  const durationMs = Date.now() - startedAt;
  const finalRun: AgentRunDoc = {
    ...initialRun,
    status: finalStatus,
    sourceMode,
    summary: reply,
    toolCallCount: toolCalls.length,
    memorySyncedCount,
    updatedSurfaces: finalSurfaces,
    error: errorMessage,
    completedAt,
    durationMs,
  };

  await params.repo.writeAgentPlan(params.uid, plan.id, {
    ...plan,
    status: finalStatus,
    updatedAt: completedAt,
  });
  await params.repo.writeAgentRun(params.uid, runId, finalRun);
  await params.repo.writeAssistantRun(params.uid, runId, {
    eventType: "agent_run",
    threadId: params.threadId ?? null,
    provider: params.provider.providerName,
    model: params.provider.modelName,
    status: assistantRunStatusFrom(finalStatus, sourceMode),
    sourceMode,
    inputRefs: ["assistant_messages", "user_state", "agent_plans"],
    outputRefs: [
      "agent_runs",
      "agent_tool_calls",
      "assistant_messages",
      ...finalSurfaces,
    ],
    error: errorMessage,
    createdAt: completedAt,
    totalMs: durationMs,
  });

  await emit(params, "agent_done", {
    runId,
    planId: plan.id,
    status: finalStatus,
    toolCallCount: toolCalls.length,
    memorySyncedCount,
    updatedSurfaces: finalSurfaces,
    errorMessage,
  });

  return {
    runId,
    planId: plan.id,
    reply,
    status: finalStatus,
    goal,
    plan: {
      ...plan,
      status: finalStatus,
      updatedAt: completedAt,
    },
    toolCalls,
    updatedSurfaces: finalSurfaces,
    memorySyncedCount,
    provider: params.provider.providerName,
    model: params.provider.modelName,
    sourceMode,
    errorMessage,
    surfacePatch: null,
  };
}
