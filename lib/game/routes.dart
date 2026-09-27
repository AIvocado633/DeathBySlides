/// Named routes handled by the game's `RouterComponent`.
///
/// Routes are named after slide-editor views on purpose -- the whole game is
/// framed as "you are inside a deck".
abstract final class Routes {
  /// The start menu: a blank-ish title slide in normal editing view.
  static const normalView = 'normal-view';

  /// Level select, presented as the editor's light table of slides.
  static const slideSorter = 'slide-sorter';

  /// Gameplay: the top-down arena, presented as a running slide show.
  ///
  /// This is a route *factory* name, not a route: each level gets its own
  /// route, built on demand. Use [slideShowFor] to name a concrete one.
  static const slideShow = 'slide-show';

  /// The route for a particular level, e.g. `slide-show/2`.
  static String slideShowFor(int levelNumber) => '$slideShow/$levelNumber';

  /// Settings, presented as the "Tweaks" side panel.
  static const designIdeas = 'design-ideas';
}
