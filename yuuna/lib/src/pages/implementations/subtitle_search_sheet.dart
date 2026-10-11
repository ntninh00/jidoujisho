import 'dart:io';

import 'package:flutter/material.dart';
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// Finds Japanese subtitles for a video on Jimaku, through the dictionary
/// server, and closes with the file picked, saved on the phone.
class SubtitleSearchSheet extends BasePage {
  /// Search for [name]'s subtitles, the name of the video's file or page.
  const SubtitleSearchSheet({
    required this.name,
    super.key,
  });

  /// The video's file or page name, which the show and episode are
  /// guessed from.
  final String name;

  @override
  BasePageState<SubtitleSearchSheet> createState() =>
      _SubtitleSearchSheetState();
}

class _SubtitleSearchSheetState extends BasePageState<SubtitleSearchSheet> {
  late final SubtitleGuess _guess = SubtitleGuess.of(widget.name);
  late final TextEditingController _query =
      TextEditingController(text: _guess.show);

  List<SubtitleShow>? _shows;
  SubtitleShow? _show;
  List<SubtitleFile>? _files;
  late int? _episode = _guess.episode;
  bool _allFiles = false;

  /// The chip of the episode looked for, scrolled to when the files come.
  final GlobalKey _episodeChip = GlobalKey();
  bool _busy = false;
  String? _error;
  SubtitleFile? _fetching;

