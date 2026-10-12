import 'dart:io';

import 'package:flutter/material.dart';
import 'package:yuuna/dictionary.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// A subtitle file picked on Jimaku: where it was saved, and what it is.
class SubtitlePick {
  /// [file], saved from [show], for [episode] when its name says.
  const SubtitlePick({
    required this.file,
    required this.show,
    required this.episode,
  });

  /// The file, saved on the phone.
  final File file;

  /// The show it is of.
  final SubtitleShow show;

  /// The episode it is for, when its name says.
  final int? episode;
}

/// Finds Japanese subtitles for a video on Jimaku, through the dictionary
/// server, and closes with the [SubtitlePick] made.
class SubtitleSearchSheet extends BasePage {
  /// Search for [name]'s subtitles, the name of the video's file or page,
  /// or open on [show]'s files at [episode].
  const SubtitleSearchSheet({
    required this.name,
    this.fillQuery = true,
    this.show,
    this.episode,
    super.key,
  });

  /// The video's file or page name, which the show and episode are
  /// guessed from.
  final String name;

  /// Whether the search starts with the show guessed from [name]. A page's
  /// title is mostly the site's, so for a page it starts empty, ready to
  /// type in.
  final bool fillQuery;

  /// The show to open on, as the one of the subtitles last picked, for the
  /// next episode; back goes to the search.
  final SubtitleShow? show;

  /// The episode looked for, in place of the one guessed from [name].
  final int? episode;

  @override
  BasePageState<SubtitleSearchSheet> createState() =>
      _SubtitleSearchSheetState();
}

class _SubtitleSearchSheetState extends BasePageState<SubtitleSearchSheet> {
  late final SubtitleGuess _guess = SubtitleGuess.of(widget.name);
  late final TextEditingController _query =
      TextEditingController(text: widget.fillQuery ? _guess.show : '');

  List<SubtitleShow>? _shows;

  /// The show whose files are listed; opened on at once when given, so the
  /// search, and the keyboard, don't show first.
  late SubtitleShow? _show = widget.show;
  List<SubtitleFile>? _files;

  /// The episode looked for at first, its chip scrolled to.
  late final int? _lookedFor = widget.episode ?? _guess.episode;
  late int? _episode = _lookedFor;
  bool _allFiles = false;

  /// The chip of the episode looked for, scrolled to when the files come.
  final GlobalKey _episodeChip = GlobalKey();
  bool _busy = false;
  String? _error;
  SubtitleFile? _fetching;

  @override
  void initState() {
    super.initState();
    SubtitleShow? show = widget.show;
    if (show != null && _server != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _open(show));
    } else if (_query.text.isNotEmpty) {
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
    if (!mounted) {
      return;
    }
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
      SubtitleShow show = _show!;
      File saved = await server.subtitleFile(
        show,
        file,
        Directory('${appModel.temporaryDirectory.path}/subtitles'),
      );
      if (mounted) {
        Navigator.pop(
          context,
          SubtitlePick(file: saved, show: show, episode: file.episode),
        );
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
    MediaQueryData media = MediaQuery.of(context);
    double keyboard = media.viewInsets.bottom;

    /// The sheet stays above the keyboard, as tall as there is room for.
    double room = media.size.height - keyboard - media.padding.top;

    /// On a phone on its side, the search takes the title's place, so it
    /// shows above the keyboard. Told from the screen, not the room the
    /// keyboard leaves, or the field would move, and lose the keyboard, as
    /// it opens.
    bool short = media.size.height - media.padding.top < 480;
    bool searching = _server != null && _show == null;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: room * 0.92),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const TtuSheetHandle(),
            if (short && searching) _shortHeader() else _header(),
            if (searching && !short) _searchField(),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  if (_server == null)
                    _message(
                        Ui.subtitles_off_outlined, t.subtitle_search_no_server)
                  else if (_show == null)
                    ..._showList()
                  else
                    ..._fileList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The search in the header's place, with the close button.
  Widget _shortHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
      child: Row(
        children: [
          Expanded(child: _searchInput()),
          IconButton(
            tooltip: t.dialog_close,
            icon: const Icon(Ui.close),
            onPressed: () => Navigator.pop(context),
          ),
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
      child: _searchInput(),
    );
  }

  /// Keeps the search field, and the keyboard with it, wherever it shows.
  final GlobalKey _searchKey = GlobalKey();

  Widget _searchInput() {
    return TextField(
      key: _searchKey,
      controller: _query,
      autofocus: _query.text.isEmpty,
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
              key: episode == _lookedFor ? _episodeChip : null,
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
