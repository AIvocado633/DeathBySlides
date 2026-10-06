import 'package:death_by_slides/game/components/chip_button.dart';
import 'package:death_by_slides/game/components/menu_bullet_button.dart';
import 'package:death_by_slides/game/components/result_panel.dart';
import 'package:death_by_slides/game/components/shape_actor.dart';
import 'package:death_by_slides/game/components/status_bar.dart';
import 'package:death_by_slides/game/death_by_slides_game.dart';
import 'package:death_by_slides/game/input/menu_input.dart';
import 'package:death_by_slides/game/levels.dart';
import 'package:death_by_slides/game/pages/arena_page.dart';
import 'package:death_by_slides/game/pages/end_of_show_page.dart';
import 'package:death_by_slides/game/pages/main_menu_page.dart';
import 'package:death_by_slides/game/routes.dart';
import 'package:death_by_slides/game/save/save_data.dart';
import 'package:death_by_slides/game/save/save_store.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamepads/gamepads.dart';

import 'arena_harness.dart';

final int _last = kLevels.last.number;

InMemorySaveStore _saved(Iterable<int> beaten) => InMemorySaveStore(
  SaveData(progress: Progress(beaten: beaten.toSet())).encode(),
);

/// Every slide but the last won, so the last is open.
InMemorySaveStore _allButLast() => _saved(
  [for (final level in kLevels) level.number].where((n) => n != _last),
);

/// Wins the last slide and waits for the show to end.
Future<EndOfShowPage> _finish(DeathBySlidesGame game) async {
  final arena = await openArena(game, level: _last);
  arena.boss.takeHit(arena.boss.totalHits);
  advance(game, 0.6);
  await game.ready();
  advance(game, ArenaPage.endOfShowDelay + 0.05);
  await game.ready();
  return _page<EndOfShowPage>(game);
}

T _page<T extends Component>(DeathBySlidesGame game) =>
    game.router.currentRoute.children.whereType<T>().single;

/// Lets the end screen take input.
Future<void> _wait(DeathBySlidesGame game) async {
  advance(game, EndOfShowPage.inputDelay + 0.05);
  await game.ready();
}

Future<MainMenuPage> _backOnTitle(DeathBySlidesGame game) async {
  await game.ready();
  advance(game, 1 / 60);
  await game.ready();
  expect(game.router.currentRoute.name, Routes.normalView);
  return _page<MainMenuPage>(game);
}

void _expectFinished(MainMenuPage menu) {
  expect(
    menu.children.whereType<StatusBar>().single.slideLabel,
    'Slide $_last of ${kLevels.length} · Presented',
  );
  expect(
    menu.descendants().whereType<TextComponent>().map((text) => text.text),
    containsAll([
      MainMenuPage.footerLine(0),
      'Shape 1 · presented the whole deck',
    ]),
  );
  final hero = menu.descendants().whereType<ShapeActor>().single;
  expect(hero.state, ActorState.cheer);
}

void main() {
  group('end of slide show', () {
    testWithGame<DeathBySlidesGame>(
      'winning the last slide ends the show instead of showing the panel',
      () => DeathBySlidesGame(saveStore: _allButLast()),
      (game) async {
        final arena = await openArena(game, level: _last);
        arena.boss.takeHit(arena.boss.totalHits);
        advance(game, 0.6);
        await game.ready();
        expect(arena.isResolved, isTrue);
        expect(arena.children.whereType<ResultPanel>(), isEmpty);

        advance(game, ArenaPage.endOfShowDelay + 0.05);
        await game.ready();
        expect(game.router.currentRoute.name, Routes.endOfShow);
        expect(game.descendants().whereType<ArenaPage>(), isEmpty);
        final texts = game.descendants().whereType<TextComponent>().map(
          (text) => text.text,
        );
        expect(texts, contains('End of slide show, click to exit.'));
        expect(texts, containsAll(EndOfShowPage.speakerNotes));
      },
    );

    testWithGame<DeathBySlidesGame>(
      'a press during the last moment of the fight does not skip it',
      () => DeathBySlidesGame(saveStore: _allButLast()),
      (game) async {
        await _finish(game);
        game.handleMenuAction(MenuAction.activate);
        await game.ready();
        expect(game.router.currentRoute.name, Routes.endOfShow);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'any key continues to the title slide, finished',
      () => DeathBySlidesGame(saveStore: _allButLast()),
      (game) async {
        await _finish(game);
        await _wait(game);

        // Not a key any menu uses.
        game.onKeyEvent(
          const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.keyQ,
            logicalKey: LogicalKeyboardKey.keyQ,
            timeStamp: Duration.zero,
          ),
          {LogicalKeyboardKey.keyQ},
        );
        _expectFinished(await _backOnTitle(game));
      },
    );

    testWithGame<DeathBySlidesGame>(
      'any controller button continues too',
      () => DeathBySlidesGame(saveStore: _allButLast()),
      (game) async {
        await _finish(game);
        await _wait(game);

        game.gamepad.handle(buttonEvent(GamepadButton.x));
        advance(game, 1 / 60);
        await _backOnTitle(game);
      },
    );

    final store = _allButLast();
    testWithGame<DeathBySlidesGame>(
      'a menu action continues, and the finished deck is saved',
      () => DeathBySlidesGame(saveStore: store),
      (game) async {
        await _finish(game);
        await _wait(game);
        game.handleMenuAction(MenuAction.back);
        await _backOnTitle(game);
        expect(game.deck.isFinished, isTrue);
        final saved = SaveData.decode(store.document!);
        expect(
          kLevels.every((level) => saved.progress.hasBeaten(level.number)),
          isTrue,
        );
      },
    );

    testWithGame<DeathBySlidesGame>(
      'a finished deck stays finished across restarts',
      () => DeathBySlidesGame(
        saveStore: _saved([for (final level in kLevels) level.number]),
      ),
      (game) async {
        await game.ready();
        final menu = _page<MainMenuPage>(game);
        _expectFinished(menu);
        expect(
          menu.children.whereType<MenuBulletButton>().map(
            (button) => button.label,
          ),
          contains('From the Top'),
        );
      },
    );

    testWithGame<DeathBySlidesGame>(
      'an unfinished deck looks as before',
      () => DeathBySlidesGame(saveStore: _allButLast()),
      (game) async {
        await game.ready();
        final menu = _page<MainMenuPage>(game);
        expect(
          menu.children.whereType<StatusBar>().single.slideLabel,
          'Slide $_last of ${kLevels.length}',
        );
        expect(
          menu.descendants().whereType<ShapeActor>().single.state,
          ActorState.idle,
        );
      },
    );

    testWithGame<DeathBySlidesGame>(
      'replaying a slide afterwards works as before',
      () => DeathBySlidesGame(
        saveStore: _saved([for (final level in kLevels) level.number]),
      ),
      (game) async {
        final arena = await openArena(game, level: 3);
        arena.boss.takeHit(arena.boss.totalHits);
        advance(game, 0.6);
        await game.ready();
        final panel = arena.children.whereType<ResultPanel>().single;
        expect(panel.won, isTrue);
        expect(
          panel.children.whereType<ChipButton>().first.label,
          'Next Slide',
        );
      },
    );

    testWithGame<DeathBySlidesGame>(
      'replaying the last slide ends the show again',
      () => DeathBySlidesGame(
        saveStore: _saved([for (final level in kLevels) level.number]),
      ),
      (game) async {
        await _finish(game);
        expect(game.router.currentRoute.name, Routes.endOfShow);
      },
    );
  });
}
