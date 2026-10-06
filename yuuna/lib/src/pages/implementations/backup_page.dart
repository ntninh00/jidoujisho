import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:wakelock/wakelock.dart';
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/media.dart';
import 'package:yuuna/models.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// Saves a file somewhere the user picks, through the system's own picker.
class _SaveAs {
  static const MethodChannel _channel =
      MethodChannel('app.arianneorpilla.yuuna/files');

  /// Resolves to whether [file] was saved.
  static Future<bool> save(File file, String name) async {
    String? uri = await _channel.invokeMethod<String>('createDocument', {
      'name': name,
      'mimeType': 'application/octet-stream',
    });
    if (uri == null) {
      return false;
    }
    await _channel.invokeMethod('copyFileToUri', {
      'path': file.path,
      'uri': uri,
    });
    return true;
  }
}

/// Backs up everything the app keeps into one file, and restores it on this
/// or another device.
class BackupPage extends BasePage {
  /// Create the page.
  const BackupPage({super.key});

  @override
  BasePageState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends BasePageState<BackupPage> {
  BackupProgress? _progress;
  bool _restoring = false;
  BackupManifest? _picked;
  Directory? _pickedFolder;
  bool _confirming = false;
  bool _restored = false;
  List<String> _failed = const [];

  bool get _busy => _progress != null;

  AppBackup get _backup => AppBackup(appModel: appModelNoUpdate, ref: ref);

  @override
  void dispose() {
    Directory? folder = _pickedFolder;
    if (folder != null && folder.existsSync() && !_busy) {
      folder.deleteSync(recursive: true);
    }
    super.dispose();
  }

  void _onProgress(BackupProgress progress) {
    if (mounted) {
      setState(() => _progress = progress);
    }
  }

  Future<T?> _working<T>(Future<T> Function() work) async {
    await Wakelock.enable();
    try {
      return await work();
    } on BackupException catch (error) {
      Fluttertoast.showToast(
          msg: error.message, toastLength: Toast.LENGTH_LONG);
      return null;
    } catch (error, stack) {
      debugPrint('Backup failed: $error\n$stack');
      Fluttertoast.showToast(msg: '$error', toastLength: Toast.LENGTH_LONG);
      return null;
    } finally {
      await Wakelock.disable();
      if (mounted) {
        setState(() => _progress = null);
      }
    }
  }

  Future<void> _makeBackup() async {
    setState(() {
      _restoring = false;
      _progress = BackupProgress(t.backup_step_settings);
    });
    File? file = await _working(() => _backup.create(_onProgress));
    if (file == null) {
      return;
    }
    bool saved = false;
    try {
      saved = await _SaveAs.save(file, file.uri.pathSegments.last);
    } catch (error) {
      Fluttertoast.showToast(msg: '$error');
    } finally {
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
    Fluttertoast.showToast(msg: saved ? t.backup_saved : t.backup_not_saved);
  }

  Future<void> _choose() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    String? picked = result?.files.single.path;
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _restoring = true;
      _progress = BackupProgress(t.backup_step_packing);
    });
    (BackupManifest, Directory)? opened = await _working(() =>
        AppBackup.open(File(picked), appModelNoUpdate.temporaryDirectory));
    await FilePicker.platform.clearTemporaryFiles();
    if (opened == null || !mounted) {
      return;
    }
    Directory? previous = _pickedFolder;
    if (previous != null && previous.existsSync()) {
      previous.deleteSync(recursive: true);
    }
    setState(() {
      _picked = opened.$1;
      _pickedFolder = opened.$2;
      _confirming = false;
      _restored = false;
    });
  }

  Future<void> _restore() async {
    Directory? folder = _pickedFolder;
    if (folder == null) {
      return;
    }
    if (!_confirming) {
      setState(() => _confirming = true);
      return;
    }
    setState(() {
      _restoring = true;
      _confirming = false;
      _progress = BackupProgress(t.backup_step_settings);
    });
    List<String>? failed =
        await _working(() => _backup.restore(folder, _onProgress));
    if (!mounted) {
      return;
    }
    setState(() {
      _pickedFolder = null;
      _picked = null;
      if (failed != null) {
        _restored = true;
        _failed = failed;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !_busy,
      child: Scaffold(
        appBar: AppBar(title: Text(t.backup_title)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            buildBackUpCard(),
            const SizedBox(height: 12),
            buildRestoreCard(),
          ],
        ),
      ),
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required String hint,
    required List<Widget> children,
  }) {
    Color accent = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: theme.dividerColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: textTheme.titleMedium!
                    .copyWith(fontWeight: FontWeight.bold),
              ),
              JidoujishoInfoButton(message: hint),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _counts(List<(String, String)> counts) {
    Color muted = theme.unselectedWidgetColor;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for ((String, String) count in counts)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.dividerColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: RichText(
              text: TextSpan(
                style: textTheme.bodySmall!.copyWith(color: muted),
                children: [
                  TextSpan(
                    text: '${count.$2}  ',
                    style: textTheme.bodyMedium!
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: count.$1),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _button(String label, VoidCallback? onPressed, {Color? color}) {
    return SizedBox(
      height: 46,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? theme.colorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const StadiumBorder(),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }

  Widget _progressView() {
    BackupProgress progress = _progress!;
    Color muted = theme.unselectedWidgetColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          progress.step,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child:
              LinearProgressIndicator(minHeight: 5, value: progress.fraction),
        ),
        const SizedBox(height: 8),
        Text(
          t.backup_working,
          style: textTheme.bodySmall!.copyWith(color: muted),
        ),
      ],
    );
  }

  Widget buildBackUpCard() {
    List<TtuBook> books = ref.watch(ttuShelfProvider).valueOrNull ?? const [];
    int dictionaries = appModel.dictionaries
        .where((dictionary) => dictionary.id != MyWords.dictionaryId)
        .length;
    return _card(
      icon: Ui.cloudUpload,
      title: t.backup_make,
      hint: t.backup_make_hint,
      children: [
        _counts([
          (t.backup_books, '${books.length}'),
          (t.backup_dictionaries, '$dictionaries'),
          (t.backup_memos, '${appModel.readerMemos.length}'),
          (t.backup_terms, '${appModel.myWords.length}'),
        ]),
        const SizedBox(height: 14),
        if (_busy && !_restoring)
          _progressView()
        else
          _button(t.backup_make, _busy ? null : _makeBackup),
      ],
    );
  }

  Widget buildRestoreCard() {
    BackupManifest? picked = _picked;
    Color muted = theme.unselectedWidgetColor;
    List<Widget> children;

    if (_busy && _restoring) {
      children = [_progressView()];
    } else if (_restored) {
      children = [
        Text(
          t.backup_restored,
          style: textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w600),
        ),
        if (_failed.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            t.backup_failed_dictionaries(names: _failed.join(', ')),
            style:
                textTheme.bodySmall!.copyWith(color: theme.colorScheme.error),
          ),
        ],
        const SizedBox(height: 14),
        _button(t.backup_restart, SystemNavigator.pop),
      ];
    } else if (picked != null) {
      int books = picked.books.values.fold(0, (sum, n) => sum + n);
      String date = DateFormat.yMMMd().add_Hm().format(picked.created);
      children = [
        Text(
          t.backup_made(date: date, version: picked.appVersion),
          style: textTheme.bodySmall!.copyWith(color: muted),
        ),
        const SizedBox(height: 10),
        _counts([
          (t.backup_books, '$books'),
          (
            t.backup_dictionaries,
            '${picked.dictionariesIncluded + picked.dictionariesOnline}'
          ),
          (t.backup_memos, '${picked.memos}'),
          (t.backup_terms, '${picked.terms}'),
        ]),
        if (picked.dictionariesOnline > 0) ...[
          const SizedBox(height: 6),
          Text(
            t.backup_dictionaries_split(
              included: '${picked.dictionariesIncluded}',
              online: '${picked.dictionariesOnline}',
            ),
            style: textTheme.bodySmall!.copyWith(color: muted),
          ),
        ],
        const SizedBox(height: 14),
        _button(
          _confirming ? t.backup_restore_confirm : t.backup_restore,
          _busy ? null : _restore,
          color: _confirming ? theme.colorScheme.error : null,
        ),
        TextButton(
          onPressed: _busy ? null : _choose,
          child: Text(t.backup_choose, style: TextStyle(color: muted)),
        ),
      ];
    } else {
      children = [_button(t.backup_choose, _busy ? null : _choose)];
    }

    return _card(
      icon: Ui.cloudDownload,
      title: t.backup_restore,
      hint: t.backup_restore_hint,
      children: children,
    );
  }
}
