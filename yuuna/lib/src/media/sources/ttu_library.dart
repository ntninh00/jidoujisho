import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive_io.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as path;
import 'package:yuuna/language.dart';
import 'package:yuuna/media.dart';

/// A book stored in ッツ Ebook Reader, as shown on the shelf.
class TtuBook {
  /// Describe a book in ッツ's storage for one language.
  TtuBook({
    required this.language,
    required this.port,
    required this.id,
    required this.title,
    required this.characters,
    required this.lastBookOpen,
    required this.lastBookModified,
    required this.exploredCharCount,
    required this.progress,
    required this.coverPath,
  });

  /// The language whose copy of ッツ stores this book.
  final Language language;

  /// Port of the local ッツ server for [language].
  final int port;

  /// ッツ's id for the book.
  final int id;

  /// Title from the book's metadata.
  final String title;

  /// Characters in the book, as counted by ッツ. Zero for old imports.
  final int characters;

  /// When the book was last opened, in milliseconds since epoch.
  final int lastBookOpen;

  /// When the book was imported or changed, in milliseconds since epoch.
  final int lastBookModified;

  /// ッツ's saved reading position in characters.
  final int exploredCharCount;

  /// ッツ's saved reading position as a fraction from 0 to 1.
  final double progress;

  /// Path to the cached cover thumbnail, if the book has a cover.
  final String? coverPath;

  /// Identifies the book across both languages.
  String get key => '$port/$id';

  /// Characters in the book, worked out from the position when ッツ did not
  /// record a count.
  int get totalCharacters {
    if (characters > 0) {
      return characters;
    }
    if (progress > 0) {
      return (exploredCharCount / progress).round();
    }
    return 0;
  }

  /// The address ッツ uses for this book.
  String get readerUrl => 'http://localhost:$port/b.html?id=$id&?title=$title';

  /// The media item used to open the book and keep title and cover edits.
  MediaItem toMediaItem() {
    return MediaItem(
      mediaIdentifier: readerUrl,
      title: title,
      imageUrl: coverPath == null ? null : 'file://$coverPath',
      mediaTypeIdentifier: ReaderTtuSource.instance.mediaType.uniqueKey,
      mediaSourceIdentifier: ReaderTtuSource.instance.uniqueKey,
      position: exploredCharCount,
      duration: max(totalCharacters, 1),
      canDelete: false,
      canEdit: true,
    );
  }
}

/// A saved position to open a book at.
class TtuPosition {
  /// Describe a position in a book.
  const TtuPosition({
    required this.characters,
    required this.progress,
  });

  /// ッツ's character position.
  final int characters;

  /// Position as a fraction from 0 to 1.
  final double progress;
}

/// What the reader should do the next time it opens a book.
class TtuLaunch {
  /// Open [book], optionally at a memo, remembering where the reader was.
  TtuLaunch({
    required this.book,
    this.target,
    this.excerpt,
    this.memo,
    this.returnTo,
  });

  /// The book to open.
  final TtuBook book;

  /// Where to open the book. Null opens at ッツ's saved position.
  final TtuPosition? target;

  /// The quoted line to highlight once the page shows.
  final String? excerpt;

  /// The memo text to show while the book loads.
  final String? memo;

  /// The position before the jump, offered as a way back.
  final TtuPosition? returnTo;

  /// The first address to load.
  String get initialUrl {
    TtuPosition? position = target;
    if (position == null) {
      return book.readerUrl;
    }
    return jumpUrl(book: book, position: position);
  }

  /// The address that sets ッツ's position and then opens [book].
  static String jumpUrl({
    required TtuBook book,
    required TtuPosition position,
  }) {
    return Uri.http('localhost:${book.port}', '/jidoujisho/jump.html', {
      'id': '${book.id}',
      'c': '${position.characters}',
      'p': position.progress.toStringAsFixed(5),
      'title': book.title,
    }).toString();
  }
}

