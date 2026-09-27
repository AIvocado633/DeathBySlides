import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';

import '../combat/boss.dart';
import '../components/arena_floor.dart';
import '../components/chip_button.dart';
import '../components/control_stick.dart';
import '../components/pause_menu.dart';
import '../components/player.dart';
import '../components/result_panel.dart';
import '../input/menu_input.dart';
import '../levels.dart';
import '../routes.dart';
import '../slide/fly_in.dart';
import '../slide/focusable.dart';
import '../slide/slide_metrics.dart';
import '../slide/slide_page.dart';
import '../theme/palette.dart';
import '../theme/slide_text.dart';

/// A level: one slide, one feature, fought out from directly above.
///
/// The whole playfield is visible at once, because it is a slide. The page
/// itself is feature-agnostic -- it owns the floor, the controls and the
/// win/lose flow, and asks its [level] for whatever is standing in the way.
class ArenaPage extends SlidePage {
  /// Only a slide whose fight has been built can be opened; the slide sorter
  /// never offers the others.
  ArenaPage({required this.level})
    : assert(
        level.isBuilt,
        'Slide ${level.number} (${level.boss}) has no fight yet',
      );

  static const double _arenaWidth = 900;
  static const double _arenaHeight = 420;
  static const double _arenaTop = 150;
  static const double _playerSize = 120;

  final LevelDefinition level;

  @override
  Color get surfaceColor => Palette.showBlack;

  @override
  bool get castsShadow => false;

  late final ArenaFloor floor;

  /// Twin sticks: the left thumb moves, the right thumb aims and fires --
  /// or the other way round, with Swap sticks on in Design Ideas.
  late final ControlStick moveStick;
  late final ControlStick aimStick;

  late final Player player;
  late final Boss boss;

  /// True once the slide has been won or lost.
  bool get isResolved => _resolved;
  bool _resolved = false;

  late final TextComponent _sizeReadout;
  late final TextComponent _bossReadout;
  late final TextComponent _controlsHint;
  late int _shownHealth;
  late String _shownReadout;

  @override
  Future<void> onLoad() async {
    floor = ArenaFloor(
      position: Vector2((kSlideWidth - _arenaWidth) / 2, _arenaTop),
      size: Vector2(_arenaWidth, _arenaHeight),
    );
    final settings = game.settings;
    final underLeftThumb = Vector2(120, 612);
    final underRightThumb = Vector2(1160, 612);
    moveStick = ControlStick(
      position: settings.swapSticks ? underRightThumb : underLeftThumb,
    )..scale = Vector2.all(settings.stickSize);
    aimStick = ControlStick.aim(
      position: settings.swapSticks ? underLeftThumb : underRightThumb,
    )..scale = Vector2.all(settings.stickSize);
    player = Player(
      position: Vector2(_arenaWidth / 2, _arenaHeight - 90),
      size: _playerSize,
      moveStick: moveStick,
      aimStick: aimStick,
      gamepad: game.gamepad,
      onDefeated: _onPlayerShrunkAway,
    );
    boss = level.buildBoss!(
      BossContext(
        arenaSize: floor.size.clone(),
        aimAt: () => player.position,
        onDefeated: _onBossFinished,
      ),
    );
    _shownHealth = player.health.current;
    _shownReadout = boss.readout;

    floor.addAll([boss, player]);

    await addAll([
      TextComponent(
        text: 'Slide ${level.number} · ${level.boss}',
        textRenderer: SlideText.showHeading,
        position: Vector2(kSlideWidth / 2, 80),
        anchor: Anchor.center,
      )..flyIn(delay: 0.05),
      floor,
      moveStick,
      aimStick,
      _sizeReadout = TextComponent(
        text: _playerReadout,
        textRenderer: SlideText.showBody,
        position: Vector2(56, 524),
        anchor: Anchor.centerLeft,
      ),
      // Each feature reports its health in its own units, so the readout is
      // the boss's own wording rather than a percentage.
      _bossReadout = TextComponent(
        text: _bossReadoutText,
        textRenderer: SlideText.showBody,
        position: Vector2(1224, 524),
        anchor: Anchor.centerRight,
      ),
      _controlsHint = TextComponent(
        text: 'Left stick or WASD to move. Right stick or arrows to aim and fire.',
        textRenderer: SlideText.showBody,
        position: Vector2(kSlideWidth / 2, 598),
        anchor: Anchor.center,
      ),
      _pauseChip = ChipButton(
        label: 'Pause',
        position: Vector2(kSlideWidth - kSlideMargin - 162, 80),
        anchor: Anchor.centerRight,
        width: 120,
        height: 44,
        onSelected: pause,
      ),
      _endShowChip = ChipButton(
        label: 'End Show',
        filled: true,
        position: Vector2(kSlideWidth - kSlideMargin, 80),
        anchor: Anchor.centerRight,
        width: 150,
        height: 44,
        // Leaving takes two taps: one stray tap on a chip should not lose a
        // fight, so this opens the pause menu with End Show already chosen.
        onSelected: () => pause(focusOnLeaving: true),
      ),
    ]);
  }

