import 'dart:async';
import 'dart:io';
import 'dart:ui' show FontFeature;

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/models.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

const Map<String, String> _languageNames = {
  'ja': 'Japanese',
  'en': 'English',
  'vi': 'Vietnamese',
  'zh': 'Chinese',
  'ko': 'Korean',
  'fr': 'French',
  'de': 'German',
  'es': 'Spanish',
  'ru': 'Russian',
  'th': 'Thai',
  'ar': 'Arabic',
};

/// A language's name, or its code when the app doesn't know it.
String catalogLanguageName(String? code) => code == null
    ? t.catalog_unknown_language
    : _languageNames[code] ?? code.toUpperCase();

String _code(String? language) => (language ?? '?').toUpperCase();

String _megabytes(int bytes) {
  double mb = bytes / (1024 * 1024);
  return mb >= 10 ? '${mb.round()} MB' : '${mb.toStringAsFixed(1)} MB';
}

String _count(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (match) => '${match[1]},',
    );

/// A word worth looking up first when previewing a dictionary.
String _sampleWord(String? language) => switch (language) {
      'ja' || 'zh' => '猫',
      'ko' => '고양이',
      'vi' => 'nhà',
      'en' => 'house',
      _ => '',
    };

String _sectionName(CatalogSection section) => switch (section) {
      CatalogSection.bilingual => t.catalog_section_bilingual,
      CatalogSection.monolingual => t.catalog_section_monolingual,
      CatalogSection.kanji => t.catalog_section_kanji,
      CatalogSection.frequency => t.catalog_section_frequency,
      CatalogSection.pronunciation => t.catalog_section_pronunciation,
      CatalogSection.other => t.catalog_section_other,
    };

/// Dictionaries on the user's own server: browse them by language and kind,
/// preview them with a search, download and import them, and with an admin
/// token, upload, relabel and delete them.
class DictionaryCatalogPage extends BasePage {
  /// Create the page.
  const DictionaryCatalogPage({super.key});

  @override
  BasePageState<DictionaryCatalogPage> createState() =>
      _DictionaryCatalogPageState();
}

class _DictionaryCatalogPageState extends BasePageState<DictionaryCatalogPage> {
  DictionaryServer? _server;
  bool _admin = false;
  List<CatalogDictionary>? _dictionaries;
  Object? _error;
  bool _loading = false;
  bool _languageChosen = false;
  String? _language;
  Timer? _poll;

  /// Downloads under way: progress from 0 to 1, or null while unknown.
  final Map<String, double?> _downloads = {};
  final Map<String, CancelToken> _cancels = {};
  ({String name, double progress, CancelToken cancel})? _upload;

  /// Files were picked to upload, so the picker's copies need clearing.
  bool _picked = false;

  @override
  void initState() {
    super.initState();
    _server = appModelNoUpdate.dictionaryServer;
    _admin = appModelNoUpdate.isDictionaryServerAdmin;
    if (_server != null) {
      _load();
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    for (CancelToken cancel in _cancels.values) {
      cancel.cancel();
    }
    _upload?.cancel.cancel();
    if (_picked) {
      FilePicker.platform.clearTemporaryFiles();
    }
    super.dispose();
  }

  void _say(String message, {SnackBarAction? action}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }

  Future<void> _load({bool quietly = false}) async {
    DictionaryServer? server = _server;
    if (server == null) {
      return;
    }
    if (!quietly) {
      setState(() => _loading = true);
    }
    try {
      List<CatalogDictionary> dictionaries = await server.list();
      if (!mounted) {
        return;
      }
      setState(() {
        _dictionaries = dictionaries;
        _error = null;
        if (!_languageChosen) {
          String here = appModel.targetLanguage.languageCode;
          bool present = dictionaries.any((d) => d.sourceLanguage == here);
          _language = present ? here : null;
        }
      });
    } catch (error) {
      if (mounted && !quietly) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted && !quietly) {
        setState(() => _loading = false);
      }
    }
    _schedulePoll();
  }

  /// Follows dictionaries the server is still preparing.
  void _schedulePoll() {
    _poll?.cancel();
    if (mounted && (_dictionaries?.any((d) => d.isPreparing) ?? false)) {
      _poll = Timer(const Duration(seconds: 3), () => _load(quietly: true));
    }
  }

