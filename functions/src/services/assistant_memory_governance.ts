import { randomUUID } from "crypto";

import {
  AgentGoalDoc,
  AgentToolCallDoc,
  AssistantMemoryCandidate,
  AssistantMemoryItem,
  MorningReviewResult,
} from "../shared/types";

type JsonMap = Record<string, unknown>;

function nowIso(): string {
  return new Date().toISOString();
}

function safeMemoryKey(value: string): string {
  return value
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9\u4e00-\u9fff]+/gi, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 64);
}

function tokenize(value: string): string[] {
  return Array.from(
    new Set(
      (value.toLowerCase().match(/[a-z0-9\u4e00-\u9fff]+/g) ?? []).slice(
        0,
        8,
      ),
    ),
  );
}

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

export function buildMemoryItemsFromCandidates(params: {
  uid: string;
  candidates: AssistantMemoryCandidate[];
  sourceAgentRunId?: string | null;
  sourceActionId?: string | null;
}): AssistantMemoryItem[] {
  const timestamp = nowIso();
  return params.candidates.map((item) => {
    const canonicalKey = item.canonicalKey.trim();
    const safeKey = safeMemoryKey(canonicalKey);
    return {
      id: `${params.uid}:${item.kind}:${safeKey || cryptoSafeFallback()}`,
      kind: item.kind,
      content: item.content,
      canonicalKey,
      keywords: item.keywords,
      confidence: item.confidence,
      sourceThreadId: item.sourceThreadId ?? null,
      sourceMessageId: item.sourceMessageId ?? null,
      salience: item.salience,
      decayScore: 1,
      contradictionGroup: `${item.kind}:${safeKey || canonicalKey}`,
      evidenceRefs: [
        ...item.sourceRefs,
        ...(params.sourceAgentRunId
          ? [`agent_runs:${params.sourceAgentRunId}`]
          : []),
        ...(params.sourceActionId
          ? [`agent_tool_calls:${params.sourceActionId}`]
          : []),
      ],
      sourceActionId: params.sourceActionId ?? null,
      sourceAgentRunId: params.sourceAgentRunId ?? null,
      effectivenessScore: null,
      lastUsedAt: timestamp,
      sourceRefs: item.sourceRefs,
      createdAt: timestamp,
      updatedAt: timestamp,
    };
  });
}

export function buildMorningFeedbackMemoryItems(params: {
  uid: string;
  sessionId: string;
  review: MorningReviewResult;
  runId?: string | null;
}): AssistantMemoryItem[] {
  const timestamp = nowIso();
  const items: AssistantMemoryItem[] = [];
  const sourceRefs = [
    "morning_feedback",
    `sleep_sessions:${params.sessionId}`,
    ...(params.runId ? [`assistant_runs:${params.runId}`] : []),
  ];

  for (const action of params.review.effectiveActions) {
    const normalized = action.trim();
    if (!normalized) {
      continue;
    }
    items.push({
      id: `${params.uid}:intervention_effect:${safeMemoryKey(normalized)}`,
      kind: "intervention_effect",
      content:
        `Effective recommendation: ${normalized}. ` +
        "Morning feedback marked it helpful for the last night.",
      canonicalKey: `intervention_effect:${safeMemoryKey(normalized)}`,
      keywords: [...tokenize(normalized), "effective", "intervention"],
      confidence: 0.84,
      sourceThreadId: null,
      sourceMessageId: null,
      salience: 0.88,
      decayScore: 1,
      contradictionGroup: `intervention_effect:${safeMemoryKey(normalized)}`,
      evidenceRefs: sourceRefs,
      sourceActionId: normalized,
      sourceAgentRunId: params.runId ?? null,
      effectivenessScore: 1,
      lastUsedAt: timestamp,
      sourceRefs,
      createdAt: timestamp,
      updatedAt: timestamp,
    });
  }

  for (const action of params.review.ineffectiveActions) {
    const normalized = action.trim();
    if (!normalized) {
      continue;
    }
    items.push({
      id: `${params.uid}:intervention_effect:${safeMemoryKey(normalized)}`,
      kind: "intervention_effect",
      content:
        `Ineffective recommendation: ${normalized}. ` +
        "Morning feedback marked it as limited help for the last night, " +
        "so future planning should down-rank it.",
      canonicalKey: `intervention_effect:${safeMemoryKey(normalized)}`,
      keywords: [...tokenize(normalized), "ineffective", "intervention"],
      confidence: 0.8,
      sourceThreadId: null,
      sourceMessageId: null,
      salience: 0.86,
      decayScore: 1,
      contradictionGroup: `intervention_effect:${safeMemoryKey(normalized)}`,
      evidenceRefs: sourceRefs,
      sourceActionId: normalized,
      sourceAgentRunId: params.runId ?? null,
      effectivenessScore: -1,
      lastUsedAt: timestamp,
      sourceRefs,
      createdAt: timestamp,
      updatedAt: timestamp,
    });
  }

  const strategySummary = [
    params.review.effectiveActions.length > 0
      ? `keep: ${params.review.effectiveActions.join(", ")}`
      : "",
    params.review.ineffectiveActions.length > 0
      ? `down-rank: ${params.review.ineffectiveActions.join(", ")}`
      : "",
  ]
    .filter(Boolean)
    .join("; ");
  if (strategySummary) {
    items.push({
      id: `${params.uid}:strategy_weight:morning-feedback-${params.sessionId}`,
      kind: "strategy_weight",
      content: `Morning feedback strategy update: ${strategySummary}`,
      canonicalKey: `strategy_weight:morning-feedback:${params.sessionId}`,
      keywords: ["strategy", "feedback", "intervention"],
      confidence: 0.82,
      sourceThreadId: null,
      sourceMessageId: null,
      salience: 0.78,
      decayScore: 1,
      contradictionGroup: "strategy_weight:morning-feedback",
      evidenceRefs: sourceRefs,
      sourceActionId: params.sessionId,
      sourceAgentRunId: params.runId ?? null,
      effectivenessScore: 0,
      lastUsedAt: timestamp,
      sourceRefs,
      createdAt: timestamp,
      updatedAt: timestamp,
    });
  }

  return items;
}

