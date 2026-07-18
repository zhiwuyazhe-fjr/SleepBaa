import { AssistantDataRepository } from "../repositories/firestore_repositories";
import { buildAgentUndoMemoryItems } from "../services/assistant_memory_governance";
import { buildCardSnapshots } from "../services/materialize_card_snapshots";
import {
  AgentToolCallDoc,
  SurfaceId,
  UserStateDoc,
} from "../shared/types";

type JsonMap = Record<string, unknown>;

export interface AgentToolUndoResult {
  status: "applied" | "unavailable";
  call: AgentToolCallDoc;
  output: JsonMap;
  updatedSurfaces: SurfaceId[];
  alreadyApplied?: boolean;
}

export class AgentToolUndoError extends Error {
  constructor(
    readonly code: string,
    readonly httpStatus: number,
    message: string,
    readonly result?: AgentToolUndoResult,
  ) {
    super(message);
    this.name = "AgentToolUndoError";
  }
}

function nowIso(): string {
  return new Date().toISOString();
}

function asMap(value: unknown): JsonMap {
  return value && typeof value === "object" && !Array.isArray(value)
    ? ({ ...(value as JsonMap) } as JsonMap)
    : {};
}

function asString(value: unknown, fallback = ""): string {
  return typeof value === "string" ? value : fallback;
}

function asBoolean(value: unknown, fallback = false): boolean {
  return typeof value === "boolean" ? value : fallback;
}

function hasOwn(value: JsonMap, key: string): boolean {
  return Object.prototype.hasOwnProperty.call(value, key);
}

async function refreshSurfaces(params: {
  repo: AssistantDataRepository;
  uid: string;
  threadId?: string | null;
  surfaces: SurfaceId[];
}): Promise<void> {
  const context = await params.repo.buildAssistantContext(
    params.uid,
    params.threadId ?? undefined,
    { profile: "insight_full" },
  );
  if (!context.userState) {
    return;
  }
  const snapshots = buildCardSnapshots(
    context,
    context.userState,
    params.surfaces,
  );
  await Promise.all(
    snapshots.map((snapshot) =>
      params.repo.writeCardSnapshot(params.uid, snapshot),
    ),
  );
}

async function markUndoUnavailable(params: {
  repo: AssistantDataRepository;
  uid: string;
  call: AgentToolCallDoc;
  message: string;
}): Promise<never> {
  const nextCall: AgentToolCallDoc = {
    ...params.call,
    undoStatus: "unavailable",
    undoError: params.message,
  };
  await params.repo.writeAgentToolCall(params.uid, params.call.id, nextCall);
  const result: AgentToolUndoResult = {
    status: "unavailable",
    call: nextCall,
    output: { reason: params.message },
    updatedSurfaces: [],
  };
  throw new AgentToolUndoError(
    "AGENT_TOOL_UNDO_UNAVAILABLE",
    409,
    params.message,
    result,
  );
}

async function applyInterferenceUndo(params: {
  repo: AssistantDataRepository;
  uid: string;
  call: AgentToolCallDoc;
  undoPayload: JsonMap;
}): Promise<{ output: JsonMap; updatedSurfaces: SurfaceId[] }> {
  if (!hasOwn(params.undoPayload, "previous")) {
    await markUndoUnavailable({
      repo: params.repo,
      uid: params.uid,
      call: params.call,
      message: "interference undo requires previous interference snapshot.",
    });
  }
  const previous = params.undoPayload.previous ?? null;
  await params.repo.writeUserState(params.uid, {
    tonightInterference: previous as UserStateDoc["tonightInterference"],
  });
  const updatedSurfaces: SurfaceId[] = ["home_pre_sleep", "assistant_context"];
  await refreshSurfaces({
    repo: params.repo,
    uid: params.uid,
    threadId: params.call.threadId ?? null,
    surfaces: updatedSurfaces,
  });
  return {
    output: { restored: "tonightInterference", previous },
    updatedSurfaces,
  };
}

