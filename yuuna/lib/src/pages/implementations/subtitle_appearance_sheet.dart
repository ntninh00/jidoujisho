import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yuuna/pages.dart';
import 'package:yuuna/utils.dart';

/// A subtitle line drawn as the player draws it: white, in [options]'s font
/// and size, with a dark outline.
class SubtitleText extends StatelessWidget {
  /// Draw [text] as [options] say, its size times [scale].
  const SubtitleText({
    required this.text,
    required this.options,
    this.scale = 1,
    this.textKey,
    this.highlight,
    super.key,
  });

  /// The line.
  final String text;

  /// How it looks.
  final SubtitleOptions options;

  /// Times the size in [options], smaller where there is less room.
  final double scale;

  /// Given to the line's text, to find which character was tapped.
  final Key? textKey;

  /// The part of [text] being looked up, marked as the player marks it.
  final TextRange? highlight;

  TextSpan _spans(BuildContext context) {
    TextRange? range = highlight;
    if (range == null ||
        !range.isValid ||
        range.isCollapsed ||
        range.end > text.length) {
      return TextSpan(text: text);
    }
    return TextSpan(children: [
      TextSpan(text: range.textBefore(text)),
      TextSpan(
        text: range.textInside(text),
        style: TextStyle(
          backgroundColor:
              Theme.of(context).colorScheme.primary.withOpacity(0.4),
        ),
      ),
      TextSpan(text: range.textAfter(text)),
    ]);
  }

  TextStyle _style({Paint? foreground}) {
    double size = options.fontSize * scale;
    TextStyle base = TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: foreground == null ? Colors.white : null,
      foreground: foreground,
    );
    if (options.fontName.trim().isEmpty) {
      return base;
    }
    try {
      return GoogleFonts.getFont(options.fontName, textStyle: base);
    } catch (_) {
      return base;
    }
  }

  @override
  Widget build(BuildContext context) {
    double outline = options.subtitleOutlineWidth;
    return Stack(
      alignment: Alignment.center,
      children: [
        if (outline > 0)
          Text(
            text,
            textAlign: TextAlign.center,
            style: _style(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = outline
                ..strokeJoin = StrokeJoin.round
                ..color = Colors.black.withOpacity(0.8),
            ),
          ),
        Text.rich(
          _spans(context),
          key: textKey,
          textAlign: TextAlign.center,
          style: _style(),
        ),
      ],
    );
  }
}

/// A subtitle line on its background, as [options] say.
class SubtitleBox extends StatelessWidget {
  /// Put [child] on the background of [options].
  const SubtitleBox({
    required this.options,
    required this.child,
    super.key,
  });

  /// How the background looks.
  final SubtitleOptions options;

  /// The line.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    double blur = options.subtitleBackgroundBlurRadius;
    Widget box = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      color: Colors.black.withOpacity(options.subtitleBackgroundOpacity),
      child: child,
    );
    if (blur > 0) {
      box = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: box,
      );
    }
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: box);
  }
}

/// How subtitles look, for the player and over pages' videos alike, with a
/// line to see the changes on.
class SubtitleAppearanceSheet extends BasePage {
  /// Change how subtitles look; [onChanged] follows each change.
  const SubtitleAppearanceSheet({
    this.onChanged,
    this.showHeight = false,
    super.key,
  });

  /// Called after each change, to show it at once.
  final VoidCallback? onChanged;

  /// Whether the height of the line over a page's video can be changed.
  final bool showHeight;

  @override
  BasePageState<SubtitleAppearanceSheet> createState() =>
      _SubtitleAppearanceSheetState();
}

