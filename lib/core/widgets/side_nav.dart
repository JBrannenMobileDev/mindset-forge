import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_strings.dart';
import '../constants/app_text_styles.dart';

/// Persistent left navigation rail shown on wide (tablet/desktop/web) layouts
/// in place of the floating bottom pill. Mirrors the same four destinations
/// plus a prominent Coach call-to-action and a Settings entry.
class SideNav extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      width: AppSpacing.sideNavWidth,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          right: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.lg),
            const _Wordmark(),
            const SizedBox(height: AppSpacing.xl),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
              ),
              child: _CoachCta(
                selected: _isSelected('/chat'),
                onTap: () => context.go('/chat'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            ..._items.map(
              (d) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs / 2,
                ),
                child: _SideNavItem(
                  icon: d.icon,
                  label: d.label,
                  selected: _isSelected(d.path),
                  onTap: () => context.go(d.path),
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
              ),
              child: _SideNavItem(
                icon: Icons.settings_rounded,
                label: AppStrings.navSettings,
                selected: _isSelected('/settings'),
                onTap: () => context.push('/settings'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child:
                const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
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
        ],
      ),
    );
  }
}

/// Prominent gradient call-to-action that opens the full coach chat.
class _CoachCta extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _CoachCta({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
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
            boxShadow: selected
                ? const [
                    BoxShadow(color: AppColors.primaryGlow, blurRadius: 16)
                  ]
                : null,
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
                Text(
                  AppStrings.navCoach,
                  style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
                ),
              ],
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
      color: selected ? AppColors.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        hoverColor: AppColors.surfaceElevated,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          child: Row(
            children: [
              Icon(icon, size: AppSpacing.iconMd, color: color),
              const SizedBox(width: AppSpacing.md),
              Text(
                label,
                style: AppTextStyles.labelLarge.copyWith(color: color),
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
