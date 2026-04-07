import { AssistantContext, InterferenceFactor } from "../shared/types";

function clampScore(score: number): number {
  return Math.max(0, Math.min(100, Math.round(score)));
}

export function rankInterferenceFactors(context: AssistantContext): InterferenceFactor[] {
  const averageAwakenings =
    context.recentSessions.length === 0
      ? 0
      : context.recentSessions.reduce(
          (sum, item) => sum + item.awakeningsCount,
          0,
        ) / context.recentSessions.length;
  const selectedMood = (context.settings.selectedNightMood ?? "").toLowerCase();
  const moodPenalty =
    selectedMood === "sad" ? 22 : selectedMood === "calm" ? 8 : 12;
  const averageSleepHours =
    context.recentSessions
      .filter((item) => typeof item.totalSleepHours === "number")
      .reduce((sum, item, _, list) => {
        return sum + ((item.totalSleepHours ?? 0) / Math.max(list.length, 1));
      }, 0) || 0;
  const goalGap = Math.max(0, context.settings.sleepGoalHours - averageSleepHours);
  const hasRecentDreamEmotion = context.recentDreams.some((item) => {
    const emotion = (item.emotionLabel ?? "").toLowerCase();
    return emotion.includes("stress") || emotion.includes("anx");
  });

  return [
    {
      key: "noise",
      label: "Dorm noise",
      score: clampScore(context.dorm.noiseDb * 2 + averageAwakenings * 8),
      evidence: `Dorm noise is around ${context.dorm.noiseDb} dB and recent nights averaged ${averageAwakenings.toFixed(1)} awakenings.`,
      sourceRefs: ["dorm.noiseDb", "sleep_sessions.awakenings"],
    },
    {
      key: "routine",
      label: "Routine drift",
      score: clampScore(goalGap * 18 + averageAwakenings * 10),
      evidence: `Recent sleep is about ${averageSleepHours.toFixed(1)} h against a ${context.settings.sleepGoalHours.toFixed(1)} h goal.`,
      sourceRefs: ["user_settings.sleepGoalHours", "sleep_sessions.summary"],
    },
    {
      key: "emotion",
      label: "Emotional load",
      score: clampScore(moodPenalty + (hasRecentDreamEmotion ? 18 : 6)),
      evidence: `Night mood is ${context.settings.selectedNightMood || "unset"} and dream notes suggest ${hasRecentDreamEmotion ? "higher" : "manageable"} emotional carry-over.`,
      sourceRefs: ["user_settings.selectedNightMood", "dream_entries.emotionLabel"],
    },
  ].sort((a, b) => b.score - a.score);
}
