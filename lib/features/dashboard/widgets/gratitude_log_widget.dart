import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../models/user_profile.dart';
import '../../../models/gratitude_entry.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/daily_completion_provider.dart';
import '../../../core/utils/app_date_utils.dart';

class GratitudeLogWidget extends ConsumerStatefulWidget {
  final UserProfile profile;

  const GratitudeLogWidget({super.key, required this.profile});

  @override
  ConsumerState<GratitudeLogWidget> createState() => _GratitudeLogWidgetState();
}

class _GratitudeLogWidgetState extends ConsumerState<GratitudeLogWidget> {
  final _controller = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid == null) return;

      final entry = GratitudeEntry(
        id: const Uuid().v4(),
        content: text,
        createdAt: DateTime.now(),
      );

      final updated = [...widget.profile.gratitudeLog, entry];
      await ref.read(firestoreServiceProvider).updateUserField(uid, {
        'gratitudeLog': updated.map((e) => e.toJson()).toList(),
      });

      await ref.read(dailyCompletionProvider.notifier).toggle('gratitudeLogged', true);
      _controller.clear();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recent = widget.profile.gratitudeLog.reversed.take(3).toList();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Row(
                children: [
                  const Icon(Icons.favorite_rounded, color: AppColors.error, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    AppStrings.gratitudeLog,
                    style: AppTextStyles.headlineSmall,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                AppStrings.gratitudePrompt,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Input row
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: AppTextStyles.bodyMedium,
                      cursorColor: AppColors.primary,
                      textInputAction: TextInputAction.done,
                      autofocus: true,
                      onSubmitted: (_) => _save(),
                      decoration: InputDecoration(
                        hintText: 'I am grateful for...',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.surfaceElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      : IconButton(
                          onPressed: _save,
                          icon: const Icon(Icons.send_rounded),
                          color: AppColors.primary,
                        ),
                ],
              ),
              // Recent entries
              if (recent.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: AppSpacing.md),
                ...recent.map(
                  (g) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.circle, size: 6, color: AppColors.textMuted),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            g.content,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          AppDateUtils.formatDateShort(g.createdAt),
                          style: AppTextStyles.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
