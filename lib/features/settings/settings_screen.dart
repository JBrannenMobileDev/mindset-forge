import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/firebase/accountability_service.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/widget_education_sheet.dart';
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
      final insight =
          await ref.read(claudeServiceProvider).generateMindsetSummary(profile);
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
        title: Text('Delete Account',
            style: AppTextStyles.headlineSmall
                .copyWith(color: AppColors.error)),
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _isDeletingAccount = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Failed to delete account. Please try again.')),
      );
    }
  }

  Future<void> _restorePurchases() async {
    try {
      final info = await Purchases.restorePurchases();
      final isActive =
          info.entitlements.all['premium']?.isActive ?? false;
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
    final journalPref = profile?.journalPreference ?? 'both';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text('Settings', style: AppTextStyles.headlineMedium),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPaddingH,
          AppSpacing.md,
          AppSpacing.screenPaddingH,
          100,
        ),
        children: [
          // ── Profile ──────────────────────────────────────────────
          if (profile != null)
            _ProfileCard(profile: profile).animate().fadeIn(),
          if (profile != null) const SizedBox(height: AppSpacing.sectionGap),

          // ── Subscription ─────────────────────────────────────────
          const _GroupLabel('Subscription'),
          _SettingsCard(
            children: [
              _CardRow(
                icon: Icons.star_rounded,
                iconColor: AppColors.warning,
                title: 'Manage Subscription',
                subtitle: 'View plan, billing, and cancellation',
                onTap: () => context.push('/pricing?source=settings'),
              ),
              const _CardDivider(),
              _CardRow(
                icon: Icons.restore_rounded,
                iconColor: AppColors.primary,
                title: 'Restore Purchases',
                subtitle: 'Recover a previous subscription',
                onTap: _restorePurchases,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Preferences ──────────────────────────────────────────
          const _GroupLabel('Preferences'),
          _SettingsCard(
            children: [
              _CardRow(
                icon: Icons.wb_twilight_rounded,
                iconColor: AppColors.categoryPersonalGrowth,
                title: 'Journal Time',
                subtitle: _journalPrefLabel(journalPref),
                trailing: _isSavingPreference
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      )
                    : _ValueChip(text: _journalPrefLabel(journalPref)),
                onTap: () => _pickJournalPreference(journalPref),
              ),
              const _CardDivider(),
              _CardRow(
                icon: Icons.notifications_rounded,
                iconColor: AppColors.primary,
                title: 'Notifications',
                subtitle: 'Reminders, streak alerts, and quiet hours',
                onTap: () => context.push('/notification-settings'),
              ),
              const _CardDivider(),
              _CardRow(
                icon: Icons.widgets_outlined,
                iconColor: AppColors.secondary,
                title: 'Home Screen Widget',
                subtitle: "Add Today's Focus to your home screen",
                onTap: () => showWidgetEducationSheet(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Practice ─────────────────────────────────────────────
          const _GroupLabel('Practice'),
          _SettingsCard(
            children: [
              _CardRow(
                icon: Icons.show_chart_rounded,
                iconColor: AppColors.primary,
                title: 'My Progress',
                subtitle: 'Streaks, milestones, and activity heatmap',
                onTap: () => context.push('/progress'),
              ),
              const _CardDivider(),
              _CardRow(
                icon: Icons.self_improvement_rounded,
                iconColor: AppColors.secondary,
                title: 'Future Self Practice',
                subtitle: 'Visualization scripts and timed sessions',
                onTap: () => context.push('/future-self'),
              ),
              const _CardDivider(),
              _CardRow(
                icon: Icons.psychology_alt_rounded,
                iconColor: AppColors.categoryPersonalGrowth,
                title: 'Deep Dive Assessment',
                subtitle: '5 self-discovery modules with AI insights',
                onTap: () => context.push('/deep-dive'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Accountability ────────────────────────────────────────
          const _GroupLabel('Accountability'),
          _SettingsCard(
            children: [
              _CardRow(
                icon: Icons.people_rounded,
                iconColor: AppColors.categoryRelationships,
                title: 'My Partnerships',
                subtitle: 'Invite and manage accountability partners',
                onTap: () => context.push('/accountability'),
              ),
              const _CardDivider(),
              _CardRow(
                icon: Icons.mail_outline_rounded,
                iconColor: AppColors.secondary,
                title: 'Partner Messages',
                subtitle: 'Encouragement your partners have sent',
                onTap: () => context.push('/notifications'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Coaching ─────────────────────────────────────────────
          const _GroupLabel('Coaching'),
          _SettingsCard(
            children: [
              _CardRow(
                icon: Icons.auto_awesome_rounded,
                iconColor: AppColors.primary,
                title: 'Refresh Mindset Blueprint',
                subtitle: 'Re-analyze your mindset with fresh AI insights',
                trailing: _isRefreshingBlueprint
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      )
                    : null,
                onTap: _isRefreshingBlueprint ? null : _refreshBlueprint,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Account ───────────────────────────────────────────────
          const _GroupLabel('Account'),
          _SettingsCard(
            borderColor: AppColors.error.withValues(alpha: 0.2),
            children: [
              _CardRow(
                icon: Icons.logout_rounded,
                iconColor: AppColors.error,
                title: AppStrings.logout,
                titleColor: AppColors.error,
                onTap: () =>
                    ref.read(authNotifierProvider.notifier).signOut(),
              ),
              const _CardDivider(),
              _CardRow(
                icon: Icons.delete_forever_rounded,
                iconColor: AppColors.error,
                title: 'Delete Account',
                titleColor: AppColors.error,
                subtitle: 'Permanently removes all your data',
                trailing: _isDeletingAccount
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.error),
                      )
                    : null,
                onTap: _isDeletingAccount ? null : _deleteAccount,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  String _journalPrefLabel(String pref) => switch (pref) {
        'morning' => 'Morning',
        'evening' => 'Evening',
        _ => 'AM & PM',
      };
}

// ─── Profile card ─────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final dynamic profile;
  const _ProfileCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final status = profile.subscriptionStatus as String;
    final color = _statusColor(status);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary]),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                (profile.firstName as String)[0].toUpperCase(),
                style: AppTextStyles.headlineLarge
                    .copyWith(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.displayName as String,
                    style: AppTextStyles.headlineSmall),
                Text(
                  profile.email as String,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Text(
                    _statusLabel(status),
                    style: AppTextStyles.labelSmall.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String s) => switch (s) {
        'active' => '✓ PREMIUM',
        'trialing' => '✓ TRIAL',
        'canceled' => 'CANCELED',
        'past_due' => 'PAST DUE',
        _ => 'FREE',
      };

  Color _statusColor(String s) => switch (s) {
        'active' || 'trialing' => AppColors.primary,
        'canceled' || 'past_due' || 'expired' => AppColors.error,
        _ => AppColors.textMuted,
      };
}

// ─── Shared card primitives ────────────────────────────────────────────────

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(text.toUpperCase(), style: AppTextStyles.overline),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  final Color? borderColor;

  const _SettingsCard({required this.children, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      borderColor: borderColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.cardPadding),
        child: Column(children: children),
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(color: AppColors.borderSubtle, height: 1);
}

class _CardRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Color? titleColor;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _CardRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.titleColor,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: titleColor ?? AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            trailing ??
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ValueChip extends StatelessWidget {
  final String text;
  const _ValueChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        text,
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
      ),
    );
  }
}
