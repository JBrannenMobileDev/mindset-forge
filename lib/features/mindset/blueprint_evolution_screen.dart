import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/confetti_gate.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/hoverable.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/mindset_evolution_provider.dart';

class BlueprintEvolutionScreen extends ConsumerStatefulWidget {
  const BlueprintEvolutionScreen({super.key});

  @override
  ConsumerState<BlueprintEvolutionScreen> createState() =>
      _BlueprintEvolutionScreenState();
}

class _BlueprintEvolutionScreenState
    extends ConsumerState<BlueprintEvolutionScreen> {
  late final ConfettiController _confettiCtrl;
  int _step = 0;
  bool _loading = false;
  List<String> _beliefCandidates = [];
  List<String> _fearCandidates = [];
  final Set<String> _selectedBeliefs = {};
  final Set<String> _selectedFears = {};
  final _customBeliefCtrl = TextEditingController();
  final _customFearCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _confettiCtrl = ConfettiController(duration: const Duration(milliseconds: 1600));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ConfettiGate.play(_confettiCtrl, const Duration(milliseconds: 1600));
    });
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    _customBeliefCtrl.dispose();
    _customFearCtrl.dispose();
    super.dispose();
  }

  Future<void> _excavate(UserProfile profile) async {
    setState(() => _loading = true);
    final result = await ref.read(mindsetEvolutionBusyProvider.notifier).runExcavation(profile);
    if (!mounted) return;
    setState(() {
      _beliefCandidates = List<String>.from(result['beliefs'] ?? []);
      _fearCandidates = List<String>.from(result['fears'] ?? []);
      _selectedBeliefs
        ..clear()
        ..addAll(_beliefCandidates.take(3));
      _selectedFears
        ..clear()
        ..addAll(_fearCandidates.take(2));
      _loading = false;
      _step = 1;
    });
  }

  Future<void> _save(UserProfile profile) async {
    if (_selectedBeliefs.isEmpty && _selectedFears.isEmpty) return;
    try {
      await ref.read(mindsetEvolutionBusyProvider.notifier).saveSelections(
            profile: profile,
            beliefs: _selectedBeliefs.toList(),
            fears: _selectedFears.toList(),
          );
      if (!mounted) return;
      context.pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.errorGeneric),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final busy = ref.watch(mindsetEvolutionBusyProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
        title: Text(AppStrings.blueprintEvolutionTitle, style: AppTextStyles.headlineMedium),
      ),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ResponsiveLayout(
              maxWidth: 680,
              child: profile == null
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenPaddingH,
                        AppSpacing.lg,
                        AppSpacing.screenPaddingH,
                        100,
                      ),
                      child: _step == 0
                          ? _CelebrateStep(
                              profile: profile,
                              onContinue: () => _excavate(profile),
                              loading: _loading || busy,
                            )
                          : _ExcavateStep(
                              beliefCandidates: _beliefCandidates,
                              fearCandidates: _fearCandidates,
                              selectedBeliefs: _selectedBeliefs,
                              selectedFears: _selectedFears,
                              customBeliefCtrl: _customBeliefCtrl,
                              customFearCtrl: _customFearCtrl,
                              onToggleBelief: (b) => setState(() {
                                if (_selectedBeliefs.contains(b)) {
                                  _selectedBeliefs.remove(b);
                                } else {
                                  _selectedBeliefs.add(b);
                                }
                              }),
                              onToggleFear: (f) => setState(() {
                                if (_selectedFears.contains(f)) {
                                  _selectedFears.remove(f);
                                } else {
                                  _selectedFears.add(f);
                                }
                              }),
                              onAddBelief: () {
                                final text = _customBeliefCtrl.text.trim();
                                if (text.isEmpty) return;
                                setState(() {
                                  if (!_beliefCandidates.contains(text)) {
                                    _beliefCandidates.add(text);
                                  }
                                  _selectedBeliefs.add(text);
                                  _customBeliefCtrl.clear();
                                });
                              },
                              onAddFear: () {
                                final text = _customFearCtrl.text.trim();
                                if (text.isEmpty) return;
                                setState(() {
                                  if (!_fearCandidates.contains(text)) {
                                    _fearCandidates.add(text);
                                  }
                                  _selectedFears.add(text);
                                  _customFearCtrl.clear();
                                });
                              },
                              onSave: () => _save(profile),
                              saving: busy,
                            ),
                    ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiCtrl,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                AppColors.primary,
                AppColors.secondary,
                Colors.white,
                AppColors.warning,
              ],
              numberOfParticles: 45,
              gravity: 0.22,
            ),
          ),
        ],
      ),
    );
  }
}

