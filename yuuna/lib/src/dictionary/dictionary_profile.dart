/// What a dictionary is for: the language of the words it looks up, the
/// language it explains them in, and what it holds. Known from the server's
/// catalog for dictionaries installed from it, and otherwise told from a
/// few of its rows.
class DictionaryProfile {
  /// Describe a dictionary.
  const DictionaryProfile({
    required this.source,
    required this.target,
    required this.kind,
  });

  /// Read what [toJson] wrote.
  factory DictionaryProfile.fromJson(Map<String, dynamic> json) =>
      DictionaryProfile(
        source: json['source'] as String?,
        target: json['target'] as String?,
        kind: json['kind'] as String? ?? words,
      );

  /// The profile the server's catalog gives, as kept in the app's record of
  /// where a dictionary came from: `language`, `target` and `section`.
  static DictionaryProfile? fromSource(Map<String, dynamic>? source) {
    if (source == null || source['section'] == null) {
      return null;
    }
    return DictionaryProfile(
      source: source['language'] as String?,
      target: source['target'] as String?,
      kind: kindOfSection(source['section'] as String?),
    );
  }

  /// Words with their meanings.
  static const String words = 'words';

  /// Grammar points.
  static const String grammar = 'grammar';

  /// Characters with their readings and meanings.
  static const String kanji = 'kanji';

  /// How common words are.
  static const String frequency = 'frequency';

  /// How words are said.
  static const String pronunciation = 'pronunciation';

  /// The kind a catalog section stands for.
  static String kindOfSection(String? section) {
    switch (section) {
      case grammar:
      case kanji:
      case frequency:
      case pronunciation:
        return section!;
      default:
        return words;
    }
  }

  /// Language code of the words looked up, as `ja`, or null when unknown.
  final String? source;

  /// Language code the words are explained in, or null when unknown or when
  /// nothing is explained, as in a frequency list.
  final String? target;

  /// What the dictionary holds: [words], [grammar], [kanji], [frequency] or
  /// [pronunciation].
  final String kind;

  /// Written to keep a guess.
  Map<String, dynamic> toJson() => {
        'source': source,
        'target': target,
        'kind': kind,
      };

  /// This profile with [source] instead, when the catalog knew only that.
  DictionaryProfile withSource(String? source) => DictionaryProfile(
      source: source ?? this.source, target: target, kind: kind);

  /// The language that comes up most among [languages].
  static String? languageOfMost(Iterable<String?> languages) {
    Map<String, int> counts = {};
    for (String? language in languages) {
      if (language != null) {
        counts[language] = (counts[language] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) {
      return null;
    }
    return (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
        .first
        .key;
  }

  /// The language an entry's definitions are written in: structured
  /// content is JSON, so its keys and tag names are left out first.
  static String? languageOfDefinitions(List<String> definitions) {
    String text = definitions
        .join(' ')
        .replaceAll(RegExp(r'"[A-Za-z-]+"\s*:'), ' ')
        .replaceAll(
            RegExp(
                '"(span|div|ul|ol|li|ruby|rt|rp|br|table|tr|td|th|a|img|details|summary|structured-content)"'),
            ' ');
    if (RegExp('[ăđơưĂĐƠƯẠ-ỹ]').hasMatch(text)) {
      return 'vi';
    }
    // Meanings in English have phrases, as `repetition mark`, however many
    // Japanese examples and readings they show; a Japanese dictionary's
    // seldom do.
    if (RegExp('[A-Za-z]{2,}[ ,;]+[A-Za-z]{2,}').hasMatch(text)) {
      return 'en';
    }
    if (RegExp('[぀-ヿ㐀-䶿一-鿿]').hasMatch(text)) {
      return 'ja';
    }
    return RegExp('[A-Za-z]').hasMatch(text) ? 'en' : null;
  }
}
