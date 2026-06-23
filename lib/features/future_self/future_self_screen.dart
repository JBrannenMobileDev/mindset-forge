import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/app_button.dart';
import '../../models/future_self_practice.dart';
import '../../providers/auth_provider.dart';
import '../../providers/claude_provider.dart';
import '../../providers/daily_completion_provider.dart';

class FutureSelfScreen extends ConsumerStatefulWidget {
  const FutureSelfScreen({super.key});

  @override
  ConsumerState<FutureSelfScreen> createState() => _FutureSelfScreenState();
}

class _FutureSelfScreenState extends ConsumerState<FutureSelfScreen> {
  final _audioPlayer = AudioPlayer();
  int _selectedHz = 10;
  int _elapsedSeconds = 0;
  Timer? _timer;
  bool _sessionActive = false;
  bool _isLoadingScript = false;
  List<String> _paragraphs = [];
  int _visibleParagraphs = 0;

  static const _frequencies = [7, 10, 14];

  @override
  void initState() {
    super.initState();
    _loadScript();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadScript() async {
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    final setup = profile?.futureSelfSetup;
    if (setup == null) return;

    if (setup.generatedScript != null && setup.generatedScript!.isNotEmpty) {
      _setScript(setup.generatedScript!);
      return;
    }

    setState(() => _isLoadingScript = true);
    try {
      final script = await ref.read(claudeServiceProvider).generateFutureSelfScript(setup, profile!);
      _setScript(script);

      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid != null) {
        final updatedSetup = setup.copyWith(generatedScript: script);
        await ref.read(firestoreServiceProvider).updateUserField(uid, {
          'futureSelfSetup': updatedSetup.toJson(),
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingScript = false);
    }
  }

  void _setScript(String script) {
    setState(() {
      _paragraphs = script.split('\n').where((p) => p.trim().isNotEmpty).toList();
    });
  }

  Future<void> _startSession() async {
    setState(() {
      _sessionActive = true;
      _elapsedSeconds = 0;
      _visibleParagraphs = 0;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _elapsedSeconds++);
    });

    _revealParagraphs();
  }

  void _revealParagraphs() {
    if (_paragraphs.isEmpty) return;
    for (int i = 0; i < _paragraphs.length; i++) {
      Future.delayed(Duration(seconds: i * 8), () {
        if (mounted && _sessionActive) {
          setState(() => _visibleParagraphs = i + 1);
        }
      });
    }
  }

  Future<void> _endSession() async {
    _timer?.cancel();
    setState(() => _sessionActive = false);

    await _audioPlayer.stop();

    await ref.read(dailyCompletionProvider.notifier).toggle('futureSelfCompleted', true);

    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid != null) {
      final practice = FutureSelfPractice(
        sessionDate: DateTime.now(),
        durationSeconds: _elapsedSeconds,
        binauralFrequencyHz: _selectedHz,
      );
      await ref.read(firestoreServiceProvider).updateUserField(uid, {
        'futureSelfPractice': practice.toJson(),
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Session complete — ${(_elapsedSeconds / 60).toStringAsFixed(1)} minutes with your future self.',
          ),
        ),
      );
    }
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final setup = profile?.futureSelfSetup;

    return Scaffold(
      backgroundColor: AppColors.futureSelfBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.futureSelfAccent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppStrings.futureSelf,
          style: AppTextStyles.headlineSmall.copyWith(color: AppColors.futureSelfAccent),
        ),
      ),
      body: setup == null
          ? Center(
              child: Text(
                'Set up your Future Self profile in the Chat tab.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: const RadialGradient(colors: [AppColors.futureSelfAccent, AppColors.warning]),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppColors.futureSelfGlow, blurRadius: 30, spreadRadius: 10)],
                      ),
                      child: const Icon(Icons.self_improvement_rounded, color: Colors.white, size: 40),
                    ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.8, 0.8)),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      '${setup.timeframeYears} Years From Now',
                      style: AppTextStyles.displaySmall.copyWith(color: AppColors.futureSelfAccent),
                    ).animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: AppSpacing.xl),
                    if (_sessionActive) ...[
                      Text(
                        _formatTime(_elapsedSeconds),
                        style: AppTextStyles.statNumber.copyWith(color: AppColors.futureSelfAccent),
                      ).animate().fadeIn(),
                      const SizedBox(height: AppSpacing.xl),
                      if (_isLoadingScript)
                        const CircularProgressIndicator(color: AppColors.futureSelfAccent)
                      else
                        Column(
                          children: List.generate(
                            _visibleParagraphs.clamp(0, _paragraphs.length),
                            (i) => Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                              child: Text(
                                _paragraphs[i],
                                style: AppTextStyles.bodyLarge.copyWith(height: 1.9, color: AppColors.textPrimary),
                                textAlign: TextAlign.center,
                              ).animate().fadeIn(duration: 1500.ms).slideY(begin: 0.05, end: 0),
                            ),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.xl),
                      AppSecondaryButton(
                        label: AppStrings.endSession,
                        onPressed: _endSession,
                      ),
                    ] else ...[
                      if (_isLoadingScript)
                        Column(
                          children: [
                            const CircularProgressIndicator(color: AppColors.futureSelfAccent),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Generating your future self script...',
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        )
                      else
                        _SessionPreview(setup: setup),
                      const SizedBox(height: AppSpacing.xl),
                      _BinauralSelector(
                        selected: _selectedHz,
                        onSelect: (hz) => setState(() => _selectedHz = hz),
                        frequencies: _frequencies,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppPrimaryButton(
                        label: AppStrings.startSession,
                        onPressed: _isLoadingScript ? null : _startSession,
                        icon: Icons.play_arrow_rounded,
                      ),
                    ],
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SessionPreview extends StatelessWidget {
  final dynamic setup;

  const _SessionPreview({required this.setup});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.futureSelfSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.futureSelfAccent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Future Self',
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.futureSelfAccent),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            setup.evolvedIdentity as String,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textPrimary,
              fontStyle: FontStyle.italic,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _BinauralSelector extends StatelessWidget {
  final int selected;
  final void Function(int) onSelect;
  final List<int> frequencies;

  const _BinauralSelector({
    required this.selected,
    required this.onSelect,
    required this.frequencies,
  });

  String _label(int hz) {
    return switch (hz) {
      7 => 'Theta 7Hz\nDeep Focus',
      10 => 'Alpha 10Hz\nRelaxed',
      14 => 'Beta 14Hz\nAlertness',
      _ => '$hz Hz',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.binauralFrequency,
          style: AppTextStyles.labelLarge.copyWith(color: AppColors.futureSelfAccent),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: frequencies.map((hz) {
            final sel = hz == selected;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: hz == frequencies.last ? 0 : AppSpacing.sm),
                child: GestureDetector(
                  onTap: () => onSelect(hz),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.futureSelfAccent.withValues(alpha: 0.15)
                          : AppColors.futureSelfSurface,
                      border: Border.all(
                        color: sel ? AppColors.futureSelfAccent : AppColors.border,
                      ),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Text(
                      _label(hz),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: sel ? AppColors.futureSelfAccent : AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
