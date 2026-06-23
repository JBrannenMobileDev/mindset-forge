import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../models/user_profile.dart';
import '../../../models/evidence_entry.dart';
import '../../../providers/auth_provider.dart';

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

      _controller.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evidence logged! Keep building that identity.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.errorGeneric)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionHeader(title: AppStrings.evidenceLog),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: AppColors.warning, size: 16),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      AppStrings.evidencePrompt,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _controller,
                maxLines: 3,
                style: AppTextStyles.bodyMedium,
                cursorColor: AppColors.primary,
                decoration: InputDecoration(
                  hintText: 'I showed up for...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surface,
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
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      )
                    : TextButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Log Evidence'),
                        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