class _CelebrateStep extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onContinue;
  final bool loading;

  const _CelebrateStep({
    required this.profile,
    required this.onContinue,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final overcome = [
      ...profile.overcomeBeliefs.map((e) => e.text),
      ...profile.overcomeFears.map((e) => e.text),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.blueprintEvolutionCelebrateHeadline,
          style: AppTextStyles.headlineLarge,
        ).animate().fadeIn(duration: 400.ms),
        const SizedBox(height: AppSpacing.sm),
        Text(
          AppStrings.blueprintEvolutionCelebrateBody,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
        const SizedBox(height: AppSpacing.lg),
        AppGlowCard(
          glowColor: AppColors.success.withValues(alpha: 0.2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppStrings.blueprintEvolutionArchiveTitle,
                  style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppSpacing.md),
              if (overcome.isEmpty)
                Text(
                  AppStrings.blueprintEvolutionArchiveEmpty,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                )
              else
                ...overcome.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.success, size: 18),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(item, style: AppTextStyles.bodyMedium),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
        const SizedBox(height: AppSpacing.xl),
        AppPrimaryButton(
          label: AppStrings.blueprintEvolutionContinue,
          isLoading: loading,
          onPressed: loading ? null : onContinue,
        ),
      ],
    );
  }
}

class _ExcavateStep extends StatelessWidget {
  final List<String> beliefCandidates;
  final List<String> fearCandidates;
  final Set<String> selectedBeliefs;
  final Set<String> selectedFears;
  final TextEditingController customBeliefCtrl;
  final TextEditingController customFearCtrl;
  final ValueChanged<String> onToggleBelief;
  final ValueChanged<String> onToggleFear;
  final VoidCallback onAddBelief;
  final VoidCallback onAddFear;
  final VoidCallback onSave;
  final bool saving;

  const _ExcavateStep({
    required this.beliefCandidates,
    required this.fearCandidates,
    required this.selectedBeliefs,
    required this.selectedFears,
    required this.customBeliefCtrl,
    required this.customFearCtrl,
    required this.onToggleBelief,
    required this.onToggleFear,
    required this.onAddBelief,
    required this.onAddFear,
    required this.onSave,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.blueprintEvolutionExcavateHeadline,
          style: AppTextStyles.headlineLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          AppStrings.blueprintEvolutionExcavateBody,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(AppStrings.limitingBeliefs, style: AppTextStyles.headlineSmall),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: beliefCandidates
              .map(
                (b) => _SelectableChip(
                  label: b,
                  selected: selectedBeliefs.contains(b),
                  onTap: () => onToggleBelief(b),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: customBeliefCtrl,
                style: AppTextStyles.bodyMedium,
                decoration: InputDecoration(
                  hintText: AppStrings.blueprintEvolutionAddBeliefHint,
                  hintStyle: AppTextStyles.bodySmall,
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppSecondaryButton(label: AppStrings.add, onPressed: onAddBelief),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(AppStrings.blueprintEvolutionFearsTitle,
            style: AppTextStyles.headlineSmall),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: fearCandidates
              .map(
                (f) => _SelectableChip(
                  label: f,
                  selected: selectedFears.contains(f),
                  onTap: () => onToggleFear(f),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: customFearCtrl,
                style: AppTextStyles.bodyMedium,
                decoration: InputDecoration(
                  hintText: AppStrings.blueprintEvolutionAddFearHint,
                  hintStyle: AppTextStyles.bodySmall,
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppSecondaryButton(label: AppStrings.add, onPressed: onAddFear),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        AppPrimaryButton(
          label: AppStrings.blueprintEvolutionSave,
          isLoading: saving,
          onPressed: (selectedBeliefs.isEmpty && selectedFears.isEmpty) || saving
              ? null
              : onSave,
        ),
      ],
    );
  }
}

class _SelectableChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Hoverable(
      onTap: onTap,
      builder: (_, __) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryContainer : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(
            color: selected ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
