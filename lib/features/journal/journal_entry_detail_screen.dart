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

  String _moodEmoji(String mood) {
    return switch (mood) {
      'amazing' => '🤩',
      'good' => '😊',
      'okay' => '😐',
      'struggling' => '😟',
      'low' => '😔',
      _ => '😐',
    };
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.scrim,
      builder: (_) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          side: BorderSide(color: AppColors.error.withValues(alpha: 0.25)),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.delete_outline_rounded,
                  color: AppColors.error, size: 32),
              const SizedBox(height: AppSpacing.md),
              Text('Delete Entry?', style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'This entry will be permanently deleted.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                      ),
                      child: Text('Cancel',
                          style: AppTextStyles.labelLarge
                              .copyWith(color: AppColors.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                      ),
                      child: Text('Delete',
                          style: AppTextStyles.labelLarge
                              .copyWith(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(journalProvider.notifier).deleteEntry(entryId);
      if (context.mounted) context.pop();
    }
  }

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
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.error),
                onPressed: () => _confirmDelete(context, ref),
              );
            },
          ) ?? const SizedBox.shrink(),
        ],
      ),
      body: entriesAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => const Center(child: Text('Failed to load entry')),
        data: (entries) {
          final entry = entries.where((e) => e.id == entryId).firstOrNull;
          if (entry == null) {
            return Center(
              child: Text(
                'Entry not found',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header row ─────────────────────────────────────────
                Row(
                  children: [
                    Text(
                      entry.mode[0].toUpperCase() + entry.mode.substring(1),
                      style: AppTextStyles.overline
                          .copyWith(color: AppColors.primary),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(_moodEmoji(entry.mood),
                        style: const TextStyle(fontSize: 14)),
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

                // ── AI prompt ──────────────────────────────────────────
                if (entry.prompt.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
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

                // ── Entry content ──────────────────────────────────────
                Text(
                  entry.content,
                  style: AppTextStyles.bodyLarge.copyWith(height: 1.8),
                ),

                // ── Beliefs shifted ────────────────────────────────────
                if (entry.limitingBeliefsShifted.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Text('Beliefs Shifted', style: AppTextStyles.labelLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: entry.limitingBeliefsShifted
                        .map((b) => _TagPill(
                              label: b,
                              color: AppColors.secondary,
                              bgColor: AppColors.secondaryContainer,
                            ))
                        .toList(),
                  ),
                ],

                // ── Fears outwitted ────────────────────────────────────
                if (entry.fearsOutwitted.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      const Icon(Icons.bolt_rounded,
                          color: AppColors.warning, size: 16),
                      const SizedBox(width: 4),
                      Text('Fears Outwitted',
                          style: AppTextStyles.labelLarge),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: entry.fearsOutwitted
                        .map((f) => _TagPill(
                              label: f,
                              color: AppColors.warning,
                              bgColor:
                                  AppColors.warning.withValues(alpha: 0.12),
                            ))
                        .toList(),
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

class _TagPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;

  const _TagPill({
    required this.label,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(color: color),
      ),
    );
  }
}