async function applySleepExitUndo(params: {
  repo: AssistantDataRepository;
  uid: string;
  call: AgentToolCallDoc;
  undoPayload: JsonMap;
}): Promise<{ output: JsonMap; updatedSurfaces: SurfaceId[] }> {
  const previous = asMap(params.undoPayload.previous);
  const sessionId = asString(previous.id);
  if (!sessionId) {
    await markUndoUnavailable({
      repo: params.repo,
      uid: params.uid,
      call: params.call,
      message: "sleep exit undo requires a previous sleep session snapshot.",
    });
  }
  const restoredSession = {
    ...previous,
    id: sessionId,
    uid: params.uid,
    updatedAt: nowIso(),
  };
  await params.repo.saveSleepSession(restoredSession);
  let dormStatusRestored = true;
  try {
    const sleepModeActive = asBoolean(previous.sleepModeActive);
    await params.repo.updateDormMemberStatus(params.uid, {
      sleepModeActive,
      status: sleepModeActive ? "sleeping" : "quiet",
      note: "Agent undo restored the previous sleep session state.",
    });
  } catch {
    dormStatusRestored = false;
  }
  const updatedSurfaces: SurfaceId[] = ["sleep_mode", "assistant_context"];
  await refreshSurfaces({
    repo: params.repo,
    uid: params.uid,
    threadId: params.call.threadId ?? null,
    surfaces: updatedSurfaces,
  });
  return {
    output: {
      restored: "sleepSession",
      sessionId,
      dormStatusRestored,
    },
    updatedSurfaces,
  };
}

export async function undoAgentToolCall(params: {
  repo: AssistantDataRepository;
  uid: string;
  callId: string;
}): Promise<AgentToolUndoResult> {
  const call = await params.repo.getAgentToolCall(params.uid, params.callId);
  if (!call) {
    throw new AgentToolUndoError(
      "AGENT_TOOL_CALL_NOT_FOUND",
      404,
      "Agent tool call was not found.",
    );
  }
  if (call.undoStatus === "applied") {
    return {
      status: "applied",
      call,
      output: asMap(call.undoResult),
      updatedSurfaces: [],
      alreadyApplied: true,
    };
  }
  if (call.status !== "success") {
    await markUndoUnavailable({
      repo: params.repo,
      uid: params.uid,
      call,
      message: "Only successful tool calls can be undone.",
    });
  }
  const undoPayload = asMap(call.undoPayload);
  if (Object.keys(undoPayload).length === 0) {
    await markUndoUnavailable({
      repo: params.repo,
      uid: params.uid,
      call,
      message: "This tool call did not record an undo payload.",
    });
  }

  let applied: { output: JsonMap; updatedSurfaces: SurfaceId[] };
  if (call.toolName === "interference.save_tonight") {
    applied = await applyInterferenceUndo({
      repo: params.repo,
      uid: params.uid,
      call,
      undoPayload,
    });
  } else if (call.toolName === "sleep.mode.exit") {
    applied = await applySleepExitUndo({
      repo: params.repo,
      uid: params.uid,
      call,
      undoPayload,
    });
  } else {
    const compensation = asString(undoPayload.compensation);
    return await markUndoUnavailable({
      repo: params.repo,
      uid: params.uid,
      call,
      message: compensation
        ? `This action has a compensation note but no exact undo: ${compensation}`
        : `No exact undo handler is registered for ${call.toolName}.`,
    });
  }

  const nextCall: AgentToolCallDoc = {
    ...call,
    undoStatus: "applied",
    undoAppliedAt: nowIso(),
    undoResult: applied.output,
    undoError: null,
  };
  await params.repo.writeAgentToolCall(params.uid, call.id, nextCall);
  try {
    const memoryItems = buildAgentUndoMemoryItems({
      uid: params.uid,
      call: nextCall,
      output: applied.output,
    });
    if (memoryItems.length > 0) {
      await params.repo.upsertAssistantMemoryItems(params.uid, memoryItems);
    }
  } catch {
    // Undo has already been applied; memory synthesis should not roll it back.
  }
  return {
    status: "applied",
    call: nextCall,
    output: applied.output,
    updatedSurfaces: applied.updatedSurfaces,
  };
}
