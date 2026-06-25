import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../core/widgets/shimmer_widget.dart';
import '../../providers/auth_provider.dart';
import 'affirmations_tab.dart';

/// Pushed detail screen for Affirmations (morning/evening sessions, list,
/// add/generate). Reached from the Mindset hub.
class AffirmationsScreen extends ConsumerWidget {
  const AffirmationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title:
            Text(AppStrings.affirmations, style: AppTextStyles.headlineMedium),
      ),
      body: SafeArea(
        bottom: false,
        child: ResponsiveLayout(
          maxWidth: 680,
          child: profileAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.screenPaddingH),
              child: ShimmerList(count: 3),
            ),
            error: (_, __) =>
                const ErrorState(message: 'Failed to load affirmations.'),
            data: (profile) => profile == null
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary))
                : AffirmationsTab(profile: profile),
          ),
        ),
      ),
    );
  }
}
