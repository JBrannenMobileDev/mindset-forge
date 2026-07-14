import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/adaptive_sheet.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../models/user_profile.dart';
import '../../../providers/identity_provider.dart';

/// Opens the AI identity evolution review flow.
Future<void> showIdentityEvolveSheet(
  BuildContext context,
  WidgetRef ref, {
  required UserProfile profile,
}) {
  return showAdaptiveSheet<void>(
    context: context,
    builder: (sheetCtx) => _IdentityEvolveSheet(profile: profile),
  );
}

class _IdentityEvolveSheet extends ConsumerStatefulWidget {
  final UserProfile profile;

  const _IdentityEvolveSheet({required this.profile});

  @override
  ConsumerState<_IdentityEvolveSheet> createState() =>
      _IdentityEvolveSheetState();
}

class _IdentityEvolveSheetState extends ConsumerState<_IdentityEvolveSheet> {
  bool _loading = true;
  bool _saving = false;
  bool _editing = false;
  String? _error;
  String _proposed = '';
  String _rationale = '';
  late final TextEditingController _editCtrl;

  @override
  void initState() {
    super.initState();
    _editCtrl = TextEditingController();
    _loadProposal();
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProposal() async {
    setState(() {
      _loading = true;
      _error = null;
      _editing = false;
    });
    try {
      final result =
          await ref.read(identityProvider.notifier).proposeEvolution();
      if (!mounted) return;
      setState(() {
        _proposed = result.statement;
        _rationale = result.rationale;
        _editCtrl.text = result.statement;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = AppStrings.errorGeneric;
        _loading = false;
      });
    }
  }

  Future<void> _accept(String statement) async {
    setState(() => _saving = true);
    try {
      await ref.read(identityProvider.notifier).acceptEvolution(
            statement,
            source: 'evolved',
            rationale: _rationale,
          );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.errorGeneric),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.profile.identityStatement.trim();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
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
              AppStrings.identityEvolveTitle,
              style: AppTextStyles.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_loading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: Center(
                  child: Column(
                    children: [
                      const CircularProgressIndicator(color: AppColors.primary),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        AppStrings.identityEvolveLoading,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else if (_error != null)
              Center(
                child: Column(
                  children: [
                    Text(
                      _error!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppSecondaryButton(
                      label: AppStrings.identityEvolveTryAgain,
                      onPressed: _loadProposal,
                    ),
                  ],
                ),
              )
            else ...[
              if (current.isNotEmpty) ...[
                Text(
                  AppStrings.identityEvolveCurrentLabel,
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: Text(
                    current,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              Text(
                AppStrings.identityEvolveProposedLabel,
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_editing)
                TextField(
                  controller: _editCtrl,
                  autofocus: true,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppTextStyles.bodyMedium,
                  cursorColor: AppColors.primary,
                  decoration: InputDecoration(
                    hintText: AppStrings.identityStatementHint,
                    hintStyle: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                )
              else
                AppGlowCard(
                  glowColor: AppColors.primaryGlow,
                  child: Text(
                    _proposed,
                    style: AppTextStyles.headlineSmall.copyWith(
                      height: 1.5,
                    ),
                  ),
                ),
              if (_rationale.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  AppStrings.identityEvolveRationaleLabel,
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _rationale,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              AppPrimaryButton(
                label: AppStrings.identityEvolveUseThis,
                isLoading: _saving,
                onPressed: _saving
                    ? null
                    : () => _accept(
                          _editing ? _editCtrl.text.trim() : _proposed,
                        ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (!_editing)
                AppSecondaryButton(
                  label: AppStrings.identityEvolveEdit,
                  onPressed: _saving
                      ? null
                      : () => setState(() => _editing = true),
                ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: AppTextButton(
                      label: AppStrings.identityEvolveKeepCurrent,
                      color: AppColors.textSecondary,
                      onPressed: _saving ? null : () => Navigator.pop(context),
                    ),
                  ),
                  Expanded(
                    child: AppTextButton(
                      label: AppStrings.identityEvolveTryAgain,
                      onPressed: _saving ? null : _loadProposal,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
