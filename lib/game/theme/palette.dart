import 'dart:ui';

/// The colours of the made-up slide editor the game takes place in.
///
/// Every screen in this game is dressed as a slide, so the whole palette is
/// deliberately "office software" rather than "game": the fun comes from the
/// contrast. The editor is nobody's in particular -- ink-navy chrome, warm
/// paper slides and a teal accent -- so it reads as slideware in general.
abstract final class Palette {
  /// The grey desk the slide sits on (visible as letterbox bars).
  static const workspace = Color(0xFF121826);
  static const workspaceEdge = Color(0xFF0A0E17);

  /// The slide surface itself.
  static const slide = Color(0xFFFFFCF5);
  static const slideShadow = Color(0x66000000);

  /// The editor's own teal, plus shades for hover/press states.
  static const brand = Color(0xFF0E7C7B);
  static const brandDark = Color(0xFF095C5B);
  static const brandLight = Color(0xFF2FA3A1);
  static const brandWash = Color(0x140E7C7B);
  static const brandWashStrong = Color(0x290E7C7B);

  /// Warm yellow, for whatever the chrome is pointing at.
  static const highlight = Color(0xFFF4B942);

  /// The editor's chrome: toolbar and status bar, dark so the slide glows.
  static const toolbar = Color(0xFF1E2638);
  static const toolbarEdge = Color(0xFF2E3850);
  static const statusBar = Color(0xFF1E2638);

  /// Text and marks drawn on the dark chrome.
  static const chromeInk = Color(0xFFE8ECF4);
  static const chromeInkSoft = Color(0xFF98A3BA);

  /// Panels and cards laid on the slide, a shade warmer than the slide.
  static const card = Color(0xFFF7F2E8);

  /// Hairlines drawn on the slide itself, such as an unselected thumbnail.
  static const rule = Color(0xFFE4DED2);

  /// Text.
  static const ink = Color(0xFF1A2233);
  static const inkSoft = Color(0xFF55607A);
  static const inkFaint = Color(0xFF8A93A6);

  /// Empty-placeholder chrome (the dashed boxes on a blank slide).
  static const placeholderStroke = Color(0xFFC4BDB0);
  static const placeholderText = Color(0xFFA8A194);

  /// Boss colours, one family per feature so two fights never read alike.
  static const shrinkToFit = Color(0xFF6A4C93);
  static const diagramWizard = Color(0xFFD1495B);
  static const diagramWizardDark = Color(0xFFA3364A);
  static const masterTemplate = Color(0xFFC77D1A);
  static const masterTemplateDark = Color(0xFF8F5610);
  static const masterTemplateLight = Color(0xFFF0B45C);
  static const buildOrder = Color(0xFF3A6FD8);
  static const buildOrderDark = Color(0xFF2A52A3);
  static const snapToGrid = Color(0xFFD14FA8);
  static const snapToGridDark = Color(0xFF9C3480);

  /// The Legacy Format: a 2003-era window, in the few colours it can save.
  /// Title bars fade from [legacyTitle] to [legacyTitleFade].
  static const legacyTitle = Color(0xFF0A246A);
  static const legacyTitleFade = Color(0xFFA6CAF0);
  static const legacyFace = Color(0xFFD4D0C8);
  static const legacyShadow = Color(0xFF808080);
  static const legacyWindow = Color(0xFFFFFFFF);
  static const legacyInk = Color(0xFF000000);

  /// The old format's floor: a navy slide background with its grid.
  static const legacyFloor = Color(0xFF0B1A5C);
  static const legacyFloorGrid = Color(0xFF1F3388);

  /// The stars beside a build step: green for an entrance, yellow for an
  /// emphasis, red for an exit.
  static const entranceStar = Color(0xFF4CAF6A);
  static const emphasisStar = Color(0xFFE8B53A);
  static const exitStar = Color(0xFFD9534F);

  /// Accents.
  static const hyperlink = Color(0xFF2A6FDB);
  static const selection = Color(0xFF2A6FDB);
  static const locked = Color(0xFFD9D3C7);

  /// Presenting mode: the projector-black behind a running slide show.
  static const showBlack = Color(0xFF0B0F18);
}