interface ToolOutcomeHint {
  label: string;
  actionId?: string;
  keywords: string[];
}

const TOOL_OUTCOME_HINTS: Record<string, ToolOutcomeHint> = {
  "interference.save_tonight": {
    label: "tonight interference update",
    keywords: ["interference", "tonight", "noise", "light", "phone", "emotion"],
  },
  "plan.generate_tonight": {
    label: "tonight plan generation",
    keywords: ["tonight", "plan", "recommendation"],
  },
  "cards.refresh": {
    label: "surface card refresh",
    keywords: ["cards", "surface", "refresh"],
  },
  "dorm.reminder.send": {
    label: "gentle dorm reminder",
    actionId: "dorm-quiet",
    keywords: ["dorm-quiet", "dorm", "roommate", "reminder"],
  },
  "dorm.status.update": {
    label: "dorm quiet status update",
    actionId: "dorm-quiet",
    keywords: ["dorm-quiet", "dorm", "roommate", "quiet"],
  },
  "dorm.rules.save": {
    label: "dorm rules draft",
    keywords: ["dorm", "rules", "agreement"],
  },
  "dorm.invite.create": {
    label: "dorm invite creation",
    keywords: ["dorm", "invite", "roommate"],
  },
  "sleep.mode.enter": {
    label: "sleep mode entry",
    keywords: ["sleep", "mode", "bedtime"],
  },
  "sleep.mode.exit": {
    label: "sleep mode exit",
    keywords: ["sleep", "mode", "morning"],
  },
  "capture.save": {
    label: "sleep capture save",
    actionId: "thought-clean",
    keywords: ["thought-clean", "capture", "memo", "dream"],
  },
  "notification.write": {
    label: "notification write",
    keywords: ["notification", "reminder"],
  },
  "audio.recommend": {
    label: "sleep audio recommendation",
    actionId: "audio-ocean",
    keywords: ["audio-ocean", "audio", "music", "white-noise"],
  },
};

interface StrategyAccumulator {
  actionId: string;
  label: string;
  keywords: Set<string>;
  score: number;
  positive: string[];
  negative: string[];
  evidenceRefs: string[];
  sourceCallId: string | null;
}

function toolHint(toolName: string): ToolOutcomeHint {
  return (
    TOOL_OUTCOME_HINTS[toolName] ?? {
      label: toolName,
      keywords: tokenize(toolName.replace(/\./g, " ")),
    }
  );
}

function compactToolOutput(output: unknown): string {
  const value = asMap(output);
  const selected: JsonMap = {};
  for (const key of [
    "skipped",
    "reason",
    "status",
    "sessionId",
    "riskLevel",
    "actionCount",
    "targetUid",
    "dormId",
    "route",
    "record",
  ]) {
    if (value[key] != null) {
      selected[key] = value[key];
    }
  }
  if (value.interference != null) {
    selected.interferenceUpdated = true;
  }
  const text = JSON.stringify(
    Object.keys(selected).length > 0 ? selected : value,
  );
  return text.length > 180 ? `${text.slice(0, 177)}...` : text;
}

function outputIndicatesSkipped(call: AgentToolCallDoc): boolean {
  return asBoolean(asMap(call.output).skipped);
}

function problemReason(call: AgentToolCallDoc): string {
  return (
    asString(call.error) ||
    asString(asMap(call.output).reason) ||
    (call.status === "skipped" ? "skipped" : "unknown")
  );
}

