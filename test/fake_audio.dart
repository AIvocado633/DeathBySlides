import 'package:death_by_slides/game/audio/audio_backend.dart';
import 'package:death_by_slides/game/audio/cues.dart';

/// An [AudioBackend] that plays nothing and remembers everything it was asked
/// to do, so tests can check the game's sound without a platform channel.
class RecordingAudioBackend implements AudioBackend {
  /// Every file loaded ahead of time, in order.
  final List<String> loaded = [];

  /// Every effect played, in order, with the volume it was played at.
  final List<({String file, double volume})> effects = [];

  /// Every music call, as short strings: `start menu_loop.wav`, `pause`, ...
  final List<String> music = [];

  /// How many times [cue] has been played.
  int played(Cue cue) => effects.where((e) => e.file == cue.file).length;

  /// The loop last started, or null once it has been stopped.
  String? get looping => _looping;
  String? _looping;

  /// Whether the loop is paused.
  bool get isPaused => _paused;
  bool _paused = false;

  /// Forgets what has happened so far, so a test can look at what follows.
  void clear() {
    loaded.clear();
    effects.clear();
    music.clear();
  }

  @override
  Future<void> load(Iterable<String> files) async => loaded.addAll(files);

  @override
  void playEffect(String file, double volume) =>
      effects.add((file: file, volume: volume));

  @override
  void startLoop(String file, double volume) {
    music.add('start $file');
    _looping = file;
    _paused = false;
  }

  @override
  void pauseLoop() {
    music.add('pause');
    _paused = true;
  }

  @override
  void resumeLoop() {
    music.add('resume');
    _paused = false;
  }

  @override
  void stopLoop() {
    music.add('stop');
    _looping = null;
    _paused = false;
  }

  @override
  void setLoopVolume(double volume) => music.add('volume $volume');
}
