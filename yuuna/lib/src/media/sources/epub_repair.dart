import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;

/// A copy of an EPUB mended so ッツ can add it.
class EpubRepair {
  /// Describe a mended copy.
  const EpubRepair({required this.file, required this.missing});

  /// The mended copy, with the original's name.
  final File file;

  /// Chapters the book lists but the file lacks, left out of the copy.
  final int missing;
}

/// Mends what stops ッツ from adding an EPUB, which refuses a book when any
/// file it names cannot be found: a missing or wrong `container.xml`, names
/// written with `\`, percent-encoded or in another case than in the zip, and
/// files the book lists but lacks, which are left out. A book that needs
/// none of this, or is not a zip at all, gives null and is added as it is.
/// The copy is written to [into].
Future<EpubRepair?> repairEpub(File file, Directory into) async {
  String source = file.path;
  String target = path.join(into.path, path.basename(file.path));
  int? missing = await Isolate.run(() => _mend(source, target));
  if (missing == null) {
    return null;
  }
  return EpubRepair(file: File(target), missing: missing);
}

const String _containerPath = 'META-INF/container.xml';

/// Mends the EPUB at [source] into [target]. Returns how many chapters were
/// missing, or null when nothing needed mending.
Future<int?> _mend(String source, String target) async {
  InputFileStream input = InputFileStream(source);
  try {
    ZipDecoder decoder = ZipDecoder();
    Archive archive;
    try {
      archive = decoder.decodeBuffer(input);
    } catch (_) {
      return null;
    }

    /// The zip's own names: the archive reads `\` as `/`, as the book means
    /// it, which ッツ does not.
    bool changed = decoder.directory.fileHeaders.any((header) =>
        header.filename.contains(r'\') || header.filename.startsWith('/'));

    /// Entries by their name in the book: `/` between folders, no leading
    /// slash.
    Map<String, ArchiveFile> files = {};
    for (ArchiveFile file in archive.files) {
      if (!file.isFile) {
        continue;
      }
      String name = file.name.replaceFirst(RegExp('^/+'), '');
      files.putIfAbsent(name, () => file);
    }
    Map<String, String> byLowerCase = {
      for (String name in files.keys) name.toLowerCase(): name,
    };

    /// The entry a reference means: as written, percent-decoded, or in
    /// another case.
    String? find(String wanted) {
      if (files.containsKey(wanted)) {
        return wanted;
      }
      String decoded = wanted;
      try {
        decoded = Uri.decodeFull(wanted);
      } catch (_) {
        /* Kept as written. */
      }
      if (files.containsKey(decoded)) {
        return decoded;
      }
      return byLowerCase[wanted.toLowerCase()] ??
          byLowerCase[decoded.toLowerCase()];
    }

    String text(String name) {
      List<int> bytes = files[name]!.content as List<int>;
      return utf8.decode(bytes, allowMalformed: true);
    }

    /* The package file, as container.xml names it, or the one in the zip. */
    String? opfPath;
    String? container = find(_containerPath);
    if (container != null) {
      String? named = _attribute(
        RegExp(r'<(?:\w+:)?rootfile\b[^>]*>').firstMatch(text(container))?[0] ??
            '',
        'full-path',
      );
      String? found = named == null ? null : find(_unescape(named));
      if (found != null) {
        opfPath = found;
        if (found != _unescape(named!) || container != _containerPath) {
          changed = true;
        }
      }
    }
    if (opfPath == null) {
      List<String> packages = files.keys
          .where((name) => name.toLowerCase().endsWith('.opf'))
          .toList()
        ..sort((a, b) => '/'.allMatches(a).length != '/'.allMatches(b).length
            ? '/'.allMatches(a).length.compareTo('/'.allMatches(b).length)
            : a.compareTo(b));
      if (packages.isEmpty) {
        return null;
      }
      opfPath = packages.first;
      changed = true;
    }

    /* The manifest: names as they are in the zip, missing files left out. */
    String opf = text(opfPath);
    String folder = path.posix.dirname(opfPath);
    folder = folder == '.' ? '' : folder;
    Set<String> kept = {};
    Set<String> dropped = {};
    opf = opf.replaceAllMapped(
        RegExp(r'<(?:\w+:)?item\b[^>]*>', caseSensitive: false), (match) {
      String tag = match[0]!;
      String? href = _attribute(tag, 'href');
      String? id = _attribute(tag, 'id');
      if (href == null) {
        return tag;
      }
      String file = _unescape(href).split('#').first;
      String wanted =
          path.posix.normalize(folder.isEmpty ? file : '$folder/$file');
      String? actual = find(wanted);
      if (actual == null) {
        changed = true;
        if (id != null) {
          dropped.add(id);
        }
        return '';
      }
      if (actual != wanted) {
        changed = true;
        String relative =
            path.posix.relative(actual, from: folder.isEmpty ? '.' : folder);
        tag = _withAttribute(tag, 'href', _escape(relative));
      }
      if (id != null) {
        kept.add(id);
      }
      return tag;
    });

    /* The reading order: only chapters that are there. */
    int missing = 0;
    opf = opf.replaceAllMapped(
        RegExp(r'<(?:\w+:)?itemref\b[^>]*>', caseSensitive: false), (match) {
      String? idref = _attribute(match[0]!, 'idref');
      if (idref != null && kept.contains(idref)) {
        return match[0]!;
      }
      changed = true;
      missing++;
      return '';
    });

    /* What else points at what was left out. */
    opf = opf.replaceAllMapped(
        RegExp(r'<(?:\w+:)?meta\b[^>]*>', caseSensitive: false), (match) {
      String tag = match[0]!;
      bool cover = _attribute(tag, 'name')?.toLowerCase() == 'cover';
      String? content = _attribute(tag, 'content');
      return cover && content != null && !kept.contains(content) ? '' : tag;
    });
    opf = opf.replaceAllMapped(
        RegExp(r'<(?:\w+:)?spine\b[^>]*>', caseSensitive: false), (match) {
      String tag = match[0]!;
      String? toc = _attribute(tag, 'toc');
      return toc != null && !kept.contains(toc)
          ? tag.replaceFirst(RegExp(r'\s+toc\s*=\s*("[^"]*"|' "'[^']*')"), '')
          : tag;
    });
    opf = opf.replaceAllMapped(
        RegExp(r'<(?:\w+:)?reference\b[^>]*>', caseSensitive: false), (match) {
      String tag = match[0]!;
      String? href = _attribute(tag, 'href');
      if (href == null) {
        return tag;
      }
      String file = _unescape(href).split('#').first;
      return find(path.posix
                  .normalize(folder.isEmpty ? file : '$folder/$file')) ==
              null
          ? ''
          : tag;
    });

    if (!changed) {
      return null;
    }

    ZipFileEncoder encoder = ZipFileEncoder()..create(target);
    List<int> mimetype = utf8.encode('application/epub+zip');
    encoder.addArchiveFile(
        ArchiveFile.noCompress('mimetype', mimetype.length, mimetype));
    List<int> containerXml = utf8.encode(
      '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<container version="1.0" '
      'xmlns="urn:oasis:names:tc:opendocument:xmlns:container">\n'
      '<rootfiles><rootfile full-path="${_escape(opfPath)}" '
      'media-type="application/oebps-package+xml"/></rootfiles>\n'
      '</container>\n',
    );
    encoder.addArchiveFile(
        ArchiveFile(_containerPath, containerXml.length, containerXml));
    List<int> package = utf8.encode(opf);
    for (MapEntry<String, ArchiveFile> entry in files.entries) {
      String name = entry.key;
      if (name == 'mimetype' || name == container || name == _containerPath) {
        continue;
      }
      List<int> data =
          name == opfPath ? package : entry.value.content as List<int>;
      encoder.addArchiveFile(ArchiveFile(name, data.length, data));
      entry.value.clear();
    }
    encoder.close();
    return missing;
  } finally {
    await input.close();
  }
}

/// The value of attribute [name] in an XML start tag.
String? _attribute(String tag, String name) {
  Match? match = RegExp(
    '(?:^|\\s)${RegExp.escape(name)}\\s*=\\s*(?:"([^"]*)"|\'([^\']*)\')',
    caseSensitive: false,
  ).firstMatch(tag);
  return match == null ? null : (match[1] ?? match[2]);
}

/// [tag] with attribute [name] set to [value], already escaped.
String _withAttribute(String tag, String name, String value) {
  return tag.replaceFirstMapped(
    RegExp(
      '(\\s${RegExp.escape(name)}\\s*=\\s*)(?:"[^"]*"|\'[^\']*\')',
      caseSensitive: false,
    ),
    (match) => '${match[1]}"$value"',
  );
}

String _unescape(String value) => value
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');

String _escape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
