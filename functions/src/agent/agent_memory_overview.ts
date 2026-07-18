import { AssistantMemoryItem } from "../shared/types";

type JsonMap = Record<string, unknown>;

export interface AgentMemoryKindSummary {
  kind: string;
  count: number;
  averageConfidence: number | null;
  averageSalience: number | null;
}

export interface AgentMemoryEffectSummary {
  actionId: string | null;
  content: string;
  effectivenessScore: number | null;
  confidence: number | null;
  evidenceRefs: string[];
  updatedAt: string;
}

export interface AgentMemoryOverview {
  generatedAt: string;
  totalCount: number;
  byKind: AgentMemoryKindSummary[];
  recent: AssistantMemoryItem[];
  interventionEffects: AgentMemoryEffectSummary[];
  strategyWeights: AgentMemoryEffectSummary[];
  contradictionGroups: Array<{
    group: string;
    count: number;
    latestUpdatedAt: string | null;
  }>;
}

function roundScore(value: number): number {
  return Math.round(value * 1000) / 1000;
}

function average(values: number[]): number | null {
  if (values.length === 0) {
    return null;
  }
  return roundScore(values.reduce((sum, value) => sum + value, 0) / values.length);
}

function asNumber(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function memoryRank(item: AssistantMemoryItem): number {
  const salience = asNumber(item.salience) ?? 0.5;
  const confidence = asNumber(item.confidence) ?? 0.5;
  const decay = asNumber(item.decayScore) ?? 1;
  const effectiveness =
    item.effectivenessScore == null ? 0 : Math.abs(item.effectivenessScore);
  return salience * 4 + confidence * 2 + decay + effectiveness;
}

function effectSummary(item: AssistantMemoryItem): AgentMemoryEffectSummary {
  return {
    actionId: item.sourceActionId ?? null,
    content: item.content,
    effectivenessScore: item.effectivenessScore ?? null,
    confidence: item.confidence ?? null,
    evidenceRefs: item.evidenceRefs ?? item.sourceRefs ?? [],
    updatedAt: item.updatedAt,
  };
}

export function buildAgentMemoryOverview(
  items: AssistantMemoryItem[],
): AgentMemoryOverview {
  const byKindMap = new Map<
    string,
    { count: number; confidence: number[]; salience: number[] }
  >();
  const contradictionMap = new Map<string, { count: number; latest: string }>();

  for (const item of items) {
    const kind = item.kind || "profile";
    const summary =
      byKindMap.get(kind) ?? { count: 0, confidence: [], salience: [] };
    summary.count += 1;
    const confidence = asNumber(item.confidence);
    const salience = asNumber(item.salience);
    if (confidence != null) {
      summary.confidence.push(confidence);
    }
    if (salience != null) {
      summary.salience.push(salience);
    }
    byKindMap.set(kind, summary);

    const group = item.contradictionGroup?.trim();
    if (group) {
      const existing = contradictionMap.get(group);
      const updatedAt = item.updatedAt || "";
      contradictionMap.set(group, {
        count: (existing?.count ?? 0) + 1,
        latest:
          !existing || updatedAt > existing.latest ? updatedAt : existing.latest,
      });
    }
  }

  const byKind = Array.from(byKindMap.entries())
    .map(([kind, value]) => ({
      kind,
      count: value.count,
      averageConfidence: average(value.confidence),
      averageSalience: average(value.salience),
    }))
    .sort((left, right) => right.count - left.count || left.kind.localeCompare(right.kind));

  const ranked = [...items].sort((left, right) => memoryRank(right) - memoryRank(left));
  return {
    generatedAt: new Date().toISOString(),
    totalCount: items.length,
    byKind,
    recent: [...items]
      .sort((left, right) => right.updatedAt.localeCompare(left.updatedAt))
      .slice(0, 12),
    interventionEffects: ranked
      .filter((item) => item.kind === "intervention_effect")
      .slice(0, 12)
      .map(effectSummary),
    strategyWeights: ranked
      .filter((item) => item.kind === "strategy_weight")
      .slice(0, 12)
      .map(effectSummary),
    contradictionGroups: Array.from(contradictionMap.entries())
      .filter(([, value]) => value.count > 1)
      .map(([group, value]) => ({
        group,
        count: value.count,
        latestUpdatedAt: value.latest || null,
      }))
      .sort((left, right) => right.count - left.count),
  };
}

export function compactMemoryItem(item: AssistantMemoryItem): JsonMap {
  return {
    id: item.id,
    kind: item.kind,
    content: item.content,
    canonicalKey: item.canonicalKey ?? null,
    confidence: item.confidence ?? null,
    salience: item.salience,
    decayScore: item.decayScore ?? null,
    effectivenessScore: item.effectivenessScore ?? null,
    sourceActionId: item.sourceActionId ?? null,
    sourceAgentRunId: item.sourceAgentRunId ?? null,
    evidenceRefs: item.evidenceRefs ?? item.sourceRefs ?? [],
    lastUsedAt: item.lastUsedAt ?? null,
    updatedAt: item.updatedAt,
  };
}