/// Page settings for books in one language. ッツ reads these from its local
/// storage when a book opens, so they are written there before ッツ starts.
class TtuPagePreset {
  /// Describe the page settings for one language.
  TtuPagePreset({
    required this.theme,
    required this.fontSize,
    required this.vertical,
    required this.paginated,
    required this.furigana,
    this.fontFamily = '',
    this.lineHeight = 1.65,
    this.margin = 0,
    this.columns = 0,
    this.furiganaStyle = 'partial',
    this.avoidPageBreak = false,
    this.blurImages = true,
  });

  /// ッツ's font for the text, or empty for its default serif.
  String fontFamily;

  /// Line height as a multiple of the font size.
  double lineHeight;

  /// Space at the page edges in CSS pixels: top and bottom for horizontal
  /// text, left and right for vertical text.
  int margin;

  /// Page columns in Pages layout, or 0 to let ッツ choose.
  int columns;

  /// How hidden furigana shows: `partial` greyed out, `full` hidden, or
  /// `toggle` shown on tap.
  String furiganaStyle;

  /// Keeps a paragraph on one page instead of splitting it.
  bool avoidPageBreak;

  /// Covers pictures until tapped, as ッツ does for spoilers.
  bool blurImages;

  /// ッツ's built-in fonts, with the empty name meaning its default serif.
  static const List<String> fontFamilies = [
    '',
    'Noto Sans JP',
    'Shippori Mincho',
    'Klee One',
  ];

  /// ッツ theme name without the `-theme` suffix, or null to leave ッツ's own.
  String? theme;

  /// Font size in CSS pixels.
  int fontSize;

  /// Vertical, right-to-left text when true.
  bool vertical;

  /// Pages when true, continuous scrolling when false.
  bool paginated;

  /// Show furigana when true.
  bool furigana;

  /// The themes ッツ offers, in its own order.
  static const List<String> themes = [
    'light',
    'ecru',
    'water',
    'gray',
    'dark',
    'black',
  ];

  /// Background and text colours of each ッツ theme.
  static const Map<String, List<int>> themeColors = {
    'light': [0xFFF9F9F9, 0xDE000000],
    'ecru': [0xFFF7F6EB, 0xDE000000],
    'water': [0xFFDFECF4, 0xDE000000],
    'gray': [0xFF23272A, 0xDBFFFFFF],
    'dark': [0xFF121212, 0xDBFFFFFF],
    'black': [0xFF000000, 0xDBFFFFFF],
  };

  /// Script that writes these settings to ッツ's local storage. Runs before
  /// ッツ's own scripts.
  String toScript({required bool autoBookmark}) {
    String? currentTheme = theme;
    return '''
(function () {
  try {
    var s = window.localStorage;
    ${currentTheme == null ? '' : "s.setItem('theme', '$currentTheme-theme');"}
    s.setItem('fontSize', '$fontSize');
    s.setItem('writingMode', '${vertical ? 'vertical-rl' : 'horizontal-tb'}');
    s.setItem('viewMode', '${paginated ? 'paginated' : 'continuous'}');
    s.setItem('hideFurigana', '${furigana ? '0' : '1'}');
    s.setItem('furiganaStyle', '${const [
      'partial',
      'full',
      'toggle'
    ].contains(furiganaStyle) ? furiganaStyle : 'partial'}');
    s.setItem('autoBookmark', '${autoBookmark ? '1' : '0'}');
    s.setItem('fontFamilyGroupOne', '${fontFamilies.contains(fontFamily) ? fontFamily : ''}');
    s.setItem('lineHeight', '$lineHeight');
    s.setItem('firstDimensionMargin', '$margin');
    s.setItem('pageColumns', '$columns');
    s.setItem('avoidPageBreak', '${avoidPageBreak ? '1' : '0'}');
    s.setItem('hideSpoilerImage', '${blurImages ? '1' : '0'}');
  } catch (e) {}
})();
''';
  }
}

/// Reads and changes ッツ's library from the app, without showing ッツ's pages.
/// Each call runs a hidden WebView on the ッツ origin for one language.
class TtuLibrary {
  TtuLibrary._();

  static String? _libraryScript;
  static String? _readerScript;
  static String? _fitScript;