  Future<String?> _connect(String url, String token) async {
    DictionaryServer server = DictionaryServer(url: url, token: token);
    try {
      String role = await server.role();
      await appModel.setDictionaryServer(
        url: server.url,
        token: token,
        role: role,
      );
      setState(() {
        _server = server;
        _admin = role == 'admin';
      });
      await _load();
      return null;
    } on DictionaryServerException catch (error) {
      return error.message;
    }
  }

  Future<void> _disconnect() async {
    await appModel.clearDictionaryServer();
    setState(() {
      _server = null;
      _admin = false;
      _dictionaries = null;
      _error = null;
    });
  }

  /* ---------- download and import ---------- */

  Future<void> _download(CatalogDictionary dictionary) async {
    DictionaryServer? server = _server;
    if (server == null || _downloads.containsKey(dictionary.id)) {
      return;
    }
    Directory temp = await getTemporaryDirectory();
    File file = File(path.join(temp.path, 'catalog-${dictionary.id}.zip'));
    CancelToken cancel = CancelToken();
    setState(() {
      _downloads[dictionary.id] = 0;
      _cancels[dictionary.id] = cancel;
    });

    bool done = false;
    try {
      int shown = -1;
      await server.download(
        dictionary,
        file,
        cancelToken: cancel,
        onProgress: (received, total) {
          int size = total > 0 ? total : dictionary.size;
          int percent = size > 0 ? received * 100 ~/ size : -1;
          if (percent != shown && mounted) {
            shown = percent;
            setState(() =>
                _downloads[dictionary.id] = percent < 0 ? null : percent / 100);
          }
        },
      );
      done = true;
    } on DictionaryServerException catch (error) {
      _say(error.message);
    } on DioError {
      // Cancelled.
    } finally {
      if (mounted) {
        setState(() {
          _downloads.remove(dictionary.id);
          _cancels.remove(dictionary.id);
        });
      }
    }

    if (done && mounted) {
      await _import(dictionary, file);
    }
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  Future<void> _import(CatalogDictionary dictionary, File file) async {
    ValueNotifier<String> progress = ValueNotifier(t.import_start);
    ValueNotifier<int?> count = ValueNotifier(1);
    ValueNotifier<int?> total = ValueNotifier(1);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => DictionaryDialogImportPage(
        progressNotifier: progress,
        countNotifier: count,
        totalNotifier: total,
      ),
    );
    bool imported = false;
    await appModel.importDictionary(
      file: file,
      progressNotifier: progress,
      format: YomichanFormat.instance,
      onImportSuccess: () => imported = true,
    );
    if (!mounted) {
      return;
    }
    Navigator.pop(context);
    if (imported) {
      _say(t.catalog_imported(name: dictionary.title));
    }
    setState(() {});
  }

  /* ---------- admin ---------- */

