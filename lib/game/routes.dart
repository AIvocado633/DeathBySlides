/// Named routes handled by the game's `RouterComponent`.
///
/// Routes are named after slide-editor views on purpose -- the whole game is
/// framed as "you are inside a deck".
abstract final class Routes {
  /// The start menu: a blank-ish title slide in normal editing view.
  static const normalView = 'normal-view';

  /// Level select, presented as the editor's light table of slides.
  static const lightTable = 'light-table';

  /// Gameplay: the top-down arena, presented as a running slide show.
  ///
  /// This is a route *factory* name, not a route: each level gets its own
  /// route, built on demand. Use [slideShowFor] to name a concrete one.
  static const slideShow = 'slide-show';

  /// The route for a particular level, e.g. `slide-show/2`.
  static String slideShowFor(int levelNumber) => '$slideShow/$levelNumber';

  /// The story before the deck: the night before the presentation.
  static const intro = 'intro';

  /// The scenes between slides. A route factory, like [slideShow]: use
  /// [storyAfter] to name a concrete one.
  static const story = 'story';

  /// The scene that follows slide [slide], e.g. `story/2`.
  static String storyAfter(int slide) => '$story/$slide';

  /// Whether [route] is a scene of the story rather than something to play.
  static bool isCutscene(String route) =>
      route == intro || route.startsWith('$story/');

  /// The black slide after the last one: the end of the show, and the
  /// credits.
  static const endOfShow = 'end-of-show';

  /// Settings, presented as the "Tweaks" side panel.
  static const tweaks = 'tweaks';

  /// The assists, opened from Tweaks.
  static const pepTalk = 'pep-talk';
}
