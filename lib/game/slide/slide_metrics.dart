import 'package:flame/components.dart';

/// The game is laid out on a fixed 16:9 "slide" and letterboxed onto whatever
/// screen it runs on -- exactly the way a real deck behaves in slide show mode.
///
/// Every position, size and font size in the game is expressed in these slide
/// units, so layout code never has to think about device pixels.
const double kSlideWidth = 1280;
const double kSlideHeight = 720;

/// Height of the faux toolbar strip along the top of a slide.
const double kToolbarHeight = 54;

/// Height of the faux status bar along the bottom of a slide.
const double kStatusBarHeight = 30;

/// Standard left/right margin for slide content.
const double kSlideMargin = 80;

/// Vertical band available for actual content, between toolbar and status bar.
const double kContentTop = kToolbarHeight;
const double kContentBottom = kSlideHeight - kStatusBarHeight;

Vector2 get slideSize => Vector2(kSlideWidth, kSlideHeight);
