import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// The sheet where a video or page link is entered, with the pages whose
/// videos were played before.
class NetworkStreamDialogPage extends BasePage {
  /// Create an instance of this page.
  const NetworkStreamDialogPage({
    required this.onPlay,
    super.key,
  });

  /// Opens the link entered or picked.
  final Function(String) onPlay;

  @override
  BasePageState createState() => _NetworkStreamDialogPageState();
}

class _NetworkStreamDialogPageState
    extends BasePageState<NetworkStreamDialogPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open() {
    String link = _controller.text.trim();
    if (link.isNotEmpty) {
      widget.onPlay(link);
    }
  }

  Future<void> _paste() async {
    String text = (await Clipboard.getData('text/plain'))?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      _controller.text = text;
      _controller.selection = TextSelection.collapsed(offset: text.length);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TtuSheetHandle(),
            _header(),
            _field(),
            ..._recentPages(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              t.stream_open,
              style:
                  textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          JidoujishoInfoButton(message: t.video_finder_info),
          IconButton(
            tooltip: t.dialog_close,
            icon: const Icon(Ui.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _field() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _open(),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: t.stream_url,
                isDense: true,
                filled: true,
                fillColor: theme.dividerColor.withOpacity(0.08),
                prefixIcon: const Icon(Ui.link, size: 18),
                suffixIcon: IconButton(
                  tooltip: t.paste,
                  icon: const Icon(Ui.paste, size: 18),
                  onPressed: _paste,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 44,
            child: FilledButton(
              style: FilledButton.styleFrom(
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onPressed: _controller.text.trim().isEmpty ? null : _open,
              child: Text(t.stream_go),
            ),
          ),
        ],
      ),
    );
  }

  /// Pages whose videos were played, to open again for a fresh link.
  List<Widget> _recentPages() {
    List<({String url, String title})> pages =
        appModel.videoPages.take(8).toList();
    if (pages.isEmpty) {
      return const [];
    }
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 6),
        child: Text(
          t.video_finder_recent,
          style: textTheme.labelMedium!.copyWith(
            color: theme.unselectedWidgetColor,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      for (var page in pages)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          child: Material(
            color: theme.dividerColor.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => widget.onPlay(page.url),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
                child: Row(
                  children: [
                    Icon(Ui.globe, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            page.title.isNotEmpty
                                ? page.title
                                : Uri.tryParse(page.url)?.host ?? page.url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyLarge!
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            Uri.tryParse(page.url)?.host ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall!
                                .copyWith(color: theme.unselectedWidgetColor),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: t.video_finder_forget,
                      icon: Icon(Ui.close,
                          size: 16, color: theme.unselectedWidgetColor),
                      onPressed: () async {
                        await appModel.forgetVideoPage(page.url);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ];
  }
}
