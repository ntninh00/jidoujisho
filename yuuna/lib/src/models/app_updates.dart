import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// A build of the app published on GitHub: its notes and its APK.
class AppRelease {
  /// Describe a release.
  AppRelease({
    required this.tag,
    required this.title,
    required this.notes,
    required this.publishedAt,
    this.apkUrl,
    this.apkSize = 0,
    this.apkSha256,
  });

  /// Read a release from GitHub's JSON, or from what was kept of it.
  factory AppRelease.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? apk;
    for (Object? asset in json['assets'] as List? ?? const []) {
      if (asset is Map<String, dynamic> &&
          '${asset['name']}'.endsWith('-arm64.apk')) {
        apk = asset;
      }
    }
    String? digest = apk?['digest'] as String? ?? json['apkSha256'] as String?;
    return AppRelease(
      tag: json['tag_name'] as String? ?? json['tag'] as String? ?? '',
      title: json['name'] as String? ?? json['title'] as String? ?? '',
      notes: json['body'] as String? ?? json['notes'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['published_at'] as String? ??
              json['publishedAt'] as String? ??
              '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      apkUrl:
          apk?['browser_download_url'] as String? ?? json['apkUrl'] as String?,
      apkSize: (apk?['size'] as num? ?? json['apkSize'] as num? ?? 0).toInt(),
      apkSha256: digest?.replaceFirst('sha256:', ''),
    );
  }

  /// What is kept of the release between checks.
  Map<String, Object?> toJson() => {
        'tag': tag,
        'title': title,
        'notes': notes,
        'publishedAt': publishedAt.toIso8601String(),
        'apkUrl': apkUrl,
        'apkSize': apkSize,
        'apkSha256': apkSha256,
      };

  /// The release's tag, as `v2.9.1-dev.12`.
  final String tag;

  /// Its title, as `2.9.1-dev.12 · Grammar section`.
  final String title;

  /// Its notes, as Markdown bullets.
  final String notes;

  /// When it was published.
  final DateTime publishedAt;

  /// Where its APK downloads from, when it has one.
  final String? apkUrl;

  /// The APK's size in bytes.
  final int apkSize;

  /// The APK's SHA-256, as GitHub reports it, to check the download by.
  final String? apkSha256;

  /// The version it installs, as `2.9.1-dev.12`.
  String get version => tag.startsWith('v') ? tag.substring(1) : tag;

  /// The title without its version, as `Grammar section`.
  String get theme {
    int dot = title.indexOf('·');
    return dot == -1 ? '' : title.substring(dot + 1).trim();
  }

  /// The notes' points, without the line every release ends with about
  /// how it installs.
  List<String> get points => notes
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.startsWith('- ') || line.startsWith('* '))
      .map((line) => line.substring(2).trim())
      .where((line) => line.isNotEmpty)
      .toList();
}

/// Compares versions such as `2.9.1-dev.12`: by their numbers, then by the
/// dev number, a version without one counting as newer.
int compareAppVersions(String a, String b) {
  List<int> numbers(String version) {
    String base = version.split('-').first;
    return base.split('.').map((part) => int.tryParse(part) ?? 0).toList();
  }

  int? dev(String version) {
    Match? match = RegExp(r'-dev\.(\d+)').firstMatch(version);
    return match == null ? null : int.parse(match.group(1)!);
  }

  List<int> left = numbers(a);
  List<int> right = numbers(b);
  for (int i = 0; i < 3; i++) {
    int x = i < left.length ? left[i] : 0;
    int y = i < right.length ? right[i] : 0;
    if (x != y) {
      return x.compareTo(y);
    }
  }
  int? x = dev(a);
  int? y = dev(b);
  if (x == y) {
    return 0;
  }
  if (x == null) {
    return 1;
  }
  if (y == null) {
    return -1;
  }
  return x.compareTo(y);
}

/// The SHA-256 of the file at [filePath], read a megabyte at a time.
String _sha256Of(String filePath) {
  late Digest digest;
  ByteConversionSink sink = sha256.startChunkedConversion(
      ChunkedConversionSink<Digest>.withCallback(
          (digests) => digest = digests.single));
  RandomAccessFile file = File(filePath).openSync();
  Uint8List buffer = Uint8List(1 << 20);
  for (int read = file.readIntoSync(buffer);
      read > 0;
      read = file.readIntoSync(buffer)) {
    sink.addSlice(buffer, 0, read, false);
  }
  sink.close();
  file.closeSync();
  return digest.toString();
}

