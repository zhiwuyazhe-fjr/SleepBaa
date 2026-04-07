import { refreshUserCards } from "../orchestrators/assistant_orchestrator";
import { AIProvider } from "../providers/ai_provider";
import { AssistantDataRepository } from "../repositories/firestore_repositories";
import { SurfaceId } from "../shared/types";

function normalizeSurfaces(value: unknown): SurfaceId[] {
  const allowed: SurfaceId[] = [
    "home_pre_sleep",
    "sleep_mode",
    "morning_feedback",
    "profile_report",
    "assistant_context",
  ];
  if (!Array.isArray(value)) {
    return ["home_pre_sleep", "profile_report"];
  }
  const next = value
    .map((item) => String(item))
    .filter((item): item is SurfaceId => allowed.includes(item as SurfaceId));
  return next.length > 0 ? next : ["home_pre_sleep", "profile_report"];
}

export async function refreshUserCardsCallable(params: {
  uid: string;
  surfaces?: unknown;
  repo: AssistantDataRepository;
  provider: AIProvider;
}): Promise<Record<string, unknown>> {
  return refreshUserCards(
    params.repo,
    params.provider,
    params.uid,
    normalizeSurfaces(params.surfaces),
  );
}
