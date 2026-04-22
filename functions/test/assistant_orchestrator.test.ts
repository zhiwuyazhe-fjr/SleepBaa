import test from "node:test";
import assert from "node:assert/strict";
import {
  finalizeAssistantReplyPostprocess,
  handleAssistantReply,
  handleDreamEntryChange,
  handleSleepSessionChange,
  prepareAssistantReplyPhase,
  prepareTonightPlan,
} from "../src/orchestrators/assistant_orchestrator";
import { DeterministicAIProvider } from "../src/providers/ai_provider";
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
      assistantName: "Xiaomian",
      identityPrompt: "You are a gentle sleep companion assistant.",
      tone: "gentle, steady",
      relationshipRole: "sleep companion",
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
      activeMemberCount: 1,
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
    recentSessions: [
      {
        id: "session-1",
        sleepDayKey: "2026-04-13",
        status: "completed",
        awakeningsCount: 1,
        totalSleepHours: 6.8,
        sleepQuality: 74,
        restedLevel: 72,
        note: "Mostly okay",
      },
    ],
    recentDreams: [
      {
        id: "dream-1",
        title: "Ocean",
        body: "I was walking by water.",
        emotionLabel: "reflective",
      },
    ],
    recentMessages: [],
    userState: null,
  };
}

function createFakeRepo(context: AssistantContext) {
  const userStates: Array<{ uid: string; patch: Partial<UserStateDoc> }> = [];
  const cardSnapshots: Array<{ uid: string; snapshot: CardSnapshotDoc }> = [];
  const assistantRuns: Array<{
    uid: string;
    runId: string;
    run: AssistantRunDoc;
  }> = [];
  const dreamAnalyses: Array<{ entryId: string; analysis: DreamAnalysis }> = [];
  const notifications: Array<{
    uid: string;
    notificationId: string;
    payload: Record<string, unknown>;
  }> = [];
  const threadSummaries: Array<Record<string, unknown>> = [];
  const memoryItems: Array<Record<string, unknown>> = [];
  const contextBuildCalls: Array<{
    uid: string;
    threadId?: string;
    options?: Record<string, unknown>;
  }> = [];
  let committedTurnId = "turn-1";

  return {
    repo: {
      buildAssistantContext: async (
        uid: string,
        threadId?: string,
        options?: Record<string, unknown>,
      ) => {
        contextBuildCalls.push({ uid, threadId, options });
        return context;
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
      setDreamAnalysis: async (entryId: string, analysis: DreamAnalysis) => {
        dreamAnalyses.push({ entryId, analysis });
      },
      upsertNotification: async (
        uid: string,
        notificationId: string,
        payload: Record<string, unknown>,
      ) => {
        notifications.push({ uid, notificationId, payload });
      },
      writeAssistantThreadSummary: async (
        uid: string,
        summary: Record<string, unknown>,
      ) => {
        threadSummaries.push({ uid, ...summary });
      },
      upsertAssistantMemoryItems: async (
        uid: string,
        items: Array<Record<string, unknown>>,
      ) => {
        memoryItems.push(...items.map((item) => ({ uid, ...item })));
      },
      isAssistantThreadCommittedTurn: async (params: { turnId: string }) =>
        params.turnId === committedTurnId,
    },
    userStates,
    cardSnapshots,
    assistantRuns,
    dreamAnalyses,
    notifications,
    threadSummaries,
    memoryItems,
    contextBuildCalls,
    setCommittedTurnId: (next: string) => {
      committedTurnId = next;
    },
  };
}

test("prepareTonightPlan writes user_state, card snapshots, and assistant run", async () => {
  const context = buildContext();
  const fake = createFakeRepo(context);
  const provider = new DeterministicAIProvider();

  const result = await prepareTonightPlan(
    fake.repo as never,
    provider,
    "user-1",
    "test",
  );

  assert.ok(result.userState.tonightPlan);
  assert.equal(fake.userStates.length, 1);
  assert.equal(fake.cardSnapshots.length, 2);
  assert.equal(fake.assistantRuns.length, 1);
  assert.equal(fake.assistantRuns[0]?.run.sourceMode, "fallbackSuccess");
});

test("assistantReply refreshes state and records the run", async () => {
  const context = buildContext();
  const fake = createFakeRepo(context);
  const provider = new DeterministicAIProvider();

  const result = await handleAssistantReply(
    fake.repo as never,
    provider,
    "user-1",
    "roommate is loud tonight",
    "thread-1",
  );

  assert.equal(result.intent, "noise_issue");
  assert.equal(fake.userStates.length, 1);
  assert.ok(fake.cardSnapshots.length >= 1);
  assert.equal(fake.assistantRuns.length, 1);
  assert.equal(fake.assistantRuns[0]?.run.sourceMode, "fallbackSuccess");
  assert.equal(fake.threadSummaries.length, 1);
});

test("assistantReply greeting still uses reply lite context and skips insight", async () => {
  const context = buildContext();
  const fake = createFakeRepo(context);
  const provider = new DeterministicAIProvider();

  const result = await handleAssistantReply(
    fake.repo as never,
    provider,
    "user-1",
    "hi",
    "thread-1",
  );

  assert.equal(result.intent, "general_support");
  assert.equal(fake.contextBuildCalls.length, 1);
  assert.deepEqual(fake.contextBuildCalls[0], {
    uid: "user-1",
    threadId: "thread-1",
    options: {
      profile: "reply_lite",
      recentSessionCount: 1,
      recentDreamCount: 0,
      messageCount: 4,
      memoryLimit: 2,
      memoryQuery: "hi",
    },
  });
  assert.equal(fake.memoryItems.length, 0);
  assert.equal(fake.threadSummaries.length, 1);
  assert.equal(fake.assistantRuns.length, 1);
  assert.equal(fake.assistantRuns[0]?.run.fastPath, false);
  assert.ok((fake.assistantRuns[0]?.run.replyContextMs ?? 0) >= 0);
});

test("assistantReply reply lite path avoids insight for low-signal prompts", async () => {
  const context = buildContext();
  const fake = createFakeRepo(context);
  const provider = new DeterministicAIProvider();

  const result = await handleAssistantReply(
    fake.repo as never,
    provider,
    "user-1",
    "stay with me a bit",
    "thread-1",
  );

  assert.equal(result.intent, "general_support");
  assert.equal(fake.contextBuildCalls.length, 1);
  assert.deepEqual(fake.contextBuildCalls[0], {
    uid: "user-1",
    threadId: "thread-1",
    options: {
      profile: "reply_lite",
      recentSessionCount: 1,
      recentDreamCount: 0,
      messageCount: 4,
      memoryLimit: 2,
      memoryQuery: "stay with me a bit",
    },
  });
  assert.equal(fake.cardSnapshots.length, 0);
  assert.equal(fake.memoryItems.length, 0);
  assert.equal(fake.threadSummaries.length, 1);
});

test("assistantReply uses a lightweight reply context before richer insight context", async () => {
  const context = buildContext();
  const fake = createFakeRepo(context);
  const provider = new DeterministicAIProvider();

  await handleAssistantReply(
    fake.repo as never,
    provider,
    "user-1",
    "roommate is loud tonight",
    "thread-1",
  );

  assert.equal(fake.contextBuildCalls.length, 2);
  assert.deepEqual(fake.contextBuildCalls[0], {
    uid: "user-1",
    threadId: "thread-1",
    options: {
      profile: "reply_lite",
      recentSessionCount: 1,
      recentDreamCount: 0,
      messageCount: 4,
      memoryLimit: 2,
      memoryQuery: "roommate is loud tonight",
    },
  });
  assert.deepEqual(fake.contextBuildCalls[1], {
    uid: "user-1",
    threadId: "thread-1",
    options: {
      profile: "insight_full",
      recentSessionCount: 5,
      recentDreamCount: 3,
      messageCount: 8,
      memoryLimit: 6,
      memoryQuery: "roommate is loud tonight",
    },
  });
});

test("assistant reply postprocess skips projected writes for stale committed turns", async () => {
  const context = buildContext();
  const fake = createFakeRepo(context);
  const provider = new DeterministicAIProvider();

  const phase = await prepareAssistantReplyPhase({
    repo: fake.repo as never,
    provider,
    uid: "user-1",
    prompt: "roommate is loud tonight",
    threadId: "thread-1",
  });

  fake.setCommittedTurnId("turn-2");

  const result = await finalizeAssistantReplyPostprocess({
    repo: fake.repo as never,
    provider,
    uid: "user-1",
    turnId: "turn-1",
    phase,
  });

  assert.equal(result.skippedProjection, true);
  assert.deepEqual(result.updatedSurfaces, []);
  assert.equal(fake.userStates.length, 0);
  assert.equal(fake.cardSnapshots.length, 0);
  assert.equal(fake.threadSummaries.length, 1);
  assert.ok(fake.memoryItems.length >= 1);
});

test("sleep session transition to awaitingFeedback creates reminder notification", async () => {
  const context = buildContext();
  const fake = createFakeRepo(context);
  const provider = new DeterministicAIProvider();

  await handleSleepSessionChange(
    fake.repo as never,
    provider,
    "user-1",
    "session-2",
    "active",
    "awaitingFeedback",
  );

  assert.equal(fake.notifications.length, 1);
  assert.equal(fake.notifications[0]?.notificationId, "feedback-session-2");
});

test("dream entry change persists ai analysis and updates cards", async () => {
  const context = buildContext();
  const fake = createFakeRepo(context);
  const provider = new DeterministicAIProvider();

  const analysis = await handleDreamEntryChange(
    fake.repo as never,
    provider,
    "user-1",
    "dream-2",
    "I kept running late to an exam.",
  );

  assert.equal(analysis.dominantEmotion, "不安");
  assert.equal(fake.dreamAnalyses.length, 1);
  assert.ok(fake.cardSnapshots.length >= 2);
});
