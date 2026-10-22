/// Calendar-day helpers. Streaks care about days, not instants.
extension DayOnly on DateTime {
  DateTime get atStartOfDay => DateTime(year, month, day);

  int daysBetween(DateTime other) =>
      atStartOfDay.difference(other.atStartOfDay).inDays;

  bool isSameDay(DateTime other) => daysBetween(other) == 0;
}

/// Counts consecutive study days ending today or yesterday. An older last
/// session means the streak has already lapsed.
int streakFromDays(Iterable<DateTime> studyDays, DateTime now) {
  final days = studyDays.map((d) => d.atStartOfDay).toSet().toList()
    ..sort((a, b) => b.compareTo(a));
  if (days.isEmpty) return 0;

  final gapToNewest = now.daysBetween(days.first);
  if (gapToNewest > 1) return 0;

  var streak = 1;
  for (var i = 1; i < days.length; i++) {
    if (days[i - 1].daysBetween(days[i]) != 1) break;
    streak++;
  }
  return streak;
}
