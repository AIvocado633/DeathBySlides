import 'dart:ui';

import 'package:flame/components.dart';

import '../slide/slide_metrics.dart';
import '../theme/palette.dart';
import '../theme/slide_text.dart';

/// The status bar along the bottom of a slide: where you are, a reassuring
/// autosave notice, and a zoom slider nobody has ever intentionally used.
class StatusBar extends PositionComponent {
  StatusBar({this.slideLabel = 'Slide 1 of 1', this.detailLabel = 'Autosaved just now'})
    : super(
        position: Vector2(0, kContentBottom),
        size: Vector2(kSlideWidth, kStatusBarHeight),
      );

  final String slideLabel;
  final String detailLabel;

  final Paint _backgroundPaint = Paint()..color = Palette.statusBar;
  final Paint _edgePaint = Paint()..color = Palette.ribbonEdge;
  final Paint _trackPaint = Paint()
    ..color = Palette.chromeInkSoft
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round;
  final Paint _knobPaint = Paint()..color = Palette.highlight;

  static const double _trackLeft = 1080;
  static const double _trackRight = 1180;
  static const double _knobX = 1152;

  static const double _leftInset = 18;
  static const double _labelGap = 28;

  @override
  Future<void> onLoad() async {
    final centreY = height / 2;
    final slideLabelWidth = SlideText.status.getLineMetrics(slideLabel).width;
    addAll([
      TextComponent(
        text: slideLabel,
        textRenderer: SlideText.status,
        position: Vector2(_leftInset, centreY),
        anchor: Anchor.centerLeft,
      ),
      TextComponent(
        text: detailLabel,
        textRenderer: SlideText.status,
        position: Vector2(
          _leftInset + slideLabelWidth + _labelGap,
          centreY,
        ),
        anchor: Anchor.centerLeft,
      ),
      TextComponent(
        text: '100%',
        textRenderer: SlideText.status,
        position: Vector2(1262, centreY),
        anchor: Anchor.centerRight,
      ),
    ]);
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), _backgroundPaint);
    canvas.drawRect(Rect.fromLTWH(0, 0, kSlideWidth, 1.5), _edgePaint);

    final centreY = height / 2;
    // Zoom slider: minus, track, knob, plus.
    canvas.drawLine(
      Offset(_trackLeft - 22, centreY),
      Offset(_trackLeft - 12, centreY),
      _trackPaint,
    );
    canvas.drawLine(
      Offset(_trackLeft, centreY),
      Offset(_trackRight, centreY),
      _trackPaint,
    );
    canvas.drawCircle(Offset(_knobX, centreY), 5, _knobPaint);
    canvas.drawLine(
      Offset(_trackRight + 12, centreY),
      Offset(_trackRight + 22, centreY),
      _trackPaint,
    );
    canvas.drawLine(
      Offset(_trackRight + 17, centreY - 5),
      Offset(_trackRight + 17, centreY + 5),
      _trackPaint,
    );
  }
}
