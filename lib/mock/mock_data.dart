import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/routes.dart';

class AssistantSuggestion {
  const AssistantSuggestion({
    required this.title,
    required this.summary,
    required this.tag,
  });

  final String title;
  final String summary;
  final String tag;
}

class ConversationPlaceholder {
  const ConversationPlaceholder({
    required this.fromAssistant,
    required this.message,
  });

  final bool fromAssistant;
  final String message;
}

class PlaceholderPageMeta {
  const PlaceholderPageMeta({
    required this.title,
    required this.description,
    required this.icon,
    required this.primaryActionLabel,
    required this.supportingPoints,
  });

  final String title;
  final String description;
  final IconData icon;
  final String primaryActionLabel;
  final List<String> supportingPoints;
}

abstract final class MockData {
  static const List<AssistantSuggestion> assistantSuggestions =
      <AssistantSuggestion>[
        AssistantSuggestion(
          title: '本地演示已准备好',
          summary: '无需注册或连接 CloudBase，也可以直接查看首页、宿舍、梦境、报告和助手流程。',
          tag: '演示模式',
        ),
        AssistantSuggestion(
          title: '今晚先试 15 分钟呼吸放松',
          summary: '根据预置的最近几晚睡眠记录，温和、低刺激的睡前流程更容易起效。',
          tag: '优先处理',
        ),
        AssistantSuggestion(
          title: '先选今晚心情',
          summary: '开心、低落、平静会影响主题色、陪伴语和本地建议排序，可在欢迎流程或设置里切换。',
          tag: '心情',
        ),
        AssistantSuggestion(
          title: '回看事记仓库',
          summary: '本地演示已预置几条睡前事记，可查看 AI 整理提要和原文内容。',
          tag: '事记',
        ),
      ];

  static const List<ConversationPlaceholder> conversation =
      <ConversationPlaceholder>[
        ConversationPlaceholder(
          fromAssistant: true,
          message: '这是本地演示对话，我会根据预置的宿舍、睡眠和梦境数据给出建议。',
        ),
        ConversationPlaceholder(
          fromAssistant: false,
          message: '今晚室友可能会晚回来，有没有更稳妥一点的方案？',
        ),
        ConversationPlaceholder(
          fromAssistant: true,
          message: '可以先准备耳塞，再把睡眠模式切到“轻干预 + 噪声优先”。',
        ),
        ConversationPlaceholder(
          fromAssistant: false,
          message: '如果我今天有点低落，建议会不会太多？',
        ),
        ConversationPlaceholder(
          fromAssistant: true,
          message: '不会。低落时会优先给慢呼吸、思绪清理和柔和音频，尽量减少任务感。',
        ),
        ConversationPlaceholder(
          fromAssistant: true,
          message: '你也可以去“我的 / 事记仓库”看看预置记录，那里有 AI 整理提要。',
        ),
      ];

  static const Map<String, PlaceholderPageMeta> placeholderPages =
      <String, PlaceholderPageMeta>{
        AppRoutes.analysisInterferenceFactors: PlaceholderPageMeta(
          title: '干扰因子分析',
          description: '这里会汇总噪声、光线、手机使用与情绪压力对今晚睡眠的影响。',
          icon: Icons.insights_rounded,
          primaryActionLabel: '分析模块待接入',
          supportingPoints: <String>['今晚干扰因子排序', '连续 7 天趋势对比', '可触发的微干预建议'],
        ),
        AppRoutes.interventionTask: PlaceholderPageMeta(
          title: '微干预任务',
          description: '任务页会承接今晚的实验策略，让用户快速执行并记录完成度。',
          icon: Icons.task_alt_rounded,
          primaryActionLabel: '任务流程待补全',
          supportingPoints: <String>['任务目标与预计时长', '执行前准备与提示', '完成后反馈入口'],
        ),
        AppRoutes.dreamDetail: PlaceholderPageMeta(
          title: '梦境详情',
          description: '梦境详情页会呈现单次梦境的标签、情绪强度与睡前因素关联。',
          icon: Icons.auto_stories_rounded,
          primaryActionLabel: '梦境详情待补全',
          supportingPoints: <String>['梦境摘要与关键词', '睡前触发因素', '后续追踪建议'],
        ),
        AppRoutes.dreamJournal: PlaceholderPageMeta(
          title: '梦境日志',
          description: '用于快速记录梦境片段、灵感与醒来后的情绪状态。',
          icon: Icons.menu_book_rounded,
          primaryActionLabel: '梦境日志待补全',
          supportingPoints: <String>['语音或文字捕获', '情绪标签', '梦境回顾列表'],
        ),
        AppRoutes.profileReport: PlaceholderPageMeta(
          title: '睡眠报告',
          description: '更完整的周期报告会在这里聚合实验结果、得分变化和长期规律。',
          icon: Icons.ssid_chart_rounded,
          primaryActionLabel: '报告页待补全',
          supportingPoints: <String>['阶段性趋势对比', '实验有效率统计', '个体化洞察摘要'],
        ),
      };
}
