import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:wakelock/wakelock.dart';
import 'package:yuuna/models.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// Newer builds of the app and what they bring, every one missed since the
/// version installed, with the newest to download and install.
class AppUpdateSheet extends BasePage {
  /// Create the sheet.
  const AppUpdateSheet({super.key});

  @override
  BasePageState<AppUpdateSheet> createState() => _AppUpdateSheetState();
}

class _AppUpdateSheetState extends BasePageState<AppUpdateSheet> {
  bool _checking = false;
  bool _checkFailed = false;

  /// The share of the download done, while there is one.
  double? _progress;
  CancelToken? _cancel;

  /// The release downloaded, and its APK, so Install works again once
  /// Android has been told to allow it.
  String? _downloadedVersion;
  File? _apk;
  String? _message;

  AppUpdates get _updates => appModelNoUpdate.updates;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void dispose() {
    _cancel?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _checkFailed = false;
    });
    try {
      await _updates.check(force: true);
    } catch (_) {
      _checkFailed = true;
    }
    if (mounted) {
      setState(() => _checking = false);
    }
  }

  Future<void> _install(AppRelease release) async {
    setState(() {
      _message = null;
      _progress = 0;
    });
    _cancel = CancelToken();
    await Wakelock.enable();
    try {
      File apk = _downloadedVersion == release.version && _apk != null
          ? _apk!
          : await _updates.download(
              release,
              cancelToken: _cancel,
              onProgress: (share) {
                if (mounted) {
                  setState(() => _progress = share);
                }
              },
            );
      _apk = apk;
      _downloadedVersion = release.version;
      if (mounted) {
        setState(() => _progress = null);
      }
      if (!await _updates.install(apk) && mounted) {
        setState(() => _message = t.update_allow);
      }
    } on AppUpdateException catch (error) {
      _message =
          error.reason == 'damaged' ? t.update_damaged : t.update_download_failed;
    } on DioError {
      _message = null;
    } catch (_) {
      _message = t.update_download_failed;
    } finally {
      await Wakelock.disable();
      if (mounted) {
        setState(() => _progress = null);
      }
    }
  }

  String _megabytes(int bytes) => '${(bytes / (1 << 20)).round()} MB';

  Widget _group(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      child: Text(
        title.toUpperCase(),
        style: textTheme.labelMedium!.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _release(AppRelease release) {
    Color muted = theme.unselectedWidgetColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                release.version,
                style: textTheme.titleSmall!
                    .copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  release.theme,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall!.copyWith(color: muted),
                ),
              ),
              Text(
                intl.DateFormat.MMMd().format(release.publishedAt.toLocal()),
                style: textTheme.bodySmall!.copyWith(color: muted),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (String point in release.points)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 0, 10, 0),
                    child: Text('•',
                        style: textTheme.bodyMedium!
                            .copyWith(color: theme.colorScheme.primary)),
                  ),
                  Expanded(child: Text(point, style: textTheme.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _action(AppRelease newest) {
    Color muted = theme.unselectedWidgetColor;
    double? progress = _progress;
    List<Widget> children;
    if (progress != null) {
      bool checking = progress >= 1;
      children = [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: checking ? null : progress,
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                checking
                    ? t.update_checking_file
                    : t.update_downloading(
                        percent: '${(progress * 100).floor()}'),
                style: textTheme.bodySmall!.copyWith(color: muted),
              ),
            ),
            if (!checking)
              TextButton(
                onPressed: () => _cancel?.cancel(),
                child: Text(t.dialog_cancel),
              ),
          ],
        ),
      ];
    } else {
      bool downloaded = _downloadedVersion == newest.version && _apk != null;
      children = [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: Icon(downloaded ? Ui.update : Ui.download, size: 18),
          label: Text(downloaded
              ? t.update_install_downloaded
              : t.update_install(size: _megabytes(newest.apkSize))),
          onPressed: () => _install(newest),
        ),
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(
            _message!,
            style: textTheme.bodySmall!.copyWith(
              color: _message == t.update_allow
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          t.update_keeps_data,
          style: textTheme.bodySmall!.copyWith(color: muted),
        ),
      ];
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color muted = theme.unselectedWidgetColor;
    return ValueListenableBuilder<List<AppRelease>>(
      valueListenable: _updates.newer,
      builder: (context, newer, _) {
        AppRelease? installed = _updates.installed;
        DateTime? checked = _updates.lastChecked;
        List<AppRelease> notes = newer.isNotEmpty
            ? newer
            : [if (installed != null) installed];
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: newer.isEmpty ? 0.5 : 0.75,
          minChildSize: 0.35,
          maxChildSize: 0.95,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              const TtuSheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Text(
                  t.update_menu,
                  style: textTheme.titleLarge!
                      .copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      newer.isNotEmpty
                          ? t.update_ready(version: newer.first.version)
                          : t.update_latest,
                      style: textTheme.titleMedium!
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.update_installed(version: _updates.installedVersion),
                      style: textTheme.bodySmall!.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              if (newer.isNotEmpty) _action(newer.first),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 20, 0),
                child: Row(
                  children: [
                    TextButton.icon(
                      icon: _checking
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Ui.refresh, size: 16),
                      label: Text(t.update_check_again),
                      onPressed: _checking ? null : _check,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _checkFailed
                            ? t.update_check_failed
                            : checked == null
                                ? ''
                                : t.update_checked(time: ttuAgo(checked)),
                        style: textTheme.bodySmall!.copyWith(
                          color: _checkFailed ? theme.colorScheme.error : muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (notes.isNotEmpty) ...[
                _group(t.update_whats_new),
                for (AppRelease release in notes) _release(release),
              ],
            ],
          ),
        );
      },
    );
  }
}
