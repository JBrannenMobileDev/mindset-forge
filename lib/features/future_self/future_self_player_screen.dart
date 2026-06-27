import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/audio/binaural_beat_controller.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/claude_provider.dart';
import '../../providers/future_self_provider.dart';

/// The four guided phases of a session.
enum _FsPhase { settle, load, visualize, seal }

/// The guided Future Self session. Walks the user through the effective method:
/// settle into a calm state, load the scene, replay it eyes-closed with vivid
/// detail and emotion, then seal it in. Records the completion at the end.
class FutureSelfPlayerScreen extends ConsumerStatefulWidget {
  const FutureSelfPlayerScreen({super.key});

  @override
  ConsumerState<FutureSelfPlayerScreen> createState() =>
      _FutureSelfPlayerScreenState();
}

class _FutureSelfPlayerScreenState
    extends ConsumerState<FutureSelfPlayerScreen> {
  late final BinauralBeatController _beats;
  final DateTime _start = DateTime.now();

  _FsPhase _phase = _FsPhase.settle;
  List<String> _paragraphs = [];
  bool _loadingScript = false;
  bool _beatsEnabled = true;
  bool _completing = false;

  Timer? _visualizeTimer;
  DateTime? _visualizeStart;
  int _visualizeSeconds = 0;

  @override
  void initState() {
    super.initState();
    final setup = ref.read(futureSelfProvider);
    _beatsEnabled = setup?.beatsEnabled ?? true;
    _beats = BinauralBeatController(hz: setup?.binauralHz ?? 7);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _visualizeTimer?.cancel();
    _beats.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadScript();
    if (_beatsEnabled && mounted) await _beats.play();
  }

  Future<void> _loadScript() async {
    final setup = ref.read(futureSelfProvider);
    if (setup == null) return;

    if (setup.hasPractice) {
      _setParagraphs(setup.generatedScript!);
      return;
    }

    // No stored script yet, generate once and persist it.
    setState(() => _loadingScript = true);
    try {
      final profile = ref.read(currentUserProfileProvider).valueOrNull;
      if (profile != null) {
        final script = await ref
            .read(claudeServiceProvider)
            .generateFutureSelfScript(setup, profile);
        if (!mounted) return;
        _setParagraphs(script);
        await ref.read(futureSelfProvider.notifier).attachScript(script);
      }
    } catch (_) {
      // leave empty; user can refine
    } finally {
      if (mounted) setState(() => _loadingScript = false);
    }
  }

  void _setParagraphs(String script) {
    setState(() {
      _paragraphs = script
          .split(RegExp(r'\n\s*\n'))
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
      if (_paragraphs.isEmpty && script.trim().isNotEmpty) {
        _paragraphs = [script.trim()];
      }
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

  void _goTo(_FsPhase phase) {
    if (phase == _FsPhase.visualize) {
      _visualizeStart = DateTime.now();
      _visualizeSeconds = 0;
      _visualizeTimer?.cancel();
      _visualizeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _visualizeSeconds =
              DateTime.now().difference(_visualizeStart!).inSeconds;
        });
      });
    } else {
      _visualizeTimer?.cancel();
    }
    setState(() => _phase = phase);
  }

  Future<void> _complete() async {
    setState(() => _completing = true);
    _visualizeTimer?.cancel();
    await _beats.pause();
    final seconds = DateTime.now().difference(_start).inSeconds;
    await ref.read(futureSelfProvider.notifier).recordCompletion(seconds);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          AppStrings.futureSelfCompleteSnackBar(
              (seconds / 60).toStringAsFixed(1)),
        ),
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
          icon: const Icon(Icons.close_rounded,
              color: AppColors.futureSelfAccent),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          AppStrings.futureSelf,
          style: AppTextStyles.headlineSmall
              .copyWith(color: AppColors.futureSelfAccent),
        ),
        actions: [
          IconButton(
            tooltip: 'Binaural beats',
            icon: Icon(
              _beatsEnabled
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              color: AppColors.futureSelfAccent,
            ),
            onPressed: () => _toggleBeats(!_beatsEnabled),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.sm),
            _PhaseProgress(phase: _phase),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: _buildPhase(),
              ),
            ),
            _buildCta(),
          ],
        ),
      ),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case _FsPhase.settle:
        return _SettlePhase(
          key: const ValueKey('settle'),
          beatsEnabled: _beatsEnabled,
          beats: _beats,
          onToggleBeats: _toggleBeats,
        );
      case _FsPhase.load:
        return _LoadPhase(
          key: const ValueKey('load'),
          loading: _loadingScript,
          paragraphs: _paragraphs,
        );
      case _FsPhase.visualize:
        return _VisualizePhase(
          key: const ValueKey('visualize'),
          seconds: _visualizeSeconds,
        );
      case _FsPhase.seal:
        return const _SealPhase(key: ValueKey('seal'));
    }
  }

  Widget _buildCta() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenPaddingH,
          AppSpacing.sm, AppSpacing.screenPaddingH, AppSpacing.lg),
      child: Column(
        children: [
          switch (_phase) {
            _FsPhase.settle => _AccentButton(
                label: AppStrings.futureSelfPhaseSettleCta,
                onPressed: () => _goTo(_FsPhase.load),
              ),
            _FsPhase.load => _AccentButton(
                label: AppStrings.futureSelfPhaseLoadCta,
                onPressed: () => _goTo(_FsPhase.visualize),
              ),
            _FsPhase.visualize => _AccentButton(
                label: AppStrings.futureSelfPhaseVisualizeCta,
                onPressed: () => _goTo(_FsPhase.seal),
              ),
            _FsPhase.seal => _AccentButton(
                label: AppStrings.futureSelfComplete,
                isLoading: _completing,
                onPressed: _completing ? null : _complete,
              ),
          },
          if (_phase == _FsPhase.settle)
            TextButton(
              onPressed: () => _goTo(_FsPhase.load),
              child: Text(AppStrings.futureSelfPhaseSkip,
                  style: AppTextStyles.button
                      .copyWith(color: AppColors.textSecondary)),
            ),
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
    final index = _FsPhase.values.indexOf(phase);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_FsPhase.values.length, (i) {
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

// ─── Phases ─────────────────────────────────────────────────────────────────

class _SettlePhase extends StatelessWidget {
  final bool beatsEnabled;
  final BinauralBeatController beats;
  final ValueChanged<bool> onToggleBeats;

  const _SettlePhase({
    super.key,
    required this.beatsEnabled,
    required this.beats,
    required this.onToggleBeats,
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
          Text(AppStrings.futureSelfPhaseSettleTitle,
              style: AppTextStyles.headlineMedium
                  .copyWith(color: AppColors.futureSelfAccent),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(AppStrings.futureSelfPhaseSettleBody,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary, height: 1.6),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xl),
          _BeatsPanel(
            enabled: beatsEnabled,
            controller: beats,
            onToggle: onToggleBeats,
          ),
        ],
      ),
    );
  }
}

class _LoadPhase extends StatelessWidget {
  final bool loading;
  final List<String> paragraphs;

  const _LoadPhase({super.key, required this.loading, required this.paragraphs});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenPaddingH,
          AppSpacing.lg, AppSpacing.screenPaddingH, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(AppStrings.futureSelfPhaseLoadTitle,
              style: AppTextStyles.headlineMedium
                  .copyWith(color: AppColors.futureSelfAccent),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(AppStrings.futureSelfPhaseLoadBody,
              style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xl),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Center(
                child: CircularProgressIndicator(
                    color: AppColors.futureSelfAccent),
              ),
            )
          else
            ...paragraphs.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: Text(
                  p,
                  style: AppTextStyles.bodyLarge
                      .copyWith(height: 1.9, color: AppColors.textPrimary),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VisualizePhase extends StatelessWidget {
  final int seconds;

  const _VisualizePhase({super.key, required this.seconds});

  String get _elapsed {
    final m = (seconds ~/ 60).toString();
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    const cues = AppStrings.futureSelfVisualizeCues;
    final cue = cues[(seconds ~/ 6) % cues.length];

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenPaddingH,
          AppSpacing.xl, AppSpacing.screenPaddingH, AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _BreathingOrb(size: 130),
          const SizedBox(height: AppSpacing.xl),
          Text(AppStrings.futureSelfPhaseVisualizeTitle,
              style: AppTextStyles.headlineMedium
                  .copyWith(color: AppColors.futureSelfAccent),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(AppStrings.futureSelfPhaseVisualizeBody,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary, height: 1.6),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xl),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: Text(
              cue,
              key: ValueKey(cue),
              style: AppTextStyles.bodyLarge
                  .copyWith(color: AppColors.futureSelfAccent),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(_elapsed,
              style: AppTextStyles.labelSmall),
        ],
      ),
    );
  }
}

class _SealPhase extends StatelessWidget {
  const _SealPhase({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _BreathingOrb(size: 110),
          const SizedBox(height: AppSpacing.xl),
          Text(AppStrings.futureSelfPhaseSealTitle,
              style: AppTextStyles.headlineMedium
                  .copyWith(color: AppColors.futureSelfAccent),
              textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(AppStrings.futureSelfPhaseSealBody,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textSecondary, height: 1.6),
              textAlign: TextAlign.center),
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

// ─── Accent button ────────────────────────────────────────────────────────────

class _AccentButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _AccentButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppSpacing.buttonHeight,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.futureSelfAccent,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.black),
              )
            : Text(label,
                style: AppTextStyles.button.copyWith(color: Colors.black)),
      ),
    );
  }
}