  /// Keeps wide formulas, tables and code inside the page. Runs before ッツ.
  static Future<String> get fitScript async {
    return _fitScript ??= await rootBundle
        .loadString('assets/ttu-ebook-reader/jidoujisho/fit.js');
  }

  /// The library bridge script.
  static Future<String> get libraryScript async {
    return _libraryScript ??= await rootBundle
        .loadString('assets/ttu-ebook-reader/jidoujisho/library.js');
  }

  /// The reader bridge script injected into book pages.
  static Future<String> get readerScript async {
    return _readerScript ??= await rootBundle
        .loadString('assets/ttu-ebook-reader/jidoujisho/reader.js');
  }

  static Future<T> _onPage<T>({
    required int port,
    required String page,
    required Future<T> Function(InAppWebViewController controller) action,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    Completer<InAppWebViewController> ready = Completer();
    HeadlessInAppWebView view = HeadlessInAppWebView(
      initialUrlRequest:
          URLRequest(url: WebUri('http://localhost:$port/$page')),
      onLoadStop: (controller, url) {
        if (!ready.isCompleted) {
          ready.complete(controller);
        }
      },
      onReceivedError: (controller, request, error) {
        if ((request.isForMainFrame ?? true) && !ready.isCompleted) {
          ready.completeError(StateError(error.description));
        }
      },
    );

    try {
      await view.run();
      InAppWebViewController controller = await ready.future.timeout(timeout);
      return await action(controller).timeout(timeout);
    } finally {
      await view.dispose();
    }
  }

  static Future<Object?> _call(
    InAppWebViewController controller,
    String body,
    Map<String, dynamic> arguments,
  ) async {
    CallAsyncJavaScriptResult? result = await controller.callAsyncJavaScript(
      functionBody: body,
      arguments: arguments,
    );
    if (result?.error != null) {
      throw StateError(result!.error!);
    }
    return result?.value;
  }

  static final RegExp _coverName = RegExp(r'^(\d+)_(\d+)_(\d+)\.jpg$');

  /// Lists the books of one language. Covers are cached as small JPEG files
  /// in [coverDirectory] and only fetched again when a book changes.
  static Future<List<TtuBook>> listBooks({
    required Language language,
    required int port,
    required Directory coverDirectory,
  }) async {
    Directory directory = Directory(path.join(coverDirectory.path, 'ttu'));
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }

    Map<String, String> known = {};
    Map<int, String> cached = {};
    for (FileSystemEntity file in directory.listSync()) {
      RegExpMatch? match = _coverName.firstMatch(path.basename(file.path));
      if (match != null && int.parse(match.group(1)!) == port) {
        known[match.group(2)!] = match.group(3)!;
        cached[int.parse(match.group(2)!)] = file.path;
      }
    }

    Object? value = await _onPage(
      port: port,
      page: 'jidoujisho/shelf.html',
      action: (controller) => _call(
        controller,
        'return await window.jdjLibrary.list(known);',
        {'known': known},
      ),
    );

    if (value is! Map) {
      return [];
    }
    List<Object?> raw = (value['books'] as List?) ?? [];
    List<TtuBook> books = [];

    for (Object? entry in raw) {
      if (entry is! Map) {
        continue;
      }
      int id = (entry['id'] as num).toInt();
      int modified = ((entry['lastBookModified'] as num?) ?? 0).toInt();
      String? coverPath = cached[id];

      if (entry['coverChanged'] == true) {
        if (coverPath != null) {
          File(coverPath).deleteSync();
          coverPath = null;
        }
        Object? cover = entry['cover'];
        if (cover is String && cover.startsWith('data:')) {
          UriData? data = Uri.tryParse(cover)?.data;
          if (data != null) {
            String file =
                path.join(directory.path, '${port}_${id}_$modified.jpg');
            File(file).writeAsBytesSync(data.contentAsBytes());
            coverPath = file;
          }
        }
      }

      books.add(
        TtuBook(
          language: language,
          port: port,
          id: id,
          title: (entry['title'] as String?) ?? '',
          characters: ((entry['characters'] as num?) ?? 0).toInt(),
          lastBookOpen: ((entry['lastBookOpen'] as num?) ?? 0).toInt(),
          lastBookModified: modified,
          exploredCharCount:
              ((entry['exploredCharCount'] as num?) ?? 0).toInt(),
          progress: ((entry['progress'] as num?) ?? 0).toDouble(),
          coverPath: coverPath,
        ),
      );
    }

    /// Remove covers of books that are gone.
    Set<int> ids = books.map((book) => book.id).toSet();
    cached.forEach((id, file) {
      if (!ids.contains(id) && File(file).existsSync()) {
        File(file).deleteSync();
      }
    });

    return books;
  }