  Future<void> _pickAndUpload() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      allowMultiple: true,
    );
    _picked = _picked || result != null;
    for (PlatformFile picked in result?.files ?? const <PlatformFile>[]) {
      String? filePath = picked.path;
      if (filePath != null && mounted) {
        await _uploadOne(File(filePath));
      }
    }
  }

  Future<void> _uploadOne(File file, {bool replace = false}) async {
    DictionaryServer? server = _server;
    if (server == null || _upload != null) {
      return;
    }
    String name = path.basename(file.path);
    CancelToken cancel = CancelToken();
    setState(() => _upload = (name: name, progress: 0, cancel: cancel));
    try {
      int shown = -1;
      CatalogDictionary added = await server.upload(
        file,
        replace: replace,
        cancelToken: cancel,
        onProgress: (sent, total) {
          int percent = total > 0 ? sent * 100 ~/ total : 0;
          if (percent != shown && mounted) {
            shown = percent;
            setState(() => _upload =
                (name: name, progress: percent / 100, cancel: cancel));
          }
        },
      );
      _say(t.catalog_uploaded(name: added.title));
    } on DictionaryServerException catch (error) {
      _say(
        error.message,
        action: error.statusCode == 409
            ? SnackBarAction(
                label: t.catalog_replace,
                onPressed: () => _uploadOne(file, replace: true),
              )
            : null,
      );
    } on DioError {
      // Cancelled.
    } finally {
      if (mounted) {
        setState(() => _upload = null);
      }
    }
    await _load(quietly: true);
  }

  Future<void> _manage(CatalogDictionary dictionary) async {
    DictionaryServer? server = _server;
    if (server == null) {
      return;
    }
    await showTtuSheet<void>(
      context: context,
      builder: (_) => _CatalogManageSheet(
        dictionary: dictionary,
        onRelabel: (source, target) async {
          try {
            await server.relabel(dictionary.id, source: source, target: target);
            await _load(quietly: true);
          } on DictionaryServerException catch (error) {
            _say(error.message);
          }
        },
        onDelete: () async {
          try {
            await server.delete(dictionary.id);
            _say(t.catalog_deleted(name: dictionary.title));
            await _load(quietly: true);
          } on DictionaryServerException catch (error) {
            _say(error.message);
          }
        },
      ),
    );
  }

  Future<void> _preview(CatalogDictionary dictionary) async {
    DictionaryServer? server = _server;
    if (server == null) {
      return;
    }
    if (dictionary.hasFailed) {
      _say(dictionary.error ?? t.catalog_failed);
      return;
    }
    if (!dictionary.isReady) {
      return;
    }
    bool installed = appModel.hasDictionaryNamed(dictionary.title);
    bool? download = await showTtuSheet<bool>(
      context: context,
      builder: (_) => _CatalogPreviewSheet(
        server: server,
        dictionary: dictionary,
        installed: installed,
      ),
    );
    if (download == true) {
      _download(dictionary);
    }
  }

  /* ---------- page ---------- */

  @override
  Widget build(BuildContext context) {
    DictionaryServer? server = _server;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.catalog_title),
        actions: [
          if (server != null && _admin)
            IconButton(
              tooltip: t.catalog_upload,
              icon: const Icon(Ui.cloudUpload),
              onPressed: _upload == null ? _pickAndUpload : null,
            ),
          if (server != null)
            IconButton(
              tooltip: t.catalog_server,
              icon: const Icon(Ui.server),
              onPressed: () => showTtuSheet<void>(
                context: context,
                builder: (_) => _ServerSheet(
                  server: server,
                  admin: _admin,
                  onDisconnect: _disconnect,
                ),
              ),
            ),
        ],
      ),
      body:
          server == null ? _CatalogSetup(onConnect: _connect) : buildCatalog(),
    );
  }

  Widget buildCatalog() {
    List<CatalogDictionary>? dictionaries = _dictionaries;
    Color muted = theme.unselectedWidgetColor;

    if (dictionaries == null) {
      if (_error != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                JidoujishoPlaceholderMessage(
                  icon: Ui.server,
                  message: '$_error',
                ),
                const SizedBox(height: 12),
                TextButton(onPressed: _load, child: Text(t.ttu_try_again)),
              ],
            ),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    List<String> languages = dictionaries
        .map((d) => d.sourceLanguage)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort(
          (a, b) => catalogLanguageName(a).compareTo(catalogLanguageName(b)));
    List<CatalogDictionary> shown = dictionaries
        .where((d) => _language == null || d.sourceLanguage == _language)
        .toList();
    Map<CatalogSection, List<CatalogDictionary>> sections = {};
    for (CatalogDictionary dictionary in shown) {
      sections.putIfAbsent(dictionary.section, () => []).add(dictionary);
    }
    for (List<CatalogDictionary> list in sections.values) {
      list.sort((a, b) {
        int pair = '${a.sourceLanguage}${a.targetLanguage}'
            .compareTo('${b.sourceLanguage}${b.targetLanguage}');
        return pair != 0
            ? pair
            : a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });
    }

    ({String name, double progress, CancelToken cancel})? upload = _upload;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (languages.length > 1)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _LanguageChip(
                    label: t.catalog_all,
                    selected: _language == null,
                    onTap: () => setState(() {
                      _languageChosen = true;
                      _language = null;
                    }),
                  ),
                  for (String language in languages)
                    _LanguageChip(
                      label: catalogLanguageName(language),
                      selected: _language == language,
                      onTap: () => setState(() {
                        _languageChosen = true;
                        _language = language;
                      }),
                    ),
                ],
              ),
            ),
          if (upload != null)
            _UploadCard(
              name: upload.name,
              progress: upload.progress,
              onCancel: () => upload.cancel.cancel(),
            ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (dictionaries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(48),
              child: JidoujishoPlaceholderMessage(
                icon: Ui.cloudDownload,
                message: t.catalog_empty,
              ),
            ),
          for (CatalogSection section in CatalogSection.values)
            if (sections[section] != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                child: Text(
                  '${_sectionName(section)} · ${sections[section]!.length}',
                  style: textTheme.labelLarge!.copyWith(
                    color: muted,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              for (CatalogDictionary dictionary in sections[section]!)
                _CatalogTile(
                  dictionary: dictionary,
                  installed: appModel.hasDictionaryNamed(dictionary.title),
                  downloading: _downloads.containsKey(dictionary.id),
                  progress: _downloads[dictionary.id],
                  onTap: () => _preview(dictionary),
                  onDownload: () => _download(dictionary),
                  onCancel: () => _cancels[dictionary.id]?.cancel(),
                  onManage: _admin ? () => _manage(dictionary) : null,
                ),
            ],
        ],
      ),
    );
  }
}

