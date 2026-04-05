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
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
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
      description: '最近梦里反复出现“飞行”和“找路”，适合继续记录地点和方向感。',
      icon: Icons.explore_rounded,
    ),
    DreamInsightData(
      title: '情绪映射',
      description: '平静梦境通常出现在睡前放下手机后的夜晚，颜色和情绪都更柔和。',
      icon: Icons.favorite_rounded,
    ),
    DreamInsightData(
      title: '入睡线索',
      description: '入睡前听轻音乐的夜晚，更容易记住完整片段，醒来后的表述也更具体。',
      icon: Icons.music_note_rounded,
    ),
  ];

  static const List<String> suggestions = <String>[
    '先记三个关键词，再补完整句子，醒来后更容易保留细节。',
    '映射先看“场景 + 情绪”，不用一次做太多解释。',
    '如果只记得一句话，也可以先收下，后面再补。',
  ];
}
