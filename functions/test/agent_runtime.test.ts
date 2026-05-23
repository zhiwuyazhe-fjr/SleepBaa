import test from "node:test";
import assert from "node:assert/strict";
import {
  listAgentTools,
  runAgent,
  shouldRoutePromptToAgent,
} from "../src/agent/agent_runtime";
import { DeterministicAIProvider } from "../src/providers/ai_provider";
import { createRepositoryFromEnv } from "../src/repositories/firestore_repositories";

test("agent tool registry exposes core sleep and dorm tools", () => {
  const names = listAgentTools().map((tool) => tool.name);
  assert.ok(names.includes("context.read"));
  assert.ok(names.includes("plan.generate_tonight"));
  assert.ok(names.includes("interference.save_tonight"));
  assert.ok(names.includes("dorm.reminder.send"));
  assert.ok(names.includes("memory.upsert"));
});

test("agent routing detects cross-module sleep prompts", () => {
  assert.equal(shouldRoutePromptToAgent("我睡不着，室友很吵"), true);
  assert.equal(shouldRoutePromptToAgent("hi"), false);
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
});

