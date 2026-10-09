import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/i18n/strings.g.dart';

/// Where a dictionary on the server belongs in the catalog.
enum CatalogSection {
  /// Definitions in another language than the words.
  bilingual,

  /// Definitions in the same language as the words.
  monolingual,

  /// Characters with their readings and meanings.
  kanji,

  /// How common words are.
  frequency,

  /// Pitch accent and IPA.
  pronunciation,

  /// Anything else.
  other,
}

/// A dictionary on the server, as the catalog describes it.
class CatalogDictionary {
  /// Read a dictionary from the server's JSON.
  CatalogDictionary.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        title = json['title'] as String,
        revision = json['revision'] as String? ?? '',
        author = json['author'] as String?,
        description = json['description'] as String?,
        attribution = json['attribution'] as String?,
        url = json['url'] as String?,
        notes = _notesOf(json),
        sourceLanguage = json['sourceLanguage'] as String?,
        targetLanguage = json['targetLanguage'] as String?,
        languagesGuessed = json['languagesGuessed'] as bool? ?? false,
        kinds = List<String>.from(json['kinds'] as List? ?? const []),
        counts = Map<String, int>.from(
          (json['counts'] as Map? ?? const {})
              .map((key, value) => MapEntry('$key', (value as num).toInt())),
        ),
        size = (json['size'] as num?)?.toInt() ?? 0,
        status = json['status'] as String? ?? 'ready',
        error = json['error'] as String?;

  /// The server's id for the dictionary.
  final String id;

  /// The dictionary's title, which is also its name once imported.
  final String title;

  /// The dictionary's revision.
  final String revision;

  /// Details from the dictionary's index, when it gives them.
  final String? author;

  /// See [author].
  final String? description;

  /// See [author].
  final String? attribution;

  /// See [author].
  final String? url;

  /// What the server's admin wrote about the dictionary, by the language
  /// of the app it was written for, such as `en`.
  final Map<String, String> notes;

  /// What the server's admin wrote for people using the app in the
  /// language it is shown in now. Ones written for other languages don't
  /// show.
  String? get note => notes[LocaleSettings.currentLocale.languageCode];

  static Map<String, String> _notesOf(Map<String, dynamic> json) {
    Object? notes = json['notes'];
    if (notes is Map) {
      return notes.map((language, note) => MapEntry('$language', '$note'));
    }
    // Servers from before descriptions had languages, when the app only
    // had English.
    String? note = json['note'] as String?;
    return note == null ? {} : {'en': note};
  }

  /// Language of the words looked up, such as `ja`.
  final String? sourceLanguage;

  /// Language the definitions are written in.
  final String? targetLanguage;

  /// Whether the server guessed the languages rather than being told.
  final bool languagesGuessed;

  /// What the dictionary holds: terms, kanji, frequency, pitch, ipa.
  final List<String> kinds;

  /// How many of each kind of row the dictionary has.
  final Map<String, int> counts;

  /// Size of the zip in bytes.
  final int size;

  /// waiting, indexing, ready or failed.
  final String status;

  /// Why indexing failed.
  final String? error;

  /// Whether it can be searched and downloaded.
  bool get isReady => status == 'ready';

  /// Whether the server is still preparing it.
  bool get isPreparing => status == 'waiting' || status == 'indexing';

  /// Whether preparing it failed.
  bool get hasFailed => status == 'failed';

  /// Where it belongs in the catalog.
  CatalogSection get section {
    if (kinds.contains('terms')) {
      String? source = sourceLanguage;
      return source != null && source == targetLanguage
          ? CatalogSection.monolingual
          : CatalogSection.bilingual;
    }
    if (kinds.contains('kanji')) {
      return CatalogSection.kanji;
    }
    if (kinds.contains('frequency')) {
      return CatalogSection.frequency;
    }
    if (kinds.contains('pitch') || kinds.contains('ipa')) {
      return CatalogSection.pronunciation;
    }
    return CatalogSection.other;
  }

  /// Rows of every kind.
  int get entries =>
      (counts['terms'] ?? 0) +
      (counts['kanji'] ?? 0) +
      (counts['termMeta'] ?? 0) +
      (counts['kanjiMeta'] ?? 0);
}

/// One line of frequency, pitch or IPA data, ready to show.
class CatalogMetaLine {
  /// Describe a line.
  const CatalogMetaLine({
    required this.term,
    required this.reading,
    required this.mode,
    required this.text,
    this.downsteps = const [],
  });

  /// The word or character.
  final String term;

  /// Its reading, when the data gives one.
  final String reading;

  /// `freq`, `pitch` or `ipa`.
  final String mode;

