import 'package:death_by_slides/game/combat/snap_to_grid_boss.dart';
import 'package:death_by_slides/game/components/arena_floor.dart';
import 'package:death_by_slides/game/components/result_panel.dart';
import 'package:death_by_slides/game/death_by_slides_game.dart';
import 'package:death_by_slides/game/pages/arena_page.dart';
import 'package:death_by_slides/game/save/save_data.dart';
import 'package:death_by_slides/game/save/save_store.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'arena_harness.dart';

const int _snapToGridLevel = 5;

DeathBySlidesGame _game() => DeathBySlidesGame(unlockAll: true);

Future<(ArenaPage, SnapToGridBoss)> _open(DeathBySlidesGame game) async {
  final arena = await openArena(game, level: _snapToGridLevel);
  advance(game, 1 / 60);
  await game.ready();
  return (arena, arena.boss as SnapToGridBoss);
}

/// Whether [value] lies on one of the floor's grid lines along that axis.
bool _onALine(ArenaFloor floor, double value, {required bool rows}) =>
    floor.gridLines(rows: rows).any((line) => (line - value).abs() < 1e-3);

void main() {
  group('Snap to Grid boss', () {
    testWithGame<DeathBySlidesGame>(
      'starts coarse: 2 cm, drawn and snapped alike',
      _game,
      (game) async {
        final (arena, boss) = await _open(game);

        expect(boss.readout, 'Spacing 2 cm');
        expect(arena.floor.gridSpacing, 2 * SnapToGridBoss.unitsPerCm);
        expect(arena.player.positionFilter, isNotNull);
        final at = arena.player.position;
        expect(_onALine(arena.floor, at.x, rows: false), isTrue);
        expect(_onALine(arena.floor, at.y, rows: true), isTrue);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'the player lies on the grid after moving',
      _game,
      (game) async {
        final (arena, _) = await _open(game);

        hold(arena.player, {LogicalKeyboardKey.keyD, LogicalKeyboardKey.keyW});
        for (var i = 0; i < 20; i++) {
          advance(game, 0.05);
          final at = arena.player.position;
          expect(_onALine(arena.floor, at.x, rows: false), isTrue);
          expect(_onALine(arena.floor, at.y, rows: true), isTrue);
        }
      },
    );

    testWithGame<DeathBySlidesGame>(
      'a short push moves the intention; the player hops once past halfway',
      _game,
      (game) async {
        final (arena, boss) = await _open(game);
        final start = arena.player.position.clone();

        hold(arena.player, {LogicalKeyboardKey.keyD});
        advance(game, 0.05);
        expect(arena.player.position, start, reason: 'not halfway yet');
        expect(arena.player.intendedPosition.x, greaterThan(start.x));

        advance(game, 0.4);
        expect(arena.player.position.x, closeTo(start.x + boss.spacing, 1e-3));
      },
    );

    testWithGame<DeathBySlidesGame>(
      'every few hits the grid gets finer, down to 0.25 cm',
      _game,
      (game) async {
        final (arena, boss) = await _open(game);

        for (final cm in SnapToGridBoss.spacingsCm.skip(1)) {
          boss.takeHit(SnapToGridBoss.hitsPerSpacing);
          expect(boss.spacingCm, cm);
          expect(arena.floor.gridSpacing, cm * SnapToGridBoss.unitsPerCm);
          final at = arena.player.position;
          expect(_onALine(arena.floor, at.x, rows: false), isTrue);
          expect(_onALine(arena.floor, at.y, rows: true), isTrue);
        }
        expect(boss.readout, 'Spacing 0.25 cm');
      },
    );

    testWithGame<DeathBySlidesGame>(
      'a guide hits a player on its line, and not one a line beside it',
      _game,
      (game) async {
        final (arena, boss) = await _open(game);
        final player = arena.player;
        final full = player.health.current;

        boss
          ..markGuide(horizontal: true, line: player.position.y - boss.spacing)
          ..markGuide(horizontal: false, line: player.position.x + boss.spacing);
        await game.ready();
        advance(game, SnapToGridBoss.warning + 0.1);
        await game.ready();
        expect(player.health.current, full, reason: 'a line beside it');

        boss.markGuide(horizontal: true, line: player.position.y);
        await game.ready();
        advance(game, SnapToGridBoss.warning - 0.1);
        expect(player.health.current, full, reason: 'still only a warning');
        advance(game, 0.2);
        expect(player.health.current, full - 1);
      },
    );

    testWithGame<DeathBySlidesGame>(
      "every volley marks the player's own row or column",
      _game,
      (game) async {
        final (arena, _) = await _open(game);
        final at = arena.player.position.clone();

        advance(game, SnapToGridBoss.volleyInterval);
        await game.ready();
        final guides = arena.floor.children.whereType<AlignmentGuide>();
        expect(guides, isNotEmpty);
        expect(
          guides.any(
            (g) => (g.line - (g.horizontal ? at.y : at.x)).abs() < 1e-3,
          ),
          isTrue,
        );
      },
    );

    testWithGame<DeathBySlidesGame>(
      'the dialog snaps to the grid too',
      _game,
      (game) async {
        final (arena, boss) = await _open(game);
        advance(game, 1.3);
        expect(_onALine(arena.floor, boss.position.x, rows: false), isTrue);
        expect(_onALine(arena.floor, boss.position.y, rows: true), isTrue);
      },
    );

    testWithGame<DeathBySlidesGame>(
      'spacing run out: snapping off, the plain floor back, the slide won',
      _game,
      (game) async {
        final (arena, boss) = await _open(game);
        boss.markGuide(horizontal: true, line: arena.player.position.y);
        await game.ready();

        boss.takeHit(boss.remainingHits);
        expect(boss.readout, 'Off');
        expect(arena.player.positionFilter, isNull);
        expect(arena.floor.gridSpacing, ArenaFloor.standardGridSpacing);
        await game.ready();
        expect(arena.floor.children.whereType<AlignmentGuide>(), isEmpty);

        advance(game, 0.6);
        await game.ready();
        expect(arena.isResolved, isTrue);
        expect(arena.children.whereType<ResultPanel>().single.won, isTrue);
      },
    );

    testWithGame<DeathBySlidesGame>(
      "Pep Talk's slower shots give the guides longer to read",
      () => DeathBySlidesGame(
        unlockAll: true,
        saveStore: InMemorySaveStore(
          SaveData(
            settings: const Settings(pepTalk: PepTalk(slowerShots: true)),
          ).encode(),
        ),
      ),
      (game) async {
        await _open(game);
        expect(
          SnapToGridBoss.warning,
          closeTo(SnapToGridBoss.warningTime / 0.7, 1e-9),
        );
      },
    );
  });
}
