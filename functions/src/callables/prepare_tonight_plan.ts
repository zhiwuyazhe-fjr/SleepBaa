import { prepareTonightPlan } from "../orchestrators/assistant_orchestrator";
import { AIProvider } from "../providers/ai_provider";
import { AssistantDataRepository } from "../repositories/firestore_repositories";

export async function prepareTonightPlanCallable(params: {
  uid: string;
  source?: string;
  threadId?: string;
  repo: AssistantDataRepository;
  provider: AIProvider;
}): Promise<Record<string, unknown>> {
  const result = await prepareTonightPlan(
    params.repo,
    params.provider,
    params.uid,
    params.source ?? "manual",
    params.threadId,
  );
  return {
    dateKey: result.userState.tonightPlan?.dateKey ?? "",
    riskLevel: result.userState.tonightPlan?.riskLevel ?? "low",
    coachSummary: result.userState.tonightPlan?.coachSummary ?? "",
    topFactors: result.userState.tonightPlan?.topFactors ?? [],
    recommendedActions: result.userState.tonightPlan?.recommendedActions ?? [],
    provider: result.provider,
    model: result.model,
    runId: result.runId,
    sourceMode: result.sourceMode,
    errorMessage: result.errorMessage,
    updatedSurfaces: result.updatedSurfaces,
    generatedAt: result.userState.tonightPlan?.generatedAt ?? "",
    cardVersion: result.runId,
  };
}