/* ---------- connecting ---------- */

class _CatalogSetup extends StatefulWidget {
  const _CatalogSetup({required this.onConnect});

  /// Tries the address and token; resolves to an error message or null.
  final Future<String?> Function(String url, String token) onConnect;

  @override
  State<_CatalogSetup> createState() => _CatalogSetupState();
}

class _CatalogSetupState extends State<_CatalogSetup> {
  final TextEditingController _url = TextEditingController();
  final TextEditingController _token = TextEditingController();
  bool _hidden = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // A link with the token after # fills in both fields.
    _url.addListener(() {
      String text = _url.text;
      int hash = text.indexOf('#');
      if (hash > 0 && hash < text.length - 1) {
        _token.text = text.substring(hash + 1).trim();
        _url.text = text.substring(0, hash);
      }
    });
  }

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_url.text.trim().isEmpty || _token.text.trim().isEmpty) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    String? error = await widget.onConnect(_url.text, _token.text.trim());
    if (mounted) {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Color accent = theme.colorScheme.primary;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Icon(Ui.cloudDownload, size: 36, color: accent),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                t.catalog_connect_title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge!
                    .copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            JidoujishoInfoButton(message: t.catalog_connect_hint),
          ],
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _url,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: t.catalog_address,
            hintText: 'https://dict.example.com',
            prefixIcon: const Icon(Ui.globe, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _token,
          obscureText: _hidden,
          autocorrect: false,
          enableSuggestions: false,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: t.catalog_token,
            prefixIcon: const Icon(Ui.key, size: 20),
            suffixIcon: IconButton(
              icon: Icon(_hidden ? Ui.visibility : Ui.visibility_off, size: 20),
              onPressed: () => setState(() => _hidden = !_hidden),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        const SizedBox(height: 20),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const StadiumBorder(),
            ),
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t.catalog_connect),
          ),
        ),
      ],
    );
  }
}

class _ServerSheet extends StatelessWidget {
  const _ServerSheet({
    required this.server,
    required this.admin,
    required this.onDisconnect,
  });

