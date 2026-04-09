import test from "node:test";
import assert from "node:assert/strict";
import {
  handleAssistantReply,
  handleDreamEntryChange,
  handleSleepSessionChange,
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
      preferredTrackTitle: "Deep Ocean Waves",
      smartSuggestionsEnabled: true,
      selectedNightMood: "calm",
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
    recentSessions: [
      {
        id: "session-1",
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
  const assistantRuns: Array<{ uid: string; runId: string; run: AssistantRunDoc }> = [];
  const dreamAnalyses: Array<{ entryId: string; analysis: DreamAnalysis }> = [];
  const notifications: Array<{ uid: string; notificationId: string; payload: Record<string, unknown> }> = [];
  const threadSummaries: Array<Record<string, unknown>> = [];
  const memoryItems: Array<Record<string, unknown>> = [];

  return {
    repo: {
      buildAssistantContext: async () => context,
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
    },
    userStates,
    cardSnapshots,
    assistantRuns,
    dreamAnalyses,
    notifications,
    threadSummaries,
    memoryItems,
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
    "宿舍太吵了，今晚怎么办？",
    "thread-1",
  );

  assert.equal(result.intent, "noise_issue");
  assert.equal(fake.userStates.length, 1);
  assert.ok(fake.cardSnapshots.length >= 1);
  assert.equal(fake.assistantRuns.length, 1);
  assert.equal(fake.assistantRuns[0]?.run.sourceMode, "fallbackSuccess");
  assert.equal(fake.threadSummaries.length, 1);
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
    "我梦到自己一直在追赶考试时间。",
  );

  assert.equal(analysis.dominantEmotion, "不安");
  assert.equal(fake.dreamAnalyses.length, 1);
  assert.ok(fake.cardSnapshots.length >= 2);
});
