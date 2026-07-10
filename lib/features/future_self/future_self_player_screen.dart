import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/audio/binaural_beat_controller.dart';
import '../../core/audio/future_self_audio_handler.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/future_self_voices.dart';
import '../../core/widgets/narration_voice_picker.dart';
import '../../models/future_self_setup.dart';
import '../../providers/auth_provider.dart';
import '../../providers/future_self_provider.dart';

/// The audio-first, hands-free phases of a session. Seal is the post-completion
/// payoff, not an audio phase.
enum _FsPhase { arrive, embody, carry, seal }

/// The guided Future Self session for a single scene. Audio-first and
/// eyes-closed: the user arrives with a guided breath, a neural voice narrates
/// the scene while they embody it, then they carry the feeling into their day.
/// Phases auto-advance; no tapping is required to progress.
class FutureSelfPlayerScreen extends ConsumerStatefulWidget {
  final String sceneId;

  const FutureSelfPlayerScreen({super.key, required this.sceneId});

  @override
  ConsumerState<FutureSelfPlayerScreen> createState() =>
      _FutureSelfPlayerScreenState();
}

class _FutureSelfPlayerScreenState
    extends ConsumerState<FutureSelfPlayerScreen> with WidgetsBindingObserver {
  static const _arriveSeconds = 32;
  static const _carrySeconds = 16;
  static const _persistDebounceMs = 400;

  final DateTime _start = DateTime.now();
  late final FutureSelfAudioHandler _handler;

  _FsPhase _phase = _FsPhase.arrive;
  FutureSelfScene? _scene;
  bool _preparing = true;
  bool _beatsEnabled = true;
  int _binauralHz = 7;
  double _beatsVolume = 0.3;
  double _narrationVolume = 1.0;
  String _preferredNarrationVoice = FutureSelfVoices.defaultVoice;
  bool _hasAudio = false;
  bool _regeneratingVoice = false;
  bool _synthesizing = false;
  bool _showText = false;
  bool _carryStarted = false;

  int _arriveRemaining = _arriveSeconds;
  Timer? _arriveTimer;
  Timer? _carryTimer;
  Timer? _fallbackTimer;
  Timer? _persistTimer;
  StreamSubscription<ProcessingState>? _narrationSub;

  int _daysEmbodied = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _handler = ref.read(futureSelfAudioHandlerProvider);
    final setup = ref.read(futureSelfProvider);
    _beatsEnabled = setup?.beatsEnabled ?? true;
    _binauralHz = setup?.binauralHz ?? 7;
    _beatsVolume = setup?.beatsVolume ?? 0.3;
    _narrationVolume = setup?.narrationVolume ?? 1.0;
    _preferredNarrationVoice =
        setup?.resolvedNarrationVoice ?? FutureSelfVoices.defaultVoice;
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Background playback continues via audio_service. If narration finished
    // while the app was backgrounded, advance to carry on resume.
    if (state == AppLifecycleState.resumed &&
        _phase == _FsPhase.embody &&
        _hasAudio &&
        _handler.narration.processingState == ProcessingState.completed) {
      _startCarry();
    }
  }

  Future<void> _enableSessionWakeLock() async {
    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('FutureSelfPlayerScreen wakelock enable failed: $e');
    }
  }

  Future<void> _disableSessionWakeLock() async {
    try {
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint('FutureSelfPlayerScreen wakelock disable failed: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_disableSessionWakeLock());
    _arriveTimer?.cancel();
    _carryTimer?.cancel();
    _fallbackTimer?.cancel();
    _persistTimer?.cancel();
    _narrationSub?.cancel();
    unawaited(_handler.resetForNextSession());
    super.dispose();
  }

  void _schedulePersistAudioPrefs() {
    _persistTimer?.cancel();
    _persistTimer = Timer(
      const Duration(milliseconds: _persistDebounceMs),
      _persistAudioPrefs,
    );
  }

  Future<void> _persistAudioPrefs() async {
    final setup = ref.read(futureSelfProvider);
    if (setup == null) return;
    await ref.read(futureSelfProvider.notifier).saveSetup(
          setup.copyWith(
            beatsEnabled: _beatsEnabled,
            binauralHz: _binauralHz,
            beatsVolume: _beatsVolume,
            narrationVolume: _narrationVolume,
          ),
        );
  }

  Future<void> _loadNarrationFromScene(FutureSelfScene scene) async {
    if (!scene.hasNarration) {
      if (mounted) setState(() => _hasAudio = false);
      return;
    }
    try {
      await _handler.loadSession(
        narrationUrl: Uri.parse(scene.narrationUrl!),
        sceneId: scene.id,
        sceneTitle: scene.displayTitle,
      ).timeout(const Duration(seconds: 30));
      await _handler.setNarrationVolume(_narrationVolume);
      if (mounted) setState(() => _hasAudio = true);
    } catch (e) {
      debugPrint('FutureSelfPlayerScreen narration load failed: $e');
      if (mounted) setState(() => _hasAudio = false);
    }
  }

  Future<void> _refreshSceneAudioIfNeeded() async {
    final notifier = ref.read(futureSelfProvider.notifier);
    final scene = _scene;
    if (scene == null || !notifier.sceneNeedsNarrationRefresh(scene)) return;

    setState(() => _regeneratingVoice = true);
    try {
      final ready = await notifier
          .ensureSceneReady(widget.sceneId)
          .timeout(const Duration(seconds: 90));
      if (!mounted) return;
      if (ready != null) {
        _scene = ready;
        await _loadNarrationFromScene(ready);
      } else if (mounted) {
        setState(() => _hasAudio = false);
      }
    } finally {
      if (mounted) setState(() => _regeneratingVoice = false);
    }
  }

  Future<void> _prepare() async {
    try {
      await _enableSessionWakeLock();
      await _handler.configureSession(
        beatsEnabled: _beatsEnabled,
        binauralHz: _binauralHz,
        beatsVolume: _beatsVolume,
        narrationVolume: _narrationVolume,
      );

      // Start the calming bed immediately while the scene loads.
      if (_beatsEnabled) {
        unawaited(_handler.playBeatsIfEnabled());
      }

      var scene = ref.read(futureSelfProvider)?.scenes.firstWhere(
            (s) => s.id == widget.sceneId,
            orElse: () => throw StateError('scene not found'),
          );

      final notifier = ref.read(futureSelfProvider.notifier);
      final needsSynthesis =
          scene != null && notifier.sceneNeedsNarrationRefresh(scene);
      // Only surface the slower "generating narration" copy when we actually
      // have to call TTS. A cache hit loads instantly and shouldn't imply a
      // wait, so it keeps the lighter "getting ready" state.
      if (needsSynthesis && mounted) {
        setState(() => _synthesizing = true);
      }
      if (needsSynthesis) {
        scene = await notifier
            .ensureSceneReady(widget.sceneId)
            .timeout(const Duration(seconds: 90));
      }

      _scene = scene;
      _hasAudio = scene?.hasNarration ?? false;

      if (_hasAudio && scene != null) {
        await _loadNarrationFromScene(scene);
      }
    } catch (e) {
      // Fall through — text-only practice is still usable.
      debugPrint('FutureSelfPlayerScreen prepare failed: $e');
      _hasAudio = false;
    }
    if (!mounted) return;
    setState(() {
      _preparing = false;
      _synthesizing = false;
    });
    _startArriveCountdown();
  }

  void _startArriveCountdown() {
    _arriveTimer?.cancel();
    _arriveRemaining = _arriveSeconds;
    _arriveTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _arriveRemaining--);
      if (_arriveRemaining <= 0) {
        t.cancel();
        _startEmbody();
      }
    });
  }

  Future<void> _startEmbody() async {
    if (_phase != _FsPhase.arrive) return;
    _arriveTimer?.cancel();
    if (!mounted) return;

    while (_regeneratingVoice) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
    }

    await _refreshSceneAudioIfNeeded();
    if (!mounted) return;

    setState(() => _phase = _FsPhase.embody);

    if (_hasAudio) {
      _narrationSub = _handler.narration.processingStateStream.listen((state) {
        if (state == ProcessingState.completed) _startCarry();
      });
      unawaited(_handler.play());
    } else {
      // Text fallback: pace by the script length, then move on.
      final words = _scene?.script?.split(RegExp(r'\s+')).length ?? 120;
      final seconds = (words / 2.2).clamp(45, 240).round();
      _showText = true;
      _fallbackTimer = Timer(Duration(seconds: seconds), _startCarry);
    }
  }

  Future<void> _startCarry() async {
    if (_carryStarted) return;
    _carryStarted = true;
    _narrationSub?.cancel();
    _fallbackTimer?.cancel();
    if (!mounted) return;
    setState(() => _phase = _FsPhase.carry);
    _carryTimer = Timer(const Duration(seconds: _carrySeconds), _complete);
  }

  Future<void> _complete() async {
    _carryTimer?.cancel();
    await _handler.pause();
    await _disableSessionWakeLock();

    final seconds = DateTime.now().difference(_start).inSeconds;
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    final dates = profile == null
        ? <String>{}
        : profile.futureSelfCompletions
            .where((c) => c.completed)
            .map((c) => c.date)
            .toSet();
    dates.add('today');

    await ref.read(futureSelfProvider.notifier).recordCompletion(seconds);
    if (!mounted) return;
    setState(() {
      _daysEmbodied = dates.length;
      _phase = _FsPhase.seal;
    });
  }

  Future<void> _toggleBeats(bool value) async {
    setState(() => _beatsEnabled = value);
    await _handler.setBeatsEnabled(value);
    _schedulePersistAudioPrefs();
  }

  Future<void> _setBinauralHz(int hz) async {
    if (hz == _binauralHz) return;
    setState(() => _binauralHz = hz);
    await _handler.setFrequency(hz);
    _schedulePersistAudioPrefs();
  }

  Future<void> _setBeatsVolume(double value) async {
    setState(() => _beatsVolume = value);
    await _handler.setBeatsVolume(value);
  }

  void _onBeatsVolumeEnd(double value) {
    _beatsVolume = value;
    _schedulePersistAudioPrefs();
  }

  Future<void> _setNarrationVolume(double value) async {
    setState(() => _narrationVolume = value);
    await _handler.setNarrationVolume(value);
  }

  void _onNarrationVolumeEnd(double value) {
    _narrationVolume = value;
    _schedulePersistAudioPrefs();
  }

  Future<void> _setNarrationVoice(String voiceId) async {
    if (voiceId == _preferredNarrationVoice) return;

    await _handler.stopNarration();
    setState(() {
      _preferredNarrationVoice = voiceId;
      _hasAudio = false;
      _regeneratingVoice = true;
    });

    await ref.read(futureSelfProvider.notifier).updateNarrationVoice(voiceId);
    if (!mounted) return;

    if (_scene?.hasScript ?? false) {
      await _refreshSceneAudioIfNeeded();
    } else if (mounted) {
      setState(() => _regeneratingVoice = false);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(AppStrings.futureSelfNarrationVoiceChangedNote),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.futureSelfSurface,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.futureSelfBackground,
      appBar: AppBar(
        backgroundColor: AppColors.futureSelfBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.futureSelfAccent),
          tooltip: AppStrings.futureSelfEndSession,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _scene?.displayTitle ?? AppStrings.futureSelf,
          style: AppTextStyles.headlineSmall
              .copyWith(color: AppColors.futureSelfAccent),
        ),
        actions: [
          if (_phase == _FsPhase.embody && (_scene?.hasScript ?? false))
            IconButton(
              tooltip: _showText
                  ? AppStrings.futureSelfHideText
                  : AppStrings.futureSelfShowText,
              icon: Icon(
                _showText
                    ? Icons.subtitles_off_rounded
                    : Icons.subtitles_rounded,
                color: AppColors.futureSelfAccent,
              ),
              onPressed: () => setState(() => _showText = !_showText),
            ),
        ],
      ),
      body: SafeArea(
        child: _preparing
            ? _PreparingView(synthesizing: _synthesizing)
            : Column(
                children: [
                  const SizedBox(height: AppSpacing.sm),
                  if (_phase != _FsPhase.seal) _PhaseProgress(phase: _phase),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      child: _buildPhase(),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case _FsPhase.arrive:
        return _ArrivePhase(
          key: const ValueKey('arrive'),
          remaining: _arriveRemaining,
          beatsEnabled: _beatsEnabled,
          binauralHz: _binauralHz,
          beatsVolume: _beatsVolume,
          preferredNarrationVoice: _preferredNarrationVoice,
          regeneratingVoice: _regeneratingVoice,
          onToggleBeats: _toggleBeats,
          onFrequency: _setBinauralHz,
          onBeatsVolume: _setBeatsVolume,
          onBeatsVolumeEnd: _onBeatsVolumeEnd,
          onNarrationVoice: _setNarrationVoice,
          onBeginNow: _regeneratingVoice ? null : _startEmbody,
        );
      case _FsPhase.embody:
        return _EmbodyPhase(
          key: const ValueKey('embody'),
          player: _handler.narration,
          hasAudio: _hasAudio,
          showText: _showText,
          script: _scene?.script ?? '',
          narrationVolume: _narrationVolume,
          onNarrationVolume: _setNarrationVolume,
          onNarrationVolumeEnd: _onNarrationVolumeEnd,
          onTogglePlayback: () async {
            if (_handler.narration.playing) {
              await _handler.pause();
            } else {
              await _handler.play();
            }
          },
        );
      case _FsPhase.carry:
        return _CarryPhase(
          key: const ValueKey('carry'),
          trait: ref.read(embodimentTraitTodayProvider),
          onDone: _complete,
        );
      case _FsPhase.seal:
        return _SealPhase(
          key: const ValueKey('seal'),
          daysEmbodied: _daysEmbodied,
          trait: ref.read(embodimentTraitTodayProvider),
          onTalkToFutureSelf: () {
            Navigator.of(context).pop();
            context.go('/chat', extra: {'initialMode': 'future_self'});
          },
          onDone: () => Navigator.of(context).pop(),
        );
    }
  }
}

