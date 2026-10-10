import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/media.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// The dictionaries on this device, as a sheet: their order in results,
/// which are shown, and adding them from a file or the user's server. A
/// dictionary's own sheet, from tapping or holding it, has its details and
/// the rest of what can be done with it.
class DictionaryDialogPage extends BasePage {
  /// Create an instance of this page.
  const DictionaryDialogPage({super.key});

  @override
  BasePageState createState() => _DictionaryDialogPageState();
}

class _DictionaryDialogPageState extends BasePageState {
  @override
  void initState() {
    super.initState();
    _learnLanguages();
  }

  /// Dictionaries installed from the server before the app kept their
  /// languages get them from its catalog, quietly.
  Future<void> _learnLanguages() async {
    DictionaryServer? server = appModelNoUpdate.dictionaryServer;
    if (server == null ||
        !appModelNoUpdate.dictionarySources.values.any((source) =>
            source['kind'] == 'server' && source['section'] == null)) {
      return;
    }
    try {
      await appModelNoUpdate.refreshDictionaryNotes(
          server.url, await server.list());
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      debugPrint('Dictionary languages not learnt: $error');
    }
  }

  /// Picks or unpicks [language], whose dictionaries alone are on with
  /// the others picked; null goes back to all.
  Future<void> _setMode(String? language) async {
    Set<String> picked = appModel.dictionaryModeLanguages;
    if (language == null) {
      picked.clear();
    } else if (!picked.remove(language)) {
      picked.add(language);
    }
    await appModel.setDictionaryModeLanguages(picked);
    if (mounted) {
      setState(() {});
    }
  }

