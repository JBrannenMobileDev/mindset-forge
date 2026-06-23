import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/app_button.dart';
import '../../models/future_self_setup.dart';
import '../../providers/auth_provider.dart';

class FutureSelfSetupScreen extends ConsumerStatefulWidget {
  const FutureSelfSetupScreen({super.key});

  @override
  ConsumerState<FutureSelfSetupScreen> createState() =>
      _FutureSelfSetupScreenState();
}

class _FutureSelfSetupScreenState extends ConsumerState<FutureSelfSetupScreen> {
  final _lifeCtrl = TextEditingController();
  final _goalsCtrl = TextEditingController();
  final _identityCtrl = TextEditingController();
  final _behaviorsCtrl = TextEditingController();
  int _timeframe = 5;
  bool _isSaving = false;

  @override
  void dispose() {
    _lifeCtrl.dispose();
    _goalsCtrl.dispose();
    _identityCtrl.dispose();
    _behaviorsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_lifeCtrl.text.trim().isEmpty || _identityCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in the required fields.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid == null) return;

      final behaviors = _behaviorsCtrl.text
          .split('\n')
          .map((b) => b.trim())
          .where((b) => b.isNotEmpty)
          .toList();

      final setup = FutureSelfSetup(
        timeframeYears: _timeframe,
        lifeDescription: _lifeCtrl.text.trim(),
        goalsAchieved: _goalsCtrl.text.trim(),
        evolvedIdentity: _identityCtrl.text.trim(),
        coreBehaviors: behaviors,
        createdAt: DateTime.now(),
      );

      await ref.read(firestoreServiceProvider).updateUserField(uid, {
        'futureSelfSetup': setup.toJson(),
      });

      if (mounted) Navigator.pop(context);
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
    return Scaffold(
      backgroundColor: AppColors.futureSelfBackground,
      appBar: AppBar(
        backgroundColor: AppColors.futureSelfBackground,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.futureSelfAccent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppStrings.futureSelfSetupTitle,
          style: AppTextStyles.headlineSmall.copyWith(color: AppColors.futureSelfAccent),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.futureSelfSetupSubtitle,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(AppStrings.futureSelfTimeframe, style: AppTextStyles.labelLarge),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [5, 10, 20].map((y) {
                final sel = y == _timeframe;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: GestureDetector(
                    onTap: () => setState(() => _timeframe = y),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: sel
                            ? AppColors.futureSelfAccent.withValues(alpha: 0.15)
                            : AppColors.futureSelfSurface,
                        border: Border.all(
                          color: sel ? AppColors.futureSelfAccent : AppColors.border,
                        ),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      ),
                      child: Text(
                        '$y years',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: sel ? AppColors.futureSelfAccent : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xl),
            _FutureSelfField(
              label: AppStrings.futureSelfLifeDescription,
              hint: 'Describe a typical day in your future life...',
              controller: _lifeCtrl,
              maxLines: 4,
            ),
            const SizedBox(height: AppSpacing.md),
            _FutureSelfField(
              label: AppStrings.futureSelfGoalsAchieved,
              hint: 'What have you accomplished?',
              controller: _goalsCtrl,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.md),
            _FutureSelfField(
              label: AppStrings.futureSelfEvolvedIdentity,
              hint: 'Who have you become?',
              controller: _identityCtrl,
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.md),
            _FutureSelfField(
              label: '${AppStrings.futureSelfBehaviors} (one per line)',
              hint: 'I wake up at 5am\nI meditate daily\nI take bold action',
              controller: _behaviorsCtrl,
              maxLines: 5,
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppPrimaryButton(
              label: 'Meet My Future Self',
              onPressed: _isSaving ? null : _save,
              isLoading: _isSaving,
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _FutureSelfField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;

  const _FutureSelfField({
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelLarge.copyWith(color: AppColors.futureSelfAccent)),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: AppTextStyles.bodyMedium,
          cursorColor: AppColors.futureSelfAccent,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.futureSelfSurface,
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
              borderSide: const BorderSide(color: AppColors.futureSelfAccent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
