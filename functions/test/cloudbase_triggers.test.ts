import assert from "node:assert/strict";
import test from "node:test";
import { DeterministicAIProvider } from "../src/providers/ai_provider";
import { processDreamEntryDatabaseEvent } from "../src/triggers/dream_entry";
import { processSleepSessionDatabaseEvent } from "../src/triggers/sleep_session";
import {
  AssistantContext,
  AssistantRunDoc,
  CardSnapshotDoc,
  DreamAnalysis,
  UserStateDoc,
} from "../src/shared/types";

function buildContext(): AssistantContext {
  return {
    assistantProfile: {
      userId: "user-1",
      assistantName: "小眠",
      identityPrompt: "你是一个温和的情绪陪伴助手。",
      tone: "温柔、稳定",
      relationshipRole: "情绪陪伴助手",
      updatedAt: "2026-04-06T10:00:00.000Z",
    },
    user: {
      uid: "user-1",
      displayName: "Test User",
      tagline: "Dorm sleeper",
      role: "Student",
      dormId: "dorm-204",
      avatarUrl: "",
    },
    settings: {
      sleepGoalHours: 7.5,
      bedtimeReminderEnabled: true,
      morningReminderEnabled: true,
      dormAlertsEnabled: true,
      bedtimeReminder: {
        hour: 23,
        minute: 10,
      },
      preferredTrackTitle: "Deep Ocean Waves",
      smartSuggestionsEnabled: true,
      selectedNightMood: "calm",
      homeQuickActionIds: [
        "dreamJournal",
        "profileCalendar",
        "sleepEncyclopedia",
        "thoughtClean",
      ],
    },
    dorm: {
      id: "dorm-204",
      name: "Dorm 204",
      overview: "Quiet enough for sleep.",
      noiseDb: 34,
      lightLabel: "Dim",
      quietLabel: "Stable",
      members: [
        {
          uid: "user-1",
          name: "Test User",
          status: "quiet",
          sleepModeActive: false,
        },
      ],
      events: [],
    },
    recentSessions: [],
    recentDreams: [],
    recentMessages: [],
    userState: null,
  };
}

function createTriggerRepo(context: AssistantContext) {
  const sleepPatches: Array<{ sessionId: string; patch: Record<string, unknown> }> = [];
  const dreamPatches: Array<{ entryId: string; patch: Record<string, unknown> }> = [];
  const userStates: Array<{ uid: string; patch: Partial<UserStateDoc> }> = [];
  const cardSnapshots: Array<{ uid: string; snapshot: CardSnapshotDoc }> = [];
  const dreamAnalyses: Array<{ entryId: string; analysis: DreamAnalysis }> = [];
  const dreamEntries = new Map<string, Record<string, unknown>>();
  const assistantRuns: Array<{ uid: string; runId: string; run: AssistantRunDoc }> = [];
  const notifications: Array<{
    uid: string;
    notificationId: string;
    payload: Record<string, unknown>;
  }> = [];

  return {
    repo: {
      buildAssistantContext: async () => context,
      patchSleepSession: async (sessionId: string, patch: Record<string, unknown>) => {
        sleepPatches.push({ sessionId, patch });
      },
      patchDreamEntry: async (entryId: string, patch: Record<string, unknown>) => {
        dreamPatches.push({ entryId, patch });
      },
      writeUserState: async (uid: string, patch: Partial<UserStateDoc>) => {
        userStates.push({ uid, patch });
      },
      writeCardSnapshot: async (uid: string, snapshot: CardSnapshotDoc) => {
        cardSnapshots.push({ uid, snapshot });
      },
      writeAssistantRun: async (
        uid: string,
        runId: string,
        run: AssistantRunDoc,
      ) => {
        assistantRuns.push({ uid, runId, run });
      },
      getDreamEntry: async (entryId: string) => dreamEntries.get(entryId) ?? null,
      setDreamAnalysis: async (
        entryId: string,
        analysis: DreamAnalysis,
        sourceBodyHash?: string,
      ) => {
        dreamAnalyses.push({ entryId, analysis });
        dreamEntries.set(entryId, {
          id: entryId,
          ai: {
            ...analysis,
            sourceBodyHash,
          },
        });
      },
      upsertNotification: async (
        uid: string,
        notificationId: string,
        payload: Record<string, unknown>,
      ) => {
        notifications.push({ uid, notificationId, payload });
      },
    },
    sleepPatches,
    dreamPatches,
    userStates,
    cardSnapshots,
    dreamAnalyses,
    dreamEntries,
    assistantRuns,
    notifications,
  };
}

