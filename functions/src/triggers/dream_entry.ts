import { handleDreamEntryChange } from "../orchestrators/assistant_orchestrator";
import { AIProvider } from "../providers/ai_provider";
import { AssistantDataRepository } from "../repositories/firestore_repositories";
import {
  asMap,
  asString,
  buildCompletedAutomation,
  changedPathsAreInternalOnly,
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

export async function onDreamEntryWritten(params: {
  uid: string;
  entryId: string;
  body: string;
  repo: AssistantDataRepository;
  provider: AIProvider;
}): Promise<void> {
  if (!params.uid || !params.entryId) {
    return;
  }
  await handleDreamEntryChange(
    params.repo,
    params.provider,
    params.uid,
    params.entryId,
    params.body,
  );
}

export async function processDreamEntryDatabaseEvent(params: {
  event: unknown;
  repo: AssistantDataRepository;
  provider: AIProvider;
  nowMs?: number;
}): Promise<Record<string, unknown>> {
  const payload = normalizeDatabaseEventPayload(params.event);
  const doc = payload.doc;
  const uid = asString(doc.userId);
  const entryId = asString(doc.id, payload.docId);
  const body = asString(doc.body);

  if (!uid || !entryId) {
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
      entryId,
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
      entryId,
    };
  }

  if (wasSyncProcessingRecentlyRequested(doc._automation, params.nowMs)) {
    return {
      ok: true,
      skipped: true,
      reason: "sync_processing_requested",
      uid,
      entryId,
    };
  }

  await onDreamEntryWritten({
    uid,
    entryId,
    body,
    repo: params.repo,
    provider: params.provider,
  });

  await params.repo.patchDreamEntry(entryId, {
    _automation: buildCompletedAutomation({
      previous: doc._automation,
      derivedAt: asString(
        doc.updatedAt,
        new Date(params.nowMs ?? Date.now()).toISOString(),
      ),
      derivedBy: "db-trigger",
    }),
  });

  return {
    ok: true,
    skipped: false,
    uid,
    entryId,
    dataType: payload.dataType,
  };
}
