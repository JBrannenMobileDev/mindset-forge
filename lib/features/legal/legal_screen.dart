import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/legal_content.dart';
import '../../core/widgets/responsive_layout.dart';

/// Renders a long-form legal document (Terms of Service or Privacy Policy).
class LegalScreen extends StatelessWidget {
  final String title;
  final List<LegalSection> sections;

  const LegalScreen({
    super.key,
    required this.title,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(title, style: AppTextStyles.headlineMedium),
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveLayout(
          maxWidth: 680,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPaddingH,
              AppSpacing.md,
              AppSpacing.screenPaddingH,
              100,
            ),
            children: [
              Text(
                '${AppStrings.legalEffectivePrefix}${LegalContent.effectiveDate}',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              ...sections.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.heading, style: AppTextStyles.headlineSmall),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        s.body,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
