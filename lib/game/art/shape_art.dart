import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'actor_art.dart';

/// Loader for artwork that was drawn in PowerPoint and exported to PNG.
///
/// The whole art pipeline for this game is: build the character out of
/// PowerPoint shapes, one pose per slide, then File > Export > PNG. That
/// produces a numbered sequence which this class turns into a Flame
/// [SpriteAnimation]. See `docs/art-pipeline.md`.
///
/// Loaders return `null` rather than throwing when the art has not been
/// exported yet, so the game stays runnable while the deck is still being drawn
/// and callers can fall back to a placeholder. Availability is resolved against
/// the asset manifest instead of by catching load failures, because a failed
/// `Images.load` leaves a rejected future behind in Flame's cache.
abstract final class ShapeArt {
  static const String _imageFolder = 'assets/images/';

  static Set<String>? _manifestEntries;
  static Future<Set<String>>? _manifestLoad;

  static final Map<String, Future<ActorFrames>> _actors = {};

  /// Every state and direction exported for [actor] -- `hero`,
  /// `shrink_to_fit`, ... -- loaded once and then shared by every copy of the
  /// actor, so changing state never reads the manifest again.
  static Future<ActorFrames> loadActor(String actor) =>
      _actors[actor] ??= _loadActor(actor);

  static Future<ActorFrames> _loadActor(String actor) async {
    final frames = <String, List<Sprite>>{};
    for (final prefix in ActorFrames.candidatePrefixes(actor)) {
      final sprites = await _loadSprites(prefix);
      if (sprites.isNotEmpty) {
        frames[prefix] = sprites;
      }
    }
    final loaded = ActorFrames(actor, frames);
    if (!loaded.hasArtwork) {
      debugPrint(
        'ShapeArt: no frames named "${actor}_idle_000.png" in $_imageFolder '
        '- falling back to placeholder art.',
      );
    }
    return loaded;
  }

  /// Loads `<prefix>000.png`, `<prefix>001.png`, ... until a frame is missing.
  static Future<List<Sprite>> _loadSprites(
    String prefix, {
    int maxFrames = 64,
  }) async {
    final sprites = <Sprite>[];
    for (var i = 0; i < maxFrames; i++) {
      final sprite = await loadSprite(
        '$prefix${i.toString().padLeft(3, '0')}.png',
      );
      if (sprite == null) {
        break;
      }
      sprites.add(sprite);
    }
    return sprites;
  }

  /// Loads `<prefix>000.png`, `<prefix>001.png`, ... until a frame is missing.
  ///
  /// [prefix] is relative to `assets/images/`.
  static Future<SpriteAnimation?> loadAnimation(
    String prefix, {
    double stepTime = 0.12,
    bool loop = true,
    int maxFrames = 64,
  }) async {
    final sprites = await _loadSprites(prefix, maxFrames: maxFrames);
    if (sprites.isEmpty) {
      debugPrint(
        'ShapeArt: no frames named "${prefix}000.png" in $_imageFolder '
        '- falling back to placeholder art.',
      );
      return null;
    }
    return SpriteAnimation.spriteList(sprites, stepTime: stepTime, loop: loop);
  }

  /// Loads a single exported still, or `null` if it is not bundled.
  static Future<Sprite?> loadSprite(String fileName) async {
    if (!await isBundled(fileName)) {
      return null;
    }
    return Sprite(await Flame.images.load(fileName));
  }

  /// Whether `assets/images/<fileName>` is part of the built asset bundle.
  static Future<bool> isBundled(String fileName) async {
    final entries = await _manifest();
    return entries.contains('$_imageFolder$fileName');
  }

  /// Forgets the cached manifest and every actor loaded from it. Only needed
  /// if assets change at runtime.
  @visibleForTesting
  static void resetManifestCache() {
    _manifestEntries = null;
    _manifestLoad = null;
    _actors.clear();
  }

  /// Pretends the bundle holds exactly [assets] (full paths, e.g.
  /// `assets/images/hero_idle_000.png`), so tests can check which art is
  /// chosen without shipping any. The images themselves must be put into
  /// `Flame.images` by the test.
  @visibleForTesting
  static void debugUseManifest(Set<String> assets) {
    resetManifestCache();
    _manifestEntries = assets;
  }

  /// How many times the real manifest has been read, for tests that check it
  /// is read once.
  @visibleForTesting
  static int get debugManifestReads => _manifestReads;
  static int _manifestReads = 0;

  static Future<Set<String>> _manifest() {
    final cached = _manifestEntries;
    if (cached != null) {
      return Future.value(cached);
    }
    return _manifestLoad ??= _loadManifest();
  }

  static Future<Set<String>> _loadManifest() async {
    _manifestReads++;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      return _manifestEntries = manifest.listAssets().toSet();
    } on Object {
      // No bundle at all: unit tests without a Flutter binding, mostly.
      return _manifestEntries = const <String>{};
    }
  }
}
