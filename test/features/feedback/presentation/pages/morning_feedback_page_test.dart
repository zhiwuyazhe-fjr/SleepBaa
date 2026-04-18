import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';
import 'package:sleep_dorm_app/features/feedback/presentation/pages/morning_feedback_page.dart';

void main() {
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
