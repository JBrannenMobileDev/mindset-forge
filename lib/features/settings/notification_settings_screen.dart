import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/app_card.dart';
import '../../models/notification_prefs.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  NotificationPrefs get _prefs => ref.read(notificationPrefsProvider);

  Future<void> _save(NotificationPrefs prefs) =>
      ref.read(notificationPrefsProvider.notifier).update(prefs);

  Future<bool> _ensurePermission() async {
    final service = ref.read(notificationServiceProvider);
    if (await service.hasPermission()) return true;
    final granted = await service.requestPermission();
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceElevated,
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Notifications are off for MindsetForge. Enable them in your device Settings.',
            style: AppTextStyles.bodySmall,
          ),
        ),
      );
    }
    return granted;
  }

  Future<void> _setMaster(bool value) async {
    if (value) await _ensurePermission();
    await _save(_prefs.copyWith(masterEnabled: value));
  }

  Future<void> _pickTime(
    String title,
    int currentMinutes,
    ValueChanged<int> onPicked,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: currentMinutes ~/ 60,
        minute: currentMinutes % 60,
      ),
      helpText: title,
    );
    if (picked == null) return;
    await _ensurePermission();
    onPicked(picked.hour * 60 + picked.minute);
  }

  String _fmt(int minutes) {
    final tod = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final m = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(notificationPrefsProvider);
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final hasPartners = (profile?.partnerUids.isNotEmpty ?? false) ||
        (profile?.accountabilityRelationships
                .any((r) => r.type == 'primary' && r.status == 'active') ??
            false);
    final on = prefs.masterEnabled;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text('Notifications', style: AppTextStyles.headlineMedium),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenPaddingH,
          AppSpacing.md,
          AppSpacing.screenPaddingH,
          100,
        ),
        children: [
          // ── Master toggle — full-width card at the top ────────────────
          _MasterCard(value: on, onChanged: _setMaster),
          const SizedBox(height: AppSpacing.sectionGap),

          // ── Daily routine ─────────────────────────────────────────────
          _GroupCard(
            icon: Icons.wb_sunny_rounded,
            iconColor: AppColors.warning,
            title: 'Daily Routine',
            disabled: !on,
            children: [
              _SwitchRow(
                label: 'Practice reminders',
                subtitle: 'Morning & evening nudges for unfinished practices',
                value: prefs.routineEnabled,
                enabled: on,
                onChanged: (v) => _save(prefs.copyWith(routineEnabled: v)),
              ),
              const _CardDivider(),
              _TimeRow(
                label: 'Morning reminder',
                time: _fmt(prefs.morningReminderMinutes),
                enabled: on && prefs.routineEnabled,
                onTap: () => _pickTime(
                  'Morning reminder',
                  prefs.morningReminderMinutes,
                  (m) => _save(prefs.copyWith(morningReminderMinutes: m)),
                ),
              ),
              const _CardDivider(),
              _TimeRow(
                label: 'Evening reminder',
                time: _fmt(prefs.eveningReminderMinutes),
                enabled: on && prefs.routineEnabled,
                onTap: () => _pickTime(
                  'Evening reminder',
                  prefs.eveningReminderMinutes,
                  (m) => _save(prefs.copyWith(eveningReminderMinutes: m)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Streak protection ─────────────────────────────────────────
          _GroupCard(
            icon: Icons.local_fire_department_rounded,
            iconColor: AppColors.error,
            title: 'Streak Protection',
            disabled: !on,
            children: [
              _SwitchRow(
                label: 'Streak alerts',
                subtitle: 'Last-chance nudge when your streak is at risk',
                value: prefs.streakEnabled,
                enabled: on,
                onChanged: (v) => _save(prefs.copyWith(streakEnabled: v)),
              ),
              const _CardDivider(),
              _TimeRow(
                label: 'Alert time',
                time: _fmt(prefs.streakReminderMinutes),
                enabled: on && prefs.streakEnabled,
                onTap: () => _pickTime(
                  'Streak alert time',
                  prefs.streakReminderMinutes,
                  (m) => _save(prefs.copyWith(streakReminderMinutes: m)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Accountability ────────────────────────────────────────────
          _GroupCard(
            icon: Icons.people_rounded,
            iconColor: AppColors.secondary,
            title: 'Accountability',
            disabled: !on,
            children: [
              _SwitchRow(
                label: 'Partner activity',
                subtitle: 'Encouragement and check-in nudges from partners',
                value: prefs.partnerEnabled,
                enabled: on,
                onChanged: (v) => _save(prefs.copyWith(partnerEnabled: v)),
              ),
              if (hasPartners) ...[
                const _CardDivider(),
                _SwitchRow(
                  label: 'Notify partner when I slip',
                  subtitle: 'Your partner gets a gentle nudge on a missed day',
                  value: prefs.notifyPartnerOnSlip,
                  enabled: on,
                  onChanged: (v) =>
                      _save(prefs.copyWith(notifyPartnerOnSlip: v)),
                ),
              ],
              const _CardDivider(),
              _NavRow(
                label: 'Partner messages',
                subtitle: 'View encouragement your partners have sent',
                onTap: () => context.push('/notifications'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Comeback nudges ───────────────────────────────────────────
          _GroupCard(
            icon: Icons.refresh_rounded,
            iconColor: AppColors.success,
            title: 'Comeback Nudges',
            disabled: !on,
            children: [
              _SwitchRow(
                label: 'Re-engagement reminders',
                subtitle: 'Occasional nudges when you have been away (max 4 total)',
                value: prefs.lifecycleEnabled,
                enabled: on,
                onChanged: (v) => _save(prefs.copyWith(lifecycleEnabled: v)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Quiet hours ───────────────────────────────────────────────
          _GroupCard(
            icon: Icons.bedtime_rounded,
            iconColor: AppColors.primary,
            title: 'Quiet Hours',
            subtitle: 'No reminders during this window — streak alerts can still fire.',
            disabled: !on,
            children: [
              _TimeRow(
                label: 'Start',
                time: _fmt(prefs.quietHoursStart),
                enabled: on,
                onTap: () => _pickTime(
                  'Quiet hours start',
                  prefs.quietHoursStart,
                  (m) => _save(prefs.copyWith(quietHoursStart: m)),
                ),
              ),
              const _CardDivider(),
              _TimeRow(
                label: 'End',
                time: _fmt(prefs.quietHoursEnd),
                enabled: on,
                onTap: () => _pickTime(
                  'Quiet hours end',
                  prefs.quietHoursEnd,
                  (m) => _save(prefs.copyWith(quietHoursEnd: m)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Reusable card widgets ─────────────────────────────────────────────────

/// Full-width master enable/disable card at the top of the screen.
class _MasterCard extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _MasterCard({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: AppSpacing.md,
      ),
      borderColor: value ? AppColors.primary.withValues(alpha: 0.35) : AppColors.border,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: value
                  ? AppColors.primaryContainer
                  : AppColors.surfaceHighest,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(
              Icons.notifications_rounded,
              size: 20,
              color: value ? AppColors.primary : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Enable notifications',
                    style: AppTextStyles.labelLarge),
                const SizedBox(height: 2),
                Text(
                  value ? 'Reminders are active' : 'All reminders paused',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeTrackColor: AppColors.primary,
            activeThumbColor: Colors.white,
            inactiveTrackColor: AppColors.surfaceHighest,
            inactiveThumbColor: AppColors.textSecondary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// A named card that groups related settings with an icon badge header.
class _GroupCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final bool disabled;
  final List<Widget> children;

  const _GroupCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.disabled = false,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.cardPadding,
              AppSpacing.md,
              AppSpacing.cardPadding,
              AppSpacing.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: disabled ? 0.08 : 0.15),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: disabled
                        ? iconColor.withValues(alpha: 0.35)
                        : iconColor,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: disabled
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textMuted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.borderSubtle, height: 1),
          // Items
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.cardPadding),
            child: Column(children: children),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(color: AppColors.borderSubtle, height: 1);
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: enabled
                        ? AppColors.textPrimary
                        : AppColors.textDisabled,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Switch(
            value: value && enabled,
            activeTrackColor: AppColors.primary,
            activeThumbColor: Colors.white,
            inactiveTrackColor: AppColors.surfaceHighest,
            inactiveThumbColor: AppColors.textSecondary,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final String label;
  final String time;
  final bool enabled;
  final VoidCallback onTap;

  const _TimeRow({
    required this.label,
    required this.time,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: enabled
                      ? AppColors.textPrimary
                      : AppColors.textDisabled,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 4),
              decoration: BoxDecoration(
                color: enabled
                    ? AppColors.primaryContainer
                    : AppColors.surfaceHighest,
                borderRadius:
                    BorderRadius.circular(AppSpacing.radiusFull),
              ),
              child: Text(
                time,
                style: AppTextStyles.labelLarge.copyWith(
                  color: enabled
                      ? AppColors.primary
                      : AppColors.textDisabled,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _NavRow({
    required this.label,
    required this.subtitle,
    required this.onTap,
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTextStyles.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
