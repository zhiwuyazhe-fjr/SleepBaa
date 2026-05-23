import { randomUUID } from "crypto";

import {
  AssistantMemoryCandidate,
  AssistantMemoryItem,
  MorningReviewResult,
} from "../shared/types";

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

function cryptoSafeFallback(): string {
  return randomUUID();
}
