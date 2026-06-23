import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../core/widgets/shimmer_widget.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../core/widgets/empty_state.dart';
import 'blueprint_tab.dart';
import 'affirmations_tab.dart';
import 'alignment_tab.dart';
import 'mindset_progress_tab.dart';

class MindsetScreen extends ConsumerStatefulWidget {
  const MindsetScreen({super.key});

  @override
  ConsumerState<MindsetScreen> createState() => _MindsetScreenState();
}

class _MindsetScreenState extends ConsumerState<MindsetScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Jump to the requested tab after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final tabParam =
          GoRouterState.of(context).uri.queryParameters['tab'];
      final tabIndex = int.tryParse(tabParam ?? '') ?? 0;
      if (tabIndex > 0 && tabIndex < 4) {
        _tabController.animateTo(tabIndex);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ResponsiveLayout(
          maxWidth: 680,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPaddingH,
                  AppSpacing.lg,
                  AppSpacing.screenPaddingH,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Text(AppStrings.mindset,
                        style: AppTextStyles.headlineLarge),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPaddingH),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: const [
                    Tab(text: AppStrings.blueprint),
                    Tab(text: AppStrings.affirmations),
                    Tab(text: AppStrings.alignment),
                    Tab(text: AppStrings.progress),
                  ],
                ),
              ),
              Expanded(
                child: profileAsync.when(
                  loading: () => const Padding(
                    padding:
                        EdgeInsets.all(AppSpacing.screenPaddingH),
                    child: ShimmerList(count: 3),
                  ),
                  error: (_, __) => const ErrorState(
                    message: 'Failed to load mindset data.',
                  ),
                  data: (profile) => profile == null
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary))
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            BlueprintTab(profile: profile),
                            AffirmationsTab(profile: profile),
                            AlignmentTab(profile: profile),
                            MindsetProgressTab(profile: profile),
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
