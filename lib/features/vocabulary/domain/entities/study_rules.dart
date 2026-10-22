/// The tunable numbers of the learning loop, kept in one place so the
/// scheduler, the stats and the UI can never disagree about them.
abstract final class StudyRules {
  /// XP per correct answer depends on the card: see `CardLevel`.
  static const int xpPerLevel = 900;

  /// A missed word comes back after this long, still within the session day.
  static const Duration relearnDelay = Duration(minutes: 10);

  /// The language pair label shown on the home screen.
  static const String courseLabel = 'Español';
}
