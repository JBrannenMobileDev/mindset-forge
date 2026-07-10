import 'dart:async';
import 'dart:io' show Platform;

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../constants/app_strings.dart';
import 'binaural_beat_controller.dart';

/// Singleton handler set during app startup via [initFutureSelfAudio].
FutureSelfAudioHandler? futureSelfAudioHandler;

final futureSelfAudioHandlerProvider = Provider<FutureSelfAudioHandler>((ref) {
  final handler = futureSelfAudioHandler;
  if (handler == null) {
    throw StateError('FutureSelf audio handler is not initialized');
  }
  return handler;
});

/// Initializes the Future Self audio handler once before any session starts.
///
/// On iOS/Android this registers with [AudioService] for background playback
/// and lock-screen controls. On web/desktop a plain handler is used instead.
Future<void> initFutureSelfAudio() async {
  if (futureSelfAudioHandler != null) return;

  if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
    futureSelfAudioHandler = await AudioService.init(
      builder: () => FutureSelfAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.mindsetforge.audio',
        androidNotificationChannelName: 'Future Self Practice',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  } else {
    futureSelfAudioHandler = FutureSelfAudioHandler();
  }
}

/// Coordinates narration and binaural beats for Future Self practice.
///
/// Publishes a single [MediaItem] and [PlaybackState] so lock-screen and
/// Control Center controls route to both players together, while in-app sliders
/// still adjust each channel independently.
class FutureSelfAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer narration = AudioPlayer(handleInterruptions: false);
  final BinauralBeatController beats = BinauralBeatController();

  bool _beatsEnabled = true;
  bool _pausedByInterruption = false;
  bool _intendedPlaying = false;
  bool _userPaused = false;
  DateTime? _suppressOppositeTransportUntil;
  String? _transportInFlight;
  bool _sessionConfigured = false;

  FutureSelfAudioHandler() {
    narration.playbackEventStream.listen((event) {
      playbackState.add(_transformEvent(event));
    });
    // Desired-state reconciliation: if any player starts while intent is
    // paused (duplicate OS command, plugin callback, race), pause it again.
    narration.playingStream.listen((playing) {
      if (playing && !_intendedPlaying) {
        debugPrint(
          '[FutureSelfAudio] WATCHDOG narration playing against intent, pausing',
        );
        unawaited(_safely('watchdog.narration.pause', narration.pause));
        return;
      }
      if (playing && _intendedPlaying && _beatsEnabled && !beats.isPlaying) {
        debugPrint(
          '[FutureSelfAudio] SYNC beats behind narration, restarting',
        );
        unawaited(_syncBeatsIfNeeded('narration.playing'));
      }
    });
    beats.playingStream.listen((playing) {
      if (playing && (!_intendedPlaying || !_beatsEnabled)) {
        debugPrint(
          '[FutureSelfAudio] WATCHDOG beats playing against intent, pausing',
        );
        unawaited(_safely('watchdog.beats.pause', beats.pause));
      }
    });
    _listenForInterruptions();
  }

  /// Applies persisted session prefs before loading or playing audio.
  Future<void> configureSession({
    required bool beatsEnabled,
    required int binauralHz,
    required double beatsVolume,
    required double narrationVolume,
  }) async {
    _beatsEnabled = beatsEnabled;
    await beats.setFrequency(binauralHz);
    await beats.setVolume(beatsVolume);
    await narration.setVolume(narrationVolume.clamp(0.0, 1.0));
  }

  /// Loads the scene narration MP3 and publishes lock-screen metadata.
  Future<void> loadSession({
    required Uri narrationUrl,
    required String sceneId,
    required String sceneTitle,
  }) async {
    await narration.setAudioSource(LockCachingAudioSource(narrationUrl));
    mediaItem.add(MediaItem(
      id: 'future_self_narration_$sceneId',
      album: AppStrings.futureSelf,
      title: sceneTitle,
      artist: 'MindsetForge',
      displaySubtitle: AppStrings.futureSelfPhaseEmbodyTitle,
    ));
  }

  /// Starts only the binaural bed (arrive phase, before narration begins).
  Future<void> playBeatsIfEnabled() async {
    if (_beatsEnabled) {
      _intendedPlaying = true;
      _userPaused = false;
      await _ensureAudioSessionReady();
      await _safely('playBeatsIfEnabled.beats', beats.play);
      _republishPlaybackState();
    }
  }

  @override
  Future<void> play() async {
    if (_isOppositeTransportSuppressed('play')) {
      debugPrint('[FutureSelfAudio] play() suppressed (pause in flight)');
      return;
    }
    debugPrint('[FutureSelfAudio] play() command');
    _beginTransportWindow('play');
    _intendedPlaying = true;
    _userPaused = false;
    _pausedByInterruption = false;
    await _ensureAudioSessionReady();
    if (narration.audioSource != null) {
      await _safely('play.narration', narration.play);
    }
    if (_beatsEnabled) await _safely('play.beats', beats.play);
    await _reconcileChannels('play');
    _republishPlaybackState();
    unawaited(_staggeredReconcile());
  }

  @override
  Future<void> pause() async {
    if (_isOppositeTransportSuppressed('pause')) {
      debugPrint('[FutureSelfAudio] pause() suppressed (play in flight)');
      return;
    }
    debugPrint('[FutureSelfAudio] pause() command');
    _beginTransportWindow('pause');
    _intendedPlaying = false;
    _userPaused = true;
    await _safely('pause.narration', narration.pause);
    await _safely('pause.beats', beats.pause);
    _republishPlaybackState();
  }

  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    if (button != MediaButton.media) return super.click(button);
    // iOS lock screen fires play/pause AND togglePlayPause for one tap.
    // Direct play()/pause() handlers are authoritative; toggle is ignored.
    debugPrint('[FutureSelfAudio] click() ignored (direct play/pause only)');
  }

  @override
  Future<void> seek(Duration position) => narration.seek(position);

  @override
  Future<void> stop() async {
    debugPrint('[FutureSelfAudio] handler.stop() invoked');
    _pausedByInterruption = false;
    _intendedPlaying = false;
    _userPaused = false;
    _suppressOppositeTransportUntil = null;
    _transportInFlight = null;
    await _safely('stop.narration', narration.stop);
    await _safely('stop.beats', beats.pause);
    mediaItem.add(null);
    _broadcastIdle();
  }

  /// Stops narration only (e.g. mid-session voice change) without pausing beats.
  Future<void> stopNarration() async {
    await narration.stop();
    _republishPlaybackState();
  }

  Future<void> setBeatsEnabled(bool enabled) async {
    _beatsEnabled = enabled;
    if (enabled) {
      _intendedPlaying = true;
      await _ensureAudioSessionReady();
      await _safely('setBeatsEnabled.play', beats.play);
    } else {
      // Beats off is a channel mute, not a transport pause; narration may
      // legitimately continue. Only beats gets paused here.
      if (!narration.playing) _intendedPlaying = false;
      await _safely('setBeatsEnabled.pause', beats.pause);
    }
    _republishPlaybackState();
  }

  Future<void> setFrequency(int hz) => beats.setFrequency(hz);

  Future<void> setBeatsVolume(double volume) => beats.setVolume(volume);

  Future<void> setNarrationVolume(double volume) =>
      narration.setVolume(volume.clamp(0.0, 1.0));

  /// Clears session state when the player screen closes. Does not dispose players
  /// because this handler is a process-wide singleton.
  Future<void> resetForNextSession() async {
    debugPrint('[FutureSelfAudio] resetForNextSession() invoked');
    _pausedByInterruption = false;
    _intendedPlaying = false;
    _userPaused = false;
    _suppressOppositeTransportUntil = null;
    _transportInFlight = null;
    await _safely('resetForNextSession.beats.pause', beats.pause);
    await _safely('resetForNextSession.narration.stop', narration.stop);
    mediaItem.add(null);
    _broadcastIdle();
  }

  /// Central interruption handling so both players pause/resume together.
  void _listenForInterruptions() {
    if (kIsWeb) return;

    unawaited(AudioSession.instance.then((session) {
      session.becomingNoisyEventStream.listen((_) {
        _handleInterruptionPause('becomingNoisy');
      });
      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              _handleInterruptionPause('interruption.begin');
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              break;
            case AudioInterruptionType.pause:
              if (_pausedByInterruption && !_userPaused) {
                debugPrint('[FutureSelfAudio] resuming after interruption');
                unawaited(play());
              }
              _pausedByInterruption = false;
              break;
            case AudioInterruptionType.unknown:
              _pausedByInterruption = false;
              break;
          }
        }
      });
    }));
  }

  void _handleInterruptionPause(String reason) {
    final until = _suppressOppositeTransportUntil;
    if (until != null && DateTime.now().isBefore(until)) {
      debugPrint(
        '[FutureSelfAudio] interruption suppressed during transport ($reason)',
      );
      return;
    }
    if (!_intendedPlaying) return;
    debugPrint('[FutureSelfAudio] pausing for $reason');
    _pausedByInterruption = true;
    _intendedPlaying = false;
    _republishPlaybackState();
    unawaited(_safely('interrupt.narration', narration.pause));
    unawaited(_safely('interrupt.beats', beats.pause));
  }

  /// Pushes the current combined play state to lock-screen / notification UI.
  void _republishPlaybackState() {
    playbackState.add(_transformEvent(narration.playbackEvent));
  }

  /// Restarts any channel that should be playing per intent but fell behind.
  Future<void> _reconcileChannels(String reason) async {
    if (!_intendedPlaying) return;
    await _ensureAudioSessionReady();
    if (_beatsEnabled && !beats.isPlaying) {
      debugPrint('[FutureSelfAudio] reconcile($reason): restarting beats');
      await _safely('reconcile.beats', beats.play);
    }
    if (narration.audioSource != null && !narration.playing) {
      debugPrint('[FutureSelfAudio] reconcile($reason): restarting narration');
      await _safely('reconcile.narration', narration.play);
    }
    if (_beatsEnabled) {
      debugPrint(
        '[FutureSelfAudio] reconcile($reason) done: '
        'narration=${narration.playing} beats=${beats.isPlaying}',
      );
    }
  }

  /// Catches beats that start slowly after narration session activation.
  Future<void> _staggeredReconcile() async {
    for (final delayMs in [100, 300, 600]) {
      await Future.delayed(Duration(milliseconds: delayMs));
      if (!_intendedPlaying) return;
      await _reconcileChannels('staggered+$delayMs');
      _republishPlaybackState();
    }
  }

  void _beginTransportWindow(String direction) {
    _transportInFlight = direction;
    _suppressOppositeTransportUntil =
        DateTime.now().add(const Duration(milliseconds: 800));
  }

  bool _isOppositeTransportSuppressed(String command) {
    final until = _suppressOppositeTransportUntil;
    final inFlight = _transportInFlight;
    if (until == null ||
        inFlight == null ||
        !DateTime.now().isBefore(until)) {
      return false;
    }
    return command != inFlight;
  }

  Future<void> _ensureAudioSessionReady() async {
    if (kIsWeb) return;
    final session = await AudioSession.instance;
    if (!_sessionConfigured) {
      await session.configure(const AudioSessionConfiguration.music());
      _sessionConfigured = true;
    }
    await session.setActive(true);
  }

  Future<void> _syncBeatsIfNeeded(String reason) async {
    if (!_intendedPlaying || !_beatsEnabled || beats.isPlaying) return;
    await Future.delayed(const Duration(milliseconds: 50));
    if (!_intendedPlaying || !_beatsEnabled || beats.isPlaying) return;
    debugPrint('[FutureSelfAudio] sync($reason): restarting beats');
    await _ensureAudioSessionReady();
    await _safely('sync.beats', beats.play);
  }

  /// Runs a player action in isolation so one player's failure never blocks another.
  Future<void> _safely(String label, Future<void> Function() action) async {
    try {
      await action();
    } catch (e, st) {
      debugPrint('[FutureSelfAudio] $label failed: $e\n$st');
    }
  }

  void _broadcastIdle() {
    playbackState.add(playbackState.value.copyWith(
      controls: [MediaControl.play],
      processingState: AudioProcessingState.idle,
      playing: false,
      updatePosition: Duration.zero,
    ));
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        if (_intendedPlaying) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.play,
        MediaAction.pause,
        MediaAction.stop,
      },
      androidCompactActionIndices: const [0, 1],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[narration.processingState]!,
      playing: _intendedPlaying,
      updatePosition: narration.position,
      bufferedPosition: narration.bufferedPosition,
      speed: narration.speed,
      queueIndex: event.currentIndex,
    );
  }
}
