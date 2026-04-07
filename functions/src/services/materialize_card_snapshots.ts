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
    for (const factor of userState.tonightPlan.topFactors) {
      cards.push({
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
      });
    }
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
  return {
    surfaceId: "home_pre_sleep",
    version: buildVersion(),
    generatedAt: new Date().toISOString(),
    headline: `${context.user.displayName} 的今晚计划`,
    cards,
    sourceRefs: [
      "user_state.tonightPlan",
      "dorms",
      "sleep_sessions",
      "dream_entries",
    ],
  };
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
        title: userState.activeSessionId
          ? "睡眠模式已开启"
          : "尚未进入睡眠模式",
        subtitle: "AI 助手会持续记录今晚的关键状态，方便明早做反馈回顾。",
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
