"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const node_test_1 = __importDefault(require("node:test"));
const strict_1 = __importDefault(require("node:assert/strict"));
const assistant_orchestrator_1 = require("../src/orchestrators/assistant_orchestrator");
const ai_provider_1 = require("../src/providers/ai_provider");
function buildContext() {
    return {
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
function createFakeRepo(context) {
    const userStates = [];
    const cardSnapshots = [];
    const assistantRuns = [];
    const dreamAnalyses = [];
    const notifications = [];
    return {
        repo: {
            buildAssistantContext: async () => context,
            writeUserState: async (uid, patch) => {
                userStates.push({ uid, patch });
            },
            writeCardSnapshot: async (uid, snapshot) => {
                cardSnapshots.push({ uid, snapshot });
            },
            writeAssistantRun: async (uid, runId, run) => {
                assistantRuns.push({ uid, runId, run });
            },
            setDreamAnalysis: async (entryId, analysis) => {
                dreamAnalyses.push({ entryId, analysis });
            },
            upsertNotification: async (uid, notificationId, payload) => {
                notifications.push({ uid, notificationId, payload });
            },
        },
        userStates,
        cardSnapshots,
        assistantRuns,
        dreamAnalyses,
        notifications,
    };
}
(0, node_test_1.default)("prepareTonightPlan writes user_state, card snapshots, and assistant run", async () => {
    const context = buildContext();
    const fake = createFakeRepo(context);
    const provider = new ai_provider_1.DeterministicAIProvider();
    const result = await (0, assistant_orchestrator_1.prepareTonightPlan)(fake.repo, provider, "user-1", "test");
    strict_1.default.ok(result.userState.tonightPlan);
    strict_1.default.equal(fake.userStates.length, 1);
    strict_1.default.equal(fake.cardSnapshots.length, 2);
    strict_1.default.equal(fake.assistantRuns.length, 1);
});
(0, node_test_1.default)("assistantReply refreshes state and records the run", async () => {
    const context = buildContext();
    const fake = createFakeRepo(context);
    const provider = new ai_provider_1.DeterministicAIProvider();
    const result = await (0, assistant_orchestrator_1.handleAssistantReply)(fake.repo, provider, "user-1", "宿舍太吵了，今晚怎么办？", "thread-1");
    strict_1.default.equal(result.intent, "noise_issue");
    strict_1.default.equal(fake.userStates.length, 1);
    strict_1.default.ok(fake.cardSnapshots.length >= 1);
    strict_1.default.equal(fake.assistantRuns.length, 1);
});
(0, node_test_1.default)("sleep session transition to awaitingFeedback creates reminder notification", async () => {
    const context = buildContext();
    const fake = createFakeRepo(context);
    const provider = new ai_provider_1.DeterministicAIProvider();
    await (0, assistant_orchestrator_1.handleSleepSessionChange)(fake.repo, provider, "user-1", "session-2", "active", "awaitingFeedback");
    strict_1.default.equal(fake.notifications.length, 1);
    strict_1.default.equal(fake.notifications[0]?.notificationId, "feedback-session-2");
});
(0, node_test_1.default)("dream entry change persists ai analysis and updates cards", async () => {
    const context = buildContext();
    const fake = createFakeRepo(context);
    const provider = new ai_provider_1.DeterministicAIProvider();
    const analysis = await (0, assistant_orchestrator_1.handleDreamEntryChange)(fake.repo, provider, "user-1", "dream-2", "我梦到自己一直在追赶考试时间。");
    strict_1.default.equal(analysis.dominantEmotion, "uneasy");
    strict_1.default.equal(fake.dreamAnalyses.length, 1);
    strict_1.default.ok(fake.cardSnapshots.length >= 2);
});