/// Downloads [url] into [file], carrying on from what [file] already holds,
/// to [size] bytes when that is known. A connection that sends nothing for
/// [stall], as one a phone leaves behind when it moves between Wi-Fi and
/// mobile data, is dropped, and the download picks up where it stopped,
/// giving up after [attempts] tries in a row that got nothing further.
/// [onProgress] gets the share done, from 0 to 1. A cancelled download
/// keeps what it has, for the next try to carry on from.
Future<void> downloadResuming({
  required String url,
  required File file,
  required int size,
  required void Function(double) onProgress,
  CancelToken? cancelToken,
  Duration stall = const Duration(seconds: 20),
  int attempts = 5,
  Duration pause = const Duration(seconds: 2),
}) async {
  Dio dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));
  int failures = 0;
  while (true) {
    int have = file.existsSync() ? file.lengthSync() : 0;
    if (size > 0 && have > size) {
      file.deleteSync();
      have = 0;
    }
    if (size > 0 && have == size) {
      onProgress(1);
      return;
    }
    int before = have;
    try {
      Response<ResponseBody> response = await dio.get<ResponseBody>(
        url,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: have > 0 ? {HttpHeaders.rangeHeader: 'bytes=$have-'} : null,
        ),
      );
      // A server that ignores the range sends the whole file again.
      bool resumed =
          have > 0 && response.statusCode == HttpStatus.partialContent;
      if (!resumed) {
        have = 0;
      }
      int total = size > 0
          ? size
          : have +
              (int.tryParse(
                      response.headers.value(Headers.contentLengthHeader) ??
                          '') ??
                  0);
      IOSink sink =
          file.openWrite(mode: resumed ? FileMode.append : FileMode.write);
      Completer<void> done = Completer();
      late StreamSubscription<Uint8List> subscription;
      void fail(Object error, [StackTrace? stack]) {
        subscription.cancel();
        if (!done.isCompleted) {
          done.completeError(error, stack);
        }
      }

      subscription = response.data!.stream.timeout(stall).listen(
            (chunk) {
              sink.add(chunk);
              have += chunk.length;
              if (total > 0) {
                onProgress(have / total);
              }
            },
            onError: fail,
            onDone: () {
              if (!done.isCompleted) {
                done.complete();
              }
            },
            cancelOnError: true,
          );
      cancelToken?.whenCancel.then(fail);
      try {
        await done.future;
      } finally {
        await sink.close();
      }
      if (size > 0 && have < size) {
        throw const SocketException('The download ended early.');
      }
      return;
    } catch (error) {
      if (cancelToken?.isCancelled ?? false) {
        rethrow;
      }
      int now = file.existsSync() ? file.lengthSync() : 0;
      failures = now > before ? 1 : failures + 1;
      if (failures >= attempts) {
        rethrow;
      }
      debugPrint('Download stopped at $now bytes, carrying on: $error');
      await Future.delayed(pause);
    }
  }
}

/// Why an update could not be had.
class AppUpdateException implements Exception {
  /// Describe what went wrong.
  const AppUpdateException(this.reason);

  /// `download` when the download stopped, `damaged` when it came out
  /// different from the release's.
  final String reason;
}

/// Newer builds of the dev app, from its GitHub releases: whether there are
/// any, what changed in them, and getting one installed.
class AppUpdates {
  /// Look for updates to [installedVersion], when [enabled]: only the dev
  /// app is published as releases.
  AppUpdates({
    required Box preferences,
    required this.installedVersion,
    required this.enabled,
  }) : _preferences = preferences;

  /// Where the releases are published.
  static const String repository = 'ntninh00/jidoujisho';

  /// How long a check holds before releases are looked up again.
  static const Duration checkEvery = Duration(hours: 6);

  static const MethodChannel _files =
      MethodChannel('app.arianneorpilla.yuuna/files');

  final Box _preferences;

  /// The version running, as `2.9.1-dev.12`.
  final String installedVersion;

  /// Whether this build looks for updates.
  final bool enabled;

  /// Every release found, newest first.
  List<AppRelease> releases = [];

  /// Releases newer than the one installed, newest first: what the update
  /// brings.
  final ValueNotifier<List<AppRelease>> newer = ValueNotifier(const []);

