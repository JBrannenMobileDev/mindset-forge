import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:uuid/uuid.dart';
import '../../core/audio/binaural_beat_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/evidence_entry.dart';
import '../../models/future_self_setup.dart';
import '../../providers/auth_provider.dart';
import '../../providers/daily_completion_provider.dart';
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
    extends ConsumerState<FutureSelfPlayerScreen> {
  static const _bedVolume = 0.3;
  static const _bedDuckedVolume = 0.06;
  static const _arriveSeconds = 32;
  static const _carrySeconds = 16;

  late final BinauralBeatController _beats;
  final AudioPlayer _narration = AudioPlayer();
  final DateTime _start = DateTime.now();

  _FsPhase _phase = _FsPhase.arrive;
  FutureSelfScene? _scene;
  bool _preparing = true;
  bool _beatsEnabled = true;
  bool _hasAudio = false;
  bool _showText = false;
  bool _carryStarted = false;

  int _arriveRemaining = _arriveSeconds;
  Timer? _arriveTimer;
  Timer? _carryTimer;
  Timer? _fallbackTimer;
  StreamSubscription<ProcessingState>? _narrationSub;

  int _daysEmbodied = 1;

  @override
  void initState() {
    super.initState();
    final setup = ref.read(futureSelfProvider);
    _beatsEnabled = setup?.beatsEnabled ?? true;
    _beats = BinauralBeatController(hz: setup?.binauralHz ?? 7, volume: _bedVolume);
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  @override
  void dispose() {
    _arriveTimer?.cancel();
    _carryTimer?.cancel();
    _fallbackTimer?.cancel();
    _narrationSub?.cancel();
    _narration.dispose();
    _beats.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    try {
      // Start the calming bed immediately while the scene loads.
      if (_beatsEnabled) {
        unawaited(_beats.play());
      }

      var scene = ref.read(futureSelfProvider)?.scenes.firstWhere(
            (s) => s.id == widget.sceneId,
            orElse: () => throw StateError('scene not found'),
          );

      // Lazily generate the script/narration if this scene was saved without it.
      if (scene != null && (!scene.hasScript || !scene.hasNarration)) {
        scene = await ref
            .read(futureSelfProvider.notifier)
            .ensureSceneReady(widget.sceneId)
            .timeout(const Duration(seconds: 90));
      }

      _scene = scene;
      _hasAudio = scene?.hasNarration ?? false;

      if (_hasAudio) {
        try {
          await _narration
              .setAudioSource(
                LockCachingAudioSource(Uri.parse(scene!.narrationUrl!)),
              )
              .timeout(const Duration(seconds: 30));
        } catch (_) {
          _hasAudio = false;
        }
      }
    } catch (_) {
      // Fall through — text-only practice is still usable.
      _hasAudio = false;
    }
    if (!mounted) return;
    setState(() => _preparing = false);
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
    // Duck the bed so the voice sits on top of it.
    await _beats.setVolume(_bedDuckedVolume);
    if (!mounted) return;
    setState(() => _phase = _FsPhase.embody);

    if (_hasAudio) {
      _narrationSub = _narration.processingStateStream.listen((state) {
        if (state == ProcessingState.completed) _startCarry();
      });
      unawaited(_narration.play());
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
    await _beats.setVolume(_bedVolume);
    if (!mounted) return;
    setState(() => _phase = _FsPhase.carry);
    _carryTimer = Timer(const Duration(seconds: _carrySeconds), _complete);
  }

  Future<void> _complete() async {
    _carryTimer?.cancel();
    await _narration.pause();
    await _beats.pause();

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
    if (value) {
      await _beats.play();
    } else {
      await _beats.pause();
    }
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
            ? const _PreparingView()
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
          onToggleBeats: _toggleBeats,
          onBeginNow: _startEmbody,
        );
      case _FsPhase.embody:
        return _EmbodyPhase(
          key: const ValueKey('embody'),
          player: _narration,
          hasAudio: _hasAudio,
          showText: _showText,
          script: _scene?.script ?? '',
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
          onLogEvidence: _openEvidenceSheet,
          onTalkToFutureSelf: () {
            Navigator.of(context).pop();
            context.push('/chat', extra: {'initialMode': 'future_self'});
          },
          onDone: () => Navigator.of(context).pop(),
        );
    }
  }

  Future<void> _openEvidenceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.futureSelfSurface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (_) => const _EvidenceSheet(),
    );
  }
}

