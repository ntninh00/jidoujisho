import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yuuna/src/media/sources/epub_repair.dart';

const String _container = '''
<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';

String _chapter(int n) => '''
<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head><title>$n</title></head>
  <body><h1>Chapter $n</h1><p>Text of chapter $n.</p></body>
</html>''';

String _opf({
  String chapter2 = 'ch2.xhtml',
  String extraSpine = '',
}) =>
    '''
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="uid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="uid">test</dc:identifier>
    <dc:title>Test</dc:title>
    <dc:language>en</dc:language>
    <meta name="cover" content="cover"/>
  </metadata>
  <manifest>
    <item id="cover" href="cover.png" media-type="image/png" properties="cover-image"/>
    <item id="ch1" href="ch1.xhtml" media-type="application/xhtml+xml"/>
    <item id="ch2" href="$chapter2" media-type="application/xhtml+xml"/>
    <item id="ch3" href="ch3.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="ch1"/><itemref idref="ch2"/><itemref idref="ch3"/>$extraSpine
  </spine>
</package>''';

/// A small EPUB whose entries are [files], in order.
File _epub(Directory dir, String name, Map<String, String> files) {
  Archive archive = Archive();
  files.forEach((path, content) {
    List<int> bytes = utf8.encode(content);
    archive.addFile(path == 'mimetype'
        ? ArchiveFile.noCompress(path, bytes.length, bytes)
        : ArchiveFile(path, bytes.length, bytes));
  });
  File file = File('${dir.path}/$name.epub');
  file.writeAsBytesSync(ZipEncoder().encode(archive)!);
  return file;
}

Map<String, String> _book({
  String chapter2Name = 'OEBPS/ch2.xhtml',
  String chapter2Href = 'ch2.xhtml',
  String extraSpine = '',
  bool cover = true,
  bool container = true,
}) =>
    {
      'mimetype': 'application/epub+zip',
      if (container) 'META-INF/container.xml': _container,
      'OEBPS/content.opf':
          _opf(chapter2: chapter2Href, extraSpine: extraSpine),
      if (cover) 'OEBPS/cover.png': 'png',
      'OEBPS/ch1.xhtml': _chapter(1),
      chapter2Name: _chapter(2),
      'OEBPS/ch3.xhtml': _chapter(3),
    };

/// Every file the mended book names, checked to be in it.
void _expectWhole(File file) {
  Archive archive = ZipDecoder().decodeBytes(file.readAsBytesSync());
  Set<String> names = archive.files.map((f) => f.name).toSet();
  expect(archive.files.first.name, 'mimetype');
  String text(String name) =>
      utf8.decode(archive.findFile(name)!.content as List<int>);
  String container = text('META-INF/container.xml');
  String opfPath =
      RegExp('full-path="([^"]+)"').firstMatch(container)!.group(1)!;
  expect(names, contains(opfPath));
  String opf = text(opfPath);
  String folder = opfPath.contains('/')
      ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1)
      : '';
  Set<String> ids = {};
  for (Match item in RegExp(r'<item\b[^>]*>').allMatches(opf)) {
    String tag = item[0]!;
    String href = RegExp('href="([^"]+)"').firstMatch(tag)!.group(1)!;
    expect(names, contains('$folder$href'), reason: tag);
    ids.add(RegExp('id="([^"]+)"').firstMatch(tag)!.group(1)!);
  }
  for (Match itemref in RegExp(r'<itemref\b[^>]*>').allMatches(opf)) {
    String idref =
        RegExp('idref="([^"]+)"').firstMatch(itemref[0]!)!.group(1)!;
    expect(ids, contains(idref));
  }
  for (Match meta in RegExp('<meta name="cover"[^>]*>').allMatches(opf)) {
    String id = RegExp('content="([^"]+)"').firstMatch(meta[0]!)!.group(1)!;
    expect(ids, contains(id));
  }
}

void main() {
  late Directory dir;
  late Directory out;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('jdj_epub_');
    out = Directory('${dir.path}/out')..createSync();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('a sound book is left alone', () async {
    File book = _epub(dir, 'sound', _book());
    expect(await repairEpub(book, out), isNull);
  });

  test('a file that is not a zip is left alone', () async {
    File book = File('${dir.path}/text.epub')..writeAsStringSync('hello');
    expect(await repairEpub(book, out), isNull);
  });

  Map<String, Map<String, String>> broken = {
    'no container': _book(container: false),
    'a container naming another place': {
      ..._book(),
      'META-INF/container.xml':
          _container.replaceAll('OEBPS/content.opf', 'OPS/package.opf'),
    },
    'a percent-encoded name': _book(
      chapter2Name: 'OEBPS/ch 2.xhtml',
      chapter2Href: 'ch%202.xhtml',
    ),
    'a name in another case': _book(chapter2Name: 'OEBPS/Ch2.xhtml'),
    'a missing cover': _book(cover: false),
    'the reading order naming a chapter that is not there':
        _book(extraSpine: '<itemref idref="ghost"/>'),
  };
  broken.forEach((name, files) {
    test('mends $name', () async {
      File book = _epub(dir, name.replaceAll(' ', '-'), files);
      EpubRepair? repair = await repairEpub(book, out);
      expect(repair, isNotNull);
      expect(repair!.file.path.endsWith('${name.replaceAll(' ', '-')}.epub'),
          isTrue);
      _expectWhole(repair.file);
    });
  });

  test('mends names written with backslashes', () async {
    /* The archive writes every name with /, so the zip's own bytes are
     * changed: each name is the same length either way. */
    File book = _epub(dir, 'backslashes', _book());
    List<int> bytes = book.readAsBytesSync();
    List<int> from = utf8.encode('OEBPS/');
    List<int> to = utf8.encode('OEBPS${String.fromCharCode(92)}');
    for (int i = 0; i + from.length <= bytes.length; i++) {
      bool same = true;
      for (int j = 0; j < from.length && same; j++) {
        same = bytes[i + j] == from[j];
      }
      if (same) {
        bytes.setRange(i, i + to.length, to);
      }
    }
    book.writeAsBytesSync(bytes);
    EpubRepair? repair = await repairEpub(book, out);
    expect(repair, isNotNull);
    _expectWhole(repair!.file);
  });

  test('a missing chapter is left out and counted', () async {
    Map<String, String> files = _book()..remove('OEBPS/ch2.xhtml');
    EpubRepair? repair = await repairEpub(_epub(dir, 'gap', files), out);
    expect(repair!.missing, 1);
    _expectWhole(repair.file);
    Archive archive = ZipDecoder().decodeBytes(repair.file.readAsBytesSync());
    String opf = utf8.decode(
        archive.findFile('OEBPS/content.opf')!.content as List<int>);
    expect(opf, isNot(contains('idref="ch2"')));
    expect(opf, contains('idref="ch3"'));
  });
}