test("sleep trigger handles CloudBase insert payload", async () => {
  const fake = createTriggerRepo(buildContext());
  const result = await processSleepSessionDatabaseEvent({
    event: {
      data: {
        docId: "session-1",
        dataType: "insert",
        doc: {
          id: "session-1",
          uid: "user-1",
          status: "active",
          updatedAt: "2026-04-06T10:00:00.000Z",
        },
      },
    },
    repo: fake.repo as never,
    provider: new DeterministicAIProvider(),
  });

  assert.equal(result.skipped, false);
  assert.equal(fake.sleepPatches.length, 1);
  assert.equal(fake.userStates.length, 1);
  assert.equal(fake.cardSnapshots.length, 1);
});

test("sleep trigger ignores delete events", async () => {
  const fake = createTriggerRepo(buildContext());
  const result = await processSleepSessionDatabaseEvent({
    event: {
      data: {
        docId: "session-1",
        dataType: "delete",
        doc: {
          id: "session-1",
          uid: "user-1",
        },
      },
    },
    repo: fake.repo as never,
    provider: new DeterministicAIProvider(),
  });

  assert.equal(result.skipped, true);
  assert.equal(result.reason, "delete_ignored");
  assert.equal(fake.sleepPatches.length, 0);
});

test("sleep trigger skips pure automation updates", async () => {
  const fake = createTriggerRepo(buildContext());
  const result = await processSleepSessionDatabaseEvent({
    event: {
      data: {
        docId: "session-1",
        dataType: "update",
        doc: {
          id: "session-1",
          uid: "user-1",
          status: "active",
          _automation: {
            syncProcessingRequested: false,
          },
        },
        updatedFields: {
          _automation: {
            syncProcessingRequested: false,
          },
        },
      },
    },
    repo: fake.repo as never,
    provider: new DeterministicAIProvider(),
  });

  assert.equal(result.skipped, true);
  assert.equal(result.reason, "internal_update");
});

test("sleep trigger skips while sync processing was recently requested", async () => {
  const fake = createTriggerRepo(buildContext());
  const result = await processSleepSessionDatabaseEvent({
    event: {
      data: {
        docId: "session-1",
        dataType: "update",
        doc: {
          id: "session-1",
          uid: "user-1",
          status: "awaitingFeedback",
          updatedAt: "2026-04-06T10:00:05.000Z",
          _automation: {
            origin: "app-api",
            syncProcessingRequested: true,
            syncRequestedAt: "2026-04-06T10:00:00.000Z",
            lastHandledStatus: "active",
          },
        },
        updatedFields: {
          status: "awaitingFeedback",
        },
      },
    },
    repo: fake.repo as never,
    provider: new DeterministicAIProvider(),
    nowMs: Date.parse("2026-04-06T10:00:30.000Z"),
  });

  assert.equal(result.skipped, true);
  assert.equal(result.reason, "sync_processing_requested");
  assert.equal(fake.notifications.length, 0);
});

