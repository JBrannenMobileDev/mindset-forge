import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/partner_visibility_card.dart';
import '../../providers/auth_provider.dart';
import '../../providers/accountability_provider.dart';
import 'invite_share.dart';

class AccountabilityScreen extends ConsumerStatefulWidget {
  const AccountabilityScreen({super.key});

  @override
  ConsumerState<AccountabilityScreen> createState() => _AccountabilityScreenState();
}

class _AccountabilityScreenState extends ConsumerState<AccountabilityScreen> {
  bool _showInviteForm = false;
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isSending = false;
  String? _successMessage;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendInvite() async {
    final email = _emailCtrl.text.trim();
    final name = _nameCtrl.text.trim();

    setState(() {
      _isSending = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final ok = await shareInvite(
      context,
      ref.read(accountabilityProvider.notifier),
      name: name,
      email: email,
    );

    if (!mounted) return;
    setState(() {
      _isSending = false;
      if (ok) {
        _showInviteForm = false;
        _emailCtrl.clear();
        _nameCtrl.clear();
      }
    });
  }

  Future<void> _confirmRemove(String relationshipId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.scrim,
      builder: (_) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          side: BorderSide(color: AppColors.error.withValues(alpha: 0.25)),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Remove partner?', style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'This ends your accountability partnership with $name. They will no longer see your progress, and you won\'t see theirs.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      'Cancel',
                      style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      'Remove',
                      style: AppTextStyles.labelLarge.copyWith(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;
    try {
      await ref.read(accountabilityProvider.notifier).removePartner(relationshipId);
      if (mounted) {
        setState(() => _successMessage = 'Partnership with $name ended.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not remove partner. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text('My Partnerships', style: AppTextStyles.headlineMedium),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded, color: AppColors.primary),
            onPressed: () => setState(() => _showInviteForm = !_showInviteForm),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => const Center(child: Text('Failed to load partnerships.')),
        data: (profile) {
          if (profile == null) return const SizedBox.shrink();

          final relationships = profile.accountabilityRelationships
              .where((r) => r.status == 'active')
              .toList();

          return ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingH,
              vertical: AppSpacing.lg,
            ),
            children: [
              if (_successMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(),

              if (_showInviteForm) ...[
                _InviteForm(
                  emailCtrl: _emailCtrl,
                  nameCtrl: _nameCtrl,
                  isSending: _isSending,
                  errorMessage: _errorMessage,
                  onSend: _sendInvite,
                  onCancel: () => setState(() => _showInviteForm = false),
                ).animate().fadeIn(duration: 300.ms),
                const SizedBox(height: AppSpacing.xl),
              ],

              Text('Partners', style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppSpacing.md),

              if (relationships.isEmpty && !_showInviteForm)
                EmptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'No partners yet',
                  subtitle: 'Invite someone to be your accountability partner.\nThey get free access and you both grow faster.',
                  ctaLabel: 'Invite a Partner',
                  onCta: () => setState(() => _showInviteForm = true),
                )
              else
                ...relationships.asMap().entries.map((e) {
                  final r = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: AppCard(
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, AppColors.secondary],
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                r.otherUserName.isNotEmpty ? r.otherUserName[0].toUpperCase() : '?',
                                style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.otherUserName, style: AppTextStyles.labelLarge),
                                Text(
                                  r.otherUserEmail,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryContainer,
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                                  ),
                                  child: Text(
                                    r.isPrimary ? 'My Partner' : 'Supporting',
                                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (r.isPartner)
                            IconButton(
                              icon: const Icon(Icons.visibility_rounded, color: AppColors.primary),
                              onPressed: () => context.push('/partner-view/${r.primaryUid}'),
                              tooltip: 'View their progress',
                            ),
                          IconButton(
                            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted),
                            onPressed: () => _confirmRemove(r.id, r.otherUserName),
                            tooltip: 'Remove partner',
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: Duration(milliseconds: e.key * 60)),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _InviteForm extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController nameCtrl;
  final bool isSending;
  final String? errorMessage;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  const _InviteForm({
    required this.emailCtrl,
    required this.nameCtrl,
    required this.isSending,
    this.errorMessage,
    required this.onSend,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_add_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text('Invite Accountability Partner', style: AppTextStyles.labelLarge),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Create a free invite link and share it with anyone. They get free app access and can cheer you on — here\'s exactly what they\'ll see.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          const PartnerVisibilityCard(),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: nameCtrl,
            style: AppTextStyles.bodyMedium,
            cursorColor: AppColors.primary,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration('Partner\'s name (optional)'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: emailCtrl,
            style: AppTextStyles.bodyMedium,
            cursorColor: AppColors.primary,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSend(),
            decoration: _inputDecoration('Partner\'s email (optional)'),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(errorMessage!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppPrimaryButton(
                  label: 'Create & Share Link',
                  onPressed: isSending ? null : onSend,
                  isLoading: isSending,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton(onPressed: onCancel, child: const Text('Cancel')),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
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
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
    );
  }
}