  String get _playerReadout =>
      'You: ${(player.health.fraction * 100).round()}%';

  String get _bossReadoutText => '${level.boss}: ${boss.readout}';

  /// How long the result dialog ignores Enter, Space and A, so a player still
  /// hammering fire as the boss goes down does not press a button unseen.
  static const double resultInputDelay = 0.5;

  ResultPanel? _panel;
  double _resolvedFor = 0;
  bool _dialogFocused = false;

  late final ChipButton _pauseChip;
  late final ChipButton _endShowChip;
  PauseMenu? _pauseMenu;

  /// Whether the fight is frozen behind the blanked screen.
  bool get isPaused => _pauseMenu != null;

  /// Freezes the fight and blanks the slide, PowerPoint style.
  ///
  /// Does nothing once the slide has been decided, or while already paused,
  /// so a second B is a resume rather than a second menu.
  void pause({bool focusOnLeaving = false}) {
    if (_resolved || isPaused) {
      return;
    }
    // Everything that fights lives on the floor, so one time scale stops the
    // board: movement, shot cooldowns, boss timers and projectiles alike.
    floor.pause();
    // The thumb sticks and the chips would otherwise sit under a blank
    // screen, live.
    moveStick.removeFromParent();
    aimStick.removeFromParent();
    _pauseChip.removeFromParent();
    _endShowChip.removeFromParent();

    final menu = PauseMenu(
      onResume: resume,
      onRetry: () => _replaceWith(level.number),
      onLeave: _leave,
    );
    _pauseMenu = menu;
    add(menu);
    // Focus lands on the way out when the player asked to leave, and on the
    // way back in otherwise.
    menu.loaded.then((_) {
      final buttons = menu.children.whereType<ChipButton>().toList();
      if (buttons.isNotEmpty && isPaused) {
        showFocusOn(focusOnLeaving ? buttons.last : buttons.first);
      }
    });
  }

  /// Picks the fight back up exactly where it stopped.
  void resume() {
    final menu = _pauseMenu;
    if (menu == null) {
      return;
    }
    menu.removeFromParent();
    _pauseMenu = null;
    // Keys held while paused -- Space to choose Resume, say -- must not come
    // out as a shot the moment the board moves again.
    player.stopFiring();
    floor.resume();
    addAll([moveStick, aimStick, _pauseChip, _endShowChip]);
  }

  /// A fight pauses itself when the app goes away, and stays paused on the
  /// way back, so nobody returning from a notification is ambushed.
  @override
  void onAppBackgrounded() => pause();

  /// While fighting, nothing on the slide takes focus: the arrows aim. Once
  /// the slide is paused or decided, focus moves between that menu's buttons.
  @override
  List<Focusable> get focusables {
    final dialog = _pauseMenu ?? _panel;
    if (dialog == null) {
      return const [];
    }
    return dialog.children.whereType<ChipButton>().toList();
  }

