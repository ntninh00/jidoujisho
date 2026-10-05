import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/language.dart';
import 'package:yuuna/media.dart';
import 'package:yuuna/models.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// Opens the editor for a term in My terms: a new one prefilled with [term]
/// and [meaning], or [existing] to change or remove it. [origin] records the
/// book it comes from. Resolves to true when saved.
Future<bool> showMyWordEditor({
  required BuildContext context,
  required AppModel appModel,
  String term = '',
  String reading = '',
  String meaning = '',
  TermOrigin? origin,
  MyWord? existing,
}) async {
  bool? saved = await showTtuSheet<bool>(
    context: context,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _MyWordEditor(
        appModel: appModel,
        term: existing?.term ?? term,
        reading: existing?.reading ?? reading,
        meaning: existing?.meaning ?? meaning,
        origin: existing?.origin ?? origin,
        existing: existing,
      ),
    ),
  );
  return saved ?? false;
}

class _MyWordEditor extends StatefulWidget {
  const _MyWordEditor({
    required this.appModel,
    required this.term,
    required this.reading,
    required this.meaning,
    required this.origin,
    required this.existing,
  });

  final AppModel appModel;
  final String term;
  final String reading;
  final String meaning;
  final TermOrigin? origin;
  final MyWord? existing;

  @override
  State<_MyWordEditor> createState() => _MyWordEditorState();
}

class _MyWordEditorState extends State<_MyWordEditor> {
  late final TextEditingController _term =
      TextEditingController(text: widget.term.trim());
  late final TextEditingController _reading =
      TextEditingController(text: widget.reading);
  late final TextEditingController _meaning =
      TextEditingController(text: widget.meaning);

