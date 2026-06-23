import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/firebase/accountability_service.dart';

class PartnerInviteScreen extends ConsumerStatefulWidget {
  final String inviteId;

  const PartnerInviteScreen({super.key, required this.inviteId});

  @override
  ConsumerState<PartnerInviteScreen> createState() => _PartnerInviteScreenState();
}

class _PartnerInviteScreenState extends ConsumerState<PartnerInviteScreen> {
  bool _isLoading = true;
  bool _isAccepting = false;
  bool _accepted = false;
  String? _primaryName;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInviteInfo();
  }

  Future<void> _loadInviteInfo() async {
    try {
      final name = await ref
          .read(accountabilityServiceProvider)
          .getPartnerInviteInfo(widget.inviteId);
      if (mounted) {
        setState(() {
          _primaryName = name ?? 'Someone';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'This invite link is invalid or has already been used.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _acceptInvite() async {
    setState(() => _isAccepting = true);
    try {
      await ref
          .read(accountabilityServiceProvider)
          .acceptPartnerInvite(widget.inviteId);
      if (mounted) {
        setState(() => _accepted = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to accept invite. ${e.toString()}';
          _isAccepting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPaddingH,
            vertical: AppSpacing.screenPaddingV,
          ),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _accepted
                  ? _buildAccepted()
                  : _errorMessage != null
                      ? _buildError()
                      : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.secondary],
            ),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppColors.primaryGlow, blurRadius: 24, spreadRadius: 2)],
          ),
          child: const Icon(Icons.people_rounded, color: Colors.white, size: 40),
        ).animate().scale(duration: 400.ms),
        const SizedBox(height: AppSpacing.xl),
        Text(
          '$_primaryName wants you to be their accountability partner',
          style: AppTextStyles.headlineMedium,
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 100.ms),
        const SizedBox(height: AppSpacing.md),
        Text(
          'As their partner, you\'ll be able to view their progress, send encouragement, and help them stay on track with their mindset goals.\n\nYou\'ll get free access to MindsetForge.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: AppSpacing.xxl),
        AppPrimaryButton(
          label: 'Accept Partnership',
          onPressed: _isAccepting ? null : _acceptInvite,
          isLoading: _isAccepting,
        ).animate().fadeIn(delay: 300.ms),
        const SizedBox(height: AppSpacing.md),
        TextButton(
          onPressed: () => context.go('/dashboard'),
          child: Text(
            'Decline',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            _errorMessage!,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildAccepted() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 80)
            .animate()
            .scale(duration: 400.ms),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Partnership Accepted!',
          style: AppTextStyles.headlineMedium,
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 100.ms),
        const SizedBox(height: AppSpacing.md),
        Text(
          'You\'re now $_primaryName\'s accountability partner. Head to the app to view their progress and send encouragement.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: AppSpacing.xxl),
        AppPrimaryButton(
          label: 'Go to Dashboard',
          onPressed: () => context.go('/dashboard'),
        ).animate().fadeIn(delay: 300.ms),
      ],
    );
  }

  Widget _buildError() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 64),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Invalid Invite',
          style: AppTextStyles.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          _errorMessage ?? 'This invite link is no longer valid.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xxl),
        TextButton(
          onPressed: () => context.go('/dashboard'),
          child: const Text('Go to Dashboard'),
        ),
      ],
    );
  }
}
