import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:yuuna/models.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// Asks for file access when a feature first needs it, with a short sheet
/// before Android's own prompt. On Android 11 and up the sheet offers media
/// only or all files. Resolves to true when the feature can go on.
Future<bool> ensureFileAccess({
  required BuildContext context,
  required AppModel appModel,
}) async {
  if (await appModel.hasFileAccess()) {
    return true;
  }
  if (!context.mounted) {
    return false;
  }
  bool? allFiles = await showTtuSheet<bool>(
    context: context,
    builder: (_) => _FileAccessSheet(appModel: appModel),
  );
  if (allFiles == null) {
    return false;
  }
  bool granted = await appModel.requestFileAccess(allFiles: allFiles);
  if (!granted) {
    Fluttertoast.showToast(msg: t.file_access_denied);
  }
  return granted;
}

class _FileAccessSheet extends StatelessWidget {
  const _FileAccessSheet({required this.appModel});

  final AppModel appModel;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Color accent = theme.colorScheme.primary;
    bool canLimit = appModel.canLimitFileAccess;
    ButtonStyle wide = ButtonStyle(
      minimumSize: MaterialStateProperty.all(const Size.fromHeight(46)),
      shape: MaterialStateProperty.all(const StadiumBorder()),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TtuSheetHandle(),
            const SizedBox(height: 12),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Ui.folder, color: accent, size: 26),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    t.file_access_title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium!
                        .copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                JidoujishoInfoButton(
                  message:
                      canLimit ? t.file_access_info : t.file_access_info_short,
                ),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton(
              style: wide,
              onPressed: () => Navigator.pop(context, false),
              child: Text(canLimit ? t.file_access_media : t.file_access_allow),
            ),
            if (canLimit) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                style: wide,
                onPressed: () => Navigator.pop(context, true),
                child: Text(t.file_access_all),
              ),
            ],
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                t.file_access_not_now,
                style: TextStyle(color: theme.unselectedWidgetColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
