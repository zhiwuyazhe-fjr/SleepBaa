import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/data/model_serializers.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/state/night_welcome_controller.dart';
import 'package:sleep_dorm_app/core/utils/evening_period.dart';

void main() {
  group('eveningPeriodKey', () {
    test('before 20:00 anchors to previous calendar day', () {
      expect(
        eveningPeriodKey(DateTime(2026, 4, 18, 19, 59)),
        '2026-04-17',
      );
    });

    test('at 20:00 anchors to same calendar day', () {
      expect(
        eveningPeriodKey(DateTime(2026, 4, 18, 20, 0)),
        '2026-04-18',
      );
    });

    test('after midnight belongs to period that started yesterday 20:00', () {
      expect(
        eveningPeriodKey(DateTime(2026, 4, 18, 3, 30)),
        '2026-04-17',
      );
    });

    test('first day of month before 20:00 uses last day of previous month', () {
      expect(
        eveningPeriodKey(DateTime(2026, 5, 1, 12)),
        '2026-04-30',
      );
    });
  });

  group('isNightTime', () {
    test('is 20:00 through 04:59 local', () {
      expect(isNightTime(DateTime(2026, 1, 1, 19, 59)), isFalse);
      expect(isNightTime(DateTime(2026, 1, 1, 20, 0)), isTrue);
      expect(isNightTime(DateTime(2026, 1, 1, 4, 59)), isTrue);
      expect(isNightTime(DateTime(2026, 1, 1, 5, 0)), isFalse);
    });
  });

  group('UserSettings evening encouragement serialization', () {
    test('round-trip known mood snapshot', () {
      const UserSettings original = UserSettings(
        sleepGoalHours: 7.5,
        bedtimeReminderEnabled: true,
        morningReminderEnabled: true,
        dormAlertsEnabled: true,
        bedtimeReminder: TimeOfDay(hour: 23, minute: 10),
        preferredTrackTitle: 'x',
        smartSuggestionsEnabled: true,
        eveningEncouragementPeriodKey: '2026-04-17',
        eveningEncouragementLine: '“慢”——小眠',
        eveningEncouragementMoodSnapshot: NightMood.calm,
      );
      final Map<String, dynamic> map = ModelSerializers.userSettingsToMap(
        original,
      );
      final UserSettings restored = ModelSerializers.userSettingsFromMap(map);
      expect(restored.eveningEncouragementPeriodKey, '2026-04-17');
      expect(restored.eveningEncouragementLine, '“慢”——小眠');
      expect(restored.eveningEncouragementMoodSnapshot, NightMood.calm);
    });

    test('unknown pool persists as unknown and restores null snapshot', () {
      const UserSettings original = UserSettings(
        sleepGoalHours: 7.5,
        bedtimeReminderEnabled: true,
        morningReminderEnabled: true,
        dormAlertsEnabled: true,
        bedtimeReminder: TimeOfDay(hour: 23, minute: 10),
        preferredTrackTitle: 'x',
        smartSuggestionsEnabled: true,
        eveningEncouragementPeriodKey: '2026-04-17',
        eveningEncouragementLine: '“急”——小眠',
        eveningEncouragementMoodSnapshot: null,
      );
      final Map<String, dynamic> map = ModelSerializers.userSettingsToMap(
        original,
      );
      expect(map['eveningEncouragementMoodSnapshot'], 'unknown');
      final UserSettings restored = ModelSerializers.userSettingsFromMap(map);
      expect(restored.eveningEncouragementMoodSnapshot, isNull);
    });
  });
}
