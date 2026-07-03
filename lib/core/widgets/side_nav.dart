import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_strings.dart';
import '../constants/app_text_styles.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';

/// Persistent left navigation rail shown on wide (tablet/desktop/web) layouts
/// in place of the floating bottom pill. Mirrors the same four destinations
/// plus a prominent Coach call-to-action and a personalized account footer.
class SideNav extends ConsumerWidget {
  final String location;

  const SideNav({super.key, required this.location});

  static const _items = [
    _SideNavDestination(
      path: '/dashboard',
      icon: Icons.home_rounded,
      label: AppStrings.navDashboard,
    ),
    _SideNavDestination(
      path: '/actions',
      icon: Icons.track_changes_rounded,
      label: AppStrings.navActions,
    ),
    _SideNavDestination(
      path: '/journal',
      icon: Icons.menu_book_rounded,
      label: AppStrings.navJournal,
    ),
    _SideNavDestination(
      path: '/mindset',
      icon: Icons.auto_awesome_rounded,
      label: AppStrings.navMindset,
    ),
  ];

  bool _isSelected(String path) => location.startsWith(path);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;

    return Container(
      width: AppSpacing.sideNavWidth,
      decoration: const BoxDecoration(
        // Subtle top-to-bottom fall-off gives the rail depth instead of a flat
        // slab, echoing the app's elevated-surface language.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.surface, AppColors.background],
        ),
        border: Border(
          right: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Stack(
        children: [
          // Faint violet glow behind the brand lockup — the same ambient light
          // used across the auth/dashboard surfaces.
          const Positioned(
            top: -70,
            left: -40,
            right: -40,
            height: 220,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 0.9,
                  colors: [AppColors.primaryGlow, Color(0x000A0A0F)],
                ),
              ),
            ),
          ),
          SafeArea(
            right: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.lg),
                const _Wordmark()
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideX(begin: -0.1, end: 0, duration: 400.ms),
                const SizedBox(height: AppSpacing.xl),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: _CoachCta(
                    selected: _isSelected('/chat'),
                    onTap: () => context.go('/chat'),
                  ).animate().fadeIn(delay: 80.ms, duration: 400.ms),
                ),
                const SizedBox(height: AppSpacing.lg),
                ..._items.asMap().entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs / 2,
                        ),
                        child: _SideNavItem(
                          icon: e.value.icon,
                          label: e.value.label,
                          selected: _isSelected(e.value.path),
                          onTap: () => context.go(e.value.path),
                        )
                            .animate()
                            .fadeIn(
                              delay: (140 + e.key * 60).ms,
                              duration: 300.ms,
                            )
                            .slideX(
                              begin: -0.06,
                              end: 0,
                              delay: (140 + e.key * 60).ms,
                              duration: 300.ms,
                            ),
                      ),
                    ),
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Divider(
                    height: AppSpacing.lg,
                    thickness: 1,
                    color: AppColors.borderSubtle,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: _UserFooter(
                    profile: profile,
                    selected: _isSelected('/settings'),
                    onTap: () => context.push('/settings'),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Brand lockup: the real app icon in a lit rounded chip beside the wordmark,
/// with a small product descriptor underneath.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 16,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: Image.asset(
                'assets/images/app_icon.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: AppStrings.appNamePrefix,
                        style: AppTextStyles.headlineSmall,
                      ),
                      TextSpan(
                        text: AppStrings.appNameAccent,
                        style: AppTextStyles.headlineSmall
                            .copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  AppStrings.appDescriptor,
                  style: AppTextStyles.overline.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Prominent gradient call-to-action that opens the full coach chat. Carries a
/// persistent glow so it always reads as the rail's hero action.
class _CoachCta extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _CoachCta({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGlow,
            blurRadius: selected ? 24 : 14,
            spreadRadius: selected ? 1 : -3,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md - 2,
              ),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      AppStrings.navCoach,
                      style: AppTextStyles.labelLarge
                          .copyWith(color: Colors.white),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white.withValues(alpha: 0.85),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SideNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SideNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        hoverColor: AppColors.surfaceElevated,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: AppColors.primaryGlow,
                      blurRadius: 16,
                      spreadRadius: -4,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Left accent bar — the clearest active-state signal.
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 3,
                height: 22,
                margin: const EdgeInsets.only(right: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Icon chip.
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.20)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(icon, size: AppSpacing.iconMd, color: color),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.labelLarge.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
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

/// Account entry point pinned to the bottom of the rail. Shows the signed-in
/// user's first name (premium apps anchor the rail with identity); falls back
/// to a plain Settings row while the profile resolves.
class _UserFooter extends StatelessWidget {
  final UserProfile? profile;
  final bool selected;
  final VoidCallback onTap;

  const _UserFooter({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        hoverColor: AppColors.surfaceElevated,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile?.firstName.isNotEmpty == true
                          ? profile!.firstName
                          : AppStrings.navSettings,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelLarge
                          .copyWith(color: AppColors.textPrimary),
                    ),
                    if (profile?.firstName.isNotEmpty == true)
                      Text(
                        AppStrings.navSettings,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted),
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.settings_rounded,
                color: AppColors.textMuted,
                size: AppSpacing.iconMd,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideNavDestination {
  final String path;
  final IconData icon;
  final String label;

  const _SideNavDestination({
    required this.path,
    required this.icon,
    required this.label,
  });
}
