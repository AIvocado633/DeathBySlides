import 'package:flame/text.dart';
import 'package:flutter/painting.dart';

import 'palette.dart';

/// The game's typeface, bundled so every platform draws the same letters:
/// Atkinson Hyperlegible, designed by the Braille Institute to keep easily
/// confused characters apart -- welcome at slide-show distances.
const String kFontFamily = 'Atkinson Hyperlegible';

/// Plain system sans-serifs, used only for glyphs the bundled face lacks.
const List<String> kFontStack = ['Roboto', 'Helvetica Neue', 'Helvetica', 'Arial'];

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
    fontFamily: kFontFamily,
    fontFamilyFallback: kFontStack,
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

  /// A checkbox's or slider's label in Tweaks.
  static final settingLabel = TextPaint(
    style: _style(size: 22, weight: FontWeight.w600),
  );

  static final toolbarTab = TextPaint(
    style: _style(size: 16, color: Palette.chromeInkSoft),
  );

  static final toolbarTabActive = TextPaint(
    style: _style(size: 16, weight: FontWeight.w700, color: Palette.highlight),
  );

  /// The open file's name at the end of the toolbar.
  static final toolbarFileName = TextPaint(
    style: _style(size: 14, color: Palette.chromeInkSoft, fontStyle: FontStyle.italic),
  );

  static final status = TextPaint(
    style: _style(size: 14, color: Palette.chromeInkSoft),
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

  /// The Build Order pane beside the arena: its title, each step's effect,
  /// and the trigger under it.
  static final paneTitle = TextPaint(
    style: _style(size: 18, weight: FontWeight.w700, color: Palette.chromeInk),
  );

  static final paneStep = TextPaint(
    style: _style(size: 18, weight: FontWeight.w700, color: Palette.chromeInk),
  );

  static final paneTrigger = TextPaint(
    style: _style(size: 14, color: Palette.chromeInkSoft),
  );

  /// The speaker notes under the end of the show.
  static final notes = TextPaint(
    style: _style(size: 18, color: Palette.chromeInk),
  );

  /// Text inside a dialog drawn in the arena, such as Snap to Grid's.
  static final dialogText = TextPaint(
    style: _style(size: 17, weight: FontWeight.w600, color: Palette.ink),
  );

  /// A 2003-era window's title bar, and the text in its body.
  static final legacyTitle = TextPaint(
    style: _style(size: 15, weight: FontWeight.w700, color: Palette.slide),
  );

  static final legacyText = TextPaint(
    style: _style(size: 15, color: Palette.legacyInk),
  );

  static final legacyTextBold = TextPaint(
    style: _style(size: 15, weight: FontWeight.w700, color: Palette.legacyInk),
  );

  /// The number on a build step's tag in the arena.
  static final tagNumber = TextPaint(
    style: _style(size: 18, weight: FontWeight.w700, color: Palette.ink),
  );

  /// Text drawn on top of the projector-black slide show background.
  static final showHeading = TextPaint(
    style: _style(size: 44, weight: FontWeight.w700, color: Palette.slide),
  );

  static final showBody = TextPaint(
    style: _style(size: 22, color: Color(0xFFB8C0D0)),
  );

  /// What a hit cost, floating off whatever was hit. Takes its colour from
  /// the side of the fight that paid it.
  static TextPaint damage(Color colour) =>
      TextPaint(style: _style(size: 20, weight: FontWeight.w700, color: colour));
}
