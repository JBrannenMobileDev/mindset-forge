import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/future_self_setup.dart';
import '../../providers/future_self_provider.dart';
import 'future_self_wizard.dart';
import 'future_self_player_screen.dart';
import 'widgets/future_self_how_to.dart';

/// Future Self Practice detail screen, the visualization half of the
/// Subconscious (Foundation) layer. Explains the practice, shows today's
/// status, and routes to the setup wizard and the guided player.
class FutureSelfScreen extends ConsumerWidget {
  const FutureSelfScreen({super.key});

  Future<void> _openWizard(BuildContext context) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const FutureSelfWizard()),
    );
  }

  Future<void> _openPlayer(BuildContext context, WidgetRef ref) async {
    final setup = ref.read(futureSelfProvider);
    // Show the one-time "how to practice" primer before the first session.
    if (setup != null && !setup.hasSeenHowTo) {
      final begin = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const FutureSelfHowToScreen()),
      );
      await ref.read(futureSelfProvider.notifier).markHowToSeen();
      if (begin != true) return;
    }
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FutureSelfPlayerScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(futureSelfProvider);
    final completedToday = ref.watch(futureSelfCompletedTodayProvider);
    final hasPractice = setup?.hasPractice ?? false;

    return Scaffold(
      backgroundColor: AppColors.futureSelfBackground,
      appBar: AppBar(
        backgroundColor: AppColors.futureSelfBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.futureSelfAccent),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          AppStrings.futureSelf,
          style: AppTextStyles.headlineSmall
              .copyWith(color: AppColors.futureSelfAccent),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenPaddingH,
              AppSpacing.md, AppSpacing.screenPaddingH, AppSpacing.xxl),
          children: [
            _Hero().animate().fadeIn(duration: 400.ms),
            const SizedBox(height: AppSpacing.xl),
            if (hasPractice) ...[
              _TodayStatus(
                completed: completedToday,
                onStart: () => _openPlayer(context, ref),
              ),
              const SizedBox(height: AppSpacing.md),
              _ActionButton(
                label: completedToday
                    ? AppStrings.futureSelfPracticeAgain
                    : AppStrings.futureSelfStartToday,
                icon: Icons.play_arrow_rounded,
                filled: true,
                onTap: () => _openPlayer(context, ref),
              ),
              const SizedBox(height: AppSpacing.sm),
              _ActionButton(
                label: AppStrings.futureSelfRefine,
                icon: Icons.tune_rounded,
                filled: false,
                onTap: () => _openWizard(context),
              ),
              const SizedBox(height: AppSpacing.lg),
              _PracticeSummary(setup: setup!),
            ] else ...[
              _ActionButton(
                label: AppStrings.futureSelfCreate,
                icon: Icons.auto_awesome_rounded,
                filled: true,
                onTap: () => _openWizard(context),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            const _HowToSection(),
            const SizedBox(height: AppSpacing.md),
            const _AboutSection(),
          ],
        ),
      ),
    );
  }
}

/// Always-available, collapsible "How to practice" guide reusing the shared
/// method content from the primer.
class _HowToSection extends StatefulWidget {
  const _HowToSection();

  @override
  State<_HowToSection> createState() => _HowToSectionState();
}

class _HowToSectionState extends State<_HowToSection> {
  bool _expanded = false;

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
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                const Icon(Icons.self_improvement_rounded,
                    color: AppColors.futureSelfAccent, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(AppStrings.futureSelfHowToTitle,
                      style: AppTextStyles.headlineSmall),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.lg),
                    child: FutureSelfHowToContent(showIntro: false),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
                colors: [AppColors.futureSelfAccent, AppColors.warning]),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: AppColors.futureSelfGlow,
                  blurRadius: 28,
                  spreadRadius: 6),
            ],
          ),
          child: const Icon(Icons.visibility_rounded,
              color: Colors.white, size: 34),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(AppStrings.futureSelfPracticeTitle,
            style: AppTextStyles.headlineMedium
                .copyWith(color: AppColors.futureSelfAccent),
            textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xs),
        Text(AppStrings.futureSelfPracticeSubtitle,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center),
      ],
    );
  }
}

class _TodayStatus extends StatelessWidget {
  final bool completed;
  final VoidCallback onStart;

  const _TodayStatus({required this.completed, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: completed
            ? AppColors.success.withValues(alpha: 0.10)
            : AppColors.futureSelfSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: completed
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            completed
                ? Icons.check_circle_rounded
                : Icons.visibility_outlined,
            color: completed ? AppColors.success : AppColors.textMuted,
            size: 24,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.futureSelfTodayTitle,
                    style: AppTextStyles.labelLarge),
                const SizedBox(height: 2),
                Text(
                  completed
                      ? AppStrings.futureSelfCompletedStatus
                      : AppStrings.futureSelfNotCompletedStatus,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticeSummary extends StatelessWidget {
  final FutureSelfSetup setup;

  const _PracticeSummary({required this.setup});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.futureSelfSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.futureSelfPracticeSection,
              style: AppTextStyles.headlineSmall
                  .copyWith(color: AppColors.futureSelfAccent)),
          const SizedBox(height: AppSpacing.md),
          _row(AppStrings.futureSelfTimelineLabel,
              '${setup.futureTimeline} from now'),
          if (setup.identityAnchor.isNotEmpty)
            _row(AppStrings.futureSelfIdentityLabel,
                'I am someone who ${setup.identityAnchor}'),
          if (setup.emotionalTone.isNotEmpty)
            _row(AppStrings.futureSelfToneLabel, setup.emotionalTone),
          const SizedBox(height: AppSpacing.sm),
          Text(AppStrings.futureSelfRefineNote,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textMuted, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.labelSmall),
          const SizedBox(height: 2),
          Text(value, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

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
              const Icon(Icons.auto_awesome_rounded,
                  color: AppColors.futureSelfAccent, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(AppStrings.futureSelfWhatTitle,
                    style: AppTextStyles.headlineSmall),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(AppStrings.futureSelfWhatBody,
              style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary, height: 1.6)),
          const SizedBox(height: AppSpacing.lg),
          Text(AppStrings.futureSelfPrinciplesTitle,
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.futureSelfAccent)),
          const SizedBox(height: AppSpacing.sm),
          ...AppStrings.futureSelfPrinciples.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.circle, size: 6, color: AppColors.futureSelfAccent),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                      child: Text(p,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary))),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(AppStrings.futureSelfBestTimeTitle,
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.futureSelfAccent)),
          const SizedBox(height: AppSpacing.xs),
          Text(AppStrings.futureSelfBestTimeBody,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary, height: 1.5)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
                minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
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
                minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
            ),
    );
  }
}
