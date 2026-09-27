import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamepads/gamepads.dart';
import 'package:pptx_monsters/game/components/player.dart';
import 'package:pptx_monsters/game/components/chip_button.dart';
import 'package:pptx_monsters/game/components/menu_bullet_button.dart';
import 'package:pptx_monsters/game/components/result_panel.dart';
import 'package:pptx_monsters/game/input/gamepad_input.dart';
import 'package:pptx_monsters/game/input/menu_input.dart';
import 'package:pptx_monsters/game/pages/arena_page.dart';
import 'package:pptx_monsters/game/pages/slide_sorter_page.dart';
import 'package:pptx_monsters/game/pptx_monsters_game.dart';
import 'package:pptx_monsters/game/routes.dart';
import 'package:pptx_monsters/game/save/save_data.dart';
import 'package:pptx_monsters/game/save/save_store.dart';
import 'package:pptx_monsters/game/slide/slide_page.dart';

import 'arena_harness.dart';

void main() {
  group('keys', () {
    MenuAction? down(LogicalKeyboardKey key, [Set<LogicalKeyboardKey>? held]) =>
        menuActionForKey(
          KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.keyA,
            logicalKey: key,
            timeStamp: Duration.zero,
          ),
          held ?? {key},
        );

    test('map onto menu actions', () {
      expect(down(LogicalKeyboardKey.arrowUp), MenuAction.up);
      expect(down(LogicalKeyboardKey.arrowRight), MenuAction.right);
      expect(down(LogicalKeyboardKey.enter), MenuAction.activate);
      expect(down(LogicalKeyboardKey.space), MenuAction.activate);
      expect(down(LogicalKeyboardKey.escape), MenuAction.back);
      expect(down(LogicalKeyboardKey.f5), MenuAction.startFromBeginning);
      expect(
        down(LogicalKeyboardKey.f5, {
          LogicalKeyboardKey.shiftLeft,
          LogicalKeyboardKey.f5,
        }),
        MenuAction.startFromCurrent,
      );
      expect(down(LogicalKeyboardKey.keyW), isNull);
    });

    test('repeat only for the arrows', () {
      MenuAction? repeat(LogicalKeyboardKey key) => menuActionForKey(
        KeyRepeatEvent(
          physicalKey: PhysicalKeyboardKey.keyA,
          logicalKey: key,
          timeStamp: Duration.zero,
        ),
        {key},
      );

      expect(repeat(LogicalKeyboardKey.arrowDown), MenuAction.down);
      expect(repeat(LogicalKeyboardKey.enter), isNull);
    });
  });

  group('controller', () {
    test('reports each button press once, however long it is held', () {
      final input = GamepadInput()
        ..handle(buttonEvent(GamepadButton.a))
        ..handle(buttonEvent(GamepadButton.a));

      expect(input.isHeld(GamepadButton.a), isTrue);
      expect(input.takePresses(), [GamepadButton.a]);
      expect(input.takePresses(), isEmpty, reason: 'drained by the first read');

      input
        ..handle(buttonEvent(GamepadButton.a, down: false))
        ..handle(buttonEvent(GamepadButton.a));
      expect(input.isHeld(GamepadButton.a), isTrue);
      expect(input.takePresses(), [GamepadButton.a], reason: 'a new press');
    });

    test('keeps buttons out of the sticks', () {
      final input = GamepadInput()..handle(buttonEvent(GamepadButton.dpadUp));

      expect(input.move, Vector2.zero());
      expect(input.aim, Vector2.zero());
    });

    test('maps A, B and the D-pad onto menu actions', () {
      expect(menuActionForButton(GamepadButton.a), MenuAction.activate);
      expect(menuActionForButton(GamepadButton.b), MenuAction.back);
      expect(menuActionForButton(GamepadButton.dpadLeft), MenuAction.left);
      expect(menuActionForButton(GamepadButton.start), MenuAction.pause);
      expect(menuActionForButton(GamepadButton.x), isNull);
    });

    test('a stick push steps once, then repeats only when held', () {
      final repeat = StickRepeat();
      final pushed = Vector2(0, 1);

      expect(repeat.update(1 / 60, pushed), MenuAction.down);
      var steps = 0;
      // Just short of the first repeat.
      for (var t = 0.0; t < StickRepeat.firstDelay - 0.05; t += 1 / 60) {
        if (repeat.update(1 / 60, pushed) != null) {
          steps++;
        }
      }
      expect(steps, 0);
      for (var t = 0.0; t < 0.1; t += 1 / 60) {
        if (repeat.update(1 / 60, pushed) != null) {
          steps++;
        }
      }
      expect(steps, 1);

      expect(repeat.update(1 / 60, Vector2.zero()), isNull);
      expect(repeat.update(1 / 60, pushed), MenuAction.down);
    });

    test('a stick resting inside the threshold never steps', () {
      final repeat = StickRepeat();
      for (var i = 0; i < 120; i++) {
        expect(repeat.update(1 / 60, Vector2(0.3, 0.2)), isNull);
      }
    });
  });

  group('title slide', () {
    testWithGame<PptxMonstersGame>(
      'shows focus on the first press, then moves it in order',
      PptxMonstersGame.new,
      (game) async {
        final page = await _settled(game);
        expect(page.focusVisible, isFalse);

        game.handleMenuAction(MenuAction.down);
        expect(page.focusVisible, isTrue);
        expect(_label(page.focused), 'Start Presenting');

        game.handleMenuAction(MenuAction.down);
        expect(_label(page.focused), 'Light Table');
        game.handleMenuAction(MenuAction.down);
        game.handleMenuAction(MenuAction.down);
        expect(
          _label(page.focused),
          'Tweaks',
          reason: 'stops at the end',
        );
        game.handleMenuAction(MenuAction.up);
        expect(_label(page.focused), 'Light Table');
      },
    );

    testWithGame<PptxMonstersGame>(
      'activates the focused entry',
      PptxMonstersGame.new,
      (game) async {
        await _settled(game);

        game.handleMenuAction(MenuAction.down);
        game.handleMenuAction(MenuAction.down);
        game.handleMenuAction(MenuAction.activate);
        await game.ready();

        expect(game.router.currentRoute.name, Routes.slideSorter);
      },
    );

    testWithGame<PptxMonstersGame>(
      'F5 starts the show from the beginning',
      () => PptxMonstersGame(saveStore: _saved({1})),
      (game) async {
        await _settled(game);

        _press(game, LogicalKeyboardKey.f5);
        await game.ready();

        expect(_arena(game).level.number, 1);
      },
    );

    testWithGame<PptxMonstersGame>(
      'Shift+F5 starts it from the current slide',
      () => PptxMonstersGame(saveStore: _saved({1})),
      (game) async {
        await _settled(game);

        game.handleMenuAction(MenuAction.startFromCurrent);
        await game.ready();

        expect(_arena(game).level.number, 2);
      },
    );

    testWithGame<PptxMonstersGame>(
      'back stays on the title slide, and tells Android to leave',
      PptxMonstersGame.new,
      (game) async {
        await _settled(game);

        game.handleMenuAction(MenuAction.back);
        await game.ready();

        expect(game.router.currentRoute.name, Routes.normalView);
        expect(game.goBack(), isFalse);
      },
    );
  });

  group('slide sorter', () {
    testWithGame<PptxMonstersGame>(
      'starts focus on the current slide and moves across the grid',
      () => PptxMonstersGame(saveStore: _saved({1})),
      (game) async {
        final sorter = await _settled(game, Routes.slideSorter);

        game.handleMenuAction(MenuAction.right);
        expect(_slide(sorter.focused), 2, reason: 'the first press only shows');

        final path = <int?>[];
        for (final step in [
          MenuAction.down,
          MenuAction.right,
          MenuAction.up,
          MenuAction.left,
          MenuAction.left,
        ]) {
          game.handleMenuAction(step);
          path.add(_slide(sorter.focused));
        }
        expect(path, [5, 6, 3, 2, 1]);

        game.handleMenuAction(MenuAction.up);
        expect(
          (sorter.focused! as ChipButton).label,
          'Back to Editing',
          reason: 'the only thing above the grid',
        );
        game.handleMenuAction(MenuAction.down);
        expect(_slide(sorter.focused), 3, reason: 'the nearest slide below');
      },
    );

    testWithGame<PptxMonstersGame>(
      'opens the focused slide, but not a locked one',
      PptxMonstersGame.new,
      (game) async {
        final sorter = await _settled(game, Routes.slideSorter);

        game.handleMenuAction(MenuAction.right);
        game.handleMenuAction(MenuAction.right);
        expect(_slide(sorter.focused), 2);
        game.handleMenuAction(MenuAction.activate);
        await game.ready();
        expect(game.router.currentRoute.name, Routes.slideSorter);

        game.handleMenuAction(MenuAction.left);
        game.handleMenuAction(MenuAction.activate);
        await game.ready();
        expect(_arena(game).level.number, 1);
      },
    );

    testWithGame<PptxMonstersGame>(
      'Esc goes back to the title slide',
      PptxMonstersGame.new,
      (game) async {
        await _settled(game, Routes.slideSorter);

        _press(game, LogicalKeyboardKey.escape);
        await game.ready();

        expect(game.router.currentRoute.name, Routes.normalView);
      },
    );

    testWithGame<PptxMonstersGame>(
      'controller B goes back too',
      PptxMonstersGame.new,
      (game) async {
        await _settled(game, Routes.slideSorter);

        game.gamepad.handle(buttonEvent(GamepadButton.b));
        advance(game, 1 / 60);
        await game.ready();

        expect(game.router.currentRoute.name, Routes.normalView);
      },
    );

    testWithGame<PptxMonstersGame>(
      'Android back goes back within the game',
      PptxMonstersGame.new,
      (game) async {
        await _settled(game, Routes.slideSorter);

        expect(game.goBack(), isTrue);
        await game.ready();

        expect(game.router.currentRoute.name, Routes.normalView);
      },
    );
  });

  group('slide show', () {
    testWithGame<PptxMonstersGame>(
      'Esc asks first, and a second Esc ends the show',
      PptxMonstersGame.new,
      (game) async {
        final arena = await openArena(game);

        _press(game, LogicalKeyboardKey.escape);
        await game.ready();
        expect(arena.isPaused, isTrue);
        expect(game.router.currentRoute.name, Routes.slideShowFor(1));

        _press(game, LogicalKeyboardKey.escape);
        await game.ready();
        expect(game.router.currentRoute.name, Routes.normalView);
      },
    );

    testWithGame<PptxMonstersGame>(
      'ignores menu keys mid-fight, so Space and the arrows stay weapons',
      PptxMonstersGame.new,
      (game) async {
        final arena = await openArena(game);

        game.handleMenuAction(MenuAction.activate);
        game.handleMenuAction(MenuAction.up);
        await game.ready();

        expect(game.router.currentRoute.name, Routes.slideShowFor(1));
        expect(arena.focused, isNull);
      },
    );

    testWithGame<PptxMonstersGame>(
      'selects the result dialog\'s primary action once the slide is decided',
      PptxMonstersGame.new,
      (game) async {
        final arena = await openArena(game);
        await _win(game, arena);

        expect(arena.focusVisible, isTrue);
        expect(_label(arena.focused), 'Next Slide');
        game.handleMenuAction(MenuAction.right);
        expect(_label(arena.focused), 'Retry Slide');
      },
    );

    testWithGame<PptxMonstersGame>(
      'ignores a press that lands as the dialog appears',
      PptxMonstersGame.new,
      (game) async {
        final arena = await openArena(game);
        arena.player.takeHit(arena.player.health.max);
        advance(game, Player.exitDuration + 0.1);
        await game.ready();
        expect(arena.isResolved, isTrue);

        game.handleMenuAction(MenuAction.activate);
        await game.ready();
        expect(
          _arena(game),
          same(arena),
          reason: 'still on the dialog, not a retried fight',
        );
      },
    );

    testWithGame<PptxMonstersGame>(
      'Android back pauses the fight rather than leaving it',
      PptxMonstersGame.new,
      (game) async {
        final arena = await openArena(game);

        expect(game.goBack(), isTrue);
        await game.ready();

        expect(arena.isPaused, isTrue);
        expect(game.router.currentRoute.name, Routes.slideShowFor(1));
      },
    );
  });

  testWithGame<PptxMonstersGame>(
    'the whole run can be played with only a controller',
    PptxMonstersGame.new,
    (game) async {
      await _settled(game);
      void press(GamepadButton button) {
        game.gamepad
          ..handle(buttonEvent(button))
          ..handle(buttonEvent(button, down: false));
        advance(game, 1 / 60);
      }

      // Title: A starts the show.
      press(GamepadButton.a);
      await game.ready();
      final first = _arena(game);
      expect(first.level.number, 1);

      // Win, and take Next Slide.
      await _win(game, first);
      advance(game, ArenaPage.resultInputDelay);
      press(GamepadButton.a);
      await game.ready();
      final second = _arena(game);
      expect(second.level.number, 2);

      // Lose, and retry: on a loss the primary action is Retry Slide.
      second.player.takeHit(second.player.health.max);
      advance(game, Player.exitDuration + ArenaPage.resultInputDelay + 0.1);
      await game.ready();
      press(GamepadButton.a);
      await game.ready();
      final retried = _arena(game);
      expect(retried.level.number, 2);
      expect(retried, isNot(same(second)));

      // B asks before it ends the show, so it takes two: the first blanks the
      // screen with Walk Off chosen, the second leaves.
      press(GamepadButton.b);
      await game.ready();
      expect(retried.isPaused, isTrue);
      press(GamepadButton.b);
      await game.ready();
      expect(game.router.currentRoute.name, Routes.normalView);
    },
  );
}

InMemorySaveStore _saved(Set<int> beaten) =>
    InMemorySaveStore(SaveData(progress: Progress(beaten: beaten)).encode());

/// Opens [route], lets its entrance animations finish, and returns its page.
Future<SlidePage> _settled(
  PptxMonstersGame game, [
  String route = Routes.normalView,
]) async {
  await game.ready();
  if (game.router.currentRoute.name != route) {
    game.router.pushNamed(route);
    await game.ready();
  }
  advance(game, 3);
  await game.ready();
  return game.currentPage!;
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

Future<void> _win(PptxMonstersGame game, ArenaPage arena) async {
  arena.boss.takeHit(arena.boss.totalHits);
  advance(game, 0.6);
  await game.ready();
  advance(game, 1 / 60);
  expect(arena.isResolved, isTrue);
  expect(arena.children.whereType<ResultPanel>(), hasLength(1));
}

ArenaPage _arena(PptxMonstersGame game) =>
    game.router.currentRoute.children.whereType<ArenaPage>().single;

String? _label(Object? focused) => switch (focused) {
  MenuBulletButton(:final label) => label,
  ChipButton(:final label) => label,
  _ => null,
};

int? _slide(Object? focused) =>
    focused is SlideThumbnail ? focused.level.number : null;
