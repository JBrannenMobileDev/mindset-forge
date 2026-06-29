import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../models/user_profile.dart';
import '../../../models/evidence_entry.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/daily_completion_provider.dart';
import '../../../providers/future_self_provider.dart';

class EvidenceLogWidget extends ConsumerStatefulWidget {
  final UserProfile profile;

  const EvidenceLogWidget({super.key, required this.profile});

  @override
  ConsumerState<EvidenceLogWidget> createState() => _EvidenceLogWidgetState();
}

class _EvidenceLogWidgetState extends ConsumerState<EvidenceLogWidget> {
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

      final entry = EvidenceEntry(
        id: const Uuid().v4(),
        content: text,
        createdAt: DateTime.now(),
      );

      final updated = [...widget.profile.evidenceLog, entry];
      await ref.read(firestoreServiceProvider).updateUserField(uid, {
        'evidenceLog': updated.map((e) => e.toJson()).toList(),
      });
      if (!mounted) return;

      await ref
          .read(dailyCompletionProvider.notifier)
          .toggle('evidenceLogged', true);
      _controller.clear();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.errorGeneric)),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recent = widget.profile.evidenceLog.reversed.take(3).toList();
    final identity = widget.profile.identityStatement.trim();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // When a Future Self practice exists, anchor the log to today's rotating
    // trait ("act like someone who is ...") instead of the generic identity
    // statement. Falls back to the identity statement otherwise.
    final trait = ref.watch(embodimentTraitTodayProvider);
    final hasTrait = trait != null && trait.isNotEmpty;
    final anchorAccent =
        hasTrait ? AppColors.futureSelfAccent : AppColors.secondary;
    final anchorLabel = hasTrait
        ? AppStrings.evidenceTraitLabel
        : AppStrings.evidenceIdentityLabel;
    final anchorBody = hasTrait ? 'Someone who is $trait.' : identity;
    final showAnchor = hasTrait || identity.isNotEmpty;
    final prompt = hasTrait
        ? AppStrings.evidenceTraitPrompt.replaceFirst('{trait}', trait)
        : AppStrings.evidencePrompt;

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
                  Icon(
                    hasTrait
                        ? Icons.auto_awesome_rounded
                        : Icons.nightlight_round,
                    color: anchorAccent,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    AppStrings.evidenceLog,
                    style: AppTextStyles.headlineSmall,
                  ),
                ],
              ),
              // Anchor context block (future-self trait, or identity statement)
              if (showAnchor) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        anchorLabel.toUpperCase(),
                        style: AppTextStyles.labelSmall.copyWith(
                          color: anchorAccent,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        anchorBody,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          fontStyle: FontStyle.italic,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                prompt,
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              // Input row
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: AppTextStyles.bodyMedium,
                      cursorColor: AppColors.primary,
                      maxLines: 4,
                      minLines: 3,
                      autofocus: true,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: AppStrings.evidenceHint,
                        hintStyle: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.surfaceElevated,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMd),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 1.5),
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
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary),
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
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.circle, size: 6, color: AppColors.textMuted),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            e.content,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          AppDateUtils.formatDateShort(e.createdAt),
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