  /// Hands [files] to ッツ's own importer. Returns the ids of the new books.
  static Future<List<int>> importFiles({
    required int port,
    required List<File> files,
  }) {
    return _onPage(
      port: port,
      page: 'manage.html',
      timeout: const Duration(minutes: 4),
      action: (controller) async {
        await controller.evaluateJavascript(source: await libraryScript);

        List<String> names = [];
        for (File file in files) {
          String name = path.basename(file.path);
          while (names.contains(name)) {
            name = '${names.length}_$name';
          }
          names.add(name);

          Uint8List bytes = await file.readAsBytes();
          const int chunk = 3 * 128 * 1024;
          for (int start = 0; start < bytes.length; start += chunk) {
            String encoded = base64Encode(
              bytes.sublist(start, min(start + chunk, bytes.length)),
            );
            await _call(
              controller,
              'return window.jdjLibrary.stage(key, chunk);',
              {'key': name, 'chunk': encoded},
            );
          }
        }

        Object? value = await _call(
          controller,
          'return await window.jdjLibrary.importStaged(names, 200000);',
          {'names': names},
        );

        if (value is! Map) {
          throw StateError('ッツ did not answer');
        }
        List<int> added = ((value['added'] as List?) ?? [])
            .map((id) => (id as num).toInt())
            .toList();
        Object? error = value['error'];
        if (added.isEmpty && error != null) {
          throw StateError(error.toString());
        }
        return added;
      },
    );
  }

  /// Deletes books, with their saved positions, from ッツ.
  static Future<void> deleteBooks({
    required int port,
    required List<int> ids,
  }) {
    return _onPage(
      port: port,
      page: 'jidoujisho/shelf.html',
      action: (controller) => _call(
        controller,
        'return await window.jdjLibrary.deleteBooks(ids);',
        {'ids': ids},
      ),
    );
  }

  /// Reads the language code from an EPUB's or HTMLZ's metadata, falling back
  /// to the script of its title. Returns null when it cannot tell.
  static Future<String?> detectLanguageCode(String filePath) {
    return compute(_detectLanguageCode, filePath);
  }
}

Future<String?> _detectLanguageCode(String filePath) async {
  InputFileStream? input;
  try {
    input = InputFileStream(filePath);
    Archive archive = ZipDecoder().decodeBuffer(input);

    ArchiveFile? opf;
    ArchiveFile? container = archive.findFile('META-INF/container.xml');
    if (container != null) {
      String xml = utf8.decode(
        container.content as List<int>,
        allowMalformed: true,
      );
      String? opfPath = RegExp('full-path="([^"]+)"').firstMatch(xml)?.group(1);
      if (opfPath != null) {
        opf = archive.findFile(opfPath);
      }
    }
    opf ??= archive.files
        .firstWhereOrNull((file) => file.name.toLowerCase().endsWith('.opf'));
    if (opf == null) {
      return null;
    }

    String text = utf8.decode(opf.content as List<int>, allowMalformed: true);
    String? code =
        RegExp('<dc:language[^>]*>\\s*([A-Za-z-]+)').firstMatch(text)?.group(1);
    if (code != null) {
      return code.toLowerCase().split('-').first;
    }

    String title =
        RegExp('<dc:title[^>]*>([^<]*)').firstMatch(text)?.group(1) ?? '';
    if (RegExp('[぀-ヿ一-鿿]').hasMatch(title)) {
      return 'ja';
    }
    return null;
  } catch (_) {
    return null;
  } finally {
    await input?.close();
  }
}