  /// Only the term is needed; the meaning can come later.
  bool get _canSave => _term.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _term.addListener(_refresh);
    _meaning.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _term.dispose();
    _reading.dispose();
    _meaning.dispose();
    super.dispose();
  }

  void _save() {
    if (!_canSave) {
      return;
    }
    widget.appModel.saveMyWord(
      term: _term.text.trim(),
      reading: _reading.text.trim(),
      meaning: _meaning.text.trim(),
      replaceEntryId: widget.existing?.entryId,
      origin: widget.origin,
    );
    Fluttertoast.showToast(msg: t.my_words_saved);
    Navigator.pop(context, true);
  }

  void _delete() {
    MyWord? existing = widget.existing;
    if (existing != null) {
      widget.appModel.deleteMyWord(existing.entryId);
      Fluttertoast.showToast(msg: t.my_words_deleted);
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    bool japanese = widget.appModel.targetLanguage is JapaneseLanguage;
    bool hasTerm = widget.term.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TtuSheetHandle(),
          Row(
            children: [
              Icon(Ui.myWords, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.existing == null ? t.my_words_add : t.my_words_edit,
                  style: theme.textTheme.titleMedium!
                      .copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              JidoujishoInfoButton(message: t.my_words_info),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              children: [
                TextField(
                  controller: _term,
                  autofocus: !hasTerm,
                  textInputAction: TextInputAction.next,
                  style: theme.textTheme.titleMedium,
                  decoration: InputDecoration(labelText: t.my_words_word),
                ),
                if (japanese)
                  TextField(
                    controller: _reading,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: t.my_words_reading),
                  ),
                TextField(
                  controller: _meaning,
                  autofocus: hasTerm,
                  minLines: 2,
                  maxLines: 6,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    labelText: t.my_words_meaning,
                    hintText: t.my_words_meaning_hint,
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (widget.existing != null)
                TextButton(
                  onPressed: _delete,
                  child: Text(
                    t.ttu_delete,
                    style: TextStyle(color: theme.unselectedWidgetColor),
                  ),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(t.dialog_cancel),
              ),
              TextButton(
                onPressed: _canSave ? _save : null,
                child: Text(
                  t.dialog_save,
                  style: TextStyle(
                    color: _canSave
                        ? theme.colorScheme.primary
                        : theme.disabledColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Lists the words in My words, to add, change or remove them.
class MyWordsSheet extends BasePage {
  /// Create the list.
  const MyWordsSheet({super.key});

  @override
  BasePageState<MyWordsSheet> createState() => _MyWordsSheetState();
}

class _MyWordsSheetState extends BasePageState<MyWordsSheet> {
  MyWord? _removed;
  Timer? _undoTimer;

  @override
  void initState() {
    super.initState();
    appModelNoUpdate.myWordsVersion.addListener(_refresh);
  }

  @override
  void dispose() {
    appModelNoUpdate.myWordsVersion.removeListener(_refresh);
    _undoTimer?.cancel();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  void _remove(MyWord word) {
    appModelNoUpdate.deleteMyWord(word.entryId);
    _undoTimer?.cancel();
    setState(() => _removed = word);
    _undoTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _removed = null);
      }
    });
  }

  void _undo() {
    MyWord? word = _removed;
    _undoTimer?.cancel();
    setState(() => _removed = null);
    if (word != null) {
      appModelNoUpdate.saveMyWord(
        term: word.term,
        reading: word.reading,
        meaning: word.meaning,
        origin: word.origin,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    List<MyWord> words = appModel.myWords;
    Color muted = theme.unselectedWidgetColor;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      builder: (context, controller) => Column(
        children: [
          const TtuSheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 4, 4),
            child: Row(
              children: [
                Text(
                  t.my_words,
                  style: textTheme.titleLarge!
                      .copyWith(fontWeight: FontWeight.bold),
                ),
                if (words.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${words.length}',
                    style: textTheme.titleMedium!.copyWith(color: muted),
                  ),
                ],
                JidoujishoInfoButton(message: t.my_words_info),
                const Spacer(),
                IconButton(
                  tooltip: t.my_words_new,
                  icon: Icon(Ui.plus, color: theme.colorScheme.primary),
                  onPressed: () => showMyWordEditor(
                    context: context,
                    appModel: appModelNoUpdate,
                  ),
                ),
                IconButton(
                  tooltip: t.dialog_close,
                  icon: const Icon(Ui.cross),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: words.isEmpty
                ? ListView(
                    controller: controller,
                    children: [
                      const SizedBox(height: 48),
                      Icon(Ui.myWords, size: 40, color: muted),
                      const SizedBox(height: 12),
                      Text(
                        t.my_words_empty,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyLarge!.copyWith(color: muted),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: FilledButton.tonalIcon(
                          onPressed: () => showMyWordEditor(
                            context: context,
                            appModel: appModelNoUpdate,
                          ),
                          icon: const Icon(Ui.plus, size: 18),
                          label: Text(t.my_words_new),
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: words.length,
                    itemBuilder: (context, index) {
                      MyWord word = words[index];
                      return Dismissible(
                        key: ValueKey(word.entryId),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red.shade700,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          child: const Icon(Ui.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _remove(word),
                        child: InkWell(
                          onTap: () => showMyWordEditor(
                            context: context,
                            appModel: appModelNoUpdate,
                            existing: word,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: word.term,
                                        style: textTheme.bodyLarge!.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (word.reading.isNotEmpty)
                                        TextSpan(
                                          text: '  ${word.reading}',
                                          style: textTheme.bodySmall!
                                              .copyWith(color: muted),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  word.meaning,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _removed == null
                ? const SizedBox.shrink()
                : Container(
                    key: const ValueKey('undo'),
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF323232),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.my_words_deleted,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        TextButton(
                          onPressed: _undo,
                          child: Text(
                            t.ttu_undo.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFFFF8A80),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// The terms saved from one book, from the book's long-press sheet. Tapping
/// a term opens the book where it was saved.
class TtuBookTermsSheet extends BasePage {
  /// Create the list for [book].
  const TtuBookTermsSheet({
    required this.book,
    required this.onOpen,
    super.key,
  });

  /// The book the terms come from.
  final TtuBook book;

  /// Opens the book at a term's place.
  final ValueChanged<MyWord> onOpen;

  @override
  BasePageState<TtuBookTermsSheet> createState() => _TtuBookTermsSheetState();
}

class _TtuBookTermsSheetState extends BasePageState<TtuBookTermsSheet> {
  @override
  void initState() {
    super.initState();
    appModelNoUpdate.myWordsVersion.addListener(_refresh);
  }

  @override
  void dispose() {
    appModelNoUpdate.myWordsVersion.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    List<MyWord> terms = appModel.myTermsFromBook(widget.book.key);
    Color muted = theme.unselectedWidgetColor;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.94,
      builder: (context, controller) => Column(
        children: [
          const TtuSheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
            child: Row(
              children: [
                TtuCover(book: widget.book, width: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium!
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${t.ttu_terms} · ${terms.length}',
                        style: textTheme.bodySmall!.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
                JidoujishoInfoButton(message: t.my_words_info),
                IconButton(
                  tooltip: t.dialog_close,
                  icon: const Icon(Ui.cross),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: terms.isEmpty
                ? ListView(
                    controller: controller,
                    children: [
                      const SizedBox(height: 40),
                      Icon(Ui.myWords, size: 36, color: muted),
                      const SizedBox(height: 12),
                      Text(
                        t.ttu_no_terms,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium!.copyWith(color: muted),
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: terms.length,
                    itemBuilder: (context, index) {
                      MyWord term = terms[index];
                      TermOrigin? origin = term.origin;
                      return InkWell(
                        onTap: origin != null && origin.hasPlace
                            ? () {
                                Navigator.pop(context);
                                widget.onOpen(term);
                              }
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 48,
                                child: Text(
                                  origin == null || !origin.hasPlace
                                      ? ''
                                      : ttuPercent(origin.progress),
                                  style: textTheme.bodySmall!.copyWith(
                                    color: muted,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      term.term,
                                      style: textTheme.bodyLarge!.copyWith(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    if (term.meaning.isNotEmpty)
                                      Text(
                                        term.meaning,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: textTheme.bodyMedium,
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: t.my_words_edit,
                                icon: Icon(Ui.edit, size: 18, color: muted),
                                onPressed: () => showMyWordEditor(
                                  context: context,
                                  appModel: appModelNoUpdate,
                                  existing: term,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