  /// The data itself, such as `#120` or `/haʊs/ 🇺🇸`.
  final String text;

  /// For pitch data, where each pitch accent drops, to draw like the popup.
  final List<int> downsteps;
}

/// What a search of one dictionary found.
class CatalogResults {
  /// Read results from the server's JSON.
  CatalogResults.fromJson(Map<String, dynamic> json)
      : terms = _rows(json['terms']),
        kanji = _rows(json['kanji']),
        termMeta = _rows(json['termMeta']),
        kanjiMeta = _rows(json['kanjiMeta']),
        tags = (json['tags'] as Map? ?? const {}).map(
          (key, value) => MapEntry('$key', List<dynamic>.from(value as List)),
        );

  static List<List<dynamic>> _rows(Object? value) =>
      (value as List? ?? []).whereType<List>().map(List<dynamic>.from).toList();

  /// Term rows in Yomitan's format 3.
  final List<List<dynamic>> terms;

  /// Kanji rows in Yomitan's format 3.
  final List<List<dynamic>> kanji;

  /// Frequency, pitch and IPA rows for terms.
  final List<List<dynamic>> termMeta;

  /// Frequency rows for characters.
  final List<List<dynamic>> kanjiMeta;

  /// Tags the rows use, by name.
  final Map<String, List<dynamic>> tags;

  /// Whether nothing was found.
  bool get isEmpty =>
      terms.isEmpty && kanji.isEmpty && termMeta.isEmpty && kanjiMeta.isEmpty;

  static int _nextId = -1;

  /// The term and kanji rows as entries the popup's own widgets can show,
  /// marked as coming from [dictionary]. They are never saved.
  List<DictionaryEntry> entriesFor(Dictionary dictionary) {
    DictionaryTag? tagFor(String name) {
      List<dynamic>? row = tags[name];
      if (row == null) {
        return null;
      }
      return DictionaryTag(
        dictionaryId: dictionary.id,
        name: name,
        category: '${row.length > 1 ? row[1] : ''}',
        sortingOrder:
            row.length > 2 && row[2] is num ? (row[2] as num).toInt() : 0,
        notes: '${row.length > 3 ? row[3] : ''}',
        popularity:
            row.length > 4 && row[4] is num ? (row[4] as num).toDouble() : 0,
      );
    }

    List<String> names(Object? field) => field is String
        ? field.split(' ').where((name) => name.isNotEmpty).toList()
        : const [];

    List<DictionaryEntry> entries = [];
    for (List<dynamic> row in terms) {
      List<String> entryTags = names(row[2]);
      DictionaryEntry entry = DictionaryEntry(
        // Unsaved entries are told apart by id, so each gets its own.
        id: _nextId--,
        definitions:
            YomichanFormat.processDefinitions(row[5] as List? ?? const []),
        popularity: row[4] is num ? (row[4] as num).toDouble() : 0,
        entryTagNames: entryTags,
        headingTagNames: names(row.length > 7 ? row[7] : null),
      );
      entry.dictionary.value = dictionary;
      entry.heading.value = DictionaryHeading(
        term: '${row[0]}',
        reading: '${row[1]}',
      );
      entry.tags.addAll(entryTags.map(tagFor).whereType<DictionaryTag>());
      entries.add(entry);
    }

    for (List<dynamic> row in kanji) {
      String list(Object? value) => value is String
          ? value.split(' ').where((part) => part.isNotEmpty).join('、')
          : '';
      List<String> meanings = (row.length > 4 && row[4] is List)
          ? (row[4] as List).map((meaning) => '$meaning').toList()
          : const [];
      String text = [
        if (list(row[1]).isNotEmpty) '音読み  ${list(row[1])}',
        if (list(row[2]).isNotEmpty) '訓読み  ${list(row[2])}',
        if (meanings.isNotEmpty) meanings.join('; '),
      ].join('\n');
      DictionaryEntry entry = DictionaryEntry(
        id: _nextId--,
        definitions: [text],
        popularity: 0,
      );
      entry.dictionary.value = dictionary;
      entry.heading.value = DictionaryHeading(term: '${row[0]}');
      entries.add(entry);
    }
    return entries;
  }

