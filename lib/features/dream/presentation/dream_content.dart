import 'package:flutter/material.dart';

class DreamEntryData {
  const DreamEntryData({
    required this.title,
    required this.summary,
    required this.timeLabel,
    required this.moodLabel,
    required this.tags,
    required this.icon,
  });

  final String title;
  final String summary;
  final String timeLabel;
  final String moodLabel;
  final List<String> tags;
  final IconData icon;
}

class DreamPatternData {
  const DreamPatternData({
    required this.label,
    required this.value,
    required this.colorSeed,
  });

  final String label;
  final double value;
  final int colorSeed;
}

class DreamInsightData {
  const DreamInsightData({
    required this.title,
    required this.summary,
    required this.points,
    required this.icon,
  });

  final String title;
  final String summary;
  final List<String> points;
  final IconData icon;
}

class DreamHighlightData {
  const DreamHighlightData({
    required this.title,
    required this.description,
    required this.chipLabel,
  });

  final String title;
  final String description;
  final String chipLabel;
}

abstract final class DreamContent {
  static const DreamHighlightData highlight = DreamHighlightData(
    title: '这一周的梦开始有规律了',
    description: '更常出现飞行、找路和熟悉的人，说明内容可以先聚焦在“记录 + 自我映射”。',
    chipLabel: '本周已记录 7 次',
  );

  static const List<DreamPatternData> patterns = <DreamPatternData>[
    DreamPatternData(label: '飞行', value: 0.62, colorSeed: 0),
    DreamPatternData(label: '治愈', value: 0.88, colorSeed: 1),
    DreamPatternData(label: '抽象', value: 0.34, colorSeed: 2),
    DreamPatternData(label: '强烈', value: 0.22, colorSeed: 3),
  ];

  static const List<DreamEntryData> entries = <DreamEntryData>[
    DreamEntryData(
      title: '漂浮柑橘岛',
      summary: '我在一片会发光的柑橘森林上空飘着，风里是柠檬和薰衣草的味道。',
      timeLabel: '昨天 07:15',
      moodLabel: '轻松',
      tags: <String>['飞行', '明亮', '熟悉感'],
      icon: Icons.wb_sunny_rounded,
    ),
    DreamEntryData(
      title: '水下图书馆',
      summary: '像是在找一本会发光的书，翻页的时候周围有很安静的水声。',
      timeLabel: '周二 06:40',
      moodLabel: '平静',
      tags: <String>['水', '寻找', '安静'],
      icon: Icons.water_drop_rounded,
    ),
    DreamEntryData(
      title: '会说话的风',
      summary: '风一直提醒我去找一把银色钥匙，醒来时还记得那种急切感。',
      timeLabel: '周一 05:58',
      moodLabel: '紧张',
      tags: <String>['声音', '任务', '追赶'],
      icon: Icons.air_rounded,
    ),
  ];

  static const List<DreamInsightData> insights = <DreamInsightData>[
    DreamInsightData(
      title: '高频意象',
      summary:
          '近 3 条梦境里，出现频率最高的是“寻找 / 任务感”与“流动环境意象”。其中“寻找目标、物品或答案”出现在 2 条记录中，约占 67%；“风、水、漂浮等流动场景”出现在 3 条记录中，约占 100%；明确出现“飞行 / 飘浮”意象的有 1 条，约占 33%。整体来看，最近的梦更偏向带有方向感、探索感和环境感受的内容。',
      points: <String>[
        '“水下图书馆”里有“找一本会发光的书”，对应寻找意象。',
        '“会说话的风”里有“去找一把银色钥匙”，同样带有任务导向。',
        '“漂浮柑橘岛”“水下图书馆”“会说话的风”分别对应漂浮、水域、风声，说明流动环境在近期梦里非常稳定地出现。',
      ],
      icon: Icons.explore_rounded,
    ),
    DreamInsightData(
      title: '情绪映射',
      summary:
          '梦境整体情绪以平静、好奇为主，夹杂少量紧张和催促感。当前记录里没有明显的恐惧、惊吓或失控内容，更像是在放松背景中，偶尔出现“需要完成某件事”的轻度心理负担。综合判断，最近压力水平更接近轻中度，主要来自待完成事项，而不是强烈压迫感。',
      points: <String>[
        '平静线索来自“飘着”“柠檬和薰衣草的味道”“很安静的水声”等描述，说明梦里仍有安全感和舒缓感官体验。',
        '好奇感来自“会发光的书”“银色钥匙”这类带探索意味的对象，说明注意力更多放在寻找和理解，而不是逃避。',
        '紧张感主要集中在“提醒我去找”“还记得那种急切感”这类句子，说明最近可能存在未完成任务或需要回应的现实压力。',
      ],
      icon: Icons.favorite_rounded,
    ),
    DreamInsightData(
      title: '调节建议',
      summary:
          '目前状态不算高压，更像是轻微累积的任务紧绷感。建议重点放在“白天减压 + 睡前降速”两件事上，帮助大脑把未完成事项和睡眠时间分开，让平静型梦境继续占主导。',
      points: <String>[
        '如果这几天觉得事情多、脑子停不下来，晚饭后做 20 到 30 分钟慢跑、快走或拉伸，比高强度运动更适合当前状态。',
        '睡前把第二天要做的 3 件事写下来，尤其是还没完成的小任务，能减少梦里反复出现“寻找”“赶着完成”的内容。',
        '继续保持你现在比较稳定的睡眠氛围，比如轻音乐、柔和灯光和醒来立刻记录梦境；如果最近本身就很轻松，这些习惯只需要继续保持即可。',
      ],
      icon: Icons.self_improvement_rounded,
    ),
  ];
}
