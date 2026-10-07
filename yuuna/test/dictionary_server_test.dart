import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:yuuna/dictionary.dart';

/// Runs the app's dictionary server client against a real server. Opt in
/// with JDJ_DICT_SERVER (address), JDJ_DICT_ADMIN and JDJ_DICT_READER
/// (tokens) and JDJ_DICT_FILES (dictionary zips, separated by ;). With
/// JDJ_DICT_DUMP, the catalog and some searches are saved there as JSON.
void main() {
  String? url = Platform.environment['JDJ_DICT_SERVER'];
  String admin = Platform.environment['JDJ_DICT_ADMIN'] ?? '';
  String reader = Platform.environment['JDJ_DICT_READER'] ?? '';
  List<String> files = (Platform.environment['JDJ_DICT_FILES'] ?? '')
      .split(';')
      .where((file) => file.isNotEmpty)
      .toList();
  String? dump = Platform.environment['JDJ_DICT_DUMP'];
  bool skip = url == null;

  DictionaryServer adminServer() => DictionaryServer(url: url!, token: admin);
  DictionaryServer readServer() => DictionaryServer(url: url!, token: reader);

  Future<CatalogDictionary> settled(String id) async {
    for (int i = 0; i < 600; i++) {
      CatalogDictionary entry = await readServer().get(id);
      if (!entry.isPreparing) {
        return entry;
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
    throw StateError('indexing did not finish');
  }

  CatalogDictionary named(List<CatalogDictionary> all, String title) =>
      all.firstWhere((entry) => entry.title == title);

  test('tokens decide what the app may do', () async {
    expect(await readServer().role(), 'read');
    expect(await adminServer().role(), 'admin');
    await expectLater(
      DictionaryServer(url: url!, token: 'wrong-token-0123456789abcdef').role(),
      throwsA(isA<DictionaryServerException>()
          .having((e) => e.statusCode, 'status', 401)),
    );
    await expectLater(
      readServer().upload(File(files.first)),
      throwsA(isA<DictionaryServerException>()
          .having((e) => e.statusCode, 'status', 403)),
    );
  }, skip: skip);

  test('upload, sections, search, download, relabel, delete', () async {
    DictionaryServer server = adminServer();
    for (String file in files) {
      int sent = 0;
      CatalogDictionary added = await server.upload(
        File(file),
        onProgress: (done, total) => sent = done,
      );
      expect(sent, File(file).lengthSync());
      CatalogDictionary ready = await settled(added.id);
      expect(ready.status, 'ready', reason: '${ready.title}: ${ready.error}');
    }

    await expectLater(
      server.upload(File(files.first)),
      throwsA(isA<DictionaryServerException>()
          .having((e) => e.statusCode, 'status', 409)
          .having((e) => e.message, 'message', contains('already'))),
    );
    File pack = File(r'C:\Users\Admin\Downloads\oald-release-yomitan.zip');
    if (pack.existsSync()) {
      await expectLater(
        server.upload(pack),
        throwsA(isA<DictionaryServerException>().having(
            (e) => e.message, 'message', contains('holds other dictionaries'))),
      );
    }

    List<CatalogDictionary> all = await readServer().list();
    Map<String, CatalogSection> sections = {
      for (CatalogDictionary entry in all) entry.title: entry.section,
    };
    expect(sections['新和英'], CatalogSection.bilingual);
    expect(sections['Babylon'], CatalogSection.bilingual);
    expect(sections['seth-oald'], CatalogSection.monolingual);
    expect(sections['yzk-freq-en'], CatalogSection.frequency);
    expect(sections['seth-oald-ipa'], CatalogSection.pronunciation);
    CatalogDictionary shinwaei = named(all, '新和英');
    expect((shinwaei.sourceLanguage, shinwaei.targetLanguage), ('ja', 'en'));
    CatalogDictionary babylon = named(all, 'Babylon');
    expect((babylon.sourceLanguage, babylon.targetLanguage), ('vi', 'en'));

    CatalogResults cat = await readServer().search(shinwaei.id, '猫');
    Dictionary asDictionary = Dictionary(
      id: -1,
      name: shinwaei.title,
      formatKey: 'yomichan',
      order: 0,
    );
    List<DictionaryEntry> entries = cat.entriesFor(asDictionary);
    expect(entries.first.heading.value!.term, '猫');
    expect(entries.first.heading.value!.reading, 'ねこ');
    expect(entries.first.definitions.single, contains('a cat'));
    expect(entries.map((entry) => entry.id).toSet(), hasLength(entries.length));

    CatalogResults ipa =
        await readServer().search(named(all, 'seth-oald-ipa').id, 'house');
    expect(ipa.metaLines.first.text, contains('/haʊs/'));
    CatalogResults freq =
        await readServer().search(named(all, 'yzk-freq-en').id, 'house');
    expect(freq.metaLines.first.text, startsWith('#'));

    File target = File(path.join(Directory.systemTemp.path, 'jdj-babylon.zip'));
    int received = 0;
    await readServer().download(babylon, target,
        onProgress: (done, total) => received = done);
    expect(target.lengthSync(), babylon.size);
    expect(received, babylon.size);
    target.deleteSync();

    CatalogDictionary relabelled = await server.update(babylon.id,
        const CatalogChanges(languages: (source: 'vi', target: 'fr')));
    expect(relabelled.targetLanguage, 'fr');
    expect(relabelled.languagesGuessed, isFalse);
    await server.update(babylon.id,
        const CatalogChanges(languages: (source: 'vi', target: 'en')));

    if (dump != null) {
      Dio raw = Dio(BaseOptions(
        baseUrl: '${DictionaryServer.normaliseUrl(url!)}/api/',
        headers: {'Authorization': 'Bearer $reader'},
      ));
      Directory(dump).createSync(recursive: true);
      Future<void> save(String name, String route,
          [Map<String, dynamic>? query]) async {
        Response response = await raw.get(route, queryParameters: query);
        File(path.join(dump, name))
            .writeAsStringSync(jsonEncode(response.data));
      }

      await save('catalog.json', 'dictionaries');
      await save('search-shinwaei.json', 'dictionaries/${shinwaei.id}/search',
          {'q': '猫'});
      await save('search-babylon.json', 'dictionaries/${babylon.id}/search',
          {'q': 'nhà'});
      CatalogDictionary? jitendex =
          all.where((entry) => entry.title.startsWith('Jitendex')).firstOrNull;
      if (jitendex != null) {
        await save('search-jitendex.json', 'dictionaries/${jitendex.id}/search',
            {'q': '猫'});
      }
    }

    CatalogDictionary extra = named(all, 'seth-oald-extra');
    await server.delete(extra.id);
    List<CatalogDictionary> after = await readServer().list();
    expect(after.map((entry) => entry.id), isNot(contains(extra.id)));
  }, skip: skip, timeout: const Timeout(Duration(minutes: 10)));

  test('admins describe dictionaries', () async {
    DictionaryServer server = adminServer();
    String title = 'jdj note test ${DateTime.now().millisecondsSinceEpoch}';
    Archive archive = Archive();
    void add(String name, Object json) {
      List<int> bytes = utf8.encode(jsonEncode(json));
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
    }

    add('index.json', {
      'title': title,
      'revision': '1',
      'format': 3,
      'description': 'From the index',
    });
    add('term_bank_1.json', [
      ['猫', 'ねこ', '', '', 0, ['cat'], 1, ''],
    ]);
    File zip = File(path.join(Directory.systemTemp.path, 'jdj-note.zip'))
      ..writeAsBytesSync(ZipEncoder().encode(archive)!);
    CatalogDictionary added = await settled((await server.upload(zip)).id);
    zip.deleteSync();
    expect(added.note, isNull);
    expect(added.description, 'From the index');

    CatalogDictionary described = await server.update(
        added.id,
        const CatalogChanges(notes: {
          'en': '  Small, for testing.  ',
          'vi': 'Nhỏ, để thử',
        }));
    expect(described.note, 'Small, for testing.');
    expect(described.notes,
        {'en': 'Small, for testing.', 'vi': 'Nhỏ, để thử'});
    expect(described.languagesGuessed, added.languagesGuessed);
    expect(named(await readServer().list(), title).note, 'Small, for testing.');
    await expectLater(
      readServer().update(added.id, const CatalogChanges(notes: {'en': 'x'})),
      throwsA(isA<DictionaryServerException>()
          .having((e) => e.statusCode, 'status', 403)),
    );

    CatalogDictionary relabelled = await server.update(
        added.id, const CatalogChanges(languages: (source: 'ja', target: 'vi')));
    expect(relabelled.note, 'Small, for testing.');
    CatalogDictionary cleared =
        await server.update(added.id, const CatalogChanges(notes: {'en': ''}));
    expect(cleared.note, isNull);
    expect(cleared.notes, {'vi': 'Nhỏ, để thử'});
    expect(cleared.targetLanguage, 'vi');
    await server.delete(added.id);
  }, skip: skip, timeout: const Timeout(Duration(minutes: 2)));
}
