import test from "node:test";
import assert from "node:assert/strict";
import { buildAgentMemoryOverview } from "../src/agent/agent_memory_overview";
import { AssistantMemoryItem } from "../src/shared/types";

function memory(
  id: string,
  kind: string,
  patch: Partial<AssistantMemoryItem> = {},
): AssistantMemoryItem {
  return {
    id,
    kind,
    content: `${kind} content`,
    canonicalKey: `${kind}:${id}`,
    keywords: [kind],
    confidence: 0.8,
    salience: 0.7,
    decayScore: 1,
    contradictionGroup: `${kind}:group`,
    evidenceRefs: [`test:${id}`],
    sourceActionId: null,
    sourceAgentRunId: null,
    effectivenessScore: null,
    lastUsedAt: null,
    sourceRefs: [`test:${id}`],
    createdAt: `2026-05-23T00:00:0${id}.000Z`,
    updatedAt: `2026-05-23T00:00:0${id}.000Z`,
    ...patch,
  };
}

test("agent memory overview groups kinds and ranks effects", () => {
  const overview = buildAgentMemoryOverview([
    memory("1", "intervention_effect", {
      content: "rain audio worked",
      sourceActionId: "audio-rain",
      effectivenessScore: 1,
      salience: 0.9,
    }),
    memory("2", "intervention_effect", {
      content: "earplug did not help",
      sourceActionId: "earplug",
      effectivenessScore: -1,
      salience: 0.6,
    }),
    memory("3", "strategy_weight", {
      content: "down-rank earplug",
      effectivenessScore: 0,
    }),
  ]);

  assert.equal(overview.totalCount, 3);
  assert.deepEqual(
    overview.byKind.map((item) => [item.kind, item.count]),
    [
      ["intervention_effect", 2],
      ["strategy_weight", 1],
    ],
  );
  assert.equal(overview.interventionEffects[0]?.actionId, "audio-rain");
  assert.equal(overview.strategyWeights[0]?.content, "down-rank earplug");
  assert.ok(
    overview.contradictionGroups.some(
      (group) => group.group === "intervention_effect:group",
    ),
  );
});
