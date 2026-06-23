import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../models/user_profile.dart';
import '../../../models/identity_read_log.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/daily_completion_provider.dart';

class IdentityCard extends ConsumerWidget {
  final UserProfile profile;

  const IdentityCard({super.key, required this.profile});

  Future<void> _markRead(WidgetRef ref, BuildContext context) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;

    final today = AppDateUtils.todayString();
    final log = IdentityReadLog(date: today, readAt: DateTime.now());
    final updatedLog = [...profile.identityReadLog, log];

    await ref.read(firestoreServiceProvider).updateUserField(uid, {
      'identityReadLog': updatedLog.map((l) => l.toJson()).toList(),
    });

    await ref.read(dailyCompletionProvider.notifier).toggle('identityRead', true);
  }

  bool _hasReadToday() {
    final today = AppDateUtils.todayString();
    return profile.identityReadLog.any((l) => l.date == today);
  }

  void _showFullIdentity(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) => _IdentityModal(
          statement: profile.identityStatement,
          onRead: () {
            _markRead(ref, ctx);
            Navigator.pop(ctx);
          },
          hasReadToday: _hasReadToday(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final readToday = _hasReadToday();

    return Column(
      children: [
        SectionHeader(title: AppStrings.yourIdentity),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          borderColor: readToday ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.primary, AppColors.secondary],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      profile.identityStatement.isNotEmpty
                          ? profile.identityStatement
                          : 'Set your identity statement to begin',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontStyle: FontStyle.italic,
                        height: 1.6,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  if (readToday)
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 16),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Read today',
                          style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
                        ),
                      ],
                    ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showFullIdentity(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: readToday ? AppColors.primaryContainer : AppColors.surface,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                        border: Border.all(
                          color: readToday ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
                        ),
                      ),
                      child: Text(
                        AppStrings.readToday,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: readToday ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(duration: 400.ms),
      ],
    );
  }
}

class _IdentityModal extends StatelessWidget {
  final String statement;
  final VoidCallback onRead;
  final bool hasReadToday;

  const _IdentityModal({
    required this.statement,
    required this.onRead,
    required this.hasReadToday,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollCtrl) => SingleChildScrollView(
        controller: scrollCtrl,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 48),
            const SizedBox(height: AppSpacing.lg),
            Text('Your Identity', style: AppTextStyles.headlineMedium),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                statement.isNotEmpty
                    ? statement
                    : 'No identity statement set yet.',
                style: AppTextStyles.headlineSmall.copyWith(
                  fontStyle: FontStyle.italic,
                  height: 1.8,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Read this slowly. Let it sink in. This is who you are.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),
            if (!hasReadToday)
              SizedBox(
                width: double.infinity,
                height: AppSpacing.buttonHeight,
                child: ElevatedButton(
                  onPressed: onRead,
                  child: const Text('Mark as Read Today'),
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Identity read for today',
                    style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary),
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
