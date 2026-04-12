import { AssistantContext, InterferenceFactor } from "../shared/types";

function clampScore(score: number): number {
  return Math.max(0, Math.min(100, Math.round(score)));
}

function lightScoreFromLabel(label: string): number {
  switch (label) {
    case "偏暗":
      return 18;
    case "适中":
      return 28;
    case "偏亮":
      return 62;
    case "过亮":
      return 84;
    default:
      return 30;
  }
}

function moodScore(selectedMood?: string | null): number {
  switch ((selectedMood ?? "").toLowerCase()) {
    case "sad":
      return 64;
    case "happy":
      return 24;
    case "calm":
      return 18;
    default:
      return 30;
  }
}

export function rankInterferenceFactors(
  context: AssistantContext,
): InterferenceFactor[] {
  const interference = context.userState?.tonightInterference;
  const recentAwakenings =
    context.recentSessions.length === 0
      ? 0
      : context.recentSessions.reduce(
          (sum, item) => sum + item.awakeningsCount,
          0,
        ) / context.recentSessions.length;

  const noiseScore = clampScore(
    Number(interference?.noise?.score ?? context.dorm.noiseDb * 1.6 + recentAwakenings * 8),
  );
  const lightScore = clampScore(
    Number(
      interference?.light?.score ?? lightScoreFromLabel(context.dorm.lightLabel),
    ),
  );
  const phoneUsageScore = clampScore(
    Number(interference?.phoneUsage?.score ?? 26),
  );
  const emotionScore = clampScore(
    Number(
      interference?.emotion?.score ?? moodScore(context.settings.selectedNightMood),
    ),
  );

  return [
    {
      key: "noise",
      label: "宿舍噪声",
      score: noiseScore,
      evidence:
        interference?.noise?.detail ??
        `当前宿舍噪声约为 ${context.dorm.noiseDb} dB，最近几晚平均醒来 ${recentAwakenings.toFixed(1)} 次。`,
      sourceRefs: ["user_state.tonightInterference.noise", "dorm.noiseDb"],
    },
    {
      key: "light",
      label: "灯光环境",
      score: lightScore,
      evidence:
        interference?.light?.detail ??
        `当前宿舍灯光被记录为“${context.dorm.lightLabel}”，会继续影响身体进入放松节奏的速度。`,
      sourceRefs: ["user_state.tonightInterference.light", "dorm.lightLabel"],
    },
    {
      key: "phone_usage",
      label: "手机使用",
      score: phoneUsageScore,
      evidence:
        interference?.phoneUsage?.detail ??
        "近 1 小时手机使用尚未更新，默认按中等干扰纳入今晚判断。",
      sourceRefs: ["user_state.tonightInterference.phoneUsage"],
    },
    {
      key: "emotion",
      label: "情绪压力",
      score: emotionScore,
      evidence:
        interference?.emotion?.detail ??
        `当前夜晚心情为 ${context.settings.selectedNightMood || "未设置"}，先按较低到中等压力处理。`,
      sourceRefs: ["user_state.tonightInterference.emotion", "user_settings.selectedNightMood"],
    },
  ].sort((a, b) => b.score - a.score);
}