  /// The frequency, pitch and IPA rows as lines to show.
  List<CatalogMetaLine> get metaLines {
    String describe(String mode, Object? data) {
      Object? value = data;
      if (value is Map && value.containsKey('frequency')) {
        value = value['frequency'];
      }
      if (mode == 'freq') {
        if (value is Map) {
          return '#${value['displayValue'] ?? value['value'] ?? ''}';
        }
        return '#$value';
      }
      if (mode == 'pitch' && data is Map) {
        return (data['pitches'] as List? ?? const [])
            .whereType<Map>()
            .map((pitch) => '[${pitch['position']}]')
            .join(' ');
      }
      if (mode == 'ipa' && data is Map) {
        return (data['transcriptions'] as List? ?? const [])
            .whereType<Map>()
            .map((ipa) => [
                  '${ipa['ipa'] ?? ''}',
                  ...(ipa['tags'] as List? ?? const []).map((tag) => '$tag'),
                ].join(' '))
            .join('   ');
      }
      return '$data';
    }

    List<int> downsteps(
            String mode, Object? data) =>
        mode == 'pitch' && data is Map
            ? (data['pitches'] as List? ?? const [])
                .whereType<Map>()
                .map((pitch) => pitch['position'])
                .whereType<num>()
                .map((position) => position.toInt())
                .toList()
            : const [];

    return [
      for (List<dynamic> row in [...termMeta, ...kanjiMeta])
        CatalogMetaLine(
          term: '${row[0]}',
          reading: row[2] is Map && (row[2] as Map)['reading'] is String
              ? (row[2] as Map)['reading'] as String
              : '',
          mode: '${row[1]}',
          text: describe('${row[1]}', row[2]),
          downsteps: downsteps('${row[1]}', row[2]),
        ),
    ];
  }
}

/// Something the server refused or couldn't do, said for the person using
/// the app.
class DictionaryServerException implements Exception {
  /// Describe the problem.
  DictionaryServerException(this.message, {this.statusCode});

  /// What went wrong.
  final String message;

  /// The HTTP status, when the server answered.
  final int? statusCode;

  @override
  String toString() => message;
}

/// A language the dictionary server has for the app's own text.
class AppLanguage {
  /// Read a language from the server's JSON.
  AppLanguage.fromJson(Map<String, dynamic> json)
      : code = json['code'] as String,
        name = json['name'] as String? ?? (json['code'] as String),
        builtIn = json['builtIn'] as bool? ?? false;

  /// Its code, such as `vi`.
  final String code;

  /// Its name, as it writes it.
  final String name;

  /// Whether the app was built with it, so the server only fixes it up.
  final bool builtIn;
}

/// What an admin changes about a dictionary on the server. Only what is set
/// is sent, so the rest stays as it is.
class CatalogChanges {
  /// Describe the changes.
  const CatalogChanges({this.languages, this.notes});

  /// The language of the words looked up and of the definitions.
  final ({String? source, String? target})? languages;

  /// The admin's own descriptions to change, by the app language each is
  /// for, such as `vi`; an empty one is removed. Each shows only in the app
  /// set to its language.
  final Map<String, String>? notes;

  /// Whether anything changes.
  bool get isEmpty => languages == null && (notes?.isEmpty ?? true);

  /// The changes as the server reads them.
  Map<String, Object?> toJson() => {
        if (languages != null) ...{
          'sourceLanguage': languages!.source,
          'targetLanguage': languages!.target,
        },
        if (notes?.isNotEmpty ?? false) 'notes': notes,
      };
}

