import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_button.dart';
import '../../models/user_profile.dart';
import '../../providers/streak_provider.dart';
import '../../providers/claude_provider.dart';

class MindsetProgressTab extends ConsumerStatefulWidget {
  final UserProfile profile;

  const MindsetProgressTab({super.key, required this.profile});

  @override
  ConsumerState<MindsetProgressTab> createState() => _MindsetProgressTabState();
}

class _MindsetProgressTabState extends ConsumerState<MindsetProgressTab> {
  String? _weeklyInsight;
  bool _isLoadingInsight = false;

  Future<void> _loadWeeklyInsight() async {
    setState(() => _isLoadingInsight = true);
    try {
      final insight = await ref.read(claudeServiceProvider).generateWeeklyInsight(widget.profile);
      if (!mounted) return;
      setState(() => _weeklyInsight = insight);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.errorAI)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingInsight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final streak = ref.watch(streakProvider);
    final perfectDays = ref.watch(perfectDayCountProvider);
    final completedGoals = widget.profile.goals.where((g) => g.status == 'completed').toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingH,
        AppSpacing.lg,
        AppSpacing.screenPaddingH,
        100,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                value: '$streak',
                label: AppStrings.currentStreak,
                icon: Icons.local_fire_department_rounded,
                color: AppColors.warning,
              ).animate().fadeIn(duration: 400.ms),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _StatCard(
                value: '$perfectDays',
                label: AppStrings.perfectDays,
                icon: Icons.star_rounded,
                color: AppColors.primary,
              ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Row(
          children: [
            Text(AppStrings.weeklyInsight, style: AppTextStyles.headlineSmall),
            const Spacer(),
            AppTextButton(
              label: 'Generate',
              onPressed: _loadWeeklyInsight,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (_isLoadingInsight)
          const Center(child: CircularProgressIndicator(color: AppColors.primary))
        else if (_weeklyInsight != null)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.psychology_rounded, color: AppColors.primary, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    Text('This Week', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(_weeklyInsight!, style: AppTextStyles.bodyMedium.copyWith(height: 1.7)),
              ],
            ),
          ).animate().fadeIn(duration: 500.ms)
        else
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.insights_rounded, color: AppColors.textMuted, size: 32),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Get your weekly insight from your coach',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
        if (completedGoals.isNotEmpty) ...[
          Text('Completed Goals', style: AppTextStyles.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          ...completedGoals.asMap().entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: AppCard(
                borderColor: AppColors.success.withValues(alpha: 0.3),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.value.title, style: AppTextStyles.labelLarge),
                          if (e.value.completedAt != null)
                            Text(
                              'Completed ${e.value.completedAt!.month}/${e.value.completedAt!.year}',
                              style: AppTextStyles.labelSmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: Duration(milliseconds: e.key * 60)),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: AppSpacing.sm),
          Text(value, style: AppTextStyles.statNumber.copyWith(color: color)),
          Text(label, style: AppTextStyles.labelSmall),
        ],
      ),
    );
  }
}