// ─── Binaural beats panel ─────────────────────────────────────────────────────

/// Binaural beats panel: enable toggle, frequency band selector, volume slider.
class _BeatsPanel extends StatefulWidget {
  final bool enabled;
  final BinauralBeatController controller;
  final ValueChanged<bool> onToggle;

  const _BeatsPanel({
    required this.enabled,
    required this.controller,
    required this.onToggle,
  });

  @override
  State<_BeatsPanel> createState() => _BeatsPanelState();
}

class _BeatsPanelState extends State<_BeatsPanel> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.futureSelfSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
            color: AppColors.futureSelfAccent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                widget.enabled
                    ? Icons.graphic_eq_rounded
                    : Icons.volume_off_rounded,
                color: AppColors.futureSelfAccent,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Binaural Beats',
                        style: AppTextStyles.labelLarge
                            .copyWith(color: AppColors.futureSelfAccent)),
                    Text('Supports focus and absorption',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
              Switch(
                value: widget.enabled,
                activeThumbColor: AppColors.futureSelfAccent,
                onChanged: widget.onToggle,
              ),
            ],
          ),
          if (widget.enabled) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: BinauralBeatController.bands.map((b) {
                final selected = b.hz == widget.controller.hz;
                return GestureDetector(
                  onTap: () async {
                    await widget.controller.setFrequency(b.hz);
                    if (mounted) setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.futureSelfAccent.withValues(alpha: 0.15)
                          : AppColors.futureSelfBackground,
                      border: Border.all(
                        color: selected
                            ? AppColors.futureSelfAccent
                            : AppColors.border,
                      ),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Text(
                      b.name,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: selected
                            ? AppColors.futureSelfAccent
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(Icons.volume_down_rounded,
                    color: AppColors.textMuted, size: 18),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.futureSelfAccent,
                      inactiveTrackColor: AppColors.border,
                      thumbColor: AppColors.futureSelfAccent,
                    ),
                    child: Slider(
                      value: widget.controller.volume,
                      onChanged: (v) async {
                        await widget.controller.setVolume(v);
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                ),
                const Icon(Icons.volume_up_rounded,
                    color: AppColors.textMuted, size: 18),
              ],
            ),
            Center(
              child: Text('🎧 Headphones required for the effect',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted)),
            ),
          ],
        ],
      ),
    );
  }
}