  final DictionaryServer server;
  final bool admin;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TtuSheetHandle(),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Ui.server, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  server.url,
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(
              admin ? t.catalog_role_admin : t.catalog_role_read,
              style: theme.textTheme.bodySmall!
                  .copyWith(color: theme.unselectedWidgetColor),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
                onDisconnect();
              },
              child: Text(
                t.catalog_disconnect,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------- the list ---------- */

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Color accent = theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Material(
        color: selected ? accent : theme.dividerColor.withOpacity(0.1),
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: selected ? Colors.white : null,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The languages or kind of a dictionary at a glance: `JA → EN`, `EN`,
/// `字`, `#` or `/ə/`.
class _Badge extends StatelessWidget {
  const _Badge({required this.dictionary});

  final CatalogDictionary dictionary;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Color accent = theme.colorScheme.primary;
    TextStyle big = theme.textTheme.titleSmall!.copyWith(
      fontWeight: FontWeight.bold,
      color: accent,
      height: 1.1,
      fontFamilyFallback: const [AppModel.ipaFontFamily],
    );
    TextStyle small = theme.textTheme.labelSmall!.copyWith(
      color: accent.withOpacity(0.8),
      height: 1.1,
      letterSpacing: 0,
    );
    Widget content = switch (dictionary.section) {
      CatalogSection.bilingual => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_code(dictionary.sourceLanguage), style: big),
            Text('→ ${_code(dictionary.targetLanguage)}', style: small),
          ],
        ),
      CatalogSection.monolingual =>
        Text(_code(dictionary.sourceLanguage), style: big),
      CatalogSection.kanji => Text('字', style: big),
      CatalogSection.frequency => Text('#', style: big),
      CatalogSection.pronunciation => Text('/ə/', style: big),
      CatalogSection.other => Icon(Ui.books, size: 18, color: accent),
    };
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: content,
    );
  }
}

class _CatalogTile extends StatelessWidget {
  const _CatalogTile({
    required this.dictionary,
    required this.installed,
    required this.downloading,
    required this.progress,
    required this.onTap,
    required this.onDownload,
    required this.onCancel,
    required this.onManage,
  });

  final CatalogDictionary dictionary;
  final bool installed;
  final bool downloading;
  final double? progress;
  final VoidCallback onTap;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Color muted = theme.unselectedWidgetColor;
    Color accent = theme.colorScheme.primary;

    String detail = [
      if (dictionary.entries > 0)
        t.catalog_entries(n: _count(dictionary.entries)),
      _megabytes(dictionary.size),
      if (dictionary.isPreparing) t.catalog_preparing,
      if (dictionary.hasFailed) t.catalog_failed,
    ].join(' · ');

