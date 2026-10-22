/// Languages a new deck can be created in.
///
/// The API stores a display label rather than a language code, so [label] is
/// what gets sent and later shown on the deck.
enum DeckLanguage {
  english('English'),
  polish('Polski');

  const DeckLanguage(this.label);

  final String label;
}
