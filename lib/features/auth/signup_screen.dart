import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/services/pending_invite_store.dart';
import '../../providers/auth_notifier.dart';
import 'widgets/auth_scaffold.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()
      ..onTap = () => context.push('/terms');
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => context.push('/privacy');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authNotifierProvider.notifier).signUp(
          name: _nameCtrl.text,
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;
    final errorMessage = authState.errorMessage;
    // A pending invite means this signup is resuming an accountability-partner
    // accept flow — tailor the copy so it's clear they're joining as a partner.
    final isPartnerInvite = PendingInviteStore.hasPending;

    return AuthScaffold(
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                  GestureDetector(
                    onTap: () => context.go('/login'),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (isPartnerInvite) ...[
                    _PartnerInviteBanner()
                        .animate()
                        .fadeIn(duration: 400.ms),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  Text(
                    isPartnerInvite
                        ? AppStrings.partnerSignupTitle
                        : AppStrings.signupTitle,
                    style: AppTextStyles.displaySmall,
                  ).animate().fadeIn(duration: 400.ms),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    isPartnerInvite
                        ? AppStrings.partnerSignupSubtitle
                        : AppStrings.signupSubtitle,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                  const SizedBox(height: AppSpacing.xxl),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        AppTextField(
                          label: AppStrings.displayName,
                          hint: 'Your full name',
                          controller: _nameCtrl,
                          textInputAction: TextInputAction.next,
                          validator: (v) => Validators.required(v, field: 'Name'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          label: AppStrings.email,
                          hint: 'you@example.com',
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          validator: Validators.email,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          label: AppStrings.password,
                          hint: '••••••••',
                          controller: _passwordCtrl,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          validator: Validators.password,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: AppColors.textMuted,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppTextField(
                          label: AppStrings.confirmPassword,
                          hint: '••••••••',
                          controller: _confirmCtrl,
                          obscureText: _obscureConfirm,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _signup(),
                          validator: (v) => Validators.confirmPassword(
                            v,
                            _passwordCtrl.text,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: AppColors.textMuted,
                            ),
                            onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                          ),
                        ),
                        if (errorMessage != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.errorContainer,
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            ),
                            child: Text(
                              errorMessage,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        AppPrimaryButton(
                          label: AppStrings.signup,
                          onPressed: _signup,
                          isLoading: isLoading,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text.rich(
                          TextSpan(
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textMuted,
                            ),
                            children: [
                              const TextSpan(text: AppStrings.agreementPrefix),
                              TextSpan(
                                text: AppStrings.termsTitle,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primary,
                                ),
                                recognizer: _termsTap,
                              ),
                              const TextSpan(text: AppStrings.agreementAnd),
                              TextSpan(
                                text: AppStrings.privacyTitle,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primary,
                                ),
                                recognizer: _privacyTap,
                              ),
                              const TextSpan(text: AppStrings.agreementSuffix),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppStrings.alreadyHaveAccount,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.go('/login'),
                        child: Text(
                          AppStrings.loginLink,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
        ],
      ),
    );
  }
}

class _PartnerInviteBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.people_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              AppStrings.partnerSignupBanner,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
