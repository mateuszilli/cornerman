import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AudioCue { preFinish, finish, preStart, start, beep, end }

final audioServiceProvider = Provider<AudioService>((ref) {
  final svc = AudioService();
  ref.onDispose(svc.dispose);
  return svc;
});

class AudioService {
  // Separate players so cues can overlap without cancelling each other.
  final Map<AudioCue, AudioPlayer> _players = {};

  double _volume = 1.0;
  bool _muted = false;

  AudioService() {
    for (final cue in AudioCue.values) {
      _players[cue] = AudioPlayer();
    }
    _configureAudioContext(duckAudio: true);
  }

  void setDuckAudio(bool duckAudio) => _configureAudioContext(duckAudio: duckAudio);

  void _configureAudioContext({required bool duckAudio}) {
    AudioPlayer.global.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          // Plays even when the phone is on silent/vibrate.
          category: AVAudioSessionCategory.playback,
          options: {
            AVAudioSessionOptions.mixWithOthers,
            if (duckAudio) AVAudioSessionOptions.duckOthers,
          },
        ),
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm,
          audioFocus: AndroidAudioFocus.gain,
        ),
      ),
    );
  }

  Future<void> preload() async {
    final Map<AudioCue, String> assets = {
      AudioCue.preFinish: 'sounds/clapper.wav',
      AudioCue.finish: 'sounds/bell.wav',
      AudioCue.preStart: 'sounds/clapper.wav',
      AudioCue.start: 'sounds/bell.wav',
      AudioCue.beep: 'sounds/beep.wav',
      AudioCue.end: 'sounds/bell.wav',
    };

    for (final entry in assets.entries) {
      final player = _players[entry.key]!;
      await player.setVolume(_muted ? 0.0 : _volume);
      await player.setReleaseMode(ReleaseMode.stop);
      // Pre-cache by loading the source (audioplayers v6 lazy-loads on play).
      await player.setSource(AssetSource(entry.value));
    }
  }

  void play(AudioCue cue) {
    if (_muted) return;
    final player = _players[cue];
    if (player == null) return;
    player.setVolume(_volume);
    player.resume();
  }

  void stop() {
    for (final p in _players.values) {
      p.stop();
    }
  }

  void setVolume(double v) {
    _volume = v.clamp(0.0, 1.0);
    if (!_muted) {
      for (final p in _players.values) {
        p.setVolume(_volume);
      }
    }
  }

  void setMuted(bool muted) {
    _muted = muted;
    final effectiveVolume = muted ? 0.0 : _volume;
    for (final p in _players.values) {
      p.setVolume(effectiveVolume);
    }
  }

  bool get muted => _muted;
  double get volume => _volume;

  void dispose() {
    for (final p in _players.values) {
      p.dispose();
    }
  }
}
