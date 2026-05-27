import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/app/theme/app_semantic_colors.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/widgets/app_card.dart';
import 'package:sleep_dorm_app/core/widgets/home_metric_card.dart';
import 'package:sleep_dorm_app/core/widgets/quick_action_icon_button.dart';
import 'package:sleep_dorm_app/features/home/presentation/widgets/home_widgets.dart';

void main() {
  testWidgets('sleep risk card uses semantic hero gradient tokens', (
    WidgetTester tester,
  ) async {
    final NightMoodPalette palette = NightMoodPalette.fromMood(null);
    final AppSemanticColors tokens = AppSemanticColors.light(palette).copyWith(
      heroStart: const Color(0xFFE7BFA8),
      heroMid: const Color(0xFFE9D8C9),
      heroEnd: const Color(0xFF8E6C5B),
      accentDeep: const Color(0xFF5E5149),
    );

    await tester.pumpWidget(
      _wrap(
        const SleepRiskCard(riskLabel: '偏低', primaryValue: '35 dB'),
        tokens: tokens,
      ),
    );

    final Container hero = tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(SleepRiskCard),
            matching: find.byType(Container),
          ),
        )
        .firstWhere((Container container) {
          final Decoration? decoration = container.decoration;
          return decoration is BoxDecoration && decoration.gradient != null;
        });
    final BoxDecoration decoration = hero.decoration! as BoxDecoration;
    final LinearGradient gradient = decoration.gradient! as LinearGradient;
    expect(gradient.colors, <Color>[
      tokens.heroStart,
      tokens.heroMid,
      tokens.heroEnd,
    ]);
    expect(
      find.byKey(const ValueKey<String>('home-sleep-risk-feedback-surface')),
      findsOneWidget,
    );
  });

  testWidgets('home quick action uses semantic accent tokens', (
    WidgetTester tester,
  ) async {
    final NightMoodPalette palette = NightMoodPalette.fromMood(null);
    final AppSemanticColors tokens = AppSemanticColors.light(palette).copyWith(
      accentSoft: const Color(0xFFEAE2D5),
      accentDeep: const Color(0xFF5C5449),
    );

    await tester.pumpWidget(
      _wrap(
        QuickActionIconButton(
          icon: Icons.bedtime_rounded,
          label: '助眠',
          onTap: () {},
        ),
        tokens: tokens,
      ),
    );

    final Container iconContainer = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(QuickActionIconButton),
            matching: find.byType(Container),
          )
          .first,
    );
    final BoxDecoration decoration = iconContainer.decoration! as BoxDecoration;
    expect(decoration.color, tokens.accentSoft);

    final Icon icon = tester.widget<Icon>(
      find.descendant(
        of: find.byType(QuickActionIconButton),
        matching: find.byIcon(Icons.bedtime_rounded),
      ),
    );
    expect(icon.color, tokens.accentDeep);
  });

  testWidgets('home metric card uses semantic surface and text tokens', (
    WidgetTester tester,
  ) async {
    final NightMoodPalette palette = NightMoodPalette.fromMood(null);
    final AppSemanticColors tokens = AppSemanticColors.light(palette).copyWith(
      surface: const Color(0xFFF1EEE7),
      textPrimary: const Color(0xFF302A22),
      textSecondary: const Color(0xFF70675C),
      accentDeep: const Color(0xFF5C5449),
    );

    await tester.pumpWidget(
      _wrap(
        HomeMetricCard(
          icon: Icons.lightbulb_outline_rounded,
          label: '灯光环境',
          value: '适中',
          onTap: () {},
        ),
        tokens: tokens,
      ),
    );

    final Container card = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(HomeMetricCard),
            matching: find.byType(Container),
          )
          .first,
    );
    final BoxDecoration decoration = card.decoration! as BoxDecoration;
    expect(decoration.color, tokens.surface);

    final Icon icon = tester.widget<Icon>(
      find.descendant(
        of: find.byType(HomeMetricCard),
        matching: find.byIcon(Icons.lightbulb_outline_rounded),
      ),
    );
    expect(icon.color, tokens.accentDeep);
  });

  testWidgets('support tool card only renders icon and title', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        SupportToolCard(
          title: '难以入睡',
          icon: Icons.self_improvement_rounded,
          onTap: () {},
        ),
      ),
    );

    expect(find.text('难以入睡'), findsOneWidget);
    expect(find.byIcon(Icons.self_improvement_rounded), findsOneWidget);
    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('home audio card shows transport only after playback starts', (
    WidgetTester tester,
  ) async {
    final NightRecommendation recommendation = _audioRecommendation(
      executionState: RecommendationExecutionState.idle,
    );

    await tester.pumpWidget(
      _wrap(HomeActionCard(recommendation: recommendation, onTap: () {})),
    );

    expect(find.byIcon(Icons.skip_previous_rounded), findsNothing);
    expect(find.byIcon(Icons.skip_next_rounded), findsNothing);
    expect(find.text('睡前放松音频'), findsOneWidget);

    int previousCalls = 0;
    int nextCalls = 0;
    int openCatalogCalls = 0;
    await tester.pumpWidget(
      _wrap(
        HomeActionCard(
          recommendation: _audioRecommendation(
            executionState: RecommendationExecutionState.playing,
          ),
          displayTitle: '夜雨白噪音',
          showAudioTransport: true,
          onTap: () => openCatalogCalls += 1,
          onPreviousAudio: () => previousCalls += 1,
          onNextAudio: () => nextCalls += 1,
        ),
      ),
    );

    expect(find.text('睡前放松音频'), findsNothing);
    expect(find.text('夜雨白噪音'), findsOneWidget);
    expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
    expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
    expect(
      (tester.getTopLeft(find.text('放松')).dy -
              tester.getTopLeft(find.text('15分钟')).dy)
          .abs(),
      lessThan(1),
    );

    await tester.tap(find.byIcon(Icons.skip_previous_rounded));
    await tester.tap(find.byIcon(Icons.skip_next_rounded));
    await tester.tap(find.text('夜雨白噪音'));

    expect(previousCalls, 1);
    expect(nextCalls, 1);
    expect(openCatalogCalls, 1);

    await tester.pumpWidget(
      _wrap(
        HomeActionCard(
          recommendation: _audioRecommendation(
            executionState: RecommendationExecutionState.idle,
          ),
          displayTitle: '夜雨白噪音',
          showAudioTransport: true,
          onTap: () {},
        ),
      ),
    );

    expect(find.text('夜雨白噪音'), findsOneWidget);
    expect(find.byIcon(Icons.skip_previous_rounded), findsNothing);
    expect(find.byIcon(Icons.skip_next_rounded), findsNothing);
  });

  testWidgets('home audio action card keeps the same border as other actions', (
    WidgetTester tester,
  ) async {
    final NightMoodPalette palette = NightMoodPalette.fromMood(null);
    final AppSemanticColors tokens = AppSemanticColors.light(
      palette,
    ).copyWith(borderSubtle: const Color(0xFFD8CEC3));

    await tester.pumpWidget(
      _wrap(
        HomeActionCard(
          recommendation: _audioRecommendation(
            executionState: RecommendationExecutionState.idle,
          ),
          onTap: () {},
        ),
        tokens: tokens,
      ),
    );

    final AppCard card = tester.widget<AppCard>(
      find.ancestor(of: find.text('睡前放松音频'), matching: find.byType(AppCard)),
    );
    expect(card.border, Border.all(color: tokens.borderSubtle));
  });

  testWidgets('home action card title is lower than section title', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        HomeActionCard(
          recommendation: _audioRecommendation(
            executionState: RecommendationExecutionState.idle,
          ),
          onTap: () {},
        ),
      ),
    );

    final Text title = tester.widget<Text>(find.text('睡前放松音频'));
    expect(title.style?.fontSize, 15);
    expect(title.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('home metric and quick action use compact typography roles', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        Column(
          children: <Widget>[
            QuickActionIconButton(
              icon: Icons.bedtime_rounded,
              label: '助眠',
              onTap: () {},
            ),
            HomeMetricCard(
              icon: Icons.lightbulb_outline_rounded,
              label: '灯光环境',
              value: '适中',
            ),
          ],
        ),
      ),
    );

    expect(tester.widget<Text>(find.text('助眠')).style?.fontSize, 12);
    expect(
      tester.widget<Text>(find.text('助眠')).style?.fontWeight,
      FontWeight.w600,
    );
    expect(tester.widget<Text>(find.text('适中')).style?.fontSize, 16);
    expect(tester.widget<Text>(find.text('灯光环境')).style?.fontSize, 13);
  });

  testWidgets('start sleep card separates audio status from moon action', (
    WidgetTester tester,
  ) async {
    final NightMoodPalette palette = NightMoodPalette.fromMood(null);
    final AppSemanticColors tokens = AppSemanticColors.light(palette).copyWith(
      accent: const Color(0xFFE8C9B3),
      accentDeep: const Color(0xFF5F4B40),
    );

    await tester.pumpWidget(
      _wrap(
        StartSleepModeCard(onTap: () {}, isAudioReady: true),
        tokens: tokens,
      ),
    );

    final Finder status = find.text('音频已同步');
    final Finder moon = find.byIcon(Icons.dark_mode_rounded);
    expect(tester.getTopRight(status).dx, lessThan(tester.getTopLeft(moon).dx));
    expect(
      tester.getTopLeft(moon).dx - tester.getTopRight(status).dx,
      greaterThanOrEqualTo(8),
    );
    expect(tester.widget<Icon>(moon).color, tokens.accentDeep);
  });

  testWidgets(
    'start sleep card keeps the moon action without idle helper text',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(StartSleepModeCard(onTap: () {}, isAudioReady: false)),
      );

      expect(find.text('开启睡眠模式'), findsOneWidget);
      expect(find.text('轻触进入'), findsNothing);
      expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
    },
  );

  testWidgets('session audio card hides cloud subtitle and exposes transport', (
    WidgetTester tester,
  ) async {
    int previousCalls = 0;
    int nextCalls = 0;
    await tester.pumpWidget(
      _wrap(
        SessionAudioCard(
          track: const AudioTrack(
            id: 'rain',
            title: '夜雨白噪音',
            subtitle: 'CloudBase storage 云端音频',
            duration: Duration.zero,
            sourceUrl: 'https://example.com/rain.mp3',
          ),
          playbackState: PlaybackState.playing,
          position: Duration.zero,
          onToggle: () {},
          onPrevious: () => previousCalls += 1,
          onNext: () => nextCalls += 1,
        ),
        dark: true,
      ),
    );

    expect(find.text('夜雨白噪音'), findsOneWidget);
    expect(find.textContaining('CloudBase'), findsNothing);
    expect(find.textContaining('/'), findsNothing);
    expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
    expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.skip_previous_rounded));
    await tester.tap(find.byIcon(Icons.skip_next_rounded));

    expect(previousCalls, 1);
    expect(nextCalls, 1);
  });
}

Widget _wrap(Widget child, {bool dark = false, AppSemanticColors? tokens}) {
  final NightMoodPalette palette = NightMoodPalette.fromMood(null);
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      extensions: <ThemeExtension<dynamic>>[
        palette,
        tokens ?? AppSemanticColors.light(palette),
      ],
    ),
    home: Scaffold(
      backgroundColor: dark ? const Color(0xFF111111) : Colors.white,
      body: Center(child: SizedBox(width: 420, child: child)),
    ),
  );
}

NightRecommendation _audioRecommendation({
  required RecommendationExecutionState executionState,
}) {
  return NightRecommendation(
    id: 'audio',
    title: '睡前放松音频',
    subtitle: '',
    type: RecommendationType.audio,
    icon: Icons.music_note_rounded,
    tags: const <String>['放松', '15分钟'],
    executionState: executionState,
    track: const AudioTrack(
      id: 'rain',
      title: '夜雨白噪音',
      subtitle: '',
      duration: Duration.zero,
      sourceUrl: 'https://example.com/rain.mp3',
    ),
  );
}