test("sleep trigger processes fallback updates after the sync window expires", async () => {
  const fake = createTriggerRepo(buildContext());
  const result = await processSleepSessionDatabaseEvent({
    event: {
      data: {
        docId: "session-1",
        dataType: "update",
        doc: {
          id: "session-1",
          uid: "user-1",
          status: "awaitingFeedback",
          updatedAt: "2026-04-06T10:02:30.000Z",
          _automation: {
            origin: "manual",
            syncProcessingRequested: true,
            syncRequestedAt: "2026-04-06T10:00:00.000Z",
            lastHandledStatus: "active",
          },
        },
        updatedFields: {
          status: "awaitingFeedback",
        },
      },
    },
    repo: fake.repo as never,
    provider: new DeterministicAIProvider(),
    nowMs: Date.parse("2026-04-06T10:02:30.000Z"),
  });

  assert.equal(result.skipped, false);
  assert.equal(fake.notifications.length, 1);
  assert.equal(fake.sleepPatches.length, 1);
});

test("dream trigger handles CloudBase insert payload", async () => {
  const fake = createTriggerRepo(buildContext());
  const result = await processDreamEntryDatabaseEvent({
    event: {
      data: {
        docId: "dream-1",
        dataType: "insert",
        doc: {
          id: "dream-1",
          userId: "user-1",
          body: "I kept running to an exam room.",
          updatedAt: "2026-04-06T11:00:00.000Z",
        },
      },
    },
    repo: fake.repo as never,
    provider: new DeterministicAIProvider(),
  });

  assert.equal(result.skipped, false);
  assert.equal(fake.dreamAnalyses.length, 1);
  assert.equal(fake.dreamPatches.length, 1);
});

test("dream trigger skips pure ai updates", async () => {
  const fake = createTriggerRepo(buildContext());
  const result = await processDreamEntryDatabaseEvent({
    event: {
      data: {
        docId: "dream-1",
        dataType: "update",
        doc: {
          id: "dream-1",
          userId: "user-1",
          body: "I kept running to an exam room.",
          ai: {
            summary: "Existing analysis",
          },
        },
        updatedFields: {
          ai: {
            summary: "Existing analysis",
          },
        },
      },
    },
    repo: fake.repo as never,
    provider: new DeterministicAIProvider(),
  });

  assert.equal(result.skipped, true);
  assert.equal(result.reason, "internal_update");
});

test("dream trigger skips during recent sync processing and runs again after timeout", async () => {
  const fake = createTriggerRepo(buildContext());
  const provider = new DeterministicAIProvider();
  const recent = await processDreamEntryDatabaseEvent({
    event: {
      data: {
        docId: "dream-2",
        dataType: "update",
        doc: {
          id: "dream-2",
          userId: "user-1",
          body: "I was floating on calm water.",
          updatedAt: "2026-04-06T11:00:05.000Z",
          _automation: {
            origin: "app-api",
            syncProcessingRequested: true,
            syncRequestedAt: "2026-04-06T11:00:00.000Z",
          },
        },
        updatedFields: {
          body: "I was floating on calm water.",
        },
      },
    },
    repo: fake.repo as never,
    provider,
    nowMs: Date.parse("2026-04-06T11:00:20.000Z"),
  });
  const expired = await processDreamEntryDatabaseEvent({
    event: {
      data: {
        docId: "dream-2",
        dataType: "update",
        doc: {
          id: "dream-2",
          userId: "user-1",
          body: "I was floating on calm water.",
          updatedAt: "2026-04-06T11:02:20.000Z",
          _automation: {
            origin: "manual",
            syncProcessingRequested: true,
            syncRequestedAt: "2026-04-06T11:00:00.000Z",
          },
        },
        updatedFields: {
          body: "I was floating on calm water.",
        },
      },
    },
    repo: fake.repo as never,
    provider,
    nowMs: Date.parse("2026-04-06T11:02:20.000Z"),
  });

  assert.equal(recent.skipped, true);
  assert.equal(recent.reason, "sync_processing_requested");
  assert.equal(expired.skipped, false);
  assert.equal(fake.dreamAnalyses.length, 1);
});
