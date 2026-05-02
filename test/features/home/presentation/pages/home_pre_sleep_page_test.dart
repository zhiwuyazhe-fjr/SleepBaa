import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/features/home/presentation/pages/home_pre_sleep_page.dart';

void main() {
  test(
    'home action section shows the first three generated recommendations',
    () {
      final List<NightRecommendation> generated = <NightRecommendation>[
        _recommendation('earplug'),
        _recommendation('dorm-quiet'),
        _recommendation('audio-ocean', type: RecommendationType.audio),
        _recommendation('thought-clean'),
      ];

      final List<NightRecommendation> displayed =
          displayedTonightRecommendations(generated);

      expect(displayed.map((item) => item.id), <String>[
        'earplug',
        'dorm-quiet',
        'audio-ocean',
      ]);
    },
  );

  test('home action section no longer injects thought-clean by default', () {
    final List<NightRecommendation> generated = <NightRecommendation>[
      _recommendation('earplug'),
      _recommendation('dorm-quiet'),
      _recommendation('audio-ocean', type: RecommendationType.audio),
    ];

    final List<NightRecommendation> displayed = displayedTonightRecommendations(
      generated,
    );

    expect(displayed.map((item) => item.id), isNot(contains('thought-clean')));
  });
}

NightRecommendation _recommendation(
  String id, {
  RecommendationType type = RecommendationType.quickAction,
}) {
  return NightRecommendation(
    id: id,
    title: id,
    subtitle: 'generated',
    type: type,
    icon: Icons.task_alt_rounded,
    tags: const <String>[],
    executionState: RecommendationExecutionState.idle,
  );
}
