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
import 'blueprint_tab.dart';

/// Pushed detail screen for the Mindset Blueprint (radar, traits, beliefs,
/// fears, AI analysis). Reached from the Mindset hub.
class BlueprintScreen extends ConsumerWidget {
  const BlueprintScreen({super.key});

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
        title: Text(AppStrings.blueprint, style: AppTextStyles.headlineMedium),
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
                const ErrorState(message: 'Failed to load blueprint data.'),
            data: (profile) => profile == null
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary))
                : BlueprintTab(profile: profile),
          ),
        ),
      ),
    );
  }
}
