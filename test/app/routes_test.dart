import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/app/routes.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

void main() {
  test('active sleep mode redirects from shell entry routes', () {
    final SleepSession session = _session(
      status: SleepSessionStatus.active,
      sleepModeActive: true,
    );

    expect(
      shouldRedirectToActiveSleepMode(
        location: AppRoutes.root,
        activeSession: session,
      ),
      isTrue,
    );
    expect(
      shouldRedirectToActiveSleepMode(
        location: AppRoutes.home,
        activeSession: session,
      ),
      isTrue,
    );
    expect(
      shouldRedirectToActiveSleepMode(
        location: AppRoutes.homePreSleep,
        activeSession: session,
      ),
      isTrue,
    );
  });

  test('inactive sleep sessions do not redirect to post-sleep route', () {
    for (final SleepSession session in <SleepSession>[
      _session(status: SleepSessionStatus.paused, sleepModeActive: false),
      _session(
        status: SleepSessionStatus.awaitingFeedback,
        sleepModeActive: false,
      ),
      _session(status: SleepSessionStatus.completed, sleepModeActive: false),
      _session(
        status: SleepSessionStatus.active,
        sleepModeActive: true,
        endedAt: DateTime(2026, 4, 15, 7),
      ),
    ]) {
      expect(
        shouldRedirectToActiveSleepMode(
          location: AppRoutes.homePreSleep,
          activeSession: session,
        ),
        isFalse,
      );
    }
  });

  test('active sleep mode does not hijack non-entry routes', () {
    final SleepSession session = _session(
      status: SleepSessionStatus.active,
      sleepModeActive: true,
    );

    for (final String location in <String>[
      AppRoutes.homePostSleep,
      AppRoutes.assistant,
      AppRoutes.dreamJournal,
      AppRoutes.logNightAwakening,
      AppRoutes.dorm,
      AppRoutes.profile,
    ]) {
      expect(
        shouldRedirectToActiveSleepMode(
          location: location,
          activeSession: session,
        ),
        isFalse,
      );
    }
  });
}

SleepSession _session({
  required SleepSessionStatus status,
  required bool sleepModeActive,
  DateTime? endedAt,
}) {
  final DateTime startedAt = DateTime(2026, 4, 14, 23);
  return SleepSession(
    id: 'session-${status.name}-$sleepModeActive-${endedAt ?? 'open'}',
    uid: 'tester',
    startedAt: startedAt,
    endedAt: endedAt,
    sleepDayKey: sleepDayKeyFromDate(startedAt),
    status: status,
    sleepModeActive: sleepModeActive,
    dormId: 'dorm-204',
    recommendations: const <NightRecommendation>[],
    selectedRecommendationIds: const <String>[],
    segments: <SleepSegment>[
      SleepSegment(startedAt: startedAt, endedAt: endedAt),
    ],
    trackedDurationMinutes: 0,
    awakenings: const <NightAwakeningEntry>[],
    feedback: const <RecommendationFeedback>[],
    summary: null,
    updatedAt: endedAt ?? startedAt,
  );
}
