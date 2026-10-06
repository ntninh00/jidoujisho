import 'package:flutter/material.dart';
import 'package:yuuna/media.dart';
import 'package:yuuna/utils.dart';

/// The colours a memo can be marked with: its highlight on the page, its
/// flag in lists and its tab on the shelf.
enum TtuMemoColor {
  /// The first colour, and the one for memos saved before colours.
  amber(Color(0xFFFFC107)),

  /// Pink.
  rose(Color(0xFFF06292)),

  /// Green.
  green(Color(0xFF66BB6A)),

  /// Blue.
  sky(Color(0xFF42A5F5)),

  /// Purple.
  violet(Color(0xFFA084E8));

  const TtuMemoColor(this.color);

  /// The colour itself.
  final Color color;

  /// The colour saved as [name], or amber.
  static TtuMemoColor of(String? name) {
    return values.firstWhere(
      (value) => value.name == name,
      orElse: () => amber,
    );
  }

  /// The colour of [memo].
  static TtuMemoColor ofMemo(ReaderMemo memo) => of(memo.color);

  /// The colour as `#rrggbb`, for the reader page.
  String get hex =>
      '#${(color.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  /// The colour's name for screen readers.
  String get label => switch (this) {
        amber => t.ttu_color_amber,
        rose => t.ttu_color_rose,
        green => t.ttu_color_green,
        sky => t.ttu_color_sky,
        violet => t.ttu_color_violet,
      };
}

/// A row of colour swatches to pick a memo's colour from.
class TtuMemoColorPicker extends StatelessWidget {
  /// Create the picker.
  const TtuMemoColorPicker({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  /// The colour picked now.
  final TtuMemoColor selected;

  /// Called with the colour tapped.
  final ValueChanged<TtuMemoColor> onChanged;

  @override
  Widget build(BuildContext context) {
    Color ring = Theme.of(context).colorScheme.onSurface;
    return Wrap(
      spacing: 4,
      children: [
        for (TtuMemoColor value in TtuMemoColor.values)
          Semantics(
            button: true,
            selected: value == selected,
            label: value.label,
            child: InkResponse(
              onTap: () => onChanged(value),
              radius: 22,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    width: value == selected ? 30 : 24,
                    height: value == selected ? 30 : 24,
                    decoration: BoxDecoration(
                      color: value.color,
                      shape: BoxShape.circle,
                      border: value == selected
                          ? Border.all(color: ring, width: 2)
                          : null,
                    ),
                    child: value == selected
                        ? const Icon(Ui.check, size: 16, color: Colors.black87)
                        : null,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A small ribbon in a memo's colour, the mark used for memos in lists.
class TtuMemoFlag extends StatelessWidget {
  /// Create the flag.
  const TtuMemoFlag({required this.color, this.size = 14, super.key});

  /// The memo's colour.
  final Color color;

  /// Height of the flag; it is a little narrower than tall.
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size * 0.72, size),
      painter: _FlagPainter(color),
    );
  }
}

class _FlagPainter extends CustomPainter {
  _FlagPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    double w = size.width;
    double h = size.height;
    Path flag = Path()
      ..moveTo(0, 2)
      ..quadraticBezierTo(0, 0, 2, 0)
      ..lineTo(w - 2, 0)
      ..quadraticBezierTo(w, 0, w, 2)
      ..lineTo(w, h)
      ..lineTo(w / 2, h * 0.72)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(flag, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_FlagPainter oldDelegate) => oldDelegate.color != color;
}

/// Memo tabs peeking out from behind a cover's right edge, like sticky notes
/// in a book: one per memo, as far down as the memo is into the book, in the
/// memo's colour. Tabs too close together are spaced out, six at most.
class TtuMemoTabsPainter extends CustomPainter {
  /// Create the painter.
  TtuMemoTabsPainter({required this.tabs});

  /// Where each memo is, from 0 to 1, and its colour.
  final List<({double at, Color color})> tabs;

  static const double _peek = 5;
  static const double _height = 12;
  static const double _gap = 3;
  static const int _most = 6;

  @override
  void paint(Canvas canvas, Size size) {
    List<({double at, Color color})> sorted = [...tabs]
      ..sort((a, b) => a.at.compareTo(b.at));
    double top = 8;
    double bottom = size.height - 8 - _height;
    double? last;
    int drawn = 0;
    for (({double at, Color color}) tab in sorted) {
      double y = top + (bottom - top) * tab.at.clamp(0, 1).toDouble();
      if (last != null && y - last < _height + _gap) {
        y = last + _height + _gap;
      }
      if (y > bottom || drawn == _most) {
        break;
      }
      RRect shape = RRect.fromLTRBAndCorners(
        size.width - 6,
        y,
        size.width + _peek,
        y + _height,
        topRight: const Radius.circular(3),
        bottomRight: const Radius.circular(3),
      );
      canvas.drawRRect(
        shape.shift(const Offset(0.5, 1)),
        Paint()..color = Colors.black.withOpacity(0.22),
      );
      canvas.drawRRect(shape, Paint()..color = tab.color);
      last = y;
      drawn++;
    }
  }

  @override
  bool shouldRepaint(TtuMemoTabsPainter oldDelegate) {
    if (oldDelegate.tabs.length != tabs.length) {
      return true;
    }
    for (int i = 0; i < tabs.length; i++) {
      if (oldDelegate.tabs[i] != tabs[i]) {
        return true;
      }
    }
    return false;
  }
}
