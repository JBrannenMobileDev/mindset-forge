import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/notification_prefs.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';

/// User-facing controls for the notification system: master + per-category
/// toggles, reminder times, quiet hours, and partner-slip consent.
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

  /// Ensures OS permission is granted at a moment of intent. Returns true if
  /// granted; otherwise surfaces a soft-ask pointing the user to system settings.
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
            'Notifications are off for MindsetForge. Enable them in your device Settings to get reminders.',
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

  String _formatMinutes(int minutes) {
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
    final enabled = prefs.masterEnabled;

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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPaddingH,
          vertical: AppSpacing.lg,
        ),
        children: [
          SwitchListTile(
            value: enabled,
            activeThumbColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
            title: Text('Enable notifications', style: AppTextStyles.labelLarge),
            subtitle: Text(
              'Reminders, streak alerts, and partner activity',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textMuted),
            ),
            onChanged: _setMaster,
          ),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: AppSpacing.lg),

          // ── Daily routine ─────────────────────────────────────────────
          const _SectionTitle('Daily routine'),
          _CategorySwitch(
            label: 'Practice reminders',
            subtitle: 'Morning and evening nudges for unfinished practices',
            value: prefs.routineEnabled,
            enabled: enabled,
            onChanged: (v) => _save(prefs.copyWith(routineEnabled: v)),
          ),
          _TimeTile(
            label: 'Morning reminder',
            value: _formatMinutes(prefs.morningReminderMinutes),
            enabled: enabled && prefs.routineEnabled,
            onTap: () => _pickTime(
              'Morning reminder',
              prefs.morningReminderMinutes,
              (m) => _save(prefs.copyWith(morningReminderMinutes: m)),
            ),
          ),
          _TimeTile(
            label: 'Evening reminder',
            value: _formatMinutes(prefs.eveningReminderMinutes),
            enabled: enabled && prefs.routineEnabled,
            onTap: () => _pickTime(
              'Evening reminder',
              prefs.eveningReminderMinutes,
              (m) => _save(prefs.copyWith(eveningReminderMinutes: m)),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Streak protection ─────────────────────────────────────────
          const _SectionTitle('Streak protection'),
          _CategorySwitch(
            label: 'Streak alerts',
            subtitle: 'A last-chance nudge when your streak is at risk',
            value: prefs.streakEnabled,
            enabled: enabled,
            onChanged: (v) => _save(prefs.copyWith(streakEnabled: v)),
          ),
          _TimeTile(
            label: 'Streak alert time',
            value: _formatMinutes(prefs.streakReminderMinutes),
            enabled: enabled && prefs.streakEnabled,
            onTap: () => _pickTime(
              'Streak alert time',
              prefs.streakReminderMinutes,
              (m) => _save(prefs.copyWith(streakReminderMinutes: m)),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Accountability ────────────────────────────────────────────
          const _SectionTitle('Accountability'),
          _CategorySwitch(
            label: 'Partner activity',
            subtitle: 'Encouragement and check-in nudges from partners',
            value: prefs.partnerEnabled,
            enabled: enabled,
            onChanged: (v) => _save(prefs.copyWith(partnerEnabled: v)),
          ),
          if (hasPartners)
            _CategorySwitch(
              label: 'Let partners know when I slip',
              subtitle:
                  'Your partner gets a gentle nudge to check in on a missed day',
              value: prefs.notifyPartnerOnSlip,
              enabled: enabled,
              onChanged: (v) => _save(prefs.copyWith(notifyPartnerOnSlip: v)),
            ),
          _LinkTile(
            label: 'Partner messages',
            subtitle: 'View encouragement your partners have sent',
            onTap: () => context.push('/notifications'),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Comeback nudges ───────────────────────────────────────────
          const _SectionTitle('Comeback nudges'),
          _CategorySwitch(
            label: 'Re-engagement reminders',
            subtitle: 'Occasional, capped nudges when you have been away',
            value: prefs.lifecycleEnabled,
            enabled: enabled,
            onChanged: (v) => _save(prefs.copyWith(lifecycleEnabled: v)),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Quiet hours ───────────────────────────────────────────────
          const _SectionTitle('Quiet hours'),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              'No reminders during this window, except a streak about to break.',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textMuted),
            ),
          ),
          _TimeTile(
            label: 'Start',
            value: _formatMinutes(prefs.quietHoursStart),
            enabled: enabled,
            onTap: () => _pickTime(
              'Quiet hours start',
              prefs.quietHoursStart,
              (m) => _save(prefs.copyWith(quietHoursStart: m)),
            ),
          ),
          _TimeTile(
            label: 'End',
            value: _formatMinutes(prefs.quietHoursEnd),
            enabled: enabled,
            onTap: () => _pickTime(
              'Quiet hours end',
              prefs.quietHoursEnd,
              (m) => _save(prefs.copyWith(quietHoursEnd: m)),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(title.toUpperCase(), style: AppTextStyles.overline),
    );
  }
}

class _CategorySwitch extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _CategorySwitch({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value && enabled,
      activeThumbColor: AppColors.primary,
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: AppTextStyles.labelLarge.copyWith(
          color: enabled ? AppColors.textPrimary : AppColors.textDisabled,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
      ),
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final String value;
  final bool enabled;
  final VoidCallback onTap;

  const _TimeTile({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: enabled,
      title: Text(
        label,
        style: AppTextStyles.bodyMedium.copyWith(
          color: enabled ? AppColors.textPrimary : AppColors.textDisabled,
        ),
      ),
      trailing: Text(
        value,
        style: AppTextStyles.labelLarge.copyWith(
          color: enabled ? AppColors.primary : AppColors.textDisabled,
        ),
      ),
      onTap: enabled ? onTap : null,
    );
  }
}

class _LinkTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _LinkTile({
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: AppTextStyles.labelLarge),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
      ),
      trailing:
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}
