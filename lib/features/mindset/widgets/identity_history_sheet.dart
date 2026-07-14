import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/adaptive_sheet.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/identity_version.dart';
import '../../../models/user_profile.dart';

/// Opens the identity growth timeline.
Future<void> showIdentityHistorySheet(
  BuildContext context, {
  required UserProfile profile,
}) {
  return showAdaptiveSheet<void>(
    context: context,
    builder: (_) => _IdentityHistorySheet(profile: profile),
  );
}

class _IdentityHistorySheet extends StatelessWidget {
  final UserProfile profile;

  const _IdentityHistorySheet({required this.profile});

  @override
  Widget build(BuildContext context) {
    final history = [...profile.identityHistory]
      ..sort((a, b) {
        final aDate = DateTime.tryParse(a.createdAt);
        final bDate = DateTime.tryParse(b.createdAt);
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

    final current = profile.identityStatement.trim();
    if (current.isNotEmpty &&
        (history.isEmpty || history.first.statement != current)) {
      history.insert(
        0,
        IdentityVersion(
          statement: current,
          createdAt: profile.lastIdentityEvolvedAt ??
              DateTime.now().toIso8601String(),
          source: 'evolved',
          rationale: '',
        ),
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollCtrl) => SingleChildScrollView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPaddingH,
          AppSpacing.md,
          AppSpacing.screenPaddingH,
          AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              AppStrings.identityHistoryTitle,
              style: AppTextStyles.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (history.isEmpty)
              const EmptyState(
                icon: Icons.timeline_rounded,
                title: AppStrings.identityHistoryEmpty,
                subtitle: '',
              )
            else
              ...history.asMap().entries.map((entry) {
                final i = entry.key;
                final version = entry.value;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: i < history.length - 1 ? AppSpacing.md : 0,
                  ),
                  child: _HistoryTile(
                    version: version,
                    isCurrent: i == 0,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final IdentityVersion version;
  final bool isCurrent;

  const _HistoryTile({
    required this.version,
    required this.isCurrent,
  });

  String _formatDate(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return '';
    return DateFormat.yMMMd().format(parsed.toLocal());
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'onboarding':
        return 'Onboarding';
      case 'manual':
        return 'Manual edit';
      case 'evolved':
      default:
        return isCurrent ? 'Current' : 'Evolved';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _formatDate(version.createdAt),
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textMuted),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppColors.primaryContainer
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(
                    color: isCurrent ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Text(
                  _sourceLabel(version.source),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: isCurrent ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            version.statement,
            style: AppTextStyles.bodyLarge.copyWith(
              fontStyle: FontStyle.italic,
              height: 1.5,
              color: isCurrent
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
            ),
          ),
          if (version.rationale.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              version.rationale,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