  /// When releases were last looked up.
  DateTime? get lastChecked {
    int? millis = _preferences.get('app_releases_checked') as int?;
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  /// The release of the version running, when it is one.
  AppRelease? get installed => releases
      .where((release) =>
          compareAppVersions(release.version, installedVersion) == 0)
      .firstOrNull;

  /// Shows what the last check found, and removes downloads that are
  /// installed by now.
  void loadKept() {
    if (!enabled) {
      return;
    }
    try {
      List kept = jsonDecode(
              _preferences.get('app_releases', defaultValue: '[]') as String)
          as List;
      _show(
          kept.cast<Map<String, dynamic>>().map(AppRelease.fromJson).toList());
    } catch (error) {
      debugPrint('Kept releases unreadable: $error');
    }
    _removeOldDownloads();
  }

  /// Looks the releases up, unless that was done lately and not [force]d.
  /// Throws when they cannot be had and [force] is set.
  Future<void> check({bool force = false}) async {
    if (!enabled) {
      return;
    }
    DateTime? last = lastChecked;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < checkEvery) {
      return;
    }
    try {
      Response<List> response = await Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Accept': 'application/vnd.github+json'},
      )).get<List>(
          'https://api.github.com/repos/$repository/releases?per_page=50');
      List<AppRelease> found = (response.data ?? const [])
          .cast<Map<String, dynamic>>()
          .where((json) => json['draft'] != true)
          .map(AppRelease.fromJson)
          .where((release) => release.tag.isNotEmpty)
          .toList();
      _show(found);
      await _preferences.put('app_releases',
          jsonEncode(found.map((release) => release.toJson()).toList()));
      await _preferences.put(
          'app_releases_checked', DateTime.now().millisecondsSinceEpoch);
    } catch (error) {
      debugPrint('Could not check for updates: $error');
      if (force) {
        rethrow;
      }
    }
  }

  void _show(List<AppRelease> found) {
    found.sort((a, b) => compareAppVersions(b.version, a.version));
    releases = found;
    newer.value = found
        .where((release) =>
            release.apkUrl != null &&
            compareAppVersions(release.version, installedVersion) > 0)
        .toList();
  }

  Future<Directory> _downloads() async {
    Directory directory =
        Directory(path.join((await getTemporaryDirectory()).path, 'updates'));
    directory.createSync(recursive: true);
    return directory;
  }

  Future<void> _removeOldDownloads() async {
    try {
      for (FileSystemEntity file in (await _downloads()).listSync()) {
        String name = path.basenameWithoutExtension(file.path);
        if (compareAppVersions(name, installedVersion) <= 0) {
          file.deleteSync();
        }
      }
    } catch (error) {
      debugPrint('Old downloads left: $error');
    }
  }

  /// The release's APK, downloaded and checked against the release, or the
  /// one already downloaded when it checks out. [onProgress] gets the
  /// share done, from 0 to 1.
  Future<File> download(
    AppRelease release, {
    required void Function(double) onProgress,
    CancelToken? cancelToken,
  }) async {
    File file =
        File(path.join((await _downloads()).path, '${release.version}.apk'));
    if (file.existsSync() && await _matches(file, release)) {
      onProgress(1);
      return file;
    }
    // Kept when a download stops, so the next one carries on from it.
    File partial = File('${file.path}.part');
    try {
      await downloadResuming(
        url: release.apkUrl!,
        file: partial,
        size: release.apkSize,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    } on DioError catch (error) {
      if (CancelToken.isCancel(error)) {
        rethrow;
      }
      throw const AppUpdateException('download');
    } on Exception {
      throw const AppUpdateException('download');
    }
    if (!await _matches(partial, release)) {
      partial.deleteSync();
      throw const AppUpdateException('damaged');
    }
    return partial.renameSync(file.path);
  }

  Future<bool> _matches(File file, AppRelease release) async {
    if (release.apkSize > 0 && file.lengthSync() != release.apkSize) {
      return false;
    }
    String? expected = release.apkSha256;
    if (expected == null) {
      return true;
    }
    return await compute(_sha256Of, file.path) == expected;
  }

  /// Opens Android's installer on [apk]. Returns false when Android first
  /// needs the user to allow installs from the app, which it has just
  /// asked for.
  Future<bool> install(File apk) async {
    String? outcome =
        await _files.invokeMethod<String>('installApk', {'path': apk.path});
    return outcome != 'permission';
  }
}