/// The app's side of the dictionary server: browse, preview, download, and
/// with an admin token, upload, relabel and delete.
class DictionaryServer {
  /// Talk to the server at [url] with [token].
  DictionaryServer({required String url, required this.token})
      : url = normaliseUrl(url),
        _dio = Dio(
          BaseOptions(
            baseUrl: '${normaliseUrl(url)}/api/',
            headers: {'Authorization': 'Bearer $token'},
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 60),
          ),
        );

  /// The server's address, without a trailing slash.
  final String url;

  /// The token sent with every request.
  final String token;

  final Dio _dio;

  /// An address as typed: `https://` is added when missing, and a trailing
  /// slash or `/api` is dropped.
  static String normaliseUrl(String raw) {
    String value = raw.trim();
    if (value.isEmpty) {
      return value;
    }
    if (!value.contains('://')) {
      value = 'https://$value';
    }
    value = value.replaceAll(RegExp(r'/+$'), '');
    if (value.endsWith('/api')) {
      value = value.substring(0, value.length - 4);
    }
    return value;
  }

  /// Headers for loading the server's pictures.
  Map<String, String> get headers => {'Authorization': 'Bearer $token'};

  /// Where a picture in a dictionary can be loaded from.
  String mediaUrl(String dictionaryId, String mediaPath) =>
      '$url/api/dictionaries/$dictionaryId/media'
      '?path=${Uri.encodeQueryComponent(mediaPath)}';

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioError catch (error) {
      if (CancelToken.isCancel(error)) {
        rethrow;
      }
      Object? data = error.response?.data;
      if (data is Map && data['error'] is String) {
        throw DictionaryServerException(
          data['error'] as String,
          statusCode: error.response?.statusCode,
        );
      }
      if (error.response == null) {
        throw DictionaryServerException(
          'The dictionary server could not be reached.',
        );
      }
      throw DictionaryServerException(
        'The dictionary server answered with an error '
        '(${error.response?.statusCode}).',
        statusCode: error.response?.statusCode,
      );
    }
  }

  /// `admin` or `read`, the access the token gives.
  Future<String> role() => _guard(() async {
        Response response = await _dio.get('me');
        return (response.data as Map)['role'] as String;
      });

  /// Every dictionary on the server.
  Future<List<CatalogDictionary>> list() => _guard(() async {
        Response response = await _dio.get('dictionaries');
        return (response.data as List)
            .map((json) =>
                CatalogDictionary.fromJson(Map<String, dynamic>.from(json)))
            .toList();
      });

  /// One dictionary, to follow its indexing.
  Future<CatalogDictionary> get(String id) => _guard(() async {
        Response response = await _dio.get('dictionaries/$id');
        return CatalogDictionary.fromJson(
            Map<String, dynamic>.from(response.data));
      });

  /// Looks [query] up in one dictionary.
  Future<CatalogResults> search(String id, String query, {int limit = 20}) =>
      _guard(() async {
        Response response = await _dio.get(
          'dictionaries/$id/search',
          queryParameters: {'q': query, 'limit': limit},
        );
        return CatalogResults.fromJson(
            Map<String, dynamic>.from(response.data));
      });

  /// A dictionary's stylesheet, or null when it has none or the server is
  /// older than stylesheets.
  Future<String?> styles(String id) async {
    try {
      Response<String> response = await _dio.get<String>(
        'dictionaries/$id/styles',
        options: Options(responseType: ResponseType.plain),
      );
      return response.data;
    } on DioError {
      return null;
    }
  }

  /// Downloads a dictionary's zip to [target], checking it arrived whole.
  Future<void> download(
    CatalogDictionary dictionary,
    File target, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) =>
      _guard(() async {
        await _dio.download(
          'dictionaries/${dictionary.id}/download',
          target.path,
          onReceiveProgress: onProgress,
          cancelToken: cancelToken,
          options: Options(receiveTimeout: const Duration(minutes: 30)),
        );
        if (target.lengthSync() != dictionary.size) {
          target.deleteSync();
          throw DictionaryServerException(
            'The download was incomplete. Try again.',
          );
        }
      });

  /// Uploads a dictionary zip. The server checks it at once and prepares it
  /// in the background; follow it with [get].
  Future<CatalogDictionary> upload(
    File file, {
    bool replace = false,
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) =>
      _guard(() async {
        int length = file.lengthSync();
        Response response = await _dio.put(
          'dictionaries',
          data: file.openRead(),
          queryParameters: {
            'name': path.basename(file.path),
            if (replace) 'replace': '1',
          },
          onSendProgress: onProgress,
          cancelToken: cancelToken,
          options: Options(
            contentType: 'application/zip',
            headers: {Headers.contentLengthHeader: length},
            sendTimeout: const Duration(hours: 1),
            receiveTimeout: const Duration(minutes: 5),
          ),
        );
        return CatalogDictionary.fromJson(
            Map<String, dynamic>.from(response.data));
      });

  /// Corrects the languages of a dictionary, or sets its description.
  Future<CatalogDictionary> update(String id, CatalogChanges changes) =>
      _guard(() async {
        Response response = await _dio.patch(
          'dictionaries/$id',
          data: changes.toJson(),
        );
        return CatalogDictionary.fromJson(
            Map<String, dynamic>.from(response.data));
      });

  /// Removes a dictionary from the server.
  Future<void> delete(String id) => _guard(() async {
        await _dio.delete('dictionaries/$id');
      });

  /// The languages the server has for the app's own text: the ones the app
  /// was built with, and any added on its strings page.
  Future<List<AppLanguage>> appLanguages() => _guard(() async {
        Response response = await _dio.get('strings');
        return ((response.data as Map)['languages'] as List)
            .map((json) => AppLanguage.fromJson(Map<String, dynamic>.from(json)))
            .toList();
      });

  /// The app's wording in [code] where the server's differs from what the
  /// app was built with, by string key; for a language the app wasn't built
  /// with, every string the server has.
  Future<Map<String, String>> appStrings(String code) => _guard(() async {
        Response response = await _dio.get('strings/$code/changes');
        Object? strings = (response.data as Map)['strings'];
        return strings is Map
            ? strings.map((key, value) => MapEntry('$key', '$value'))
            : <String, String>{};
      });
}
