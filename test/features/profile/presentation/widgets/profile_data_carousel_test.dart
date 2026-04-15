import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/features/profile/presentation/widgets/profile_page_sections.dart';

void main() {
  testWidgets('profile data carousel shows empty seven-day placeholders', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildHarness(
        durationTrend: _buildSeries(
          metricKey: 'sleep_duration',
          unit: 'hours',
          values: const <double?>[null, null, null, null, null, null, null],
        ),
        qualityTrend: _buildSeries(
          metricKey: 'sleep_quality',
          unit: 'score',
          values: const <double?>[null, null, null, null, null, null, null],
        ),
      ),
    );

    expect(find.text('平静'), findsNothing);
    expect(find.text('愉悦'), findsNothing);

    await tester.drag(find.byType(PageView), const Offset(-280, 0));
    await tester.pumpAndSettle();

    expect(find.text('--'), findsNWidgets(7));
  });

  testWidgets(
    'profile data carousel renders partial quality and full duration data',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildHarness(
          durationTrend: _buildSeries(
            metricKey: 'sleep_duration',
            unit: 'hours',
            values: const <double?>[6.2, 6.5, 7.0, 7.4, 6.8, 7.1, 6.9],
          ),
          qualityTrend: _buildSeries(
            metricKey: 'sleep_quality',
            unit: 'score',
            values: const <double?>[null, null, 82, null, null, null, null],
          ),
        ),
      );

      expect(find.text('平静'), findsOneWidget);
      expect(find.text('愉悦'), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(-280, 0));
      await tester.pumpAndSettle();

      expect(find.text('--'), findsNothing);
    },
  );
}

Widget _buildHarness({
  required SleepTrendSeries durationTrend,
  required SleepTrendSeries qualityTrend,
}) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      extensions: <ThemeExtension<dynamic>>[NightMoodPalette.fromMood(null)],
    ),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          height: 260,
          child: ProfileDataCarousel(
            durationTrend: durationTrend,
            qualityTrend: qualityTrend,
            heatmapValues: List<int>.filled(28, 0),
            onHeatmapTap: () {},
          ),
        ),
      ),
    ),
  );
}

SleepTrendSeries _buildSeries({
  required String metricKey,
  required String unit,
  required List<double?> values,
}) {
  final DateTime today = DateUtils.dateOnly(DateTime.now());
  return SleepTrendSeries(
    metricKey: metricKey,
    unit: unit,
    points: List<SleepTrendPoint>.generate(7, (int index) {
      final DateTime day = today.subtract(Duration(days: 6 - index));
      return SleepTrendPoint(
        dateKey: _dateKeyOf(day),
        weekdayLabel: _weekdayLabelOf(day),
        value: values[index],
      );
    }, growable: false),
  );
}

String _dateKeyOf(DateTime date) {
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _weekdayLabelOf(DateTime date) {
  const List<String> labels = <String>['一', '二', '三', '四', '五', '六', '日'];
  return labels[date.weekday - 1];
}