    Widget trailing;
    if (downloading) {
      trailing = InkResponse(
        onTap: onCancel,
        radius: 22,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2.5,
                ),
              ),
              Icon(Ui.cross, size: 14, color: muted),
            ],
          ),
        ),
      );
    } else if (installed) {
      trailing = Tooltip(
        message: t.catalog_installed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(Ui.checkCircleSolid, color: accent, size: 22),
        ),
      );
    } else if (dictionary.isPreparing) {
      trailing = const SizedBox(
        width: 40,
        height: 40,
        child: Padding(
          padding: EdgeInsets.all(11),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else if (dictionary.hasFailed) {
      trailing = SizedBox(
        width: 40,
        height: 40,
        child: Icon(Ui.error, color: theme.colorScheme.error, size: 20),
      );
    } else {
      trailing = IconButton(
        tooltip: t.catalog_download,
        icon: Icon(Ui.download, color: accent, size: 22),
        onPressed: onDownload,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: theme.dividerColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onManage,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
            child: Row(
              children: [
                _Badge(dictionary: dictionary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dictionary.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge!
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall!.copyWith(
                          color: dictionary.hasFailed
                              ? theme.colorScheme.error
                              : muted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({
    required this.name,
    required this.progress,
    required this.onCancel,
  });

  final String name;
  final double progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Color accent = theme.colorScheme.primary;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 12),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Ui.cloudUpload, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.catalog_uploading(name: name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium!
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    value: progress >= 1 ? null : progress,
                    backgroundColor: accent.withOpacity(0.15),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: t.dialog_cancel,
            icon: const Icon(Ui.cross, size: 20),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

/* ---------- preview ---------- */

/// Searches one dictionary on the server and shows what it finds the way
/// the popup would. Pops with true when the user chooses to download it.
class _CatalogPreviewSheet extends StatefulWidget {
  const _CatalogPreviewSheet({
    required this.server,
    required this.dictionary,
    required this.installed,
  });

  final DictionaryServer server;
  final CatalogDictionary dictionary;
  final bool installed;

  @override
  State<_CatalogPreviewSheet> createState() => _CatalogPreviewSheetState();
}

class _CatalogPreviewSheetState extends State<_CatalogPreviewSheet> {
  late final TextEditingController _query = TextEditingController(
    text: _sampleWord(widget.dictionary.sourceLanguage),
  );
  late final Dictionary _asDictionary = Dictionary(
    id: -1,
    name: widget.dictionary.title,
    formatKey: YomichanFormat.instance.uniqueKey,
    order: 0,
  );
  Timer? _debounce;
  CatalogResults? _results;
  List<DictionaryEntry> _entries = const [];
  String? _error;
  bool _searching = false;
  int _serial = 0;

  @override
  void initState() {
    super.initState();
    if (_query.text.isNotEmpty) {
      _search();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  Future<void> _search() async {
    _debounce?.cancel();
    String query = _query.text.trim();
    int serial = ++_serial;
    if (query.isEmpty) {
      setState(() {
        _results = null;
        _entries = const [];
        _error = null;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      CatalogResults results =
          await widget.server.search(widget.dictionary.id, query);
      if (!mounted || serial != _serial) {
        return;
      }
      setState(() {
        _results = results;
        _entries = results.entriesFor(_asDictionary);
        _error = null;
      });
    } on DictionaryServerException catch (error) {
      if (mounted && serial == _serial) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted && serial == _serial) {
        setState(() => _searching = false);
      }
    }
  }

  void _lookUp(String text) {
    _query.text = text.trim();
    _search();
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    Color muted = theme.unselectedWidgetColor;
    Color accent = theme.colorScheme.primary;
    CatalogDictionary dictionary = widget.dictionary;
    String about = [
      if (dictionary.author != null) dictionary.author!,
      if (dictionary.description != null) dictionary.description!,
      if (dictionary.attribution != null) dictionary.attribution!,
      if (dictionary.url != null) dictionary.url!,
    ].join('\n\n');
    String languages = dictionary.section == CatalogSection.bilingual
        ? '${catalogLanguageName(dictionary.sourceLanguage)} → '
            '${catalogLanguageName(dictionary.targetLanguage)}'
        : catalogLanguageName(dictionary.sourceLanguage);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          const TtuSheetHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
            child: Row(
              children: [
                _Badge(dictionary: dictionary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dictionary.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium!
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '$languages · ${_megabytes(dictionary.size)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall!
                                  .copyWith(color: muted),
                            ),
                          ),
                          if (about.isNotEmpty)
                            JidoujishoInfoButton(message: about, size: 14),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (widget.installed)
                  Icon(Ui.checkCircleSolid, color: accent)
                else
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.fromLTRB(12, 0, 16, 0),
                    ),
                    icon: const Icon(Ui.download, size: 18),
                    label: Text(t.catalog_download),
                    onPressed: () => Navigator.pop(context, true),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _query,
              onChanged: _onChanged,
              onSubmitted: (_) => _search(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: t.catalog_search_hint,
                prefixIcon: const Icon(Ui.search, size: 20),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: theme.dividerColor.withOpacity(0.08),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ProviderScope(
              overrides: [
                dictionaryPreviewImageProvider.overrideWithValue(
                  (src) => NetworkImage(
                    widget.server.mediaUrl(dictionary.id, src),
                    headers: widget.server.headers,
                  ),
                ),
              ],
              child: buildResults(controller),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildResults(ScrollController controller) {
    ThemeData theme = Theme.of(context);
    Color muted = theme.unselectedWidgetColor;
    CatalogResults? results = _results;
    String? error = _error;

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(error, style: TextStyle(color: theme.colorScheme.error)),
        ),
      );
    }
    if (results == null) {
      return const SizedBox.shrink();
    }
    if (results.isEmpty) {
      return Center(
        child: Text(
          t.catalog_nothing_found(query: '“${_query.text.trim()}”'),
          style: theme.textTheme.bodyMedium!.copyWith(color: muted),
        ),
      );
    }

    List<CatalogMetaLine> meta = results.metaLines;
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        for (DictionaryEntry entry in _entries) ...[
          _PreviewEntry(entry: entry, onSearch: _lookUp),
          Divider(height: 24, color: theme.dividerColor.withOpacity(0.3)),
        ],
        for (CatalogMetaLine line in meta)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  line.term,
                  style: theme.textTheme.titleMedium!
                      .copyWith(fontWeight: FontWeight.bold),
                ),
                if (line.reading.isNotEmpty && line.reading != line.term) ...[
                  const SizedBox(width: 6),
                  Text(
                    line.reading,
                    style: theme.textTheme.bodyMedium!.copyWith(color: muted),
                  ),
                ],
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    line.text,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontFamilyFallback: const [AppModel.ipaFontFamily],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PreviewEntry extends StatelessWidget {
  const _PreviewEntry({required this.entry, required this.onSearch});

  final DictionaryEntry entry;
  final void Function(String) onSearch;

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    DictionaryHeading heading = entry.heading.value!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 8,
          children: [
            Text(
              heading.term,
              style: theme.textTheme.titleLarge!
                  .copyWith(fontWeight: FontWeight.bold),
            ),
            if (heading.reading.isNotEmpty && heading.reading != heading.term)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  heading.reading,
                  style: theme.textTheme.bodyLarge!
                      .copyWith(color: theme.unselectedWidgetColor),
                ),
              ),
          ],
        ),
        if (entry.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              children: [
                for (DictionaryTag tag in entry.tags)
                  JidoujishoTag(
                    text: tag.name,
                    message: tag.notes,
                    backgroundColor: tag.color,
                  ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        DictionaryHtmlWidget(entry: entry, onSearch: onSearch),
      ],
    );
  }
}

/* ---------- managing ---------- */

class _CatalogManageSheet extends StatefulWidget {
  const _CatalogManageSheet({
    required this.dictionary,
    required this.onRelabel,
    required this.onDelete,
  });

  final CatalogDictionary dictionary;
  final Future<void> Function(String? source, String? target) onRelabel;
  final Future<void> Function() onDelete;

  @override
  State<_CatalogManageSheet> createState() => _CatalogManageSheetState();
}

class _CatalogManageSheetState extends State<_CatalogManageSheet> {
  late String? _source = widget.dictionary.sourceLanguage;
  late String? _target = widget.dictionary.targetLanguage;
  bool _confirming = false;
  bool _busy = false;

  List<String?> get _options {
    List<String?> options = [..._languageNames.keys];
    for (String? code in [
      widget.dictionary.sourceLanguage,
      widget.dictionary.targetLanguage
    ]) {
      if (!options.contains(code)) {
        options.add(code);
      }
    }
    return options;
  }

  Widget _picker(String label, String? value, ValueChanged<String?> onChanged) {
    ThemeData theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium!
                .copyWith(color: theme.unselectedWidgetColor),
          ),
          DropdownButton<String?>(
            value: value,
            isExpanded: true,
            icon: const Icon(Ui.angleDown, size: 18),
            borderRadius: BorderRadius.circular(14),
            items: [
              for (String? code in _options)
                DropdownMenuItem(
                  value: code,
                  child: Text(catalogLanguageName(code)),
                ),
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);
    CatalogDictionary dictionary = widget.dictionary;
    bool changed = _source != dictionary.sourceLanguage ||
        _target != dictionary.targetLanguage;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TtuSheetHandle(),
          const SizedBox(height: 10),
          Row(
            children: [
              _Badge(dictionary: dictionary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  dictionary.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium!
                      .copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              JidoujishoInfoButton(message: t.catalog_languages_hint),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _picker(t.catalog_words, _source,
                  (code) => setState(() => _source = code)),
              const SizedBox(width: 16),
              _picker(t.catalog_definitions, _target,
                  (code) => setState(() => _target = code)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton.icon(
                icon: Icon(Ui.trash, size: 18, color: theme.colorScheme.error),
                label: Text(
                  _confirming ? t.catalog_delete_confirm : t.catalog_delete,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: _confirming ? FontWeight.bold : null,
                  ),
                ),
                onPressed: _busy
                    ? null
                    : () async {
                        if (!_confirming) {
                          setState(() => _confirming = true);
                          return;
                        }
                        setState(() => _busy = true);
                        Navigator.pop(context);
                        await widget.onDelete();
                      },
              ),
              const Spacer(),
              TextButton(
                onPressed: changed && !_busy
                    ? () async {
                        setState(() => _busy = true);
                        Navigator.pop(context);
                        await widget.onRelabel(_source, _target);
                      }
                    : null,
                child: Text(t.catalog_save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
