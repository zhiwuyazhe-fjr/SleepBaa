/// Local calendar day [D] when the current evening period started at 20:00.
///
/// Period is **[D 20:00, D+1 20:00)** (start inclusive, end exclusive).
String eveningPeriodKey(DateTime local) {
  final DateTime calendarDay = DateTime(local.year, local.month, local.day);
  final DateTime anchor = local.hour >= 20
      ? calendarDay
      : calendarDay.subtract(const Duration(days: 1));
  return '${anchor.year.toString().padLeft(4, '0')}-'
      '${anchor.month.toString().padLeft(2, '0')}-'
      '${anchor.day.toString().padLeft(2, '0')}';
}
