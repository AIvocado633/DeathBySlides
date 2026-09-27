import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';

import '../slide/slide_metrics.dart';
import '../theme/palette.dart';
import '../theme/slide_text.dart';
import 'chip_button.dart';

/// The pause screen, which is a blanked slide show.
///
/// Pressing B during a real presentation blacks the screen out until you press
/// it again, so that is what pausing looks like here: the fight disappears
/// behind a black slide, frozen, with a way back to it.
///
/// Covers the whole slide, so the controls underneath cannot be tapped by
/// accident while the fight is frozen.
class PauseMenu extends PositionComponent with TapCallbacks {
  PauseMenu({
    required this.onResume,
    required this.onRetry,
    required this.onLeave,
  }) : super(size: slideSize);

  final void Function() onResume;
  final void Function() onRetry;
  final void Function() onLeave;

  static const double _buttonWidth = 200;
  static const double _gap = 24;

  final Paint _blackPaint = Paint()..color = Palette.showBlack;

  @override
  Future<void> onLoad() async {
    final actions = [
      (label: 'Resume', onSelected: onResume),
      (label: 'Retry Slide', onSelected: onRetry),
      (label: 'Walk Off', onSelected: onLeave),
    ];
    const rowWidth = 3 * _buttonWidth + 2 * _gap;
    final left = (kSlideWidth - rowWidth) / 2 + _buttonWidth / 2;

    await addAll([
      TextComponent(
        text: 'Presentation paused',
        textRenderer: SlideText.showHeading,
        position: Vector2(kSlideWidth / 2, 280),
        anchor: Anchor.center,
      ),
      TextComponent(
        text:
            'The screen is blank, the way B blanks a presentation. '
            'B, Start or Resume picks the fight back up.',
        textRenderer: SlideText.showBody,
        position: Vector2(kSlideWidth / 2, 340),
        anchor: Anchor.center,
      ),
      for (final (index, action) in actions.indexed)
        ChipButton(
          label: action.label,
          filled: index == 0,
          position: Vector2(left + index * (_buttonWidth + _gap), 430),
          anchor: Anchor.center,
          width: _buttonWidth,
          onSelected: action.onSelected,
        ),
    ]);
  }

  @override
  void render(Canvas canvas) => canvas.drawRect(size.toRect(), _blackPaint);

  /// Swallows taps on the blanked screen, so the sticks and chips underneath
  /// stay out of reach until the fight is running again.
  @override
  bool containsLocalPoint(Vector2 point) => true;
}
