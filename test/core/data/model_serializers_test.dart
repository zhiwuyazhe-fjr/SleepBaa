import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/core/data/model_serializers.dart';

void main() {
  test(
    'assistant message timestamps are converted from UTC strings to local',
    () {
      final DateTime expected = DateTime.parse(
        '2026-04-08T00:00:00.000Z',
      ).toLocal();

      final message =
          ModelSerializers.assistantMessageFromMap(<String, dynamic>{
            'id': 'msg-1',
            'threadId': 'thread-1',
            'role': 'assistant',
            'content': 'hello',
            'createdAt': '2026-04-08T00:00:00.000Z',
          });

      expect(message.createdAt, expected);
      expect(message.createdAt.isUtc, isFalse);
    },
  );

  test(
    'assistant profile timestamps are converted from firestore maps to local',
    () {
      final DateTime expected = DateTime.fromMillisecondsSinceEpoch(
        1712534400000,
        isUtc: true,
      ).toLocal();

      final profile = ModelSerializers.assistantProfileFromMap(
        <String, dynamic>{
          'userId': 'user-1',
          'assistantName': '小眠',
          'identityPrompt': '陪伴入睡',
          'tone': '温柔',
          'relationshipRole': '睡前助手',
          'updatedAt': <String, dynamic>{
            '_seconds': 1712534400,
            '_nanoseconds': 0,
          },
        },
      );

      expect(profile.updatedAt, expected);
      expect(profile.updatedAt.isUtc, isFalse);
    },
  );

  test(
    'sleep session deserializes derived sleepGoalMet without persisting it back',
    () {
      final SleepSession session = ModelSerializers.sleepSessionFromMap(
        <String, dynamic>{
          'id': 'session-1',
          'uid': 'user-1',
          'startedAt': '2026-04-17T23:00:00.000Z',
          'endedAt': '2026-04-18T07:00:00.000Z',
          'sleepDayKey': '2026-04-18',
          'status': 'completed',
          'sleepModeActive': false,
          'trackedDurationMinutes': 480,
          'segments': <Map<String, dynamic>>[
            <String, dynamic>{
              'startedAt': '2026-04-17T23:00:00.000Z',
              'endedAt': '2026-04-18T07:00:00.000Z',
            },
          ],
          'awakenings': const <Map<String, dynamic>>[],
          'feedback': const <Map<String, dynamic>>[],
          'summary': <String, dynamic>{
            'sleepQuality': 4,
            'restedLevel': 4,
            'totalSleepHours': 8.0,
            'awakeningsCount': 0,
            'note': 'slept well',
          },
          'sleepGoalMet': true,
        },
      );

      final Map<String, dynamic> serialized =
          ModelSerializers.sleepSessionToMap(session);

      expect(session.sleepGoalMet, isTrue);
      expect(session.deriveSleepGoalMet(7.5), isTrue);
      expect(serialized.containsKey('sleepGoalMet'), isFalse);
    },
  );

  test('user settings round-trip home quick action ids', () {
    const List<String> quickActionIds = <String>[
      HomeQuickActionIds.profileSettings,
      HomeQuickActionIds.profileReport,
      HomeQuickActionIds.profileBadges,
      HomeQuickActionIds.thoughtVault,
    ];
    const UserSettings settings = UserSettings(
      sleepGoalHours: 7.5,
      bedtimeReminderEnabled: true,
      morningReminderEnabled: true,
      dormAlertsEnabled: true,
      bedtimeReminder: TimeOfDay(hour: 23, minute: 10),
      preferredTrackTitle: '深海海浪',
      smartSuggestionsEnabled: true,
      homeQuickActionIds: quickActionIds,
    );

    final Map<String, dynamic> map = ModelSerializers.userSettingsToMap(
      settings,
    );
    final UserSettings restored = ModelSerializers.userSettingsFromMap(map);

    expect(map['homeQuickActionIds'], quickActionIds);
    expect(restored.homeQuickActionIds, quickActionIds);
  });

  test('user settings normalizes invalid home quick action ids', () {
    final UserSettings restored = ModelSerializers.userSettingsFromMap(
      <String, dynamic>{
        'homeQuickActionIds': <String>[
          HomeQuickActionIds.profileSettings,
          'missing-action',
          HomeQuickActionIds.profileSettings,
        ],
      },
    );

    expect(restored.homeQuickActionIds, <String>[
      HomeQuickActionIds.profileSettings,
      HomeQuickActionIds.dreamJournal,
      HomeQuickActionIds.profileCalendar,
      HomeQuickActionIds.sleepEncyclopedia,
    ]);
  });
}