  /// All, and a chip for each language the dictionaries look up: picking
  /// some leaves only their dictionaries on.
  Widget _modes() {
    List<String> languages = appModel.dictionaryLanguages;
    if (languages.length < 2) {
      return const SizedBox.shrink();
    }
    Set<String> picked = appModel.dictionaryModeLanguages;
    Widget chip(String label, String? language) {
      bool selected =
          language == null ? picked.isEmpty : picked.contains(language);
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: ChoiceChip(
          label: Text(
            label,
            style: TextStyle(
              color: selected ? theme.colorScheme.primary : null,
              fontWeight: selected ? FontWeight.w600 : null,
            ),
          ),
          selected: selected,
          showCheckmark: false,
          shape: StadiumBorder(
            side: BorderSide(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.dividerColor.withOpacity(0.25),
              width: selected ? 1.5 : 1,
            ),
          ),
          backgroundColor: Colors.transparent,
          selectedColor: theme.colorScheme.primary.withOpacity(0.12),
          onSelected: (_) => _setMode(language),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 4, 6),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  chip(t.dictionary_mode_all, null),
                  for (String language in languages)
                    chip(catalogLanguageName(language), language),
                ],
              ),
            ),
          ),
          JidoujishoInfoButton(message: t.dictionary_mode_info),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  /// Small labels for what [dictionary] is: its languages, as `JA → VI`,
  /// and what it holds when that isn't words.
  Widget _labels(Dictionary dictionary, {required bool off}) {
    DictionaryProfile profile = appModel.profileOf(dictionary);
    String? source = profile.source?.toUpperCase();
    String? target = profile.target?.toUpperCase();
    String? languages = source == null
        ? null
        : target == null ||
                profile.kind == DictionaryProfile.frequency ||
                profile.kind == DictionaryProfile.pronunciation
            ? source
            : '$source → $target';
    String? kind = {
      DictionaryProfile.grammar: t.catalog_section_grammar,
      DictionaryProfile.kanji: t.catalog_section_kanji,
      DictionaryProfile.frequency: t.catalog_section_frequency,
      DictionaryProfile.pronunciation: t.catalog_section_pronunciation,
    }[profile.kind];
    if (languages == null && kind == null) {
      return const SizedBox.shrink();
    }
    Color color = off ? theme.unselectedWidgetColor : theme.colorScheme.primary;
    Widget pill(String text) => Container(
          margin: const EdgeInsets.only(right: 4, top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            style: textTheme.labelSmall!.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        );
    return Wrap(
      children: [
        if (languages != null) pill(languages),
        if (kind != null) pill(kind),
      ],
    );
  }

  /// Opens the dictionaries on the user's server, and shows any imported
  /// from there on return.
  Future<void> _openOnline() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DictionaryCatalogPage()),
    );
    if (mounted) {
      setState(() {});
    }
  }

  /// Picks files in [format] and imports them one after another.
  Future<void> _import(DictionaryFormat format) async {
    appModel.setLastSelectedDictionaryFormat(format);
    ValueNotifier<String> progressNotifier =
        ValueNotifier<String>(t.import_start);
    ValueNotifier<int?> countNotifier = ValueNotifier<int?>(null);
    ValueNotifier<int?> totalNotifier = ValueNotifier<int?>(null);
    progressNotifier.addListener(() {
      debugPrint('[Dictionary Import] ${progressNotifier.value}');
    });

    await FilePicker.platform.clearTemporaryFiles();
    bool showing = false;
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: format.fileType,
      allowedExtensions:
          format.fileType == FileType.any ? null : format.allowedExtensions,
      allowMultiple: true,
      onFileLoading: (status) {
        if (status == FilePickerStatus.done && !showing && mounted) {
          showing = true;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => DictionaryDialogImportPage(
              progressNotifier: progressNotifier,
              countNotifier: countNotifier,
              totalNotifier: totalNotifier,
            ),
          );
        }
      },
    );
    if (result == null) {
      if (showing && mounted) {
        Navigator.pop(context);
      }
      return;
    }

    totalNotifier.value = result.files.length;
    for (int i = 0; i < result.files.length; i++) {
      countNotifier.value = i + 1;
      await appModel.importDictionary(
        progressNotifier: progressNotifier,
        file: File(result.files[i].path!),
        format: format,
        onImportSuccess: () {
          if (mounted) {
            setState(() {});
          }
        },
      );
    }
    await FilePicker.platform.clearTemporaryFiles();
    if (showing && mounted) {
      Navigator.pop(context);
    }
  }

  /// Asks which format to import, the one used last first.
  Future<void> _chooseFormat(BuildContext anchor) async {
    List<DictionaryFormat> formats = appModel.dictionaryFormats.values.toList();
    DictionaryFormat last = appModel.lastSelectedDictionaryFormat;
    formats
      ..remove(last)
      ..insert(0, last);
    RenderBox box = anchor.findRenderObject()! as RenderBox;
    Offset corner = box.localToGlobal(Offset(0, box.size.height + 4));
    DictionaryFormat? format = await showMenu<DictionaryFormat>(
      context: context,
      position: RelativeRect.fromLTRB(
        corner.dx,
        corner.dy,
        MediaQuery.of(context).size.width - corner.dx - box.size.width,
        0,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        for (DictionaryFormat format in formats)
          PopupMenuItem(
            value: format,
            child: Row(
              children: [
                Icon(format.icon, size: 18),
                const SizedBox(width: 12),
                Expanded(child: Text(format.name)),
                if (format == last)
                  Icon(Ui.check, size: 16, color: theme.colorScheme.primary),
              ],
            ),
          ),
      ],
    );
    if (format != null) {
      await _import(format);
    }
  }

  Future<void> _deleteAll() async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(t.dialog_title_dictionary_clear),
        content: Text(t.dialog_content_dictionary_clear),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.dialog_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              t.dialog_clear,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (!mounted) {
      return;
    }
    if (confirmed != true) {
      return;
    }
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => const DictionaryDialogDeletePage(),
    );
    await appModel.deleteDictionaries();
    if (mounted) {
      Navigator.pop(context);
      setState(() {});
    }
  }

  Future<void> _delete(Dictionary dictionary) async {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (context) => DictionaryDialogDeletePage(name: dictionary.name),
    );
    await appModel.deleteDictionary(dictionary);
    if (mounted) {
      Navigator.pop(context);
      setState(() {});
    }
  }

  Future<void> _openDetails(Dictionary dictionary) async {
    bool? delete = await showTtuSheet<bool>(
      context: context,
      builder: (_) => _DictionaryDetailsSheet(
        dictionary: dictionary,
        onChanged: () {
          if (mounted) {
            setState(() {});
          }
        },
      ),
    );
    if (delete == true && mounted) {
      await _delete(dictionary);
    }
  }

  void _reorder(List<Dictionary> dictionaries, int from, int to) {
    if (to > from) {
      to -= 1;
    }
    Dictionary moved = dictionaries.removeAt(from);
    dictionaries.insert(to, moved);
    for (int i = 0; i < dictionaries.length; i++) {
      dictionaries[i].order = i;
    }
    appModel.updateDictionaryOrder(dictionaries);
    setState(() {});
  }

  Widget _header(int count) {
    Color muted = theme.unselectedWidgetColor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: t.dictionaries),
                  if (count > 0)
                    TextSpan(
                      text: '  $count',
                      style: textTheme.titleMedium!.copyWith(color: muted),
                    ),
                ],
              ),
              style:
                  textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (count > 0)
            PopupMenuButton<void>(
              tooltip: t.show_options,
              icon: const Icon(Ui.menuDots),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              itemBuilder: (_) => [
                PopupMenuItem<void>(
                  onTap: () => WidgetsBinding.instance
                      .addPostFrameCallback((_) => _deleteAll()),
                  child: Row(
                    children: [
                      Icon(Ui.trash, size: 18, color: theme.colorScheme.error),
                      const SizedBox(width: 12),
                      Text(
                        t.dictionary_delete_all,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          IconButton(
            tooltip: t.dialog_close,
            icon: const Icon(Ui.cross),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary.withOpacity(0.14),
                foregroundColor: theme.colorScheme.primary,
                shape: const StadiumBorder(),
                minimumSize: const Size.fromHeight(44),
              ),
              icon: const Icon(Ui.cloudDownload, size: 18),
              label: Text(t.catalog_open),
              onPressed: _openOnline,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Builder(
              builder: (anchor) => FilledButton.icon(
                style: FilledButton.styleFrom(
                  shape: const StadiumBorder(),
                  minimumSize: const Size.fromHeight(44),
                ),
                icon: const Icon(Ui.fileImport, size: 18),
                label: Text(t.dictionary_import),
                onPressed: () => _chooseFormat(anchor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(Dictionary dictionary, int index) {
    Color muted = theme.unselectedWidgetColor;
    bool hidden = dictionary.isHiddenByUser(appModel.targetLanguage);
    bool leftOut = !hidden && dictionary.isHidden(appModel.targetLanguage);
    bool off = hidden || leftOut;
    bool collapsed = dictionary.isCollapsed(appModel.targetLanguage);
    String? note = appModel.dictionaryNoteOf(dictionary);
    return Padding(
      key: ValueKey(dictionary.id),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: theme.dividerColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openDetails(dictionary),
          onLongPress: () => _openDetails(dictionary),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(Ui.grip, size: 18, color: muted),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dictionary.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyLarge!.copyWith(
                          fontWeight: FontWeight.w600,
                          color: off ? muted : null,
                        ),
                      ),
                      _labels(dictionary, off: off),
                      if (note != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          note,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall!.copyWith(
                            color: off ? muted : null,
                          ),
                        ),
                      ],
                      if (collapsed && !off) ...[
                        const SizedBox(height: 2),
                        Text(
                          t.dictionary_collapsed,
                          style: textTheme.bodySmall!.copyWith(color: muted),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  tooltip: leftOut
                      ? t.dictionary_off_in_mode
                      : hidden
                          ? t.options_show
                          : t.options_hide,
                  icon: Icon(
                    off ? Ui.eyeCrossed : Ui.eye,
                    size: 20,
                    color: off ? muted.withOpacity(leftOut ? 0.5 : 1) : null,
                  ),
                  // Out of the language mode, the dictionary comes back
                  // with All.
                  onPressed: leftOut
                      ? null
                      : () {
                          appModel.toggleDictionaryHidden(dictionary);
                          setState(() {});
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Dictionary> dictionaries = appModel.dictionaries;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => ReorderableListView.builder(
        scrollController: controller,
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.only(bottom: 24),
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TtuSheetHandle(),
            _header(dictionaries.length),
            _actions(),
            _modes(),
            if (dictionaries.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: JidoujishoPlaceholderMessage(
                  icon: DictionaryMediaType.instance.outlinedIcon,
                  message: t.dictionaries_menu_empty,
                ),
              ),
          ],
        ),
        proxyDecorator: (child, index, animation) => Material(
          color: Colors.transparent,
          elevation: 6,
          shadowColor: Colors.black38,
          borderRadius: BorderRadius.circular(16),
          child: child,
        ),
        itemCount: dictionaries.length,
        itemBuilder: (context, index) => _row(dictionaries[index], index),
        onReorder: (from, to) => _reorder(dictionaries, from, to),
      ),
    );
  }
}

/// One dictionary's details and what can be done with it. Pops with true
/// when the user chooses to delete it.
class _DictionaryDetailsSheet extends BasePage {
  const _DictionaryDetailsSheet({
    required this.dictionary,
    required this.onChanged,
  });

  final Dictionary dictionary;

  /// Showing or collapsing it changed.
  final VoidCallback onChanged;

  @override
  BasePageState<_DictionaryDetailsSheet> createState() =>
      _DictionaryDetailsSheetState();
}

class _DictionaryDetailsSheetState
    extends BasePageState<_DictionaryDetailsSheet> {
  bool _confirming = false;

  Widget _switch({
    required String title,
    required bool value,
    required VoidCallback onToggle,
  }) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 2, 6, 2),
        child: Row(
          children: [
            Expanded(child: Text(title, style: textTheme.bodyMedium)),
            Switch(value: value, onChanged: (_) => onToggle()),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Dictionary dictionary = widget.dictionary;
    Color muted = theme.unselectedWidgetColor;
    Map<String, String> index = appModel.dictionaryIndexOf(dictionary);
    Map<String, dynamic>? source = appModel.dictionarySources[dictionary.name];
    String? note = appModel.dictionaryNoteOf(dictionary);
    String? revision = appModel.installedRevisionOf(dictionary);
    DictionaryFormat? format = appModel.dictionaryFormats[dictionary.formatKey];
    String detail = [
      if (revision != null) revision,
      if (format != null) format.name,
      if (source?['kind'] == 'server')
        t.dictionary_from_server
      else
        t.dictionary_from_file,
    ].join(' · ');
    bool hidden = dictionary.isHidden(appModel.targetLanguage);
    bool collapsed = dictionary.isCollapsed(appModel.targetLanguage);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TtuSheetHandle(),
            const SizedBox(height: 10),
            Text(
              dictionary.name,
              style:
                  textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(detail, style: textTheme.bodySmall!.copyWith(color: muted)),
            if (note != null) ...[
              const SizedBox(height: 12),
              SelectableText(note, style: textTheme.bodyMedium),
            ],
            if (index.isNotEmpty) ...[
              const SizedBox(height: 12),
              DictionaryAbout(
                description: index['description'],
                author: index['author'],
                attribution: index['attribution'],
                url: index['url'],
              ),
            ],
            const SizedBox(height: 12),
            Material(
              color: theme.dividerColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _switch(
                    title: t.dictionary_show_in_results,
                    value: !hidden,
                    onToggle: () {
                      appModel.toggleDictionaryHidden(dictionary);
                      setState(() {});
                      widget.onChanged();
                    },
                  ),
                  _switch(
                    title: t.dictionary_start_collapsed,
                    value: collapsed,
                    onToggle: () {
                      appModel.toggleDictionaryCollapsed(dictionary);
                      setState(() {});
                      widget.onChanged();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: Icon(Ui.trash, size: 18, color: theme.colorScheme.error),
              label: Text(
                _confirming ? t.catalog_delete_confirm : t.dictionary_delete,
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: _confirming ? FontWeight.bold : null,
                ),
              ),
              onPressed: () {
                if (!_confirming) {
                  setState(() => _confirming = true);
                  return;
                }
                Navigator.pop(context, true);
              },
            ),
          ],
        ),
      ),
    );
  }
}
