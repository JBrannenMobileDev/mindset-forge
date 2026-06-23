import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/user_profile.dart';
import '../../../providers/affirmations_provider.dart';
import '../../../providers/daily_completion_provider.dart';
import '../../mindset/affirmations_tab.dart';

class AffirmationSessionCard extends ConsumerWidget {
  final UserProfile profile;

  const AffirmationSessionCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completion = ref.watch(dailyCompletionProvider);
    final affirmations = ref.watch(affirmationsProvider);
    final active = affirmations.where((a) => a.isActive).toList();

    final morningDone = completion.affirmationsMorning;
    final eveningDone = completion.affirmationsEvening;
    final bothDone = morningDone && eveningDone;

    // Determine which session to offer based on time + what's done
    final hour = DateTime.now().hour;
    final suggestEvening = hour >= 17 || (morningDone && !eveningDone);
    final sessionType = suggestEvening ? 'evening' : 'morning';
    final sessionDone = sessionType == 'morning' ? morningDone : eveningDone;

    // CTA label
    final ctaLabel = bothDone
        ? 'All done today!'
        : sessionType == 'morning'
            ? 'Start Morning Session'
            : 'Start Evening Session';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.secondary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(Icons.format_quote_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Affirmations', style: AppTextStyles.labelLarge),
                  Text('Daily practice',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted)),
                ],
              ),
              const Spacer(),
              // Session status dots
              _SessionDot(
                icon: Icons.wb_sunny_rounded,
                color: AppColors.warning,
                done: morningDone,
                label: 'AM',
              ),
              const SizedBox(width: AppSpacing.xs),
              _SessionDot(
                icon: Icons.nightlight_round,
                color: AppColors.secondary,
                done: eveningDone,
                label: 'PM',
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // ── CTA button ────────────────────────────────────────────────
          if (bothDone)
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Both sessions complete for today',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.primary),
                ),
              ],
            )
          else if (active.isEmpty)
            GestureDetector(
              onTap: () {},
              child: Text(
                'Add affirmations on the Mindset tab to start your practice',
                style:
                    AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: sessionDone
                    ? null
                    : () => launchAffirmationSession(
                          context: context,
                          ref: ref,
                          affirmations: active,
                          sessionType: sessionType,
                        ),
                icon: Icon(
                  sessionType == 'morning'
                      ? Icons.wb_sunny_rounded
                      : Icons.nightlight_round,
                  size: 16,
                ),
                label: Text(ctaLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: sessionDone
                      ? AppColors.surfaceElevated
                      : AppColors.primary,
                  foregroundColor:
                      sessionDone ? AppColors.textMuted : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Session dot indicator ─────────────────────────────────────────────────────

class _SessionDot extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool done;
  final String label;

  const _SessionDot({
    required this.icon,
    required this.color,
    required this.done,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? color.withValues(alpha: 0.15) : AppColors.surfaceElevated,
            border: Border.all(
              color: done ? color : AppColors.border,
              width: done ? 2 : 1,
            ),
          ),
          child: Icon(
            done ? Icons.check_rounded : icon,
            size: 16,
            color: done ? color : AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: AppTextStyles.bodySmall
                .copyWith(fontSize: 10, color: AppColors.textMuted)),
      ],
    );
  }
}
