import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:yuuna/models.dart';

Map<String, dynamic> release(int dev, {String theme = 'Things'}) => {
      'tag_name': 'v2.9.1-dev.$dev',
      'name': '2.9.1-dev.$dev · $theme',
      'draft': false,
      'published_at': '2026-10-0${dev % 9 + 1}T11:27:07Z',
      'body': '- First change\n- Second change\n\narm64 Android. Installs as '
          '**jidoujisho (dev)**, next to the regular app.',
      'assets': [
        {
          'name': 'jidoujisho-dev-2.9.1-dev.$dev-arm64.apk',
          'size': 195612429,
          'digest': 'sha256:9f4080d0',
          'browser_download_url':
              'https://github.com/x/releases/download/v2.9.1-dev.$dev/a.apk',
        }
      ],
    };

void main() {
  test('versions are ordered by number, then by dev build', () {
    expect(compareAppVersions('2.9.1-dev.12', '2.9.1-dev.9'), greaterThan(0));
    expect(compareAppVersions('2.9.1-dev.3', '2.9.1-dev.3'), 0);
    expect(compareAppVersions('2.10.0-dev.1', '2.9.1-dev.30'), greaterThan(0));
    // A version without a dev number is the finished one, newer than its
    // dev builds.
    expect(compareAppVersions('2.9.1', '2.9.1-dev.12'), greaterThan(0));
  });

  test("a release's notes are its points, without the install line", () {
    AppRelease parsed = AppRelease.fromJson(release(12, theme: 'Grammar'));
    expect(parsed.version, '2.9.1-dev.12');
    expect(parsed.theme, 'Grammar');
    expect(parsed.points, ['First change', 'Second change']);
    expect(parsed.apkSize, 195612429);
    expect(parsed.apkSha256, '9f4080d0');
    // What is kept between checks reads back the same.
    AppRelease kept = AppRelease.fromJson(
        jsonDecode(jsonEncode(parsed.toJson())) as Map<String, dynamic>);
    expect([kept.version, kept.apkUrl, kept.apkSha256, kept.points],
        [parsed.version, parsed.apkUrl, parsed.apkSha256, parsed.points]);
  });

  test('every release missed since the one installed is listed, newest first',
      () async {
    Directory directory = Directory.systemTemp.createTempSync('updates');
    Hive.init(directory.path);
    Box box = await Hive.openBox('preferences');
    await box.put(
      'app_releases',
      jsonEncode([10, 12, 11, 9]
          .map((dev) => AppRelease.fromJson(release(dev)).toJson())
          .toList()),
    );
    AppUpdates updates = AppUpdates(
      preferences: box,
      installedVersion: '2.9.1-dev.10',
      enabled: true,
    )..loadKept();
    expect(updates.newer.value.map((release) => release.version),
        ['2.9.1-dev.12', '2.9.1-dev.11']);
    expect(updates.installed?.version, '2.9.1-dev.10');

    AppUpdates regular = AppUpdates(
      preferences: box,
      installedVersion: '2.9.1',
      enabled: false,
    )..loadKept();
    expect(regular.newer.value, isEmpty);
    await box.close();
    directory.deleteSync(recursive: true);
  });

  group('an update download', () {
    late HttpServer server;
    late Directory directory;
    final Uint8List apk =
        Uint8List.fromList(List.generate(300000, (i) => i * 7 % 251));
    final List<String?> ranges = [];

    /// The first answer sends a third of the file and then nothing, as a
    /// connection the phone left behind; later ones honour the range unless
    /// [ignoreRange].
    Future<void> serve({bool ignoreRange = false}) async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        String? range = request.headers.value(HttpHeaders.rangeHeader);
        ranges.add(range);
        if (ranges.length == 1) {
          request.response.contentLength = apk.length;
          request.response.add(apk.sublist(0, 100000));
          await request.response.flush();
          return;
        }
        int from = !ignoreRange && range != null
            ? int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!)
            : 0;
        request.response.statusCode =
            from > 0 ? HttpStatus.partialContent : HttpStatus.ok;
        request.response.contentLength = apk.length - from;
        request.response.add(apk.sublist(from));
        await request.response.close();
      });
    }

    setUp(() {
      ranges.clear();
      directory = Directory.systemTemp.createTempSync('download');
    });

    tearDown(() async {
      await server.close(force: true);
      directory.deleteSync(recursive: true);
    });

    Future<File> download({CancelToken? cancelToken}) async {
      File file = File('${directory.path}/2.9.1-dev.15.apk.part');
      List<double> progress = [];
      await downloadResuming(
        url: 'http://127.0.0.1:${server.port}/a.apk',
        file: file,
        size: apk.length,
        onProgress: progress.add,
        cancelToken: cancelToken,
        stall: const Duration(milliseconds: 300),
        pause: const Duration(milliseconds: 10),
      );
      expect(progress.last, 1);
      return file;
    }

    test('carries on from where a silent connection stopped', () async {
      await serve();
      File file = await download();
      expect(file.readAsBytesSync(), apk);
      expect(ranges, [null, 'bytes=100000-']);
    });

    test('starts again when the server ignores the range', () async {
      await serve(ignoreRange: true);
      File file = await download();
      expect(file.readAsBytesSync(), apk);
    });

    test('a cancelled download keeps what it has', () async {
      await serve();
      CancelToken cancel = CancelToken();
      Future<void>.delayed(const Duration(milliseconds: 150), cancel.cancel);
      await expectLater(
          download(cancelToken: cancel), throwsA(isA<DioError>()));
      expect(
          File('${directory.path}/2.9.1-dev.15.apk.part').lengthSync(), 100000);
    });
  });
}
