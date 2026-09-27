import 'package:flame/text.dart';
import 'package:flutter/painting.dart';

import 'palette.dart';

/// Font stack chosen to look like Office on every platform we ship to.
/// Windows resolves Segoe UI, Android falls back to Roboto, iOS to Helvetica.
const List<String> _officeStack = ['Segoe UI', 'Roboto', 'Helvetica', 'Arial'];

TextStyle _style({
  required double size,
  FontWeight weight = FontWeight.w400,
  Color color = Palette.ink,
  double? letterSpacing,
  FontStyle fontStyle = FontStyle.normal,
}) {
  return TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    fontStyle: fontStyle,
    fontFamilyFallback: _officeStack,
    height: 1.1,
  );
}

/// Every text renderer used on a slide, in one place.
///
/// Sizes are expressed in *slide units* (the 1280x720 design canvas defined in
/// `slide_metrics.dart`), not in device pixels, so they scale with the slide.
abstract final class SlideText {
  static final titleBrand = TextPaint(
    style: _style(
      size: 72,
      weight: FontWeight.w800,
      color: Palette.brand,
      letterSpacing: 1,
    ),
  );

  static final titleInk = TextPaint(
    style: _style(
      size: 72,
      weight: FontWeight.w800,
      letterSpacing: 1,
    ),
  );

  static final subtitle = TextPaint(
    style: _style(
      size: 24,
      color: Palette.placeholderText,
      fontStyle: FontStyle.italic,
    ),
  );

  static final sectionTitle = TextPaint(
    style: _style(size: 46, weight: FontWeight.w800, letterSpacing: 0.5),
  );

  static final heading = TextPaint(
    style: _style(size: 30, weight: FontWeight.w700),
  );

  static final bullet = TextPaint(
    style: _style(size: 32, weight: FontWeight.w600),
  );

  static final bulletDisabled = TextPaint(
    style: _style(size: 32, weight: FontWeight.w600, color: Palette.placeholderText),
  );

  static final bulletHint = TextPaint(
    style: _style(size: 18, color: Palette.inkFaint, letterSpacing: 0.5),
  );

  static final panelHeading = TextPaint(
    style: _style(
      size: 16,
      weight: FontWeight.w700,
      color: Palette.inkSoft,
      letterSpacing: 1.6,
    ),
  );

  static final resultTitle = TextPaint(
    style: _style(
      size: 26,
      weight: FontWeight.w700,
      color: Palette.slide,
      letterSpacing: 0.4,
    ),
  );

  static final chip = TextPaint(
    style: _style(size: 19, weight: FontWeight.w600, color: Palette.brand),
  );

  static final chipOnBrand = TextPaint(
    style: _style(size: 19, weight: FontWeight.w600, color: Palette.slide),
  );

  static final caption = TextPaint(
    style: _style(size: 18, color: Palette.inkSoft),
  );

  /// A checkbox's or slider's label in Design Ideas.
  static final settingLabel = TextPaint(
    style: _style(size: 22, weight: FontWeight.w600),
  );

  static final ribbonTab = TextPaint(
    style: _style(size: 16, color: Palette.inkSoft),
  );

  static final ribbonTabActive = TextPaint(
    style: _style(size: 16, weight: FontWeight.w600, color: Palette.brand),
  );

  static final ribbonFileTab = TextPaint(
    style: _style(size: 16, weight: FontWeight.w600, color: Palette.slide),
  );

  static final status = TextPaint(
    style: _style(size: 14, color: Palette.inkSoft),
  );

  static final thumbnailNumber = TextPaint(
    style: _style(size: 20, weight: FontWeight.w700, color: Palette.inkSoft),
  );

  static final thumbnailTitle = TextPaint(
    style: _style(size: 22, weight: FontWeight.w700),
  );

  static final thumbnailTitleLocked = TextPaint(
    style: _style(size: 22, weight: FontWeight.w700, color: Palette.placeholderText),
  );

  static final thumbnailSubtitle = TextPaint(
    style: _style(size: 16, color: Palette.inkFaint),
  );

  /// Text drawn on top of the projector-black slide show background.
  static final showHeading = TextPaint(
    style: _style(size: 44, weight: FontWeight.w700, color: Palette.slide),
  );

  static final showBody = TextPaint(
    style: _style(size: 22, color: Color(0xFFBDBDBD)),
  );

  /// What a hit cost, floating off whatever was hit. Takes its colour from
  /// the side of the fight that paid it.
  static TextPaint damage(Color colour) =>
      TextPaint(style: _style(size: 20, weight: FontWeight.w700, color: colour));
}