class _SubtitleAppearanceSheetState
    extends BasePageState<SubtitleAppearanceSheet> {
  late final SubtitleOptions _options = appModelNoUpdate.subtitleOptions;
  late double _height = appModelNoUpdate.pageSubtitleHeight;
  late final TextEditingController _filter =
      TextEditingController(text: _options.regexFilter);

  /// Fonts for Japanese, from Google Fonts, besides the phone's own.
  static const List<String> fonts = [
    'Noto Sans JP',
    'Noto Serif JP',
    'M PLUS Rounded 1c',
    'Zen Maru Gothic',
    'Kosugi Maru',
    'Sawarabi Gothic',
  ];

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  void _change(void Function(SubtitleOptions options) change) {
    setState(() => change(_options));
    appModel.setSubtitleOptions(_options);
    widget.onChanged?.call();
  }

  void _reset() {
    _change((options) {
      options
        ..fontSize = 20
        ..fontName = ''
        ..subtitleOutlineWidth = 3
        ..subtitleBackgroundOpacity = 0
        ..subtitleBackgroundBlurRadius = 0
        ..regexFilter = '';
    });
    _filter.text = '';
    _setHeight(0.05);
  }

  void _setHeight(double height) {
    setState(() => _height = height);
    appModel.setPageSubtitleHeight(height);
    widget.onChanged?.call();
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
            _preview(),
            _slider(
              label: t.subtitle_size,
              value: _options.fontSize,
              min: 12,
              max: 48,
              divisions: 36,
              shown: '${_options.fontSize.round()}',
              onChanged: (value) =>
                  _change((options) => options.fontSize = value),
            ),
            _slider(
              label: t.subtitle_outline,
              value: _options.subtitleOutlineWidth,
              min: 0,
              max: 8,
              divisions: 16,
              shown: _options.subtitleOutlineWidth.toStringAsFixed(1),
              onChanged: (value) =>
                  _change((options) => options.subtitleOutlineWidth = value),
            ),
            _slider(
              label: t.subtitle_background,
              value: _options.subtitleBackgroundOpacity,
              min: 0,
              max: 1,
              divisions: 20,
              shown: '${(_options.subtitleBackgroundOpacity * 100).round()}%',
              onChanged: (value) => _change(
                  (options) => options.subtitleBackgroundOpacity = value),
            ),
            _slider(
              label: t.subtitle_blur,
              value: _options.subtitleBackgroundBlurRadius,
              min: 0,
              max: 20,
              divisions: 20,
              shown: '${_options.subtitleBackgroundBlurRadius.round()}',
              onChanged: (value) => _change(
                  (options) => options.subtitleBackgroundBlurRadius = value),
            ),
            if (widget.showHeight)
              _slider(
                label: t.subtitle_height,
                value: _height,
                min: 0,
                max: 0.4,
                divisions: 40,
                shown: '${(_height * 100).round()}%',
                onChanged: _setHeight,
              ),
            _fonts(),
            _filterField(),
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
              t.subtitle_appearance,
              style:
                  textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          JidoujishoInfoButton(message: t.subtitle_appearance_info),
          TextButton(onPressed: _reset, child: Text(t.reset)),
        ],
      ),
    );
  }

  /// A line on a picture-like background, showing the changes.
  Widget _preview() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 112,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6E8FB5), Color(0xFF3B5B45), Color(0xFF1E2A33)],
            ),
          ),
          alignment: Alignment.bottomCenter,
          padding: const EdgeInsets.all(12),
          child: SubtitleBox(
            options: _options,
            child: SubtitleText(
              text: appModel.targetLanguage.helloWorld,
              options: _options,
              scale: 0.9,
            ),
          ),
        ),
      ),
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String shown,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: Text(label,
                style: textTheme.bodyMedium!
                    .copyWith(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              shown,
              textAlign: TextAlign.end,
              style: textTheme.bodySmall!.copyWith(
                color: theme.unselectedWidgetColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fonts() {
    Widget chip(String label, String name) {
      bool selected = _options.fontName == name;
      return Padding(
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
          onSelected: (_) => _change((options) => options.fontName = name),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(t.subtitle_font,
              style:
                  textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w500)),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              chip(t.subtitle_font_default, ''),
              for (String font in fonts) chip(font, font),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _filter,
        onChanged: (value) {
          bool valid = true;
          try {
            RegExp(value);
          } catch (_) {
            valid = false;
          }
          if (valid) {
            _change((options) => options.regexFilter = value);
          }
        },
        decoration: InputDecoration(
          labelText: t.subtitle_hide_matching,
          hintText: '（.*?）',
          helperText: t.subtitle_hide_hint,
          isDense: true,
          filled: true,
          fillColor: theme.dividerColor.withOpacity(0.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
