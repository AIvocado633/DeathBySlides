import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/rendering.dart';

/// Draws whatever it decorates at a fraction of the resolution, then scales
/// it back up without smoothing: art saved by a file format that could not
/// keep any more detail than that.
///
/// Add it last on a component's decorator chain, so it receives the canvas in
/// the component's own coordinates, `0..size`.
class LowResolution extends Decorator {
  LowResolution(this.size, {this.factor = 2});

  /// The area drawn, in the component's own coordinates.
  final Vector2 size;

  /// How many slide units each stored pixel covers.
  final double factor;

  final Paint _paint = Paint()..filterQuality = FilterQuality.none;

  @override
  void apply(void Function(Canvas) draw, Canvas canvas) {
    final width = (size.x / factor).ceil();
    final height = (size.y / factor).ceil();
    final recorder = PictureRecorder();
    draw(Canvas(recorder)..scale(1 / factor));
    final picture = recorder.endRecording();
    final image = picture.toImageSync(width, height);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Rect.fromLTWH(0, 0, width * factor, height * factor),
      _paint,
    );
    image.dispose();
    picture.dispose();
  }
}