  @override
  void initState() {
    super.initState();
    if (_guess.show.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  DictionaryServer? get _server => appModelNoUpdate.dictionaryServer;

  /// What went wrong, in the app's language where it is known.
  String _problem(Object error) {
    if (error is DictionaryServerException) {
      if (error.statusCode == 404 && error.message.contains('not set up')) {
        return t.subtitle_search_not_set_up;
      }
      return error.message;
    }
    return '$error';
  }

  Future<void> _run(Future<void> Function() work) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await work();
    } catch (error) {
      _error = _problem(error);
    }
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  Future<void> _search() async {
    String query = _query.text.trim();
    DictionaryServer? server = _server;
    if (query.isEmpty || server == null) {
      return;
    }
    await _run(() async {
      _shows = await server.searchSubtitles(query);
      _show = null;
      _files = null;
    });
  }

  Future<void> _open(SubtitleShow show) async {
    DictionaryServer server = _server!;
    setState(() {
      _show = show;
      _files = null;
      _allFiles = false;
    });
    await _run(() async {
      _files = await server.subtitleFiles(show);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        BuildContext? chip = _episodeChip.currentContext;
        if (chip != null) {
          Scrollable.ensureVisible(chip, alignment: 0.5);
        }
      });
    });
  }

  Future<void> _pick(SubtitleFile file) async {
    DictionaryServer server = _server!;
    setState(() {
      _fetching = file;
      _error = null;
    });
    try {
      File saved = await server.subtitleFile(
        _show!,
        file,
        Directory('${appModel.temporaryDirectory.path}/subtitles'),
      );
      if (mounted) {
        Navigator.pop(context, saved);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _problem(error);
          _fetching = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: EdgeInsets.only(
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        children: [
          const TtuSheetHandle(),
          _header(),
          if (_server == null)
            _message(Ui.subtitles_off_outlined, t.subtitle_search_no_server)
          else if (_show == null) ...[
            _searchField(),
            ..._showList(),
          ] else
            ..._fileList(),
        ],
      ),
    );
  }

  Widget _header() {
    SubtitleShow? show = _show;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          if (show != null)
            IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const Icon(Ui.arrow_back),
              onPressed: () => setState(() {
                _show = null;
                _files = null;
                _error = null;
              }),
            )
          else
            const SizedBox(width: 12),
          Expanded(
            child: Text(
              show == null
                  ? t.player_option_find_subtitles
                  : show.japaneseName ?? show.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (show == null)
            JidoujishoInfoButton(message: t.subtitle_search_info),
          IconButton(
            tooltip: t.dialog_close,
            icon: const Icon(Ui.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: _query,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _search(),
        decoration: InputDecoration(
          hintText: t.subtitle_search_hint,
          isDense: true,
          filled: true,
          fillColor: theme.dividerColor.withOpacity(0.08),
          prefixIcon: const Icon(Ui.search, size: 18),
          suffixIcon: _busy && _show == null
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  List<Widget> _showList() {
    List<SubtitleShow>? shows = _shows;
    return [
      if (_error != null) _message(Ui.subtitles_off_outlined, _error!),
      if (shows != null && shows.isEmpty && _error == null)
        _message(Ui.search_off, t.subtitle_search_empty),
      for (SubtitleShow show in shows ?? const <SubtitleShow>[])
        _row(
          title: show.japaneseName ?? show.name,
          subtitle: [
            if (show.japaneseName != null) show.name,
            if (show.englishName != null && show.englishName != show.name)
              show.englishName!,
          ].join(' · '),
          onTap: () => _open(show),
        ),
    ];
  }

  List<Widget> _fileList() {
    List<SubtitleFile>? files = _files;
    if (files == null) {
      return [
        if (_error != null)
          _message(Ui.subtitles_off_outlined, _error!)
        else
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
      ];
    }
    List<SubtitleFile> shown = _allFiles || _episode == null
        ? files
        : files.where((file) => file.episode == _episode).toList();
    shown = [...shown]..sort((a, b) {
        int byEpisode = (a.episode ?? 9999).compareTo(b.episode ?? 9999);
        return byEpisode != 0 ? byEpisode : a.name.compareTo(b.name);
      });
    return [
      _episodeChips(files),
      if (_error != null) _message(Ui.subtitles_off_outlined, _error!),
      if (files.isEmpty)
        _message(Ui.subtitles_off_outlined, t.subtitle_files_empty)
      else if (shown.isEmpty)
        _message(Ui.search_off, t.subtitle_episode_empty),
      for (SubtitleFile file in shown)
        _row(
          title: file.fileName,
          subtitle: [
            if (file.archive != null) file.archive!,
            _size(file.size),
          ].join(' · '),
          busy: _fetching == file,
          onTap: _fetching == null ? () => _pick(file) : null,
        ),
    ];
  }

  /// The episode looked for, which can be changed, and all files.
  Widget _episodeChips(List<SubtitleFile> files) {
    List<int> episodes = files
        .map((file) => file.episode)
        .whereType<int>()
        .toSet()
        .toList()
      ..sort();
    Widget chip(String label,
            {required bool selected, required VoidCallback onTap}) =>
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            label: Text(label),
            selected: selected,
            showCheckmark: false,
            labelStyle: TextStyle(
              color: selected ? theme.colorScheme.primary : null,
              fontWeight: selected ? FontWeight.w600 : null,
            ),
            shape: StadiumBorder(
              side: BorderSide(
                color: selected
                    ? theme.colorScheme.primary
                    : theme.dividerColor.withOpacity(0.25),
              ),
            ),
            backgroundColor: Colors.transparent,
            selectedColor: theme.colorScheme.primary.withOpacity(0.12),
            onSelected: (_) => onTap(),
          ),
        );
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          chip(
            t.subtitle_all_files,
            selected: _allFiles || _episode == null,
            onTap: () => setState(() => _allFiles = true),
          ),
          for (int episode in episodes)
            KeyedSubtree(
              key: episode == _guess.episode ? _episodeChip : null,
              child: chip(
                t.subtitle_episode(n: episode),
                selected: !_allFiles && _episode == episode,
                onTap: () => setState(() {
                  _episode = episode;
                  _allFiles = false;
                }),
              ),
            ),
        ],
      ),
    );
  }

  String _size(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).ceil()} KB'
      : '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';

  Widget _row({
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    bool busy = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: theme.dividerColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyLarge!
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall!
                              .copyWith(color: theme.unselectedWidgetColor),
                        ),
                      ],
                    ],
                  ),
                ),
                if (busy)
                  const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _message(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: JidoujishoPlaceholderMessage(icon: icon, message: text),
    );
  }
}
