abstract final class FirebaseCollections {
  static const String users = 'users';
  static const String userSettings = 'user_settings';
  static const String dorms = 'dorms';
  static const String dormMembers = 'members';
  static const String sleepSessions = 'sleep_sessions';
  static const String recommendations = 'recommendations';
  static const String awakenings = 'awakenings';
  static const String feedback = 'feedback';
  static const String notifications = 'notifications';
  static const String notificationItems = 'items';
}

abstract final class FirebaseContractNotes {
  static const String authStrategy =
      'Anonymous auth first, with future account linking support.';
  static const String dormRealtime =
      'Firestore listeners are the primary realtime source for dorm status, '
      'notification lists, and active sleep mode state.';
  static const String sessionModel =
      'Each night maps to a single sleep session document with recommendation '
      'snapshots, awakenings, and morning feedback.';
}
