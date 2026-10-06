import 'dart:ui';

import 'package:flame/components.dart';

import '../theme/palette.dart';
import '../theme/slide_text.dart';
import 'chip_button.dart';

/// The dialog that ends a slide, win or lose.
class ResultPanel extends PositionComponent {
  ResultPanel({
    required Vector2 position,
    required this.title,
    required this.message,
    required this.onRetry,
    required this.onLeave,
    this.onNext,
    this.won = true,
    this.timing,
  }) : super(position: position, size: Vector2(580, 260), anchor: Anchor.center);

  final String title;
  final String message;
  final void Function() onRetry;
  final void Function() onLeave;

  /// Goes on to the next slide. When set, Next Slide is offered first, as the
  /// primary action; when null, Retry Slide takes its place.
  final void Function()? onNext;
  final bool won;

  /// How long the slide took, the way a rehearsal reports it --
  /// `Slide time 00:42 · Best 00:37` -- or null for no line at all.
  final String? timing;

  static const double _headerHeight = 58;

  late final Paint _surfacePaint = Paint()..color = Palette.slide;
  late final Paint _headerPaint = Paint()
    ..color = won ? Palette.brand : Palette.inkSoft;
  final Paint _shadowPaint = Paint()
    ..color = const Color(0x99000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);

  @override
  Future<void> onLoad() async {
    await addAll([
      TextComponent(
        text: title,
        textRenderer: SlideText.resultTitle,
        position: Vector2(width / 2, _headerHeight / 2),
        anchor: Anchor.center,
      ),
      TextComponent(
        text: message,
        textRenderer: SlideText.caption,
        position: Vector2(width / 2, timing == null ? 118 : 104),
        anchor: Anchor.center,
      ),
      if (timing case final timing?)
        TextComponent(
          text: timing,
          textRenderer: SlideText.timing,
          position: Vector2(width / 2, 140),
          anchor: Anchor.center,
        ),
    ]);

    final next = onNext;
    final actions = [
      if (next != null) (label: 'Next Slide', onSelected: next),
      (label: 'Retry Slide', onSelected: onRetry),
      (label: 'Walk Off', onSelected: onLeave),
    ];
    // Buttons share the width evenly, centred, with the first one filled.
    final buttonWidth = actions.length == 3 ? 166.0 : 180.0;
    final gap = actions.length == 3 ? 16.0 : 40.0;
    final rowWidth = actions.length * buttonWidth + (actions.length - 1) * gap;
    final left = (width - rowWidth) / 2 + buttonWidth / 2;
    await addAll([
      for (final (index, action) in actions.indexed)
        ChipButton(
          label: action.label,
          filled: index == 0,
          position: Vector2(left + index * (buttonWidth + gap), 192),
          anchor: Anchor.center,
          width: buttonWidth,
          onSelected: action.onSelected,
        ),
    ]);
  }

  @override
  void render(Canvas canvas) {
    final rect = size.toRect();
    canvas.drawRect(rect.deflate(8), _shadowPaint);
    canvas.drawRect(rect, _surfacePaint);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, _headerHeight),
      _headerPaint,
    );
  }
}
