import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../core/firebase/accountability_service.dart';

class PartnerDashboardScreen extends ConsumerStatefulWidget {
  final String partnerUid;

  const PartnerDashboardScreen({super.key, required this.partnerUid});

  @override
  ConsumerState<PartnerDashboardScreen> createState() => _PartnerDashboardScreenState();
}

class _PartnerDashboardScreenState extends ConsumerState<PartnerDashboardScreen> {
  UserProfile? _partnerProfile;
  bool _isLoading = true;
  String? _errorMessage;
  final _messageCtrl = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadPartner();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPartner() async {
    try {
      final profile = await ref
          .read(firestoreServiceProvider)
          .getUserProfile(widget.partnerUid);

      if (!mounted) return;
      if (profile == null) {
        setState(() {
          _errorMessage = 'Could not load partner\'s profile.';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _partnerProfile = profile;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load partner\'s profile. Check your connection.';
        _isLoading = false;
      });
    }
  }

  Future<void> _sendEncouragement() async {
    final message = _messageCtrl.text.trim();
    if (message.isEmpty) return;

    setState(() => _isSending = true);
    try {
      await ref.read(accountabilityServiceProvider).sendEncouragement(
            partnerUid: widget.partnerUid,
            message: message,
          );
      _messageCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Encouragement sent! 🎉')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _partnerProfile?.displayName ?? 'Partner Progress',
          style: AppTextStyles.headlineMedium,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final profile = _partnerProfile!;
    final today = profile.todayCompletion;
    final streak = profile.currentStreak;
    final activeGoals = profile.goals.where((g) => g.status == 'active').toList();

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPaddingH,
        vertical: AppSpacing.lg,
      ),
      children: [
        // Partner overview
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
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
                          '"${profile.identityStatement}"',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(),

        const SizedBox(height: AppSpacing.lg),

        // Stats row
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Day Streak',
                value: '$streak',
                icon: Icons.local_fire_department_rounded,
                color: AppColors.warning,
              ).animate().fadeIn(delay: 100.ms),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _StatCard(
                label: 'Today',
                value: '${today.completionPercent.toStringAsFixed(0)}%',
                icon: Icons.today_rounded,
                color: AppColors.primary,
              ).animate().fadeIn(delay: 150.ms),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _StatCard(
                label: 'Goals',
                value: '${activeGoals.length}',
                icon: Icons.track_changes_rounded,
                color: AppColors.secondary,
              ).animate().fadeIn(delay: 200.ms),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.lg),

        // Active Goals
        if (activeGoals.isNotEmpty) ...[
          Text('Active Goals', style: AppTextStyles.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          ...activeGoals.take(3).map((g) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.title, style: AppTextStyles.labelLarge),
                  const SizedBox(height: AppSpacing.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: g.progressPercent / 100,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${g.progressPercent.toStringAsFixed(0)}% complete',
                    style: AppTextStyles.labelSmall,
                  ),
                ],
              ),
            ),
          )),
          const SizedBox(height: AppSpacing.lg),
        ],

        // Send encouragement
        Text('Send Encouragement', style: AppTextStyles.headlineSmall),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            children: [
              TextField(
                controller: _messageCtrl,
                maxLines: 3,
                style: AppTextStyles.bodyMedium,
                cursorColor: AppColors.primary,
                decoration: InputDecoration(
                  hintText: 'Write something inspiring for ${profile.firstName}...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppPrimaryButton(
                label: 'Send Encouragement',
                onPressed: _isSending ? null : _sendEncouragement,
                isLoading: _isSending,
              ),
            ],
          ),
        ).animate().fadeIn(delay: 300.ms),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTextStyles.headlineLarge.copyWith(color: color),
          ),
          Text(label, style: AppTextStyles.labelSmall),
        ],
      ),
    );
  }
}
