import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/features/dorm/presentation/support/dorm_member_status_presenter.dart';

void main() {
  test(
    'presence label hides return state when dorm location is not configured',
    () {
      final DormMember member = _member(
        presenceStatus: DormPresenceStatus.returned,
        sleepModeActive: false,
      );

      final String label = dormPresenceSleepLabel(member, showPresence: false);

      expect(label, '未睡');
      expect(label, isNot(contains('已返')));
      expect(label, isNot(contains('未返')));
    },
  );

  test('presence label hides unknown return state and keeps sleep state', () {
    final DormMember member = _member(
      presenceStatus: DormPresenceStatus.unknown,
      sleepModeActive: true,
    );

    expect(dormPresenceSleepLabel(member), '已睡');
  });

  test(
    'returned-member noise falls back to dorm aggregate without presence',
    () {
      final double average = averageNoiseDbForReturnedMembers(
        members: <DormMember>[
          _member(presenceStatus: DormPresenceStatus.returned, noiseDb: 52),
        ],
        dormAggregateNoiseDb: 31,
        showPresence: false,
      );

      expect(average, 31);
    },
  );

  test('online count ignores heartbeat timestamps that are later than now', () {
    final DateTime now = DateTime(2026, 4, 22, 20, 0, 0);

    final int count = dormAppOnlineMemberCount(<DormMember>[
      _member(
        presenceStatus: DormPresenceStatus.returned,
        appOnline: true,
        appLastSeenAt: now.add(const Duration(seconds: 10)),
      ),
    ], now: now);

    expect(count, 0);
  });

  test('online count expires once heartbeat is older than sixty seconds', () {
    final DateTime now = DateTime(2026, 4, 22, 20, 0, 0);

    expect(
      dormAppOnlineMemberCount(<DormMember>[
        _member(
          presenceStatus: DormPresenceStatus.returned,
          appOnline: true,
          appLastSeenAt: now.subtract(const Duration(seconds: 60)),
        ),
      ], now: now),
      1,
    );
    expect(
      dormAppOnlineMemberCount(<DormMember>[
        _member(
          presenceStatus: DormPresenceStatus.returned,
          appOnline: true,
          appLastSeenAt: now.subtract(const Duration(seconds: 61)),
        ),
      ], now: now),
      0,
    );
  });
}

DormMember _member({
  required DormPresenceStatus presenceStatus,
  bool sleepModeActive = false,
  bool appOnline = false,
  DateTime? appLastSeenAt,
  int? noiseDb,
}) {
  return DormMember(
    uid: 'user-1',
    name: 'Paul',
    status: DormMemberStatus.quiet,
    presenceStatus: presenceStatus,
    sleepModeActive: sleepModeActive,
    appOnline: appOnline,
    appLastSeenAt: appLastSeenAt,
    lastActiveAt: DateTime(2026, 4, 22, 20),
    note: '准备休息。',
    noiseDb: noiseDb,
  );
}