function isProblemCall(call: AgentToolCallDoc): boolean {
  return (
    call.status === "failed" ||
    call.status === "skipped" ||
    outputIndicatesSkipped(call)
  );
}

function isCommittedCall(call: AgentToolCallDoc): boolean {
  return (
    call.status === "success" &&
    call.committed === true &&
    !outputIndicatesSkipped(call)
  );
}

function buildMemoryItem(params: {
  uid: string;
  kind: string;
  content: string;
  canonicalKey: string;
  keywords: string[];
  evidenceRefs: string[];
  sourceActionId: string | null;
  sourceAgentRunId: string | null;
  effectivenessScore: number | null;
  confidence: number;
  salience: number;
  sourceThreadId?: string | null;
}): AssistantMemoryItem {
  const timestamp = nowIso();
  const safeKey = safeMemoryKey(params.canonicalKey);
  const sourceRefs = Array.from(
    new Set(["agent_runtime", "agent_execution_memory", ...params.evidenceRefs]),
  );
  return {
    id: `${params.uid}:${params.kind}:${safeKey || cryptoSafeFallback()}`,
    kind: params.kind,
    content: params.content,
    canonicalKey: params.canonicalKey,
    keywords: Array.from(new Set(params.keywords)).slice(0, 16),
    confidence: params.confidence,
    sourceThreadId: params.sourceThreadId ?? null,
    sourceMessageId: null,
    salience: params.salience,
    decayScore: 1,
    contradictionGroup: `${params.kind}:${safeKey || params.canonicalKey}`,
    evidenceRefs: params.evidenceRefs,
    sourceActionId: params.sourceActionId,
    sourceAgentRunId: params.sourceAgentRunId,
    effectivenessScore: params.effectivenessScore,
    lastUsedAt: timestamp,
    sourceRefs,
    createdAt: timestamp,
    updatedAt: timestamp,
  };
}

function addStrategyEvidence(
  strategies: Map<string, StrategyAccumulator>,
  params: {
    hint: ToolOutcomeHint;
    call: AgentToolCallDoc;
    scoreDelta: number;
    positive?: string;
    negative?: string;
  },
): void {
  if (!params.hint.actionId) {
    return;
  }
  const current =
    strategies.get(params.hint.actionId) ??
    ({
      actionId: params.hint.actionId,
      label: params.hint.label,
      keywords: new Set(["strategy", ...params.hint.keywords]),
      score: 0,
      positive: [],
      negative: [],
      evidenceRefs: [],
      sourceCallId: null,
    } satisfies StrategyAccumulator);
  current.score = Math.max(-1, Math.min(1, current.score + params.scoreDelta));
  if (params.positive) {
    current.positive.push(params.positive);
  }
  if (params.negative) {
    current.negative.push(params.negative);
  }
  current.evidenceRefs.push(`agent_tool_calls:${params.call.id}`);
  current.sourceCallId ??= params.call.id;
  strategies.set(params.hint.actionId, current);
}

