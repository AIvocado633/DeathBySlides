import 'dart:io';

import 'package:death_by_slides/game/art/actor_art.dart';
import 'package:death_by_slides/game/art/shape_art.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the exported artwork against the decks it came from and the code
/// that shows it.
///
/// Every other test runs without Flutter's test binding, so the asset bundle
/// looks empty there and actors draw their stand-in. This file sets the
/// binding up, so it sees the bundle the app ships.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Every actor the game draws, and the states it plays (see
  /// docs/art-pipeline.md).
  const cast = {
    'hero': [ActorState.idle, ActorState.walk, ActorState.hit, ActorState.die, ActorState.cheer],
    'shrink_to_fit': [ActorState.idle, ActorState.hit, ActorState.die],
    'diagram_wizard': [ActorState.idle, ActorState.hit, ActorState.die],
    'master_template': [ActorState.idle, ActorState.hit, ActorState.die],
    'snap_to_grid': [ActorState.idle, ActorState.hit, ActorState.die],
  };

  final framePattern = RegExp(r'^assets/images/(.+_)(\d{3})\.png$');

  late Set<String> bundled;

  setUpAll(() async {
    ShapeArt.resetManifestCache();
    bundled = (await AssetManifest.loadFromAssetBundle(rootBundle))
        .listAssets()
        .where((asset) => asset.startsWith('assets/images/'))
        .toSet();
  });

  tearDownAll(ShapeArt.resetManifestCache);

  /// Frame numbers bundled for each prefix.
  Map<String, List<int>> sequences() {
    final found = <String, List<int>>{};
    for (final asset in bundled) {
      final match = framePattern.firstMatch(asset);
      if (match != null) {
        found.putIfAbsent(match[1]!, () => []).add(int.parse(match[2]!));
      }
    }
    return found;
  }

  test('no actor falls back to the stand-in', () async {
    for (final actor in cast.keys) {
      final frames = await ShapeArt.loadActor(actor);
      expect(frames.hasArtwork, isTrue, reason: '$actor has no idle frames');
    }
  });

  test('every state an actor plays has frames of its own', () {
    final found = sequences();
    for (final MapEntry(key: actor, value: states) in cast.entries) {
      for (final state in states) {
        final prefix = ActorFrames.prefixFor(actor, state);
        expect(found, contains(prefix), reason: '$prefix has no frames');
      }
    }
  });

  test('every sequence runs 000, 001, ... with no gaps', () {
    for (final MapEntry(key: prefix, value: numbers) in sequences().entries) {
      expect(
        numbers..sort(),
        List.generate(numbers.length, (i) => i),
        reason: 'the loader stops at the first missing frame of $prefix',
      );
    }
  });

  test('every frame is a 512 x 512 RGBA PNG', () async {
    for (final asset in bundled.where((a) => framePattern.hasMatch(a))) {
      final bytes = (await rootBundle.load(asset)).buffer.asUint8List();
      final header = ByteData.sublistView(bytes, 16, 26);
      expect(
        (header.getUint32(0), header.getUint32(4)),
        (512, 512),
        reason: asset,
      );
      expect(header.getUint8(9), 6, reason: '$asset has no alpha channel');
    }
  });

  test('every sequence comes from a deck in art/, and every deck exports', () {
    final decks = Directory('art')
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .where((name) => name.endsWith('.pptx') && name != 'launcher_icon.pptx')
        .map((name) => '${name.substring(0, name.length - 5)}_')
        .toSet();
    expect(sequences().keys.toSet(), decks);
  });
}
