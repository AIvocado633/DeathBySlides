import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:death_by_slides/game/combat/boss.dart';
import 'package:death_by_slides/game/levels.dart';
import 'package:death_by_slides/game/pages/arena_page.dart';

/// Guards the deck as a whole, rather than any one fight.
void main() {
  group('the deck', () {
    test('builds the boss of every slide that has one', () {
      // Each fight's own tests play it in a running game. This only checks
      // that no builder throws, which covers bosses that have no tests yet.
      final context = BossContext(
        arenaSize: Vector2(900, 420),
        aimAt: Vector2.zero,
        onDefeated: () {},
      );
      for (final level in kLevels.where((level) => level.isBuilt)) {
        expect(
          () => level.buildBoss!(context),
          returnsNormally,
          reason: 'slide ${level.number} (${level.boss}) fails to build',
        );
      }
    });

    test('refuses to open a slide whose fight has not been built', () {
      const unbuilt = LevelDefinition(
        number: 99,
        boss: 'Nothing yet',
        tagline: '',
        winLine: '',
        lossLine: '',
      );

      expect(unbuilt.isBuilt, isFalse);
      expect(() => ArenaPage(level: unbuilt), throwsAssertionError);
    });

    test('numbers its levels from one, in order, with no gaps', () {
      for (var i = 0; i < kLevels.length; i++) {
        expect(kLevels[i].number, i + 1);
      }
    });

    test('builds a contiguous run of slides from the front', () {
      final built = kLevels.map((level) => level.isBuilt).toList();
      expect(
        built.skipWhile((isBuilt) => isBuilt),
        everyElement(isFalse),
        reason:
            'a slide with no fight sits before one with a fight, so the deck '
            'could not be played in order',
      );
    });
  });
}
