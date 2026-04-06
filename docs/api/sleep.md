# Sleep API

## Owner

- Sleep core teammate

## Facade

- `SleepFacade.tonightRecommendations`
- `SleepFacade.activeSession`
- `SleepFacade.latestAwaitingFeedbackSession`
- `SleepFacade.sessions`
- `SleepFacade.recentSessions({count})`
- `SleepFacade.sessionsForMonth(month)`
- `SleepFacade.handleRecommendationTap(recommendation)`
- `SleepFacade.enterSleepMode()`
- `SleepFacade.exitSleepMode()`
- `SleepFacade.addNightAwakening({occurredAt, trigger, minutesToSleep, note})`
- `SleepFacade.submitMorningFeedback({session, summary, feedback})`

## Cloud data

- `sleep_sessions/{sessionId}`
- `sleep_sessions/{sessionId}/awakenings/{awakeningId}`
- `sleep_sessions/{sessionId}/recommendation_feedback/{feedbackId}`
- `notifications/{uid}/items/{notificationId}`

## Local-only state

- Recommendation templates
- Audio playback position and playback state

## Integration notes

- All ids should come from repository or centralized id generation
- Notification creation currently happens client-side and should move to backend later if rules are tightened
