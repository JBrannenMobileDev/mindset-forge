import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/app_date_utils.dart';
import '../../providers/journal_provider.dart';

class JournalEntryDetailScreen extends ConsumerWidget {
  final String entryId;

  const JournalEntryDetailScreen({super.key, required this.entryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(journalEntriesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          entriesAsync.whenOrNull(
            data: (entries) {
              final entry = entries.where((e) => e.id == entryId).firstOrNull;
              if (entry == null) return null;
              return IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                onPressed: () async {
                  await ref.read(journalProvider.notifier).deleteEntry(entryId);
                  if (context.mounted) context.pop();
                },
              );
            },
          ) ?? const SizedBox.shrink(),
        ],
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => const Center(child: Text('Failed to load entry')),
        data: (entries) {
          final entry = entries.where((e) => e.id == entryId).firstOrNull;
          if (entry == null) {
            return Center(
              child: Text(
                'Entry not found',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.mode[0].toUpperCase() + entry.mode.substring(1),
                      style: AppTextStyles.overline.copyWith(color: AppColors.primary),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text('•', style: AppTextStyles.labelSmall),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      AppDateUtils.formatDate(entry.createdAt),
                      style: AppTextStyles.labelSmall,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text('•', style: AppTextStyles.labelSmall),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      AppDateUtils.formatTime(entry.createdAt),
                      style: AppTextStyles.labelSmall,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                if (entry.prompt.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: Text(
                      entry.prompt,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                Text(
                  entry.content,
                  style: AppTextStyles.bodyLarge.copyWith(height: 1.8),
                ),
                if (entry.limitingBeliefsShifted.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Text('Beliefs Shifted', style: AppTextStyles.labelLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: entry.limitingBeliefsShifted.map((b) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        b,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondary),
                      ),
                    )).toList(),
                  ),
                ],
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }
}
