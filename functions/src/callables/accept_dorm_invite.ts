import { AssistantDataRepository } from "../repositories/firestore_repositories";

export async function acceptDormInviteCallable(params: {
  uid: string;
  inviteCode: string;
  repo: AssistantDataRepository;
}): Promise<Record<string, unknown>> {
  if (!params.inviteCode.trim()) {
    throw new Error("inviteCode is required.");
  }
  const result = await params.repo.acceptDormInvite(params.uid, params.inviteCode);
  return {
    dormId: result.dormId,
    memberStatus: "quiet",
    acceptedAt: result.acceptedAt,
  };
}
