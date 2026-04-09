import { handleAssistantCapture } from "../orchestrators/assistant_orchestrator";
import { AIProvider } from "../providers/ai_provider";
import { AssistantDataRepository } from "../repositories/firestore_repositories";
import { SleepCaptureKind } from "../shared/types";

export async function assistantCaptureCallable(params: {
  uid: string;
  threadId: string;
  prompt: string;
  captureType: SleepCaptureKind;
  sessionId: string;
  repo: AssistantDataRepository;
  provider: AIProvider;
}): Promise<Record<string, unknown>> {
  if (
    !params.threadId.trim() ||
    !params.prompt.trim() ||
    !params.sessionId.trim()
  ) {
    throw new Error("threadId, prompt, and sessionId are required.");
  }
  const result = await handleAssistantCapture(
    params.repo,
    params.provider,
    params.uid,
    params.prompt,
    params.threadId,
    params.captureType,
    params.sessionId,
  );
  return {
    reply: result.reply,
    runId: result.runId,
    provider: result.provider,
    model: result.model,
    sourceMode: result.sourceMode,
    errorMessage: result.errorMessage,
    updatedSurfaces: result.updatedSurfaces,
    record: result.record,
  };
}
