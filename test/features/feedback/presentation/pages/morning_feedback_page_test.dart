import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/features/feedback/presentation/pages/morning_feedback_page.dart';

void main() {
  test(
    'allows explicit morning feedback lookup for an active sleep session',
    () {
      expect(
        canOpenMorningFeedbackExplicitSession(
          _buildActiveSleepModeSession(id: 'active-session'),
        ),
        isTrue,
      );
    },
  );

  test(
    'shows loading for explicit session lookup until the repository becomes ready',
    () {
      expect(
        shouldShowMorningFeedbackLoading(
          explicitSessionId: 'session-1',
          isReadyForSessionLookup: false,
          sessions: const <SleepSession>[],
        ),
        isTrue,
      );
    },
  );

  test(
    'does not show loading after readiness resolves even when the session is missing',
    () {
      expect(
        shouldShowMorningFeedbackLoading(
          explicitSessionId: 'session-1',
          isReadyForSessionLookup: true,
          sessions: const <SleepSession>[],
        ),
        isFalse,
      );
    },
  );

  test(
    'does not show loading when the explicit session is already available locally',
    () {
      expect(
        shouldShowMorningFeedbackLoading(
          explicitSessionId: 'session-1',
          isReadyForSessionLookup: false,
          sessions: <SleepSession>[
            _buildPendingFeedbackSession(id: 'session-1'),
          ],
        ),
        isFalse,
      );
    },
  );

  test('does not show loading for the generic morning feedback route', () {
    expect(
      shouldShowMorningFeedbackLoading(
        explicitSessionId: '',
        isReadyForSessionLookup: false,
        sessions: const <SleepSession>[],
      ),
      isFalse,
    );
  });

  test(
    'can submit morning feedback for a closed awaiting session with zero minutes',
    () {
      final DateTime startedAt = DateTime(2026, 4, 17, 23, 18);
      final SleepSession session = SleepSession(
        id: 'session-zero-minutes',
        uid: 'cloud-user',
        startedAt: startedAt,
        endedAt: startedAt,
        sleepDayKey: sleepDayKeyFromDate(startedAt),
        status: SleepSessionStatus.awaitingFeedback,
        sleepModeActive: false,
        dormId: 'dorm-204',
        recommendations: const <NightRecommendation>[],
        selectedRecommendationIds: const <String>[],
        segments: <SleepSegment>[
          SleepSegment(startedAt: startedAt, endedAt: startedAt),
        ],
        trackedDurationMinutes: 0,
        awakenings: const <NightAwakeningEntry>[],
        feedback: const <RecommendationFeedback>[],
        summary: null,
        updatedAt: startedAt,
      );

      expect(canSubmitMorningFeedbackForSession(session), isTrue);
      expect(resolveMorningFeedbackSessionEndAt(session), startedAt);
    },
  );

  test('rejects morning feedback when the session has no resolved end', () {
    final DateTime startedAt = DateTime(2026, 4, 17, 23, 18);
    final SleepSession session = SleepSession(
      id: 'session-open',
      uid: 'cloud-user',
      startedAt: startedAt,
      endedAt: null,
      sleepDayKey: sleepDayKeyFromDate(startedAt),
      status: SleepSessionStatus.awaitingFeedback,
      sleepModeActive: false,
      dormId: 'dorm-204',
      recommendations: const <NightRecommendation>[],
      selectedRecommendationIds: const <String>[],
      segments: <SleepSegment>[
        SleepSegment(startedAt: startedAt, endedAt: null),
      ],
      trackedDurationMinutes: 0,
      awakenings: const <NightAwakeningEntry>[],
      feedback: const <RecommendationFeedback>[],
      summary: null,
      updatedAt: startedAt,
    );

    expect(canSubmitMorningFeedbackForSession(session), isFalse);
    expect(resolveMorningFeedbackSessionEndAt(session), isNull);
  });
}

SleepSession _buildActiveSleepModeSession({required String id}) {
  final DateTime startedAt = DateTime(2026, 4, 17, 23, 18);
  return SleepSession(
    id: id,
    uid: 'cloud-user',
    startedAt: startedAt,
    endedAt: null,
    sleepDayKey: sleepDayKeyFromDate(startedAt),
    status: SleepSessionStatus.active,
    sleepModeActive: true,
    dormId: 'dorm-204',
    recommendations: <NightRecommendation>[
      NightRecommendation(
        id: '$id-rec',
        title: 'Active recommendation',
        subtitle: 'Live session recommendation',
        type: RecommendationType.quickAction,
        icon: Icons.bedtime_rounded,
        tags: const <String>['active'],
        executionState: RecommendationExecutionState.selected,
      ),
    ],
    selectedRecommendationIds: <String>['$id-rec'],
    segments: <SleepSegment>[SleepSegment(startedAt: startedAt, endedAt: null)],
    trackedDurationMinutes: 0,
    awakenings: const <NightAwakeningEntry>[],
    feedback: const <RecommendationFeedback>[],
    summary: null,
    updatedAt: startedAt,
  );
}

SleepSession _buildPendingFeedbackSession({required String id}) {
  final DateTime startedAt = DateTime(2026, 4, 17, 23, 18);
  final DateTime endedAt = DateTime(2026, 4, 18, 7, 0);
  return SleepSession(
    id: id,
    uid: 'cloud-user',
    startedAt: startedAt,
    endedAt: endedAt,
    sleepDayKey: sleepDayKeyFromDate(startedAt),
    status: SleepSessionStatus.awaitingFeedback,
    sleepModeActive: false,
    dormId: 'dorm-204',
    recommendations: <NightRecommendation>[
      NightRecommendation(
        id: '$id-rec',
        title: 'Pending recommendation',
        subtitle: 'Unique test recommendation',
        type: RecommendationType.quickAction,
        icon: Icons.bedtime_rounded,
        tags: const <String>['pending'],
        executionState: RecommendationExecutionState.selected,
      ),
    ],
    selectedRecommendationIds: <String>['$id-rec'],
    segments: <SleepSegment>[
      SleepSegment(startedAt: startedAt, endedAt: endedAt),
    ],
    trackedDurationMinutes: endedAt.difference(startedAt).inMinutes,
    awakenings: const <NightAwakeningEntry>[],
    feedback: const <RecommendationFeedback>[],
    summary: null,
    updatedAt: endedAt,
  );
}
