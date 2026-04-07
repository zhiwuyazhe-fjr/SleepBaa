import { handleSleepSessionChange } from "../orchestrators/assistant_orchestrator";
import { AIProvider } from "../providers/ai_provider";
import { AssistantDataRepository } from "../repositories/firestore_repositories";
import {
  asMap,
  asString,
  buildCompletedAutomation,
  changedPathsAreInternalOnly,
  readAutomationState,
  wasSyncProcessingRecentlyRequested,
} from "../shared/automation";

type JsonMap = Record<string, unknown>;

interface CloudBaseDatabaseEventPayload {
  docId: string;
  doc: JsonMap;
  dataType: string;
  updatedFields: JsonMap;
  removedFields: string[];
}

function asStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.map((item) => String(item));
}

function normalizeDatabaseEventPayload(event: unknown): CloudBaseDatabaseEventPayload {
  const payload = asMap(asMap(event).data);
  return {
    docId: asString(payload.docId),
    doc: asMap(payload.doc),
    dataType: asString(payload.dataType, "insert"),
    updatedFields: asMap(payload.updatedFields),
    removedFields: asStringArray(payload.RemovedFields ?? payload.removedFields),
  };
}

export async function onSleepSessionWritten(params: {
  uid: string;
  sessionId: string;
  beforeStatus?: string | null;
  afterStatus?: string | null;
  repo: AssistantDataRepository;
  provider: AIProvider;
}): Promise<void> {
  if (!params.uid || !params.sessionId) {
    return;
  }
  await handleSleepSessionChange(
    params.repo,
    params.provider,
    params.uid,
    params.sessionId,
    params.beforeStatus ?? null,
    params.afterStatus ?? null,
  );
}

export async function processSleepSessionDatabaseEvent(params: {
  event: unknown;
  repo: AssistantDataRepository;
  provider: AIProvider;
  nowMs?: number;
}): Promise<Record<string, unknown>> {
  const payload = normalizeDatabaseEventPayload(params.event);
  const doc = payload.doc;
  const automation = readAutomationState(doc._automation);
  const uid = asString(doc.uid);
  const sessionId = asString(doc.id, payload.docId);
  const afterStatus = asString(doc.status) || null;
  const beforeStatus = automation.lastHandledStatus ?? null;

  if (!uid || !sessionId) {
    return {
      ok: true,
      skipped: true,
      reason: "missing_identity",
      dataType: payload.dataType,
    };
  }

  if (payload.dataType === "delete") {
    return {
      ok: true,
      skipped: true,
      reason: "delete_ignored",
      uid,
      sessionId,
    };
  }

  if (
    payload.dataType === "update" &&
    changedPathsAreInternalOnly({
      updatedFields: payload.updatedFields,
      removedFields: payload.removedFields,
    })
  ) {
    return {
      ok: true,
      skipped: true,
      reason: "internal_update",
      uid,
      sessionId,
    };
  }

  if (wasSyncProcessingRecentlyRequested(doc._automation, params.nowMs)) {
    return {
      ok: true,
      skipped: true,
      reason: "sync_processing_requested",
      uid,
      sessionId,
    };
  }

  await onSleepSessionWritten({
    uid,
    sessionId,
    beforeStatus,
    afterStatus,
    repo: params.repo,
    provider: params.provider,
  });

  await params.repo.patchSleepSession(sessionId, {
    _automation: buildCompletedAutomation({
      previous: doc._automation,
      derivedAt: asString(
        doc.updatedAt,
        new Date(params.nowMs ?? Date.now()).toISOString(),
      ),
      derivedBy: "db-trigger",
      lastHandledStatus: afterStatus,
    }),
  });

  return {
    ok: true,
    skipped: false,
    uid,
    sessionId,
    beforeStatus,
    afterStatus,
    dataType: payload.dataType,
  };
}
