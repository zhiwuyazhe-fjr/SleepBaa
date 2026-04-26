import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/features/home/presentation/widgets/home_widgets.dart';

void main() {
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

Widget _wrap(Widget child, {bool dark = false}) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
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
