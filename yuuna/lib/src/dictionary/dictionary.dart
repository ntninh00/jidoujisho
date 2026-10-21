import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:yuuna/dictionary.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as path;

part 'dictionary.g.dart';

/// A dictionary that can be imported into the application, encapsulating its
/// metadata and current preferences.
@Collection()
@CopyWith()
class Dictionary {
  /// Initialise a dictionary with details determined from import.
  Dictionary({
    required this.id,
    required this.name,
    required this.formatKey,
    required this.order,
    this.hiddenLanguages = const [],
    this.collapsedLanguages = const [],
  });

  /// Identifier for database purposes.
  final Id id;

  /// The name of the dictionary. For example, this could be 'Merriam-Webster
  /// Dictionary' or '大辞林' or 'JMdict'.
  ///
  /// Dictionary names are meant to be unique, meaning two dictionaries of the
  /// same name should not be allowed to be added in the database.
  @Index(unique: true, replace: true)
  final String name;

  /// The unique key for the format that the dictionary was sourced from.
  final String formatKey;

  /// The order of this dictionary in terms of user sorting, relative to other
  /// dictionaries.
  @Index()
  int order;

  /// A dictionary may have multiple entries.
  @Backlink(to: 'dictionary')
  final IsarLinks<DictionaryEntry> entries = IsarLinks<DictionaryEntry>();

  /// A dictionary may have multiple tags.
  @Backlink(to: 'dictionary')
  final IsarLinks<DictionaryTag> tags = IsarLinks<DictionaryTag>();

  /// A dictionary may have multiple pitch entries.
  @Backlink(to: 'dictionary')
  final IsarLinks<DictionaryPitch> pitches = IsarLinks<DictionaryPitch>();

  /// A dictionary may have multiple frequency entries.
  @Backlink(to: 'dictionary')
  final IsarLinks<DictionaryFrequency> frequencies =
      IsarLinks<DictionaryFrequency>();

  /// Returns the resource path for within the applications documents directory.
  String getBasePath({required String appDirDocPath}) {
    return path.join(appDirDocPath, name);
  }

  /// Holds [everyLanguage] when the user turned this dictionary off. Older
  /// versions kept the code of each language it was hidden in instead;
  /// those are turned into the new form once, as the app starts.
  @Index()
  List<String> hiddenLanguages;

  /// Holds [everyLanguage] when this dictionary starts collapsed in results,
  /// as [hiddenLanguages] does for being off.
  @Index()
  List<String> collapsedLanguages;

  /// What [hiddenLanguages] and [collapsedLanguages] hold for a switch that
  /// is on: one switch for every language.
  static const String everyLanguage = '*';

  /// Whether this dictionary is left out of lookups: turned off by the user,
  /// or for another language than the words looked up (see [leftOut]).
  bool get isHidden => isHiddenByUser || (leftOut?.call(this) ?? false);

  /// Whether the user turned this dictionary off.
  bool get isHiddenByUser => hiddenLanguages.contains(everyLanguage);

  /// Whether lookups leave a dictionary out for being in another language
  /// than the words looked up: reading a Japanese book uses only Japanese
  /// dictionaries. Set by the app.
  static bool Function(Dictionary dictionary)? leftOut;

  /// Whether this dictionary starts collapsed in results.
  bool get isCollapsed => collapsedLanguages.contains(everyLanguage);

  /// Whether the old, one-language-at-a-time form of the switches is kept.
  bool get hasLanguageSwitches =>
      hiddenLanguages.any((code) => code != everyLanguage) ||
      collapsedLanguages.any((code) => code != everyLanguage);

  /// Given an asset name, returns an appropriate path to place the asset
  /// within this dictionary's resource path.
  String getResourcePath({
    required String appDirDocPath,
    required String resourceBasename,
  }) {
    return path.join(
      getBasePath(appDirDocPath: appDirDocPath),
      resourceBasename,
    );
  }

  @override
  bool operator ==(Object other) => other is Dictionary && name == other.name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  toString() {
    return 'Dictionary(name: $name, format: $formatKey)';
  }
}
