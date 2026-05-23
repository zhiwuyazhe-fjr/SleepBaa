import test from "node:test";
import assert from "node:assert/strict";
import {
  listAgentTools,
  runAgent,
  shouldRoutePromptToAgent,
  validateAgentToolInput,
} from "../src/agent/agent_runtime";
import { DeterministicAIProvider } from "../src/providers/ai_provider";
import { createRepositoryFromEnv } from "../src/repositories/firestore_repositories";
import {
  buildAgentExecutionMemoryItems,
  buildAgentUndoMemoryItems,
} from "../src/services/assistant_memory_governance";
import { pickRecommendedActions } from "../src/services/tonight_action_plan";
import {
  AgentGoalDoc,
  AgentToolCallDoc,
  AssistantContext,
} from "../src/shared/types";

test("agent tool registry exposes core sleep and dorm tools", () => {
  const names = listAgentTools().map((tool) => tool.name);
  assert.ok(names.includes("context.read"));
  assert.ok(names.includes("sleep.mode.enter"));
  assert.ok(names.includes("sleep.mode.exit"));
  assert.ok(names.includes("plan.generate_tonight"));
  assert.ok(names.includes("interference.save_tonight"));
  assert.ok(names.includes("dorm.reminder.send"));
  assert.ok(names.includes("dorm.invite.create"));
  assert.ok(names.includes("report.profile.read"));
  assert.ok(names.includes("audio.recommend"));
  assert.ok(names.includes("memory.upsert"));
});

test("agent routing detects cross-module sleep prompts", () => {
  assert.equal(shouldRoutePromptToAgent("我睡不着，室友很吵"), true);
  assert.equal(shouldRoutePromptToAgent("hi"), false);
});

test("agent tool input validator catches schema type mismatches", () => {
  const inviteTool = listAgentTools().find(
    (tool) => tool.name === "dorm.invite.create",
  );
  assert.ok(inviteTool);
  assert.deepEqual(
    validateAgentToolInput(
      inviteTool.name,
      { expiresInHours: "soon" },
      inviteTool.inputSchema,
    ),
    ["dorm.invite.create.expiresInHours must be number"],
  );
});

function toolCall(
  params: Partial<AgentToolCallDoc> & {
    id: string;
    toolName: string;
  },
): AgentToolCallDoc {
  return {
    id: params.id,
    runId: params.runId ?? "run-1",
    planId: params.planId ?? "plan-1",
    stepId: params.stepId ?? `step-${params.id}`,
    userId: params.userId ?? "user-1",
    threadId: params.threadId ?? "thread-1",
    toolName: params.toolName,
    risk: params.risk ?? "write",
    status: params.status ?? "success",
    committed: params.committed ?? false,
    input: params.input ?? {},
    output: params.output ?? null,
    error: params.error ?? null,
    undoPayload: params.undoPayload ?? null,
    startedAt: params.startedAt ?? "2026-05-23T00:00:00.000Z",
    finishedAt: params.finishedAt ?? "2026-05-23T00:00:01.000Z",
    durationMs: params.durationMs ?? 1000,
  };
}

function goal(overrides: Partial<AgentGoalDoc> = {}): AgentGoalDoc {
  return {
    id: overrides.id ?? "goal-1",
    text: overrides.text ?? "我睡不着，室友很吵",
    intent: overrides.intent ?? "noise_issue",
    riskLevel: overrides.riskLevel ?? "medium",
    autonomyMode: overrides.autonomyMode ?? "full",
    createdAt: overrides.createdAt ?? "2026-05-23T00:00:00.000Z",
  };
}

