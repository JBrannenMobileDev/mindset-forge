import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/firebase/accountability_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/auth_notifier.dart';
import '../../providers/claude_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isRefreshingBlueprint = false;
  bool _isDeletingAccount = false;
  bool _isSavingPreference = false;

  Future<void> _pickJournalPreference(String current) async {
    final options = [
      ('morning', 'Morning', 'Journal appears in the AM routine'),
      ('evening', 'Evening', 'Journal appears in the PM routine'),
      ('both', 'Both', 'Journal appears in AM and PM'),
    ];

    final result = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPaddingH, 0,
                    AppSpacing.screenPaddingH, AppSpacing.md),
                child: Text('Journal Time Preference',
                    style: AppTextStyles.headlineSmall),
              ),
              ...options.map((o) => ListTile(
                    title: Text(o.$2),
                    subtitle: Text(o.$3,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary)),
                    trailing: current == o.$1
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.primary)
                        : null,
                    onTap: () => Navigator.pop(context, o.$1),
                  )),
            ],
          ),
        ),
      ),
    );

    if (result == null || result == current) return;

    setState(() => _isSavingPreference = true);
    try {
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid != null) {
        await ref
            .read(firestoreServiceProvider)
            .updateUserField(uid, {'journalPreference': result});
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save preference.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingPreference = false);
    }
  }

  Future<void> _refreshBlueprint() async {
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null) return;
    setState(() => _isRefreshingBlueprint = true);
    try {
      final insight = await ref.read(claudeServiceProvider).generateMindsetSummary(profile);
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid != null) {
        await ref.read(firestoreServiceProvider).updateUserField(uid, {
          'mindsetBlueprintSummary': insight,
          'mindsetBlueprintRefreshedAt': DateTime.now().toIso8601String(),
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mindset blueprint refreshed!')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to refresh. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRefreshingBlueprint = false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text('Delete Account', style: AppTextStyles.headlineSmall.copyWith(color: AppColors.error)),
        content: Text(
          'This will permanently delete all your data including goals, habits, journal entries, and chat history. This action cannot be undone.',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeletingAccount = true);
    try {
      await ref.read(accountabilityServiceProvider).deleteUserAccount();
      // Auth state change will redirect to login automatically
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDeletingAccount = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete account. Please try again.')),
      );
    }
  }

  Future<void> _restorePurchases() async {
    try {
      final info = await Purchases.restorePurchases();
      final isActive = info.entitlements.all['premium']?.isActive ?? false;
      if (isActive) {
        final uid = ref.read(authStateProvider).valueOrNull?.uid;
        if (uid != null) {
          await ref.read(firestoreServiceProvider).updateUserField(uid, {
            'subscriptionStatus': 'active',
          });
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription restored!')),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active subscription found.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restore failed. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text('Settings', style: AppTextStyles.headlineMedium),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPaddingH,
          vertical: AppSpacing.lg,
        ),
        children: [
          // ── Profile card ─────────────────────────────────────────
          if (profile != null) ...[
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        profile.firstName[0].toUpperCase(),
                        style: AppTextStyles.headlineLarge.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.displayName, style: AppTextStyles.headlineSmall),
                        Text(
                          profile.email,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _subscriptionColor(profile.subscriptionStatus).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                          ),
                          child: Text(
                            _subscriptionLabel(profile.subscriptionStatus),
                            style: AppTextStyles.labelSmall.copyWith(
                              color: _subscriptionColor(profile.subscriptionStatus),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(),
            const SizedBox(height: AppSpacing.xl),
          ],

          // ── Subscription ────────────────────────────────────────
          _SectionTitle('Subscription'),
          _SettingsTile(
            icon: Icons.star_rounded,
            iconColor: AppColors.warning,
            title: 'Manage Subscription',
            subtitle: 'View plan, billing, and cancellation',
            onTap: () => context.push('/pricing'),
          ),
          const Divider(color: AppColors.border, height: 1),
          _SettingsTile(
            icon: Icons.restore_rounded,
            iconColor: AppColors.primary,
            title: 'Restore Purchases',
            subtitle: 'Recover a previous subscription',
            onTap: _restorePurchases,
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Preferences ─────────────────────────────────────────
          _SectionTitle('Preferences'),
          _SettingsTile(
            icon: Icons.wb_twilight_rounded,
            iconColor: AppColors.categoryPersonalGrowth,
            title: 'Journal Time',
            subtitle: _journalPrefLabel(profile?.journalPreference ?? 'both'),
            trailing: _isSavingPreference
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                : null,
            onTap: () =>
                _pickJournalPreference(profile?.journalPreference ?? 'both'),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Progress ────────────────────────────────────────────
          _SectionTitle('Progress'),
          _SettingsTile(
            icon: Icons.show_chart_rounded,
            iconColor: AppColors.primary,
            title: 'View Progress',
            subtitle: 'Streaks, milestones, and activity heatmap',
            onTap: () => context.push('/progress'),
          ),
          const Divider(color: AppColors.border, height: 1),
          _SettingsTile(
            icon: Icons.self_improvement_rounded,
            iconColor: AppColors.secondary,
            title: 'Future Self Practice',
            subtitle: 'Visualization scripts and timed sessions',
            onTap: () => context.push('/future-self'),
          ),
          const Divider(color: AppColors.border, height: 1),
          _SettingsTile(
            icon: Icons.psychology_alt_rounded,
            iconColor: AppColors.categoryPersonalGrowth,
            title: 'Deep Dive Assessment',
            subtitle: '5 self-discovery modules with personalized insights',
            onTap: () => context.push('/deep-dive'),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Partnerships ────────────────────────────────────────
          _SectionTitle('Accountability'),
          _SettingsTile(
            icon: Icons.people_rounded,
            iconColor: AppColors.categoryRelationships,
            title: 'My Partnerships',
            subtitle: 'Invite and manage accountability partners',
            onTap: () => context.push('/accountability'),
          ),
          const Divider(color: AppColors.border, height: 1),
          _SettingsTile(
            icon: Icons.notifications_rounded,
            iconColor: AppColors.primary,
            title: 'Notifications',
            subtitle: 'Reminders, streak alerts, and quiet hours',
            onTap: () => context.push('/notification-settings'),
          ),
          const Divider(color: AppColors.border, height: 1),
          _SettingsTile(
            icon: Icons.mail_outline_rounded,
            iconColor: AppColors.secondary,
            title: 'Partner Messages',
            subtitle: 'Encouragement your partners have sent',
            onTap: () => context.push('/notifications'),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Coaching ─────────────────────────────────────────────
          _SectionTitle('Coaching'),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 20),
            ),
            title: const Text('Refresh My Mindset Blueprint'),
            subtitle: const Text('Re-analyze your mindset with fresh insights'),
            trailing: _isRefreshingBlueprint
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            onTap: _isRefreshingBlueprint ? null : _refreshBlueprint,
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Account ─────────────────────────────────────────────
          _SectionTitle('Account'),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.error),
            title: Text(AppStrings.logout, style: const TextStyle(color: AppColors.error)),
            onTap: () => ref.read(authNotifierProvider.notifier).signOut(),
          ),
          const Divider(color: AppColors.border, height: 1),
          ListTile(
            leading: _isDeletingAccount
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error),
                  )
                : const Icon(Icons.delete_forever_rounded, color: AppColors.error),
            title: const Text('Delete Account', style: TextStyle(color: AppColors.error)),
            subtitle: const Text('Permanently delete all your data'),
            onTap: _isDeletingAccount ? null : _deleteAccount,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  String _journalPrefLabel(String pref) {
    return switch (pref) {
      'morning' => 'Morning only',
      'evening' => 'Evening only',
      _ => 'Morning & Evening',
    };
  }

  String _subscriptionLabel(String status) {
    return switch (status) {
      'active' => '✓ PREMIUM',
      'trialing' => '✓ TRIAL',
      'canceled' => 'CANCELED',
      'past_due' => 'PAST DUE',
      _ => 'FREE',
    };
  }

  Color _subscriptionColor(String status) {
    return switch (status) {
      'active' || 'trialing' => AppColors.primary,
      'canceled' || 'past_due' || 'expired' => AppColors.error,
      _ => AppColors.textMuted,
    };
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.overline,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
      ),
      trailing: trailing ??
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}
