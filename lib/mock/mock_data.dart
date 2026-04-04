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
          title: '今晚先试 15 分钟深呼吸音频',
          summary: '根据近几晚的入睡时长，你对温和的节律放松更容易起效。',
          tag: 'Suggested',
        ),
        AssistantSuggestion(
          title: '把手机提醒延后到明早',
          summary: '当前噪声不高，屏幕刺激更可能是主要干扰因子。',
          tag: 'Focus',
        ),
      ];

  static const List<ConversationPlaceholder> conversation =
      <ConversationPlaceholder>[
        ConversationPlaceholder(
          fromAssistant: true,
          message: '我已经整理好你最近几晚的干扰模式，可以先从声音和屏幕光开始。',
        ),
        ConversationPlaceholder(
          fromAssistant: false,
          message: '今晚室友可能会晚回来，有什么更稳妥的应对建议吗？',
        ),
        ConversationPlaceholder(
          fromAssistant: true,
          message: '可以先准备耳塞，并把睡眠模式切到“轻干预 + 噪声优先”。',
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
          description: '任务页会承接今晚的试验策略，让用户快速执行并记录完成度。',
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
          description: '更完整的周期报告会在这里聚合试验结果、得分变化和长期规律。',
          icon: Icons.ssid_chart_rounded,
          primaryActionLabel: '报告页待补全',
          supportingPoints: <String>['阶段性趋势对比', '试验有效率统计', '个体化洞察摘要'],
        ),
      };
}