test("agent execution memory summarizes committed and incomplete outcomes", () => {
  const items = buildAgentExecutionMemoryItems({
    uid: "user-1",
    runId: "run-1",
    threadId: "thread-1",
    prompt: "我睡不着，室友很吵，帮我处理一下",
    goal: goal(),
    toolCalls: [
      toolCall({
        id: "call-1",
        toolName: "dorm.status.update",
        committed: true,
        output: { status: "quiet" },
      }),
      toolCall({
        id: "call-2",
        toolName: "capture.save",
        status: "failed",
        committed: false,
        error: "missing_session_id",
      }),
    ],
  });

  assert.ok(
    items.some(
      (item) =>
        item.kind === "agent_action" &&
        item.content.includes("Agent committed actions"),
    ),
  );
  assert.ok(
    items.some(
      (item) =>
        item.kind === "agent_action" &&
        item.content.includes("incomplete actions"),
    ),
  );
  const dormStrategy = items.find(
    (item) =>
      item.kind === "strategy_weight" && item.sourceActionId === "dorm-quiet",
  );
  assert.ok(dormStrategy);
  assert.equal(dormStrategy.effectivenessScore, 0.18);
  const captureStrategy = items.find(
    (item) =>
      item.kind === "strategy_weight" &&
      item.sourceActionId === "thought-clean",
  );
  assert.ok(captureStrategy);
  assert.equal(captureStrategy.effectivenessScore, -0.35);
  assert.ok(
    captureStrategy.evidenceRefs?.includes("agent_tool_calls:call-2"),
  );
});

test("agent undo memory down-ranks reverted actions", () => {
  const items = buildAgentUndoMemoryItems({
    uid: "user-1",
    call: toolCall({
      id: "call-undo",
      toolName: "dorm.status.update",
      committed: true,
      output: { status: "quiet" },
    }),
    output: { restored: "dormStatus" },
  });

  assert.ok(
    items.some(
      (item) =>
        item.kind === "agent_action" &&
        item.content.includes("User undid Agent action"),
    ),
  );
  const strategy = items.find(
    (item) =>
      item.kind === "strategy_weight" && item.sourceActionId === "dorm-quiet",
  );
  assert.ok(strategy);
  assert.equal(strategy.effectivenessScore, -0.7);
});

test("agent runtime executes a noisy dorm goal with audit records", async () => {
  const repo = createRepositoryFromEnv({
    AI_PROVIDER_MODE: "deterministic",
    CLOUDBASE_ENV_ID: undefined,
    TCB_ENV: undefined,
    SCF_NAMESPACE: undefined,
  } as NodeJS.ProcessEnv);
  const provider = new DeterministicAIProvider();
  const uid = `agent-test-${Date.now()}-${Math.random()
    .toString(16)
    .slice(2)}`;
  const threadId = `${uid}-thread`;
  await repo.createDorm(uid, { name: "Dorm 1" });

  const events: string[] = [];
  const deltas: string[] = [];
  const result = await runAgent({
    repo,
    provider,
    uid,
    threadId,
    prompt: "我睡不着，室友很吵，帮我处理一下",
    onDelta: (delta) => {
      deltas.push(delta);
    },
    emitEvent: (event) => {
      events.push(event.event);
    },
  });

  assert.equal(result.status, "success");
  assert.equal(result.provider, "deterministic");
  assert.ok(result.reply.length > 0);
  assert.ok(deltas.join("").includes("小眠"));
  assert.ok(result.updatedSurfaces.includes("home_pre_sleep"));
  assert.ok(result.updatedSurfaces.includes("assistant_context"));
  assert.ok(
    result.toolCalls.some(
      (call) =>
        call.toolName === "interference.save_tonight" &&
        call.status === "success",
    ),
  );
  assert.ok(
    result.toolCalls.some(
      (call) => call.toolName === "plan.generate_tonight",
    ),
  );
  assert.ok(events.includes("planning_started"));
  assert.ok(events.includes("tool_started"));
  assert.ok(events.includes("tool_completed"));
  assert.ok(events.includes("agent_done"));

  const storedRun = await repo.getAgentRun(uid, result.runId);
  assert.ok(storedRun);
  assert.equal(storedRun.status, "success");
  assert.equal(storedRun.toolCallCount, result.toolCalls.length);
  const memories = await repo.listAssistantMemoryItems(uid, {
    limit: 50,
    touchLastUsed: false,
  });
  assert.ok(
    memories.some(
      (item) =>
        item.kind === "agent_action" &&
        item.evidenceRefs?.includes(`agent_runs:${result.runId}`),
    ),
  );
  assert.ok(
    memories.some(
      (item) =>
        item.kind === "strategy_weight" &&
        item.sourceActionId === "dorm-quiet",
    ),
  );
});

