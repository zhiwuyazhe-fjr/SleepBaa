import { handleAssistantReply } from "../orchestrators/assistant_orchestrator";
import { AIProvider } from "../providers/ai_provider";
import { AssistantDataRepository } from "../repositories/firestore_repositories";

export async function assistantReplyCallable(params: {
  uid: string;
  threadId: string;
  prompt: string;
  repo: AssistantDataRepository;
  provider: AIProvider;
}): Promise<Record<string, unknown>> {
  if (!params.threadId.trim() || !params.prompt.trim()) {
    throw new Error("threadId and prompt are required.");
  }
  const result = await handleAssistantReply(
    params.repo,
    params.provider,
    params.uid,
    params.prompt,
    params.threadId,
  );
  return {
    reply: result.reply,
    runId: result.runId,
    intent: result.intent,
    provider: params.provider.providerName,
    model: params.provider.modelName,
    recommendedActions: result.userState.tonightPlan?.recommendedActions ?? [],
    updatedSurfaces: result.updatedSurfaces,
  };
}
