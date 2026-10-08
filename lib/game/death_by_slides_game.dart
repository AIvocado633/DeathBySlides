import 'dart:async';

import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState, KeyEventResult;
import 'package:gamepads/gamepads.dart';

import 'audio/audio_backend.dart';
import 'audio/game_audio.dart';
import 'deck.dart';
import 'input/gamepad_input.dart';
import 'input/menu_input.dart';

import 'pages/arena_page.dart';
import 'pages/end_of_show_page.dart';
import 'pages/intro_page.dart';
import 'pages/pep_talk_page.dart';
import 'pages/tweaks_page.dart';
import 'pages/main_menu_page.dart';
import 'pages/story_page.dart';
import 'pages/light_table_page.dart';
import 'levels.dart';
import 'routes.dart';
import 'save/save_data.dart';
import 'save/save_file.dart';
import 'save/save_store.dart';
import 'slide/motion.dart';
import 'slide/slide_page.dart';
import 'theme/palette.dart';

/// Root of the game.
///
/// Screens are Flame [Route]s rather than Flutter navigator pages, so the whole
/// game lives inside a single `GameWidget` and transitions can be animated by
/// the engine.
///
/// [HasKeyboardHandlerComponents] lets components opt into key events, which is
/// what makes the game playable on desktop without a touch stick.
class DeathBySlidesGame extends FlameGame
    with HasKeyboardHandlerComponents, HasCollisionDetection
    implements AudioHost {
  DeathBySlidesGame({
    Stream<NormalizedGamepadEvent>? gamepadEvents,
    SaveStore? saveStore,
    AudioBackend? audioBackend,
    this.unlockAll = kUnlockAll,
    this.tellStory = false,
    bool Function()? deviceReducesMotion,
  }) : _gamepadEvents = gamepadEvents,
       _saveStore = saveStore ?? InMemorySaveStore(),
       audio = GameAudio(audioBackend ?? const SilentAudioBackend()),
       _deviceReducesMotion = deviceReducesMotion ?? _platformReducesMotion;

  /// The game's sound. The app hands in the platform's audio; tests leave it
  /// out and get silence, or pass a fake that records what played.
  @override
  final GameAudio audio;

  /// Opens every built slide, whatever has been won. See [kUnlockAll].
  final bool unlockAll;

  /// Tells the story: the intro on a first launch, and the scene between
  /// slides the first time each next slide is reached. The app asks for it;
  /// tests leave it off, so a game goes straight to its slides unless a test
  /// is about the story.
  final bool tellStory;

  /// Controller events to follow. The app passes the real platform stream;
  /// tests leave it null, so building a game never touches a platform channel.
  final Stream<NormalizedGamepadEvent>? _gamepadEvents;
  StreamSubscription<NormalizedGamepadEvent>? _gamepadSubscription;

  /// Where the save is kept. The app passes the device's own store; tests
  /// leave it null and get a fresh one in memory, for the same reason.
  final SaveStore _saveStore;

  /// What the player has done so far, loaded before the first page is shown.
  late final SaveFile save;

  /// What the player chose in Tweaks.
  Settings get settings => save.data.settings;

  /// Whether the device asks apps to keep animation down. Read afresh each
  /// time, since it can change while the game is in the background. Tests
  /// pass their own.
  final bool Function() _deviceReducesMotion;

  static bool _platformReducesMotion() =>
      PlatformDispatcher.instance.accessibilityFeatures.disableAnimations;

  /// Whether decoration stays still: the player's choice, or the device's
  /// until they make one.
  bool get reducesMotion => settings.reduceMotion ?? _deviceReducesMotion();

  /// Saves [settings] and puts them into effect straight away.
  void changeSettings(Settings settings) {
    unawaited(save.updateSettings(settings));
    _applySettings();
  }

  /// Hands the settings to the parts of the game that read them every frame.
  /// The thumb sticks are read as a fight is built, and Tweaks cannot
  /// be opened mid-fight.
  void _applySettings() {
    gamepad.deadzone = settings.deadzone;
    Motion.reduced = reducesMotion;
    PepTalk.current = settings.pepTalk;
    audio.setVolumes(
      music: settings.musicVolume,
      effects: settings.effectsVolume,
    );
  }

  /// The latest win, with the best it was up against: for the end of the
  /// show, which comes after the last win instead of a dialog.
  ({int slide, SlideTime time, SlideTime? best})? lastRun;

  /// Which slides can be opened, as of the latest save.
  Deck get deck => Deck(progress: save.data.progress, unlockAll: unlockAll);

  /// The connected controller's sticks, shared by every page.
  final GamepadInput gamepad = GamepadInput();

  late final RouterComponent router;

  @override
  Color backgroundColor() => Palette.workspace;

  @override
  Future<void> onLoad() async {
    _gamepadSubscription = _gamepadEvents?.listen(
      gamepad.handle,
      // A controller failing should cost you the controller, not the game.
      onError: (Object error) => debugPrint('Gamepad input failed: $error'),
    );
    // Before any page exists, so none renders with defaults and then flips.
    save = await SaveFile.load(_saveStore);
    _applySettings();
    await add(
      router = RouterComponent(
        initialRoute: Routes.normalView,
        routeFactories: {
          // One route per level, built on demand, and not kept alive:
          // re-entering a level should start a fresh fight rather than drop
          // you back into one you already won or lost.
          Routes.slideShow: (levelNumber) => Route(
            () => ArenaPage(level: levelNumbered(int.parse(levelNumber))),
            maintainState: false,
          ),
          Routes.story: (slide) => Route(
            () => StoryPage(after: int.parse(slide)),
            maintainState: false,
          ),
        },
        routes: {
          Routes.normalView: Route(MainMenuPage.new),
          Routes.lightTable: Route(LightTablePage.new),
          Routes.endOfShow: Route(EndOfShowPage.new),
          // Not kept alive: every viewing starts from the first scene.
          Routes.intro: Route(IntroPage.new, maintainState: false),
          Routes.tweaks: Route(TweaksPage.new),
          Routes.pepTalk: Route(PepTalkPage.new),
        },
      ),
    );
    // The story plays once, over the title slide it hands over to -- which
    // only exists once the router is mounted.
    if (tellStory && !save.data.introSeen) {
      unawaited(router.mounted.then((_) => router.pushNamed(Routes.intro)));
    }
  }

  /// What follows the scene of the story on top: the fight it leads into,
  /// the end of the show, or the next scene of a replay.
  final List<String> _afterStory = [];

  /// Opens [slide], first playing the scene that leads into it if the story
  /// is told and that scene has not been seen.
  void presentSlide(int slide) =>
      _playThen(slide - 1, Routes.slideShowFor(slide));

  /// The end of the show, after the last slide is won: the morning of the
  /// presentation first, the first time.
  void presentEnding() => _playThen(kLevels.last.number, Routes.endOfShow);

  void _playThen(int storyAfter, String next) {
    final story = save.data.storiesSeen;
    if (tellStory &&
        StoryPage.scenes.containsKey(storyAfter) &&
        save.data.progress.hasBeaten(storyAfter) &&
        !story.contains(storyAfter)) {
      _afterStory
        ..clear()
        ..add(next);
      router.pushNamed(Routes.storyAfter(storyAfter));
    } else {
      router.pushNamed(next);
    }
  }

  /// The story so far, from the title slide: the intro, then every scene
  /// between slides seen already.
  void watchStory() {
    _afterStory
      ..clear()
      ..addAll([
        for (final slide in save.data.storiesSeen.toList()..sort())
          Routes.storyAfter(slide),
      ]);
    router.pushNamed(Routes.intro);
  }

  /// Called by a scene that has ended: on to what was queued after it, or
  /// back to the page beneath. [skipping] skips any further scenes queued.
  void continueStory({bool skipping = false}) {
    if (skipping) {
      _afterStory.removeWhere(Routes.isCutscene);
    }
    if (_afterStory.isEmpty) {
      router.pop();
    } else {
      router.pushReplacementNamed(_afterStory.removeAt(0));
    }
  }

  final StickRepeat _stickRepeat = StickRepeat();

  /// The page on top, which is the one menu input goes to. Pages underneath
  /// stay mounted, so they must not hear it.
  SlidePage? get currentPage =>
      router.currentRoute.children.whereType<SlidePage>().firstOrNull;

  /// Sends [action] to the page on top. Public so tests can drive menus the
  /// way a player would, without synthesising key events.
  void handleMenuAction(MenuAction action) => currentPage?.onMenuAction(action);

  /// Android's back gesture. Returns false on the title slide, where back
  /// should leave the app; anywhere else it goes back within the game.
  bool goBack() {
    if (!isLoaded || router.currentRoute.name == Routes.normalView) {
      return false;
    }
    handleMenuAction(MenuAction.back);
    return true;
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    // Components first: the player reads WASD and the arrows mid-fight.
    final result = super.onKeyEvent(event, keysPressed);
    if (event is KeyDownEvent) {
      currentPage?.onAnyPress();
    }
    final action = menuActionForKey(event, keysPressed);
    if (action == null) {
      return result;
    }
    handleMenuAction(action);
    return KeyEventResult.handled;
  }

  @override
  void update(double dt) {
    super.update(dt);
    audio.update(dt);
    if (!isLoaded) {
      return;
    }
    // Music follows whichever page is on top, so going back to a menu brings
    // its music back without the page having to know it was covered.
    audio.track = currentPage?.music;
    for (final button in gamepad.takePresses()) {
      currentPage?.onAnyPress();
      final action = menuActionForButton(button);
      if (action != null) {
        handleMenuAction(action);
      }
    }
    final step = _stickRepeat.update(dt, gamepad.leftStick);
    if (step != null) {
      handleMenuAction(step);
    }
  }

  /// Going away -- backgrounded on a phone, or the window losing focus on a
  /// desktop -- pauses whatever is running. Flame stops its own loop too, but
  /// only until the app is back; a fight has to stay paused after that.
  @override
  void lifecycleStateChange(AppLifecycleState state) {
    super.lifecycleStateChange(state);
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        audio.away = true;
        currentPage?.onAppBackgrounded();
      // The device's own setting may have changed while it was away.
      case AppLifecycleState.resumed:
        audio.away = false;
        if (isLoaded) {
          _applySettings();
        }
    }
  }

  @override
  void onDispose() {
    _gamepadSubscription?.cancel();
    super.onDispose();
  }
}