test("agent runtime can enter sleep mode through tools", async () => {
  const repo = createRepositoryFromEnv({
    AI_PROVIDER_MODE: "deterministic",
    CLOUDBASE_ENV_ID: undefined,
    TCB_ENV: undefined,
    SCF_NAMESPACE: undefined,
  } as NodeJS.ProcessEnv);
  const provider = new DeterministicAIProvider();
  const uid = `agent-sleep-${Date.now()}-${Math.random()
    .toString(16)
    .slice(2)}`;
  await repo.createDorm(uid, { name: "Sleep Dorm" });

  const result = await runAgent({
    repo,
    provider,
    uid,
    threadId: `${uid}-thread`,
    prompt: "Start sleep mode for me.",
  });

  assert.equal(result.status, "success");
  assert.ok(result.updatedSurfaces.includes("sleep_mode"));
  assert.ok(
    result.toolCalls.some(
      (call) =>
        call.toolName === "sleep.mode.enter" && call.status === "success",
    ),
  );
  const context = await repo.buildAssistantContext(uid);
  assert.equal(context.userState?.currentPhase, "sleep_mode");
  assert.ok(context.userState?.activeSessionId);
});

test("intervention effect memory adjusts future action ranking", () => {
  const context: AssistantContext = {
    assistantProfile: {
      userId: "user-1",
      assistantName: "Xiaomian",
      identityPrompt: "sleep assistant",
      tone: "gentle",
      relationshipRole: "assistant",
      updatedAt: "2026-05-23T00:00:00.000Z",
    },
    user: {
      uid: "user-1",
      displayName: "Test",
      tagline: "",
      role: "",
      dormId: "dorm-1",
    },
    settings: {
      sleepGoalHours: 7.5,
      bedtimeReminderEnabled: true,
      morningReminderEnabled: true,
      dormAlertsEnabled: true,
      bedtimeReminder: { hour: 23, minute: 0 },
      preferredTrackTitle: "",
      smartSuggestionsEnabled: true,
      selectedNightMood: "calm",
      homeQuickActionIds: [],
    },
    dorm: {
      id: "dorm-1",
      name: "Dorm 1",
      overview: "",
      noiseDb: 50,
      lightLabel: "Dim",
      quietLabel: "Stable",
      members: [],
      events: [],
    },
    recentSessions: [],
    recentDreams: [],
    recentMessages: [],
    longTermMemory: [
      {
        id: "m-effective-audio",
        kind: "intervention_effect",
        content: "effective audio-ocean",
        canonicalKey: "intervention_effect:audio-ocean",
        keywords: ["audio-ocean"],
        confidence: 0.9,
        salience: 0.9,
        decayScore: 1,
        evidenceRefs: ["test"],
        sourceActionId: "audio-ocean",
        sourceAgentRunId: null,
        effectivenessScore: 1,
        lastUsedAt: null,
        sourceRefs: ["test"],
        createdAt: "2026-05-23T00:00:00.000Z",
        updatedAt: "2026-05-23T00:00:00.000Z",
      },
      {
        id: "m-ineffective-earplug",
        kind: "intervention_effect",
        content: "ineffective earplug",
        canonicalKey: "intervention_effect:earplug",
        keywords: ["earplug"],
        confidence: 0.9,
        salience: 0.9,
        decayScore: 1,
        evidenceRefs: ["test"],
        sourceActionId: "earplug",
        sourceAgentRunId: null,
        effectivenessScore: -1,
        lastUsedAt: null,
        sourceRefs: ["test"],
        createdAt: "2026-05-23T00:00:00.000Z",
        updatedAt: "2026-05-23T00:00:00.000Z",
      },
    ],
    userState: null,
  };

  const actions = pickRecommendedActions(context);
  assert.equal(actions[0]?.id, "audio-ocean");
});
