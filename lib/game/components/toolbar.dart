import 'dart:ui';

import 'package:flame/components.dart';

import '../slide/slide_metrics.dart';
import '../theme/palette.dart';
import '../theme/slide_text.dart';

/// The editor's toolbar along the top of a slide.
///
/// Purely decorative: it exists so that the first thing a player sees is
/// unmistakably a slide editor -- a made-up one, with its own mark, its own
/// tabs and dark chrome, rather than any real product's.
class Toolbar extends PositionComponent {
  Toolbar({this.activeTab = 'Present'})
    : super(position: Vector2.zero(), size: Vector2(kSlideWidth, kToolbarHeight));

  static const List<String> tabs = [
    'Edit',
    'Add',
    'Arrange',
    'Tweak',
    'Motion',
    'Present',
  ];

  /// The open file's name, shown at the right-hand end.
  static const String documentName = 'final_FINAL_v7.deck';

  /// Which tab is drawn highlighted.
  final String activeTab;

  static const double _markSize = 30;
  static const double _markLeft = 20;
  static const double _tabsLeft = 78;
  static const double _tabPadding = 18;

  final Paint _backgroundPaint = Paint()..color = Palette.toolbar;
  final Paint _edgePaint = Paint()..color = Palette.toolbarEdge;
  final Paint _markPaint = Paint()..color = Palette.brand;
  final Paint _markInkPaint = Paint()
    ..color = Palette.slide
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round;
  final Paint _pillPaint = Paint()..color = const Color(0x2EF4B942);
  final Paint _underlinePaint = Paint()..color = Palette.highlight;

  /// Left edge of each tab label, measured once so `render` stays layout-free.
  final List<double> _tabOffsets = [];
  final List<double> _tabWidths = [];

  @override
  Future<void> onLoad() async {
    var cursor = _tabsLeft + _tabPadding;
    for (final tab in tabs) {
      final renderer = tab == activeTab
          ? SlideText.toolbarTabActive
          : SlideText.toolbarTab;
      final width = renderer.getLineMetrics(tab).width;
      _tabOffsets.add(cursor);
      _tabWidths.add(width);
      cursor += width + _tabPadding * 2;
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(size.toRect(), _backgroundPaint);
    canvas.drawRect(
      Rect.fromLTWH(0, kToolbarHeight - 1.5, kSlideWidth, 1.5),
      _edgePaint,
    );
    _renderMark(canvas);

    final centreY = kToolbarHeight / 2;
    for (var i = 0; i < tabs.length; i++) {
      final tab = tabs[i];
      final isActive = tab == activeTab;
      if (isActive) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              _tabOffsets[i] - 12,
              centreY - 16,
              _tabWidths[i] + 24,
              32,
            ),
            const Radius.circular(16),
          ),
          _pillPaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(_tabOffsets[i], kToolbarHeight - 5, _tabWidths[i], 3),
            const Radius.circular(1.5),
          ),
          _underlinePaint,
        );
      }
      (isActive ? SlideText.toolbarTabActive : SlideText.toolbarTab).render(
        canvas,
        tab,
        Vector2(_tabOffsets[i], centreY),
        anchor: Anchor.centerLeft,
      );
    }

    SlideText.toolbarFileName.render(
      canvas,
      documentName,
      Vector2(kSlideWidth - 24, centreY),
      anchor: Anchor.centerRight,
    );
  }

  /// The editor's mark: a teal tile holding a tiny slide with two bullets.
  void _renderMark(Canvas canvas) {
    final top = (kToolbarHeight - _markSize) / 2;
    final tile = Rect.fromLTWH(_markLeft, top, _markSize, _markSize);
    canvas.drawRRect(
      RRect.fromRectAndRadius(tile, const Radius.circular(8)),
      _markPaint,
    );
    for (final row in [0.4, 0.62]) {
      final y = top + _markSize * row;
      canvas.drawCircle(Offset(_markLeft + 9, y), 1.8, _markInkPaint);
      canvas.drawLine(
        Offset(_markLeft + 14, y),
        Offset(_markLeft + _markSize - 8, y),
        _markInkPaint,
      );
    }
  }
}