// ─── Preparing ────────────────────────────────────────────────────────────────

class _PreparingView extends StatelessWidget {
  /// True when we're waiting on TTS synthesis (slow, first-play) rather than a
  /// fast cache load, so the copy sets the right expectation.
  final bool synthesizing;

  const _PreparingView({required this.synthesizing});

  @override
  Widget build(BuildContext context) {
    final title = synthesizing
        ? AppStrings.futureSelfPreparing
        : AppStrings.futureSelfLoading;
    final note = synthesizing
        ? AppStrings.futureSelfPreparingNote
        : AppStrings.futureSelfLoadingNote;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _BreathingOrb(size: 120),
          const SizedBox(height: AppSpacing.xl),
          Text(title,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          Text(note,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─── Phase progress ───────────────────────────────────────────────────────────

class _PhaseProgress extends StatelessWidget {
  final _FsPhase phase;

  const _PhaseProgress({required this.phase});

  @override
  Widget build(BuildContext context) {
    // Three user-facing steps; seal isn't shown.
    const steps = [_FsPhase.arrive, _FsPhase.embody, _FsPhase.carry];
    final index = steps.indexOf(phase);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(steps.length, (i) {
        final active = i <= index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: i == index ? 22 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active
                ? AppColors.futureSelfAccent
                : AppColors.futureSelfSurface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
        );
      }),
    );
  }
}

// ─── Arrive ─────────────────────────────────────────────────────────────────

class _ArrivePhase extends StatelessWidget {
  final int remaining;
  final bool beatsEnabled;
  final int binauralHz;
  final double beatsVolume;
  final String preferredNarrationVoice;
  final bool regeneratingVoice;
  final ValueChanged<bool> onToggleBeats;
  final ValueChanged<int> onFrequency;
  final ValueChanged<double> onBeatsVolume;
  final ValueChanged<double> onBeatsVolumeEnd;
  final ValueChanged<String> onNarrationVoice;
  final VoidCallback? onBeginNow;

  const _ArrivePhase({
    super.key,
    required this.remaining,
    required this.beatsEnabled,
    required this.binauralHz,
    required this.beatsVolume,
    required this.preferredNarrationVoice,
    required this.regeneratingVoice,
    required this.onToggleBeats,
    required this.onFrequency,
    required this.onBeatsVolume,
    required this.onBeatsVolumeEnd,
    required this.onNarrationVoice,
    required this.onBeginNow,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenPaddingH,
          AppSpacing.xl, AppSpacing.screenPaddingH, AppSpacing.xl),
      child: Column(
        children: [
          const _BreathingOrb(),
          const SizedBox(height: AppSpacing.xl),
          Text(AppStrings.futureSelfPhaseArriveTitle,
              style: AppTextStyles.headlineMedium
                  .copyWith(color: AppColors.futureSelfAccent),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(AppStrings.futureSelfPhaseArriveBody,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary, height: 1.6),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          Text(
            AppStrings.futureSelfEyesClosedHint,
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textMuted, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          _AudioSettingsPanel(
            enabled: beatsEnabled,
            binauralHz: binauralHz,
            beatsVolume: beatsVolume,
            onToggle: onToggleBeats,
            onFrequency: onFrequency,
            onBeatsVolume: onBeatsVolume,
            onBeatsVolumeEnd: onBeatsVolumeEnd,
          ),
          const SizedBox(height: AppSpacing.lg),
          NarrationVoicePicker(
            selectedVoiceId: preferredNarrationVoice,
            onSelected: onNarrationVoice,
          ),
          if (regeneratingVoice) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppStrings.futureSelfPreparingNote,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.futureSelfAccent,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          TextButton(
            onPressed: onBeginNow,
            child: Text(
              '${AppStrings.futureSelfBeginNow}  ·  ${remaining}s',
              style: AppTextStyles.button.copyWith(
                color: onBeginNow == null
                    ? AppColors.textMuted
                    : AppColors.futureSelfAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Embody ─────────────────────────────────────────────────────────────────

class _EmbodyPhase extends StatelessWidget {
  final AudioPlayer player;
  final bool hasAudio;
  final bool showText;
  final String script;
  final double narrationVolume;
  final ValueChanged<double> onNarrationVolume;
  final ValueChanged<double> onNarrationVolumeEnd;
  final Future<void> Function() onTogglePlayback;

  const _EmbodyPhase({
    super.key,
    required this.player,
    required this.hasAudio,
    required this.showText,
    required this.script,
    required this.narrationVolume,
    required this.onNarrationVolume,
    required this.onNarrationVolumeEnd,
    required this.onTogglePlayback,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenPaddingH,
          AppSpacing.lg, AppSpacing.screenPaddingH, AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showText)
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  script,
                  style: AppTextStyles.bodyLarge
                      .copyWith(height: 1.9, color: AppColors.textPrimary),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else ...[
            const Spacer(),
            _ProgressOrb(player: player, hasAudio: hasAudio),
            const SizedBox(height: AppSpacing.xl),
            Text(AppStrings.futureSelfPhaseEmbodyTitle,
                style: AppTextStyles.headlineMedium
                    .copyWith(color: AppColors.futureSelfAccent),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(AppStrings.futureSelfPhaseEmbodyBody,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary, height: 1.6),
                textAlign: TextAlign.center),
            const Spacer(),
          ],
          if (hasAudio)
            _NarrationControls(
              player: player,
              volume: narrationVolume,
              onVolume: onNarrationVolume,
              onVolumeEnd: onNarrationVolumeEnd,
              onTogglePlayback: onTogglePlayback,
            ),
        ],
      ),
    );
  }
}

/// Breathing orb wrapped in a progress ring driven by narration position.
class _ProgressOrb extends StatelessWidget {
  final AudioPlayer player;
  final bool hasAudio;

  const _ProgressOrb({required this.player, required this.hasAudio});

  @override
  Widget build(BuildContext context) {
    if (!hasAudio) return const _BreathingOrb(size: 150);
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        final total = player.duration ?? Duration.zero;
        final progress = total.inMilliseconds == 0
            ? 0.0
            : (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
        return SizedBox(
          width: 168,
          height: 168,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 168,
                height: 168,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  backgroundColor: AppColors.futureSelfSurface,
                  valueColor: const AlwaysStoppedAnimation(
                      AppColors.futureSelfAccent),
                ),
              ),
              const _BreathingOrb(size: 130),
            ],
          ),
        );
      },
    );
  }
}

class _NarrationControls extends StatelessWidget {
  final AudioPlayer player;
  final double volume;
  final ValueChanged<double> onVolume;
  final ValueChanged<double> onVolumeEnd;
  final Future<void> Function() onTogglePlayback;

  const _NarrationControls({
    required this.player,
    required this.volume,
    required this.onVolume,
    required this.onVolumeEnd,
    required this.onTogglePlayback,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        StreamBuilder<PlayerState>(
          stream: player.playerStateStream,
          builder: (context, snap) {
            final playing = snap.data?.playing ?? true;
            return IconButton(
              iconSize: 44,
              icon: Icon(
                playing
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_fill_rounded,
                color: AppColors.futureSelfAccent,
              ),
              onPressed: () => unawaited(onTogglePlayback()),
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppStrings.futureSelfNarrationVolumeLabel,
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textSecondary)),
              Slider(
                value: volume,
                min: 0,
                max: 1,
                divisions: 20,
                activeColor: AppColors.futureSelfAccent,
                inactiveColor: AppColors.border,
                onChanged: onVolume,
                onChangeEnd: onVolumeEnd,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Carry ────────────────────────────────────────────────────────────────────

class _CarryPhase extends StatelessWidget {
  final String? trait;
  final VoidCallback onDone;

  const _CarryPhase({super.key, required this.trait, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _BreathingOrb(size: 120),
          const SizedBox(height: AppSpacing.xl),
          Text(AppStrings.futureSelfPhaseCarryTitle,
              style: AppTextStyles.headlineMedium
                  .copyWith(color: AppColors.futureSelfAccent),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(AppStrings.futureSelfPhaseCarryBody,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary, height: 1.6),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xl),
          TextButton(
            onPressed: onDone,
            child: Text(AppStrings.futureSelfSealDone,
                style: AppTextStyles.button
                    .copyWith(color: AppColors.futureSelfAccent)),
          ),
        ],
      ),
    );
  }
}

// ─── Seal (payoff) ─────────────────────────────────────────────────────────────

class _SealPhase extends StatelessWidget {
  final int daysEmbodied;
  final String? trait;
  final VoidCallback onTalkToFutureSelf;
  final VoidCallback onDone;

  const _SealPhase({
    super.key,
    required this.daysEmbodied,
    required this.trait,
    required this.onTalkToFutureSelf,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenPaddingH,
          AppSpacing.xl, AppSpacing.screenPaddingH, AppSpacing.xl),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                  colors: [AppColors.futureSelfAccent, AppColors.warning]),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: AppColors.futureSelfGlow,
                    blurRadius: 32,
                    spreadRadius: 6),
              ],
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
          ).animate().scale(
              duration: 500.ms, curve: Curves.elasticOut, begin: const Offset(0.6, 0.6)),
          const SizedBox(height: AppSpacing.lg),
          Text(AppStrings.futureSelfSealHeadline,
              style: AppTextStyles.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          Text(AppStrings.futureSelfSealDaysEmbodied(daysEmbodied),
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.futureSelfAccent),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.futureSelfSurface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(
                  color: AppColors.futureSelfAccent.withValues(alpha: 0.2)),
            ),
            child: Text(
              trait != null && trait!.isNotEmpty
                  ? AppStrings.futureSelfSealCarryTrait(trait!)
                  : AppStrings.futureSelfSealCarryGeneric,
              style: AppTextStyles.bodyLarge
                  .copyWith(color: AppColors.textPrimary, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          _SealButton(
            icon: Icons.forum_rounded,
            label: AppStrings.futureSelfSealTalkToFutureSelf,
            filled: true,
            onTap: onTalkToFutureSelf,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: onDone,
            child: Text(AppStrings.futureSelfSealDone,
                style: AppTextStyles.button
                    .copyWith(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _SealButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _SealButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.buttonHeight,
      child: filled
          ? ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: AppSpacing.iconMd),
              label: Text(label,
                  style: AppTextStyles.button.copyWith(color: Colors.black)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.futureSelfAccent,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: AppSpacing.iconMd),
              label: Text(label, style: AppTextStyles.button),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
            ),
    );
  }
}

// ─── Breathing orb ────────────────────────────────────────────────────────────

class _BreathingOrb extends StatelessWidget {
  final double size;

  const _BreathingOrb({this.size = 150});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [AppColors.futureSelfAccent, AppColors.futureSelfSurface],
        ),
        boxShadow: [
          BoxShadow(
              color: AppColors.futureSelfGlow, blurRadius: 40, spreadRadius: 8),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(
            begin: 0.82,
            end: 1.06,
            duration: 3600.ms,
            curve: Curves.easeInOut)
        .fadeIn(begin: 0.6, duration: 3600.ms, curve: Curves.easeInOut);
  }
}

// ─── Audio settings (Arrive) ──────────────────────────────────────────────────

class _AudioSettingsPanel extends StatelessWidget {
  final bool enabled;
  final int binauralHz;
  final double beatsVolume;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onFrequency;
  final ValueChanged<double> onBeatsVolume;
  final ValueChanged<double> onBeatsVolumeEnd;

  const _AudioSettingsPanel({
    required this.enabled,
    required this.binauralHz,
    required this.beatsVolume,
    required this.onToggle,
    required this.onFrequency,
    required this.onBeatsVolume,
    required this.onBeatsVolumeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.futureSelfSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border:
            Border.all(color: AppColors.futureSelfAccent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                enabled ? Icons.graphic_eq_rounded : Icons.volume_off_rounded,
                color: AppColors.futureSelfAccent,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppStrings.futureSelfBeatsToggleTitle,
                        style: AppTextStyles.labelLarge
                            .copyWith(color: AppColors.futureSelfAccent)),
                    Text(AppStrings.futureSelfBeatsToggleSubtitle,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                activeThumbColor: AppColors.futureSelfAccent,
                onChanged: onToggle,
              ),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(AppStrings.binauralFrequency,
                style: AppTextStyles.labelLarge
                    .copyWith(color: AppColors.futureSelfAccent)),
            const SizedBox(height: AppSpacing.xs),
            Text(AppStrings.futureSelfHeadphonesHint,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: BinauralBeatController.bands
                  .map((band) => _FrequencyChip(
                        label: band.name,
                        description: band.description,
                        selected: band.hz == binauralHz,
                        onTap: () => onFrequency(band.hz),
                      ))
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(AppStrings.futureSelfBeatsVolumeLabel,
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textSecondary)),
            Slider(
              value: beatsVolume,
              min: 0,
              max: 1,
              divisions: 20,
              activeColor: AppColors.futureSelfAccent,
              inactiveColor: AppColors.border,
              onChanged: onBeatsVolume,
              onChangeEnd: onBeatsVolumeEnd,
            ),
          ],
        ],
      ),
    );
  }
}

class _FrequencyChip extends StatelessWidget {
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _FrequencyChip({
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.futureSelfAccent.withValues(alpha: 0.15)
              : AppColors.futureSelfBackground,
          border: Border.all(
            color: selected ? AppColors.futureSelfAccent : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: selected
                      ? AppColors.futureSelfAccent
                      : AppColors.textSecondary,
                )),
            Text(description,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                )),
          ],
        ),
      ),
    );
  }
}
