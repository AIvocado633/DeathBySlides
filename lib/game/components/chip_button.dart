import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../slide/focusable.dart';
import '../theme/palette.dart';
import '../theme/slide_text.dart';
import 'placeholder_frame.dart';

/// A compact pill button, used for secondary actions such as going back to
/// normal view. Styled after the buttons in the editor's side panels.
class ChipButton extends PositionComponent
    with TapCallbacks, HoverCallbacks, Focusable {
  ChipButton({
    required this.label,
    required this.onSelected,
    this.filled = false,
    super.position,
    super.anchor,
    double width = 240,
    double height = 52,
  }) : super(size: Vector2(width, height));

  final String label;
  final void Function() onSelected;

  /// Filled buttons are the primary action on a page; outlined ones are not.
  final bool filled;

  bool _pressed = false;

  final Paint _fillPaint = Paint();
  final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8;

  @override
  Future<void> onLoad() async {
    await add(
      TextComponent(
        text: label,
        textRenderer: filled ? SlideText.chipOnBrand : SlideText.chip,
        position: size / 2,
        anchor: Anchor.center,
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    final rrect = RRect.fromRectAndRadius(
      size.toRect(),
      Radius.circular(height / 2),
    );
    if (filled) {
      _fillPaint.color = _pressed
          ? Palette.brandDark
          : (isHighlighted ? Palette.brandLight : Palette.brand);
      canvas.drawRRect(rrect, _fillPaint);
    } else {
      if (isHighlighted || _pressed) {
        _fillPaint.color = _pressed
            ? Palette.brandWashStrong
            : Palette.brandWash;
        canvas.drawRRect(rrect, _fillPaint);
      }
      _strokePaint.color = Palette.brand;
      canvas.drawRRect(rrect, _strokePaint);
    }
    if (isHighlighted) {
      drawSelection(canvas, size.toRect().inflate(5), handleSize: 9);
    }
  }

  @override
  void activate() => onSelected();

  @override
  void onTapDown(TapDownEvent event) => _pressed = true;

  @override
  void onTapUp(TapUpEvent event) {
    if (!_pressed) {
      return;
    }
    _pressed = false;
    onSelected();
  }

  @override
  void onTapCancel(TapCancelEvent event) => _pressed = false;
}
