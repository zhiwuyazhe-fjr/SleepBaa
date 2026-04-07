import { AssistantDataRepository } from "../repositories/firestore_repositories";

export async function createDormInviteCallable(params: {
  uid: string;
  expiresInHours?: number;
  repo: AssistantDataRepository;
}): Promise<Record<string, unknown>> {
  return params.repo.createDormInvite(params.uid, params.expiresInHours);
}
