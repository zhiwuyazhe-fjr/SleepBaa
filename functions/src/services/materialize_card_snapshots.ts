import {
  AssistantContext,
  CardSnapshotCard,
  CardSnapshotDoc,
  SurfaceId,
  UserStateDoc,
} from "../shared/types";

function buildVersion(): string {
  return `v-${Date.now()}`;
}

function dateKeyOf(date: Date): string {
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${date.getFullYear()}-${month}-${day}`;
}

function sleepDayKeyFromDate(date: Date): string {
  if (Number.isNaN(date.getTime())) {
    return "";
  }
  const shifted = new Date(date.getTime() + 4 * 60 * 60 * 1000);
  return dateKeyOf(shifted);
}

function sleepDayDateFromKey(value: string): Date | null {
  if (!value) {
    return null;
  }
  const date = new Date(`${value}T00:00:00`);
  if (Number.isNaN(date.getTime())) {
    return null;
  }
  return date;
}

function weekdayLabelOf(date: Date): string {
  return ["日", "一", "二", "三", "四", "五", "六"][date.getDay()] ?? "日";
}

function buildTrendPoints(
  sessions: AssistantContext["recentSessions"],
  valueOf: (session: AssistantContext["recentSessions"][number]) => number | null | undefined,
): Array<Record<string, unknown>> {
  const today =
    sleepDayDateFromKey(sleepDayKeyFromDate(new Date())) ?? new Date();
  today.setHours(0, 0, 0, 0);
  const timeline = Array.from({ length: 7 }, (_, index) => {
    const day = new Date(today);
    day.setDate(today.getDate() - (6 - index));
    return day;
  });
  const valuesByDateKey = new Map<string, number | null>();
  for (const session of sessions) {
    const sleepDayKey =
      session.sleepDayKey ||
      (session.startedAt ? sleepDayKeyFromDate(new Date(session.startedAt)) : "");
    if (!sleepDayKey) {
      continue;
    }
    valuesByDateKey.set(sleepDayKey, valueOf(session) ?? null);
  }
  return timeline.map((day) => ({
    dateKey: dateKeyOf(day),
    weekdayLabel: weekdayLabelOf(day),
    value: valuesByDateKey.get(dateKeyOf(day)) ?? null,
  }));
}

export function buildCardSnapshots(
  context: AssistantContext,
  userState: UserStateDoc,
  surfaces?: SurfaceId[],
): CardSnapshotDoc[] {
  const requested = surfaces ?? [
    "home_pre_sleep",
    "sleep_mode",
    "morning_feedback",
    "profile_report",
    "assistant_context",
  ];

  return requested.map((surfaceId) => {
    switch (surfaceId) {
      case "home_pre_sleep":
        return buildHomePreSleepSnapshot(context, userState);
      case "sleep_mode":
        return buildSleepModeSnapshot(userState);
      case "morning_feedback":
        return buildMorningFeedbackSnapshot(userState);
      case "profile_report":
        return buildProfileReportSnapshot(context, userState);
      case "assistant_context":
        return buildAssistantContextSnapshot(userState);
    }
  });
}

function buildHomePreSleepSnapshot(
  context: AssistantContext,
  userState: UserStateDoc,
): CardSnapshotDoc {
  const cards: CardSnapshotCard[] = [];
  if (userState.tonightPlan) {
    cards.push({
      id: "coach-summary",
      type: "coach_summary",
      title: "今晚重点",
      subtitle: userState.tonightPlan.coachSummary,
      metric:
        userState.tonightPlan.riskLevel === "high"
          ? "高风险"
          : userState.tonightPlan.riskLevel === "medium"
            ? "中风险"
            : "低风险",
      chipLabel: "AI 计划",
      actionRoute: "/assistant",
      payload: {
        dateKey: userState.tonightPlan.dateKey,
      },
      priority: 0,
    });
    for (const action of userState.tonightPlan.recommendedActions) {
      cards.push({
        id: `action-${action.id}`,
        type: "recommended_action",
        title: action.title,
        subtitle: action.subtitle,
        metric: `优先级 ${action.priority}`,
        chipLabel: action.type === "audio" ? "助眠音频" : "行动建议",
        actionRoute: action.route,
        payload: {
          actionId: action.id,
          reason: action.reason,
          trackId: action.trackId,
          tags: action.tags,
        },
        priority: 200 - action.priority,
      });
    }
  }

  cards.push(...buildInterferenceFactorCards(userState));

  return {
    surfaceId: "home_pre_sleep",
    version: buildVersion(),
    generatedAt: new Date().toISOString(),
    headline: `${context.user.displayName} 的今晚计划`,
    cards,
    sourceRefs: [
      "user_state.tonightPlan",
      "user_state.tonightInterference",
      "dorms",
      "sleep_sessions",
      "dream_entries",
    ],
  };
}

function buildInterferenceFactorCards(userState: UserStateDoc): CardSnapshotCard[] {
  const state = userState.tonightInterference;
  if (!state) {
    return (userState.tonightPlan?.topFactors ?? []).map((factor) => ({
      id: `factor-${factor.key}`,
      type: "interference_factor",
      title: factor.label,
      subtitle: factor.evidence,
      metric: `${factor.score}/100`,
      chipLabel: "干扰因子",
      actionRoute: "/analysis/interference_factors",
      payload: {
        factorKey: factor.key,
        sourceRefs: factor.sourceRefs,
      },
      priority: factor.score,
    }));
  }

  const factors = [
    { key: "noise", value: state.noise },
    { key: "light", value: state.light },
    { key: "phoneUsage", value: state.phoneUsage },
    { key: "emotion", value: state.emotion },
  ];

  return factors.map(({ key, value }) => ({
    id: `factor-${key}`,
    type: "interference_factor",
    title: value.title,
    subtitle: value.detail,
    metric: value.value,
    chipLabel: "干扰因子",
    actionRoute: "/analysis/interference_factors",
    payload: {
      factorKey: key,
      status: value.status,
      source: value.source,
      measuredAt: value.measuredAt ?? null,
    },
    priority: Number(value.score ?? 0),
  }));
}

function buildSleepModeSnapshot(userState: UserStateDoc): CardSnapshotDoc {
  return {
    surfaceId: "sleep_mode",
    version: buildVersion(),
    generatedAt: new Date().toISOString(),
    headline: "睡眠模式进度",
    cards: [
      {
        id: "sleep-mode-status",
        type: "session_status",
        title: userState.activeSessionId ? "睡眠模式已开启" : "尚未进入睡眠模式",
        subtitle:
          "AI 助手会持续记录今晚的关键状态，方便明早做反馈回顾。",
        metric: userState.activeSessionId ? "进行中" : "未开始",
        chipLabel: "睡眠会话",
        actionRoute: "/home/post_sleep",
        payload: {
          activeSessionId: userState.activeSessionId,
        },
        priority: 0,
      },
    ],
    sourceRefs: ["user_state.activeSessionId"],
  };
}

function buildMorningFeedbackSnapshot(
  userState: UserStateDoc,
): CardSnapshotDoc {
  return {
    surfaceId: "morning_feedback",
    version: buildVersion(),
    generatedAt: new Date().toISOString(),
    headline: "晨间反馈",
    cards: [
      {
        id: "feedback-loop",
        type: "feedback_status",
        title: "晨间反馈会持续优化后续建议",
        subtitle:
          userState.feedbackLoop?.lastReviewSummary ??
          "补完晨间反馈后，AI 才能用更完整的证据优化下一晚计划。",
        metric: userState.feedbackLoop ? "已更新" : "待填写",
        chipLabel: "反馈闭环",
        actionRoute: "/feedback/morning",
        payload: {
          feedbackLoop: userState.feedbackLoop,
        },
        priority: 0,
      },
    ],
    sourceRefs: ["user_state.feedbackLoop"],
  };
}

function buildProfileReportSnapshot(
  context: AssistantContext,
  userState: UserStateDoc,
): CardSnapshotDoc {
  const completed = context.recentSessions.filter(
    (item) => typeof item.totalSleepHours === "number",
  );
  const averageSleepHours =
    completed.length === 0
      ? 0
      : completed.reduce((sum, item) => sum + (item.totalSleepHours ?? 0), 0) /
        completed.length;
  const averageSleepQuality =
    completed.length === 0
      ? 0
      : completed.reduce((sum, item) => sum + (item.sleepQuality ?? 0), 0) /
        completed.length;
  const averageRestedLevel =
    completed.length === 0
      ? 0
      : completed.reduce((sum, item) => sum + (item.restedLevel ?? 0), 0) /
        completed.length;
  const calmNights = context.recentSessions.filter(
    (item) => item.awakeningsCount === 0,
  ).length;
  const payload = {
    averageSleepHours,
    averageSleepQuality,
    averageRestedLevel,
    calmNights,
    dreamEntriesCount: context.recentDreams.length,
    highlights: [
      userState.profileSummary.sleepPatternSummary,
      userState.profileSummary.dreamTrendSummary,
      userState.profileSummary.emotionTrendSummary,
    ],
  };
  const durationTrendPoints = buildTrendPoints(
    context.recentSessions,
    (session) =>
      typeof session.totalSleepHours === "number" ? session.totalSleepHours : null,
  );
  const qualityTrendPoints = buildTrendPoints(
    context.recentSessions,
    (session) => {
      if (typeof session.sleepQuality !== "number") {
        return null;
      }
      return session.sleepQuality <= 5
        ? session.sleepQuality * 20
        : session.sleepQuality;
    },
  );
  return {
    surfaceId: "profile_report",
    version: buildVersion(),
    generatedAt: new Date().toISOString(),
    headline: "本周睡眠快照",
    cards: [
      {
        id: "sleep-report-summary",
        type: "sleep_report_summary",
        title: "本周睡眠快照",
        subtitle: userState.profileSummary.sleepPatternSummary,
        metric: `${averageSleepHours.toFixed(1)} 小时`,
        chipLabel: "画像报告",
        actionRoute: "/profile/report",
        payload,
        priority: 0,
      },
      {
        id: "sleep-duration-trend",
        type: "sleep_duration_trend",
        title: "七日睡眠时长",
        subtitle: "保留近 7 天睡眠时长趋势，后续按晨间反馈补齐。",
        metric: `${averageSleepHours.toFixed(1)} 小时`,
        chipLabel: "睡眠趋势",
        actionRoute: "/profile",
        payload: {
          metricKey: "sleep_duration",
          unit: "hours",
          points: durationTrendPoints,
        },
        priority: -1,
      },
      {
        id: "sleep-quality-trend",
        type: "sleep_quality_trend",
        title: "七日睡眠质量",
        subtitle: "保留近 7 天睡眠质量趋势，后续按晨间反馈补齐。",
        metric: `${averageSleepQuality.toFixed(1)} 分`,
        chipLabel: "睡眠趋势",
        actionRoute: "/profile",
        payload: {
          metricKey: "sleep_quality",
          unit: "score",
          points: qualityTrendPoints,
        },
        priority: -2,
      },
    ],
    sourceRefs: [
      "sleep_sessions",
      "dream_entries",
      "user_state.profileSummary",
    ],
  };
}

function buildAssistantContextSnapshot(
  userState: UserStateDoc,
): CardSnapshotDoc {
  return {
    surfaceId: "assistant_context",
    version: buildVersion(),
    generatedAt: new Date().toISOString(),
    headline: "助手上下文",
    cards: [
      {
        id: "assistant-context-summary",
        type: "assistant_context",
        title: "陪伴上下文已刷新",
        subtitle:
          userState.tonightPlan?.coachSummary ??
          userState.profileSummary.sleepPatternSummary,
        metric: userState.currentPhase,
        chipLabel: "助手状态",
        actionRoute: "/assistant",
        payload: {
          profileSummary: userState.profileSummary,
          tonightPlan: userState.tonightPlan,
        },
        priority: 0,
      },
    ],
    sourceRefs: ["user_state"],
  };
}
