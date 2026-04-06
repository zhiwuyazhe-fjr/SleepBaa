abstract final class FirebaseCollections {
  static const String users = 'users';
  static const String userSettings = 'user_settings';
  static const String notificationTokens = 'notification_tokens';
  static const String dorms = 'dorms';
  static const String dormMembers = 'members';
  static const String dormRules = 'rules';
  static const String dormEvents = 'events';
  static const String dormInvites = 'invites';
  static const String sleepSessions = 'sleep_sessions';
  static const String awakenings = 'awakenings';
  static const String recommendationFeedback = 'recommendation_feedback';
  static const String notifications = 'notifications';
  static const String notificationItems = 'items';
  static const String dreamEntries = 'dream_entries';
  static const String assistantThreads = 'assistant_threads';
  static const String assistantMessages = 'messages';
}

abstract final class FirebaseContractNotes {
  static const String authStrategy =
      'Anonymous auth first, with future account linking support.';
  static const String dormRealtime =
      'Firestore listeners are the primary realtime source for dorm state, '
      'member presence, invites, rules, events, and notifications.';
  static const String sessionModel =
      'Each night maps to a single sleep session document with recommendation '
      'snapshots, while awakenings and recommendation feedback live in '
      'dedicated subcollections.';
  static const String localVsCloud =
      'Playback state, animation state, and draft form inputs stay local. '
      'Profiles, settings, sessions, dorm state, dreams, notifications, and '
      'assistant history are cloud-backed.';
}
