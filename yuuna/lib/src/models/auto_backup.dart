import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuuna/models.dart';
import 'package:yuuna/utils.dart';

/// Keeps one backup file, in a place the user chose once such as Google
/// Drive, up to date: when a backup is due, the app writes a fresh one over
/// it, so only the newest is ever kept. It runs while the app is open, a
/// little after it starts or comes back, since books live in the reader's
/// web storage, which needs the app. It waits while a book is open, and
/// its heavy work, packing and writing the file, runs off the app's main
/// thread.
class AutoBackup {
  static const MethodChannel _channel =
      MethodChannel('app.arianneorpilla.yuuna/files');

  /// Whether a backup is being written now.
  static final ValueNotifier<bool> running = ValueNotifier(false);

  /// What the backup being written is doing, for whoever is watching.
  static final ValueNotifier<BackupProgress?> progress = ValueNotifier(null);

  static Timer? _timer;

  /// Asks where to keep the backup and keeps it there. Resolves to whether
  /// a place was chosen that can be written again later.
  static Future<bool> choose(AppModel appModel) async {
    Map<dynamic, dynamic>? picked =
        await _channel.invokeMapMethod('createDocument', {
      'name': 'jidoujisho.${AppBackup.extension}',
      'mimeType': 'application/octet-stream',
      'keep': true,
    });
    if (picked == null) {
      return false;
    }
    if (picked['kept'] != true) {
      throw BackupException(t.auto_backup_cannot_keep);
    }
    String? previous = appModel.autoBackupUri;
    if (previous != null && previous != picked['uri']) {
      await _release(previous);
    }
    await appModel.setAutoBackupFile(
      picked['uri'] as String,
      name: picked['name'] as String?,
    );
    return true;
  }

  /// Stops keeping a backup. The file stays where it is.
  static Future<void> turnOff(AppModel appModel) async {
    String? uri = appModel.autoBackupUri;
    if (uri != null) {
      await _release(uri);
    }
    await appModel.setAutoBackupFile(null);
  }

  static Future<void> _release(String uri) async {
    try {
      await _channel.invokeMethod('releaseUri', {'uri': uri});
    } catch (_) {}
  }

  /// Whether a backup is due now.
  static bool isDue(AppModel appModel) {
    if (appModel.autoBackupUri == null) {
      return false;
    }
    DateTime? last = appModel.lastAutoBackup;
    return last == null ||
        DateTime.now().difference(last) >=
            Duration(days: appModel.autoBackupDays);
  }

  /// Writes a backup [after] a while, if one is due then. A later call
  /// replaces an earlier one still waiting.
  static void scheduleIfDue(
    AppModel appModel,
    WidgetRef ref, {
    Duration after = const Duration(seconds: 30),
  }) {
    _timer?.cancel();
    if (!isDue(appModel)) {
      return;
    }
    _timer = Timer(after, () {
      if (!isDue(appModel)) {
        return;
      }

      /// Reading comes first: try again in a few minutes.
      if (appModel.isMediaOpen) {
        scheduleIfDue(appModel, ref, after: const Duration(minutes: 5));
        return;
      }
      run(appModel, ref);
    });
  }

  /// Writes a backup now over the kept file. Resolves to whether it was
  /// written; why not is recorded for the backup page.
  static Future<bool> run(AppModel appModel, WidgetRef ref) async {
    String? uri = appModel.autoBackupUri;
    if (uri == null || running.value) {
      return false;
    }
    running.value = true;
    progress.value = BackupProgress(t.backup_step_settings);
    File? file;
    try {
      Map<dynamic, dynamic>? status =
          await _channel.invokeMapMethod('uriStatus', {'uri': uri});
      if (status?['writable'] != true) {
        await appModel.recordAutoBackup(error: t.auto_backup_lost);
        return false;
      }
      file = await AppBackup(appModel: appModel, ref: ref).create(
        (step) => progress.value = step,
        includeOwnDictionaries: appModel.autoBackupIncludesOwnDictionaries,
      );
      progress.value = BackupProgress(t.auto_backup_writing);
      await _channel.invokeMethod('copyFileToUri', {
        'path': file.path,
        'uri': uri,
      });
      await appModel.recordAutoBackup();
      return true;
    } catch (error, stack) {
      debugPrint('Automatic backup failed: $error\n$stack');
      await appModel.recordAutoBackup(
        error: error is BackupException ? error.message : '$error',
      );
      return false;
    } finally {
      if (file != null && file.existsSync()) {
        file.deleteSync();
      }
      progress.value = null;
      running.value = false;
    }
  }
}