// ─── Preparing ────────────────────────────────────────────────────────────────

class _PreparingView extends StatelessWidget {
  const _PreparingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _BreathingOrb(size: 120),
          const SizedBox(height: AppSpacing.xl),
          Text(AppStrings.futureSelfPreparing,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          Text(AppStrings.futureSelfPreparingNote,
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
  final ValueChanged<bool> onToggleBeats;
  final VoidCallback onBeginNow;

  const _ArrivePhase({
    super.key,
    required this.remaining,
    required this.beatsEnabled,
    required this.onToggleBeats,
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
          _BeatsToggle(enabled: beatsEnabled, onToggle: onToggleBeats),
          const SizedBox(height: AppSpacing.xl),
          TextButton(
            onPressed: onBeginNow,
            child: Text('${AppStrings.futureSelfBeginNow}  ·  ${remaining}s',
                style: AppTextStyles.button
                    .copyWith(color: AppColors.futureSelfAccent)),
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

  const _EmbodyPhase({
    super.key,
    required this.player,
    required this.hasAudio,
    required this.showText,
    required this.script,
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
          if (hasAudio) _NarrationControls(player: player),
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

  const _NarrationControls({required this.player});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
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
          onPressed: () => playing ? player.pause() : player.play(),
        );
      },
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
  final VoidCallback onLogEvidence;
  final VoidCallback onTalkToFutureSelf;
  final VoidCallback onDone;

  const _SealPhase({
    super.key,
    required this.daysEmbodied,
    required this.trait,
    required this.onLogEvidence,
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
            icon: Icons.auto_awesome_rounded,
            label: AppStrings.futureSelfSealLogEvidence,
            filled: true,
            onTap: onLogEvidence,
          ),
          const SizedBox(height: AppSpacing.sm),
          _SealButton(
            icon: Icons.forum_rounded,
            label: AppStrings.futureSelfSealTalkToFutureSelf,
            filled: false,
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

// ─── Evidence sheet ─────────────────────────────────────────────────────────────

/// Compact evidence entry reused from the dashboard flow, offered right after a
/// session so the user can capture proof of the identity they just rehearsed.
class _EvidenceSheet extends ConsumerStatefulWidget {
  const _EvidenceSheet();

  @override
  ConsumerState<_EvidenceSheet> createState() => _EvidenceSheetState();
}

class _EvidenceSheetState extends ConsumerState<_EvidenceSheet> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    try {
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      final profile = ref.read(currentUserProfileProvider).valueOrNull;
      if (uid == null || profile == null) return;
      final updated = [
        ...profile.evidenceLog,
        EvidenceEntry(
          id: const Uuid().v4(),
          content: text,
          createdAt: DateTime.now(),
        ),
      ];
      await ref.read(firestoreServiceProvider).updateUserField(uid, {
        'evidenceLog': updated.map((e) => e.toJson()).toList(),
      });
      if (!mounted) return;
      await ref
          .read(dailyCompletionProvider.notifier)
          .toggle('evidenceLogged', true);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.errorGeneric)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(AppStrings.evidenceLog,
              style: AppTextStyles.headlineSmall
                  .copyWith(color: AppColors.futureSelfAccent)),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            maxLines: 3,
            autofocus: true,
            style: AppTextStyles.bodyMedium,
            cursorColor: AppColors.futureSelfAccent,
            decoration: InputDecoration(
              hintText: AppStrings.evidenceHint,
              hintStyle:
                  AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.futureSelfBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                borderSide: const BorderSide(
                    color: AppColors.futureSelfAccent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: AppSpacing.buttonHeight,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.futureSelfAccent,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  : Text(AppStrings.save,
                      style:
                          AppTextStyles.button.copyWith(color: Colors.black)),
            ),
          ),
        ],
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

// ─── Binaural toggle (simple on/off) ────────────────────────────────────────────

class _BeatsToggle extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onToggle;

  const _BeatsToggle({required this.enabled, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.futureSelfSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border:
            Border.all(color: AppColors.futureSelfAccent.withValues(alpha: 0.2)),
      ),
      child: Row(
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
                Text('Binaural beats',
                    style: AppTextStyles.labelLarge
                        .copyWith(color: AppColors.futureSelfAccent)),
                Text('Calming audio bed · headphones recommended',
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
    );
  }
}
