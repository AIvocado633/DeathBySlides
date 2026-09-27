import 'dart:async';

import 'package:flame/components.dart';

import 'audio_backend.dart';
import 'cues.dart';

export 'cues.dart';

/// The game's sound, and every rule about it, in one place.
///
/// * Volumes come from Tweaks. At zero a side is off: nothing of it is loaded
///   and nothing plays, so a player who turns the music off never pays for it.
/// * Effects are capped per cue ([Cue.maxVoices]), so they cannot pile up.
/// * Music follows the page on top ([track]), and holds -- pauses, to pick up
///   where it stopped -- while the fight is paused or the app is away.
///
/// Time is the game's own, advanced by [update], so tests step it frame by
/// frame like everything else.
class GameAudio {
  GameAudio([this._backend = const SilentAudioBackend()]);

  /// A service that plays nothing, for components outside a game.
  static final GameAudio silent = GameAudio();

  final AudioBackend _backend;

  double _musicVolume = 0;
  double _effectsVolume = 0;

  double get musicVolume => _musicVolume;
  double get effectsVolume => _effectsVolume;

  double _now = 0;
  final Set<Cue> _loaded = {};

  /// When each cue's sounding voices started, oldest first.
  final Map<Cue, List<double>> _voices = {};

  /// Sets both volumes (0–1) and brings the music into line with them.
  void setVolumes({required double music, required double effects}) {
    _musicVolume = music.clamp(0, 1);
    _effectsVolume = effects.clamp(0, 1);
    _syncMusic();
  }

  /// Loads [cues] ahead of their first play. Does nothing while effects are
  /// off; they are loaded when they are first played after that instead.
  void preload(Iterable<Cue> cues) {
    if (_effectsVolume <= 0) {
      return;
    }
    final fresh = cues.where(_loaded.add).map((cue) => cue.file).toList();
    if (fresh.isNotEmpty) {
      unawaited(_backend.load(fresh));
    }
  }

  /// Plays [cue] once, unless effects are off or it already sounds as often
  /// as it may.
  void play(Cue cue) {
    if (_effectsVolume <= 0) {
      return;
    }
    final voices = _voices.putIfAbsent(cue, () => [])
      ..removeWhere((start) => _now - start >= cue.length);
    if (voices.length >= cue.maxVoices) {
      return;
    }
    voices.add(_now);
    preload([cue]);
    _backend.playEffect(cue.file, _effectsVolume);
  }

  Track? _track;

  /// Why the music is holding, if it is.
  bool _fightPaused = false;
  bool _away = false;

  /// What the backend is actually doing, so it is only told about changes.
  Track? _looping;
  bool _loopPaused = false;
  double _loopVolume = 0;

  /// The music the page on top wants, or null for silence.
  Track? get track => _track;
  set track(Track? track) {
    if (track == _track) {
      return;
    }
    _track = track;
    _syncMusic();
  }

  /// Holds the music while a fight is paused.
  set fightPaused(bool paused) {
    _fightPaused = paused;
    _syncMusic();
  }

  /// Holds the music while the app is in the background.
  set away(bool away) {
    _away = away;
    _syncMusic();
  }

  /// The loop playing now, or null. Held music still counts as playing.
  Track? get playing => _looping;

  /// Whether the loop playing now is held.
  bool get isMusicHeld => _looping != null && _loopPaused;

  void update(double dt) => _now += dt;

  void _syncMusic() {
    final wanted = _musicVolume > 0 ? _track : null;
    if (wanted == null) {
      if (_looping != null) {
        _backend.stopLoop();
        _looping = null;
        _loopPaused = false;
      }
      return;
    }
    if (_looping != wanted) {
      _backend.startLoop(wanted.file, _musicVolume);
      _looping = wanted;
      _loopPaused = false;
      _loopVolume = _musicVolume;
    } else if (_loopVolume != _musicVolume) {
      _backend.setLoopVolume(_musicVolume);
      _loopVolume = _musicVolume;
    }
    final hold = _fightPaused || _away;
    if (hold && !_loopPaused) {
      _backend.pauseLoop();
      _loopPaused = true;
    } else if (!hold && _loopPaused) {
      _backend.resumeLoop();
      _loopPaused = false;
    }
  }
}

/// A game that owns a [GameAudio]. An interface rather than the game class
/// itself, so components can reach the sound without importing the game.
abstract interface class AudioHost {
  GameAudio get audio;
}

/// Gives a component the game's sound. Outside a game -- a component built
/// on its own in a test -- it gets [GameAudio.silent].
mixin HasAudio on Component {
  GameAudio get audio {
    final game = findGame();
    return game is AudioHost ? (game as AudioHost).audio : GameAudio.silent;
  }
}
