import assert from "node:assert/strict";
import test from "node:test";
import { buildCardSnapshots } from "../src/services/materialize_card_snapshots";
import { AssistantContext, UserStateDoc } from "../src/shared/types";

function buildContext(): AssistantContext {
  return {
    assistantProfile: {
      userId: "user-1",
      assistantName: "灏忕湢",
      identityPrompt: "陪伴式睡眠助手",
      tone: "温和",
      relationshipRole: "睡眠陪伴",
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
    },
    dorm: {
      id: "dorm-204",
      name: "Dorm 204",
      overview: "Quiet enough for sleep.",
      noiseDb: 34,
      lightLabel: "Dim",
      quietLabel: "Stable",
      members: [],
      events: [],
    },
    recentSessions: [
      {
        id: "session-1",
        sleepDayKey: "2026-04-11",
        startedAt: "2026-04-10T23:10:00.000Z",
        status: "completed",
        awakeningsCount: 0,
        totalSleepHours: 7.2,
        sleepQuality: 82,
        restedLevel: 76,
      },
      {
        id: "session-2",
        sleepDayKey: "2026-04-13",
        startedAt: "2026-04-12T23:20:00.000Z",
        status: "completed",
        awakeningsCount: 1,
        totalSleepHours: 6.4,
        sleepQuality: 4,
        restedLevel: 70,
      },
    ],
    recentDreams: [],
    recentMessages: [],
    userState: null,
  };
}

function buildUserState(): UserStateDoc {
  return {
    currentPhase: "home_pre_sleep",
    activeSessionId: null,
    latestThreadId: null,
    latestNightMood: "calm",
    profileSummary: {
      sleepPatternSummary: "Sleep window is getting steadier.",
      highRiskFactors: ["noise"],
      effectiveActions: ["earplugs"],
      dreamTrendSummary: "Dream notes are still sparse.",
      emotionTrendSummary: "Mood is settling down.",
      lastUpdatedAt: "2026-04-12T10:00:00.000Z",
    },
    tonightPlan: null,
    tonightInterference: null,
    feedbackLoop: null,
    sleepCapture: null,
    updatedAt: "2026-04-12T10:00:00.000Z",
  };
}

test("profile report snapshot includes summary and two 7-day trend cards", () => {
  const snapshots = buildCardSnapshots(buildContext(), buildUserState(), [
    "profile_report",
  ]);
  assert.equal(snapshots.length, 1);
  const profileReport = snapshots[0];
  assert.equal(profileReport?.surfaceId, "profile_report");
  const cardTypes = profileReport?.cards.map((card) => card.type) ?? [];
  assert.deepEqual(cardTypes, [
    "sleep_report_summary",
    "sleep_duration_trend",
    "sleep_quality_trend",
  ]);
  const durationTrend = profileReport?.cards.find(
    (card) => card.type === "sleep_duration_trend",
  );
  const qualityTrend = profileReport?.cards.find(
    (card) => card.type === "sleep_quality_trend",
  );
  const durationPoints = (durationTrend?.payload?.points as Array<Record<string, unknown>>) ?? [];
  const qualityPoints = (qualityTrend?.payload?.points as Array<Record<string, unknown>>) ?? [];
  assert.equal(durationPoints.length, 7);
  assert.equal(qualityPoints.length, 7);
  assert.ok(durationPoints.some((point) => point.value === null));
  assert.ok(qualityPoints.some((point) => point.value === 80));
});

test("profile report snapshot ignores pending sessions when building averages and trends", () => {
  const context = buildContext();
  context.recentSessions.push({
    id: "session-pending",
    sleepDayKey: "2026-04-14",
    startedAt: "2026-04-13T23:10:00.000Z",
    status: "awaitingFeedback",
    awakeningsCount: 0,
    totalSleepHours: 9.5,
    sleepQuality: 95,
    restedLevel: 92,
  });

  const snapshots = buildCardSnapshots(context, buildUserState(), [
    "profile_report",
  ]);
  const profileReport = snapshots[0];
  const summaryCard = profileReport?.cards.find(
    (card) => card.type === "sleep_report_summary",
  );
  const payload = (summaryCard?.payload ?? {}) as Record<string, unknown>;
  const durationTrend = profileReport?.cards.find(
    (card) => card.type === "sleep_duration_trend",
  );
  const durationPoints =
    (durationTrend?.payload?.points as Array<Record<string, unknown>>) ?? [];

  assert.ok(
    Math.abs(Number(payload.averageSleepHours) - 6.8) < 1e-9,
    `expected averageSleepHours to stay at 6.8, got ${payload.averageSleepHours}`,
  );
  assert.ok(durationPoints.every((point) => point.value !== 9.5));
});