export function buildAgentExecutionMemoryItems(params: {
  uid: string;
  runId: string;
  threadId?: string | null;
  prompt: string;
  goal: AgentGoalDoc;
  toolCalls: AgentToolCallDoc[];
}): AssistantMemoryItem[] {
  const calls = params.toolCalls.filter(
    (call) => call.toolName !== "memory.upsert",
  );
  const committedCalls = calls.filter(isCommittedCall);
  const problemCalls = calls.filter(isProblemCall);
  const strategies = new Map<string, StrategyAccumulator>();
  const items: AssistantMemoryItem[] = [];
  const runRef = `agent_runs:${params.runId}`;

  if (committedCalls.length > 0) {
    const labels = committedCalls.map((call) => toolHint(call.toolName).label);
    const toolNames = committedCalls.map((call) => call.toolName).sort();
    items.push(
      buildMemoryItem({
        uid: params.uid,
        kind: "agent_action",
        content:
          `Agent committed actions for ${params.goal.intent}: ` +
          `${labels.join(", ")}. User goal: ${params.prompt.trim()}`,
        canonicalKey: `agent_action:${params.goal.intent}:committed:${toolNames.join(",")}`,
        keywords: [
          "agent",
          "committed",
          params.goal.intent,
          ...committedCalls.flatMap((call) => toolHint(call.toolName).keywords),
        ],
        evidenceRefs: [
          runRef,
          ...committedCalls.map((call) => `agent_tool_calls:${call.id}`),
        ],
        sourceActionId: params.runId,
        sourceAgentRunId: params.runId,
        effectivenessScore: null,
        confidence: 0.74,
        salience: 0.76,
        sourceThreadId: params.threadId ?? null,
      }),
    );

    for (const call of committedCalls) {
      const hint = toolHint(call.toolName);
      addStrategyEvidence(strategies, {
        hint,
        call,
        scoreDelta: 0.18,
        positive: `${hint.label} completed`,
      });
    }
  }

  if (problemCalls.length > 0) {
    const descriptions = problemCalls
      .slice(0, 6)
      .map(
        (call) =>
          `${call.toolName}: ${problemReason(call)} ${compactToolOutput(
            call.output,
          )}`,
      );
    const toolNames = problemCalls.map((call) => call.toolName).sort();
    items.push(
      buildMemoryItem({
        uid: params.uid,
        kind: "agent_action",
        content:
          `Agent encountered incomplete actions for ${params.goal.intent}: ` +
          descriptions.join("; "),
        canonicalKey: `agent_action:${params.goal.intent}:incomplete:${toolNames.join(",")}`,
        keywords: [
          "agent",
          "incomplete",
          params.goal.intent,
          ...problemCalls.flatMap((call) => toolHint(call.toolName).keywords),
        ],
        evidenceRefs: [
          runRef,
          ...problemCalls.map((call) => `agent_tool_calls:${call.id}`),
        ],
        sourceActionId: params.runId,
        sourceAgentRunId: params.runId,
        effectivenessScore: null,
        confidence: 0.78,
        salience: 0.82,
        sourceThreadId: params.threadId ?? null,
      }),
    );

    for (const call of problemCalls) {
      const reason = problemReason(call);
      if (reason === "hard_confirm_required" || call.risk === "read") {
        continue;
      }
      const hint = toolHint(call.toolName);
      addStrategyEvidence(strategies, {
        hint,
        call,
        scoreDelta: -0.35,
        negative: `${hint.label} incomplete: ${reason}`,
      });
    }
  }

  for (const strategy of strategies.values()) {
    if (Math.abs(strategy.score) < 0.01) {
      continue;
    }
    items.push(
      buildMemoryItem({
        uid: params.uid,
        kind: "strategy_weight",
        content:
          `Agent execution strategy update for ${strategy.actionId}: ` +
          [
            strategy.positive.length > 0
              ? `completed ${strategy.positive.join(", ")}`
              : "",
            strategy.negative.length > 0
              ? `down-rank after ${strategy.negative.join(", ")}`
              : "",
          ]
            .filter(Boolean)
            .join("; ") +
          ". Treat this as weak execution evidence until morning feedback confirms user benefit.",
        canonicalKey: `strategy_weight:agent-outcome:${strategy.actionId}`,
        keywords: Array.from(strategy.keywords),
        evidenceRefs: [runRef, ...Array.from(new Set(strategy.evidenceRefs))],
        sourceActionId: strategy.actionId,
        sourceAgentRunId: params.runId,
        effectivenessScore: Number(strategy.score.toFixed(2)),
        confidence: 0.68,
        salience: 0.7,
        sourceThreadId: params.threadId ?? null,
      }),
    );
  }

  return items;
}

export function buildAgentUndoMemoryItems(params: {
  uid: string;
  call: AgentToolCallDoc;
  output: JsonMap;
}): AssistantMemoryItem[] {
  const hint = toolHint(params.call.toolName);
  const runRef = `agent_runs:${params.call.runId}`;
  const callRef = `agent_tool_calls:${params.call.id}`;
  const evidenceRefs = [runRef, callRef, `agent_tool_undo:${params.call.id}`];
  const items: AssistantMemoryItem[] = [
    buildMemoryItem({
      uid: params.uid,
      kind: "agent_action",
      content:
        `User undid Agent action ${params.call.toolName}. ` +
        `Undo result: ${compactToolOutput(params.output)}`,
      canonicalKey: `agent_action:undo:${params.call.toolName}`,
      keywords: ["agent", "undo", ...hint.keywords],
      evidenceRefs,
      sourceActionId: params.call.id,
      sourceAgentRunId: params.call.runId,
      effectivenessScore: null,
      confidence: 0.86,
      salience: 0.9,
      sourceThreadId: params.call.threadId ?? null,
    }),
  ];

  if (hint.actionId) {
    items.push(
      buildMemoryItem({
        uid: params.uid,
        kind: "strategy_weight",
        content:
          `User reverted Agent-managed ${hint.label}. ` +
          `Down-rank ${hint.actionId} until later positive feedback outweighs this undo evidence.`,
        canonicalKey: `strategy_weight:agent-undo:${hint.actionId}`,
        keywords: ["strategy", "undo", ...hint.keywords],
        evidenceRefs,
        sourceActionId: hint.actionId,
        sourceAgentRunId: params.call.runId,
        effectivenessScore: -0.7,
        confidence: 0.82,
        salience: 0.88,
        sourceThreadId: params.call.threadId ?? null,
      }),
    );
  }

  return items;
}

function cryptoSafeFallback(): string {
  return randomUUID();
}
