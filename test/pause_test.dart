import 'package:flame_test/flame_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:gamepads/gamepads.dart';
import 'package:pptx_monsters/game/combat/projectiles.dart';
import 'package:pptx_monsters/game/components/chip_button.dart';
import 'package:pptx_monsters/game/components/control_stick.dart';
import 'package:pptx_monsters/game/components/pause_menu.dart';
import 'package:pptx_monsters/game/components/result_panel.dart';
import 'package:pptx_monsters/game/pages/arena_page.dart';
import 'package:pptx_monsters/game/pptx_monsters_game.dart';
import 'package:pptx_monsters/game/routes.dart';

import 'arena_harness.dart';

void main() {
  group('pausing', () {
    testWithGame<PptxMonstersGame>(
      'B blanks the screen and freezes the board',
      PptxMonstersGame.new,
      (game) async {
        final arena = await openArena(game);
        // Something of everything in flight: the player walking, a shot of
        // theirs, and the boss going about its business.
        hold(arena.player, {LogicalKeyboardKey.keyD});
        arena.player.fire();
        advance(game, 0.1);
        await game.ready();
        final shot = arena.floor.children.whereType<BulletPoint>().first;
        final was = (
          player: arena.player.position.clone(),
          shot: shot.position.clone(),
          boss: arena.boss.position.clone(),
          readout: arena.boss.readout,
        );

        _press(game, LogicalKeyboardKey.keyB);
        await game.ready();
        expect(arena.isPaused, isTrue);
        expect(arena.floor.timeScale, 0);
        expect(arena.children.whereType<PauseMenu>(), hasLength(1));

        advance(game, 2);
        await game.ready();
        expect(arena.player.position, was.player);
        expect(shot.position, was.shot, reason: 'shots hang in the air');
        expect(arena.boss.position, was.boss);
        expect(arena.boss.readout, was.readout, reason: 'boss timers stop');
        expect(
          arena.floor.children.whereType<BulletPoint>(),
          hasLength(1),
          reason: 'and nothing new is fired',
        );
      },
    );

    testWithGame<PptxMonstersGame>(
      'takes the controls away, and gives them back on resume',
      PptxMonstersGame.new,
      (game) async {
        final arena = await openArena(game);

        arena.pause();
        await game.ready();
        expect(arena.children.whereType<ControlStick>(), isEmpty);
        expect(_chipLabels(arena), isNot(contains('Pause')));

        arena.resume();
        await game.ready();
        expect(arena.children.whereType<ControlStick>(), hasLength(2));
        expect(_chipLabels(arena), containsAll(['Pause', 'Walk Off']));
        expect(arena.children.whereType<PauseMenu>(), isEmpty);
      },
    );

    testWithGame<PptxMonstersGame>(
      'carries on from exactly where it stopped',
      PptxMonstersGame.new,
      (game) async {
        final arena = await openArena(game);
        hold(arena.player, {LogicalKeyboardKey.keyD});
        advance(game, 0.2);
        await game.ready();

        arena.pause();
        advance(game, 1);
        await game.ready();
        final paused = arena.player.position.clone();

        arena.resume();
        advance(game, 0.2);
        await game.ready();

        expect(
          arena.player.position.x,
          greaterThan(paused.x),
          reason: 'walking again, from where it left off',
        );
      },
    );

    testWithGame<PptxMonstersGame>(
      'does not fire a shot queued while paused',
      PptxMonstersGame.new,
      (game) async {
        final arena = await openArena(game);
        advance(game, 0.5);
        await game.ready();
        final before = arena.floor.children.whereType<BulletPoint>().length;

        _press(game, LogicalKeyboardKey.keyB);
        await game.ready();
        // Space chooses Resume on the pause menu -- and would otherwise be
        // held down as the fight starts again.
        hold(arena.player, {LogicalKeyboardKey.space});
        arena.resume();
        advance(game, 1 / 60);
        await game.ready();

        expect(
          arena.floor.children.whereType<BulletPoint>(),
          hasLength(before),
        );
      },
    );

    testWithGame<PptxMonstersGame>(
      'the slide cannot be decided while it is paused',
      PptxMonstersGame.new,
      (game) async {
        final arena = await openArena(game);
        arena.pause();
        await game.ready();

        // The boss would go down, if anything on the board could move.
        arena.boss.takeHit(arena.boss.totalHits);
        advance(game, 2);
        await game.ready();

        expect(arena.isResolved, isFalse);
        expect(arena.children.whereType<ResultPanel>(), isEmpty);
      },
    );

    testWithGame<PptxMonstersGame>(
      'a second B picks the fight back up',
      PptxMonstersGame.new,
      (game) async {
        final arena = await openArena(game);

        _press(game, LogicalKeyboardKey.keyB);
        await game.ready();
        _press(game, LogicalKeyboardKey.keyB);
        await game.ready();

        expect(arena.isPaused, isFalse);
        expect(arena.floor.timeScale, 1);
      },
    );

    testWithGame<PptxMonstersGame>(
      'controller Start pauses and resumes',
      PptxMonstersGame.new,
      (game) async {
        final arena = await openArena(game);

        _pressButton(game, GamepadButton.start);
        expect(arena.isPaused, isTrue);
        await game.ready();
        _pressButton(game, GamepadButton.start);

        expect(arena.isPaused, isFalse);
      },
    );

    testWithGame<PptxMonstersGame>(
      'chooses Resume for a pause, and Walk Off for a request to leave',
      PptxMonstersGame.new,
      (game) async {
        final arena = await openArena(game);

        arena.pause();
        await game.ready();
        expect(_focusedLabel(arena), 'Resume');
        arena.resume();
        await game.ready();

        _press(game, LogicalKeyboardKey.escape);
        await game.ready();
        expect(_focusedLabel(arena), 'Walk Off');
      },
    );

    testWithGame<PptxMonstersGame>(
      'the pause menu retries and leaves',
      PptxMonstersGame.new,
      (game) async {
        final arena = await openArena(game);
        arena.pause();
        await game.ready();

        _chip(arena, 'Retry Slide').onSelected();
        await game.ready();
        final retried = game.router.currentRoute.children
            .whereType<ArenaPage>()
            .single;
        expect(retried, isNot(same(arena)));
        expect(retried.isPaused, isFalse);

        retried.pause();
        await game.ready();
        _chip(retried, 'Walk Off').onSelected();
        await game.ready();
        expect(game.router.currentRoute.name, Routes.normalView);
      },
    );

    testWithGame<PptxMonstersGame>(
      'the Walk Off chip asks rather than leaving at once',
      PptxMonstersGame.new,
      (game) async {
        final arena = await openArena(game);

        _chip(arena, 'Walk Off').onSelected();
        await game.ready();

        expect(arena.isPaused, isTrue);
        expect(game.router.currentRoute.name, Routes.slideShowFor(1));
      },
    );

    testWithGame<PptxMonstersGame>(
      'leaving the app pauses, and coming back leaves it paused',
      PptxMonstersGame.new,
      (game) async {
        final arena = await openArena(game);

        game.lifecycleStateChange(AppLifecycleState.inactive);
        await game.ready();
        expect(arena.isPaused, isTrue);

        game.lifecycleStateChange(AppLifecycleState.resumed);
        advance(game, 1);
        await game.ready();
        expect(
          arena.isPaused,
          isTrue,
          reason: 'nobody comes back from a notification mid-dodge',
        );
      },
    );

    testWithGame<PptxMonstersGame>(
      'a menu ignores the app going away, and B',
      PptxMonstersGame.new,
      (game) async {
        await game.ready();

        game.lifecycleStateChange(AppLifecycleState.paused);
        _press(game, LogicalKeyboardKey.keyB);
        await game.ready();

        expect(game.router.currentRoute.name, Routes.normalView);
        expect(game.descendants().whereType<PauseMenu>(), isEmpty);
      },
    );

    testWithGame<PptxMonstersGame>(
      'a decided slide stays decided: no pausing the result',
      PptxMonstersGame.new,
      (game) async {
        final arena = await openArena(game);
        arena.boss.takeHit(arena.boss.totalHits);
        advance(game, 0.6);
        await game.ready();
        expect(arena.isResolved, isTrue);

        _press(game, LogicalKeyboardKey.keyB);
        await game.ready();

        expect(arena.isPaused, isFalse);
        expect(arena.children.whereType<ResultPanel>(), hasLength(1));
      },
    );
  });
}

void _press(PptxMonstersGame game, LogicalKeyboardKey key) {
  game.onKeyEvent(
    KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.keyA,
      logicalKey: key,
      timeStamp: Duration.zero,
    ),
    {key},
  );
}

void _pressButton(PptxMonstersGame game, GamepadButton button) {
  game.gamepad
    ..handle(buttonEvent(button))
    ..handle(buttonEvent(button, down: false));
  advance(game, 1 / 60);
}

Iterable<String> _chipLabels(ArenaPage arena) =>
    arena.children.whereType<ChipButton>().map((chip) => chip.label);

ChipButton _chip(ArenaPage arena, String label) => arena
    .descendants()
    .whereType<ChipButton>()
    .singleWhere((chip) => chip.label == label);

String? _focusedLabel(ArenaPage arena) {
  final focused = arena.focused;
  return focused is ChipButton ? focused.label : null;
}