  @override
  void onMenuAction(MenuAction action) {
    if (isPaused) {
      switch (action) {
        // B and Start pick the fight back up, the way B unblanks a slide show.
        case MenuAction.pause:
          resume();
        // A second Esc ends the show, as it would in PowerPoint.
        case MenuAction.back:
          _leave();
        default:
          super.onMenuAction(action);
      }
      return;
    }
    if (!_resolved) {
      switch (action) {
        case MenuAction.pause:
          pause();
        // Esc no longer loses the fight on its own: it asks first.
        case MenuAction.back:
          pause(focusOnLeaving: true);
        default:
          break;
      }
      return;
    }
    if (action == MenuAction.activate && _resolvedFor < resultInputDelay) {
      return;
    }
    super.onMenuAction(action);
  }

  /// Back from the result dialog ends the show, as End Show does.
  @override
  void onBack() => _leave();

  @override
  void update(double dt) {
    super.update(dt);
    final panel = _panel;
    if (panel != null) {
      _resolvedFor += dt;
      // The dialog's buttons exist once it has loaded. Its primary action
      // starts selected, so a controller player can see what A will do.
      if (!_dialogFocused) {
        final buttons = focusables;
        if (buttons.isNotEmpty) {
          _dialogFocused = true;
          showFocusOn(buttons.first);
        }
      }
    }
    // Only re-lay out a readout when the value it shows actually moves.
    if (_shownHealth != player.health.current) {
      _shownHealth = player.health.current;
      _sizeReadout.text = _playerReadout;
    }
    if (_shownReadout != boss.readout) {
      _shownReadout = boss.readout;
      _bossReadout.text = _bossReadoutText;
    }
  }

  void _onBossFinished() =>
      _resolve(won: true, title: 'Slide complete', message: level.winLine);

  void _onPlayerShrunkAway() =>
      _resolve(won: false, title: 'Slide failed', message: level.lossLine);

  void _resolve({
    required bool won,
    required String title,
    required String message,
  }) {
    // Nothing on the board moves while paused, so nothing can decide the
    // slide either: a blanked screen never turns into a result.
    if (_resolved || isPaused) {
      return;
    }
    // The player's exit animation plays before the slide is called lost, and
    // the fight runs on underneath it. A boss finished off during those last
    // moments does not steal the win.
    if (won && player.health.isDead) {
      return;
    }
    _resolved = true;
    if (won) {
      // Saved the moment it is won, so leaving from the dialog keeps it.
      unawaited(game.save.recordWin(level.number));
    }
    // Only after a win, and only onto a slide that has been built: beating
    // the last built slide ends on the normal dialog.
    final next = won ? game.deck.nextAfter(level.number) : null;

    // Freeze the board rather than tearing it down, so the last moment of the
    // fight stays on screen behind the dialog.
    floor.pause();
    moveStick.removeFromParent();
    aimStick.removeFromParent();
    // The dialog carries End Show of its own.
    _pauseChip.removeFromParent();
    _endShowChip.removeFromParent();
    // The hint would otherwise outlive the controls it describes.
    _controlsHint.removeFromParent();

    add(
      _panel = ResultPanel(
        position: Vector2(kSlideWidth / 2, kSlideHeight / 2),
        title: title,
        message: message,
        won: won,
        onRetry: () => _replaceWith(level.number),
        onLeave: _leave,
        onNext: next == null ? null : () => _replaceWith(next),
      ),
    );
  }

  /// The route does not maintain state, so popping drops this page and pushing
  /// builds a brand new fight -- the same slide again, or the next one.
  void _replaceWith(int slide) {
    game.router.pop();
    game.router.pushNamed(Routes.slideShowFor(slide));
  }

  void _leave() => game.router.pop();
}
