import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

/// What actually makes noise: the platform, or nothing at all.
///
/// Deliberately dumb. Every decision -- what to load, whether a cue may play,
/// when music pauses -- is made by `GameAudio`, so tests can swap this for a
/// recording fake and still check the game's rules without touching a
/// platform channel.
abstract interface class AudioBackend {
  /// Loads [files] ahead of time, so the first play has no delay.
  Future<void> load(Iterable<String> files);

  /// Plays [file] once at [volume] (0–1).
  void playEffect(String file, double volume);

  /// Starts [file] looping at [volume], replacing any loop already playing.
  void startLoop(String file, double volume);

  void pauseLoop();
  void resumeLoop();
  void stopLoop();
  void setLoopVolume(double volume);
}

/// A backend that plays nothing. What the game uses unless it is given a
/// real one, so tests and tools stay silent by default.
class SilentAudioBackend implements AudioBackend {
  const SilentAudioBackend();

  @override
  Future<void> load(Iterable<String> files) async {}

  @override
  void playEffect(String file, double volume) {}

  @override
  void startLoop(String file, double volume) {}

  @override
  void pauseLoop() {}

  @override
  void resumeLoop() {}

  @override
  void stopLoop() {}

  @override
  void setLoopVolume(double volume) {}
}

/// The platform's audio, through `flame_audio`, from `assets/audio/`.
///
/// Nothing here may take the game down: a sound that fails to load or play
/// costs that sound, and a line in the log.
class FlameAudioBackend implements AudioBackend {
  @override
  Future<void> load(Iterable<String> files) async {
    try {
      await FlameAudio.audioCache.loadAll(files.toList());
    } on Object catch (error) {
      debugPrint('Audio: could not load $files: $error');
    }
  }

  @override
  void playEffect(String file, double volume) {
    _guard('play $file', FlameAudio.play(file, volume: volume));
  }

  @override
  void startLoop(String file, double volume) {
    _guard('loop $file', FlameAudio.bgm.play(file, volume: volume));
  }

  @override
  void pauseLoop() => _guard('pause music', FlameAudio.bgm.pause());

  @override
  void resumeLoop() => _guard('resume music', FlameAudio.bgm.resume());

  @override
  void stopLoop() => _guard('stop music', FlameAudio.bgm.stop());

  @override
  void setLoopVolume(double volume) => _guard(
    'set music volume',
    FlameAudio.bgm.audioPlayer.setVolume(volume),
  );

  static void _guard(String what, Future<Object?> future) {
    unawaited(
      future.then<void>(
        (_) {},
        onError: (Object error) => debugPrint('Audio: could not $what: $error'),
      ),
    );
  }
}
