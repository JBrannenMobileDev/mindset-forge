import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/app_date_utils.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/store_buttons.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/auth_notifier.dart';
import '../../providers/auth_provider.dart';

class PricingScreen extends ConsumerStatefulWidget {
  final String source;

  const PricingScreen({super.key, this.source = 'subscription_gate'});

  @override
  ConsumerState<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends ConsumerState<PricingScreen> {
  Offerings? _offerings;
  Package? _selectedPackage;
  bool _isLoading = true;
  bool _isPurchasing = false;
  bool _isAnnual = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Subscriptions run through RevenueCat, which is only configured on mobile.
    // On web we skip offering loading entirely and show a "use the app" gate.
    if (kIsWeb) {
      _isLoading = false;
    } else {
      _loadOfferings();
      // Self-heal: if RevenueCat reports an active entitlement that Firestore
      // hasn't caught up to yet (e.g. the webhook lagged after a purchase),
      // reconcile so this screen flips to the subscribed view instead of the
      // paywall.
      _reconcileSubscription();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(analyticsServiceProvider)
          .trackPaywallViewed(source: widget.source);
    });
  }

  Future<void> _loadOfferings() async {
    // Guard: a native Swift fatalError fires if getOfferings() is called before
    // Purchases.configure(). This cannot be caught in Dart, so check first.
    if (!await Purchases.isConfigured) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Subscription service is unavailable. Please try again later.';
        });
      }
      return;
    }
    try {
      final offerings = await Purchases.getOfferings();
      if (mounted) {
        setState(() {
          _offerings = offerings;
          _isLoading = false;
          _selectDefault(offerings);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load pricing. Please check your connection.';
        });
      }
    }
  }

  /// Reads the live entitlement from RevenueCat and upgrades the Firestore
  /// `subscriptionStatus` if it is behind. Only heals upward (grants access) —
  /// cancellations and expirations are authoritative through the webhook, so we
  /// never downgrade here to avoid locking out a user on a transient read.
  Future<void> _reconcileSubscription() async {
    if (!await Purchases.isConfigured) return;
    try {
      final info = await Purchases.getCustomerInfo();
      final entitlement = info.entitlements.all['premium'];
      if (entitlement == null || !entitlement.isActive) return;
      final liveStatus = entitlement.periodType == PeriodType.trial
          ? 'trialing'
          : (entitlement.willRenew ? 'active' : 'canceled');
      final profile = ref.read(currentUserProfileProvider).valueOrNull;
      if (profile != null && profile.subscriptionStatus == liveStatus) return;
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid == null) return;
      await ref.read(firestoreServiceProvider).updateUserField(uid, {
        'subscriptionStatus': liveStatus,
      });
    } catch (e) {
      debugPrint('PricingScreen._reconcileSubscription failed: $e');
    }
  }

  void _selectDefault(Offerings offerings) {
    final current = offerings.current;
    if (current == null) return;
    final annual = current.annual;
    final monthly = current.monthly;
    _selectedPackage = _isAnnual ? (annual ?? monthly) : (monthly ?? annual);
  }

  Future<void> _purchase() async {
    if (_selectedPackage == null) return;
    setState(() => _isPurchasing = true);

    try {
      final result = await Purchases.purchasePackage(_selectedPackage!);
      if (!mounted) return;

      final entitlement = result.entitlements.all['premium'];
      final isActive = entitlement?.isActive ?? false;
      final isTrial = entitlement?.periodType == PeriodType.trial;
      final newStatus = isActive ? (isTrial ? 'trialing' : 'active') : 'trialing';

      // Update Firestore regardless of isActive — the purchase completed so
      // at minimum the user is in a trial. isActive may be false if the
      // entitlement products aren't attached in RevenueCat yet.
      final uid = ref.read(authStateProvider).valueOrNull?.uid;
      if (uid != null) {
        await ref.read(firestoreServiceProvider).updateUserField(uid, {
          'subscriptionStatus': newStatus,
        });
      }
      if (!mounted) return;
      final planType = _selectedPackage!.packageType == PackageType.annual
          ? 'annual'
          : 'monthly';
      ref.read(analyticsServiceProvider).trackSubscriptionStarted(
            plan: planType,
            priceUsd: _selectedPackage!.storeProduct.price,
          );
      context.go('/dashboard');
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        // User cancelled — no error needed
      } else if (mounted) {
        setState(() => _errorMessage = 'Purchase failed. Please try again.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _isPurchasing = true);
    try {
      final info = await Purchases.restorePurchases();
      if (!mounted) return;
      final isActive = info.entitlements.all['premium']?.isActive ?? false;
      if (isActive) {
        final uid = ref.read(authStateProvider).valueOrNull?.uid;
        if (uid != null) {
          await ref.read(firestoreServiceProvider).updateUserField(uid, {
            'subscriptionStatus': 'active',
          });
        }
        ref.read(analyticsServiceProvider).trackSubscriptionRestored();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subscription restored!')),
        );
        context.go('/dashboard');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active subscription found.')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Restore failed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Web users cannot purchase (RevenueCat is mobile-only) — direct them to
    // manage their subscription in the app instead of the native paywall.
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: _buildWebGate(),
      );
    }

    // An already-subscribed user reaching this screen (e.g. via
    // Settings -> Manage Subscription) should see their subscription status and
    // store-management options, not the purchase paywall.
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    if (profile != null && profile.hasActiveSubscription) {
      return _SubscribedView(
        status: profile.subscriptionStatus,
        expiresAt: profile.subscriptionExpiresAt,
        isBusy: _isPurchasing,
        onRestore: _isPurchasing ? null : _restorePurchases,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _buildContent(),
    );
  }

  Widget _buildWebGate() {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPaddingH,
            vertical: AppSpacing.screenPaddingV,
          ),
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.primaryGlow,
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.phone_iphone_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ).animate().scale(duration: 400.ms),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  AppStrings.manageSubscriptionWebTitle,
                  style: AppTextStyles.displaySmall,
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppStrings.manageSubscriptionWebSubtitle,
                  style: AppTextStyles.bodyLarge
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: AppSpacing.xxl),
                const StoreButtons()
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 400.ms),
                const SizedBox(height: AppSpacing.lg),
                AppTextButton(
                  label: AppStrings.logout,
                  onPressed: () =>
                      ref.read(authNotifierProvider.notifier).signOut(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final current = _offerings?.current;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPaddingH,
          vertical: AppSpacing.screenPaddingV,
        ),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xl),
            _buildHero(),
            const SizedBox(height: AppSpacing.xxl),
            _buildFeatures(),
            const SizedBox(height: AppSpacing.xxl),
            if (current != null) ...[
              _buildToggle(current),
              const SizedBox(height: AppSpacing.lg),
              _buildPriceCards(current),
            ] else ...[
              Text(
                _errorMessage ?? 'Pricing unavailable.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            if (current != null) ...[
              AppPrimaryButton(
                label: _isPurchasing ? 'Processing...' : 'Start 7-Day Free Trial',
                onPressed: _isPurchasing ? null : _purchase,
                isLoading: _isPurchasing,
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    AppStrings.pricingCancelAnytimeNote,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _errorMessage!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: _isPurchasing ? null : _restorePurchases,
              child: Text(
                'Restore Purchases',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildLegalFooter(),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalFooter() {
    return Column(
      children: [
        Text(
          'Subscription auto-renews unless cancelled at least 24 hours before the end of the current period. '
          'Manage or cancel in iPhone Settings → Apple ID → Subscriptions.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => context.push('/terms'),
              child: Text(
                'Terms of Service',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.textSecondary,
                ),
              ),
            ),
            Text(
              '  ·  ',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
            ),
            GestureDetector(
              onTap: () => context.push('/privacy'),
              child: Text(
                'Privacy Policy',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHero() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.secondary],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: AppColors.primaryGlow, blurRadius: 24, spreadRadius: 2)],
          ),
          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 36),
        ).animate().scale(duration: 400.ms),
        const SizedBox(height: AppSpacing.lg),
        Text('Unlock Your Full Potential', style: AppTextStyles.displaySmall, textAlign: TextAlign.center)
            .animate().fadeIn(delay: 100.ms),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Personalized mindset coaching built for you.\nForge the identity that creates the life you want.',
          style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded, size: 14, color: AppColors.warning),
              const SizedBox(width: 6),
              Text(
                'Founding Member Rate',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.warning,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 300.ms),
      ],
    );
  }

  Widget _buildFeatures() {
    const features = [
      (Icons.psychology_rounded, 'Coach & Future Self Chat', 'Grounded in 6 mindset books'),
      (Icons.track_changes_rounded, 'Goal Breakdown & Habit Tracking', 'Personalized daily priorities'),
      (Icons.book_rounded, 'Smart Journaling', 'Personalized prompts that unlock insight'),
      (Icons.self_improvement_rounded, 'Future Self Visualization', 'Immersive personalized scripts'),
      (Icons.people_rounded, 'Accountability Partners', 'Free access for your partner'),
      (Icons.insights_rounded, 'Weekly Mindset Analysis', 'Track your transformation over time'),
    ];

    return Column(
      children: features
          .asMap()
          .entries
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Icon(e.value.$1, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.value.$2, style: AppTextStyles.labelLarge),
                        Text(
                          e.value.$3,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
                ],
              ).animate().fadeIn(delay: Duration(milliseconds: 100 + e.key * 60)),
            ),
          )
          .toList(),
    );
  }

  int? _annualSavingsPercent(Offering current) {
    final monthly = current.monthly;
    final annual = current.annual;
    if (monthly == null || annual == null) return null;
    final monthlyPrice = monthly.storeProduct.price;
    final annualPrice = annual.storeProduct.price;
    if (monthlyPrice <= 0 || annualPrice <= 0) return null;
    final yearlyCostAtMonthlyRate = monthlyPrice * 12;
    final percent =
        ((yearlyCostAtMonthlyRate - annualPrice) / yearlyCostAtMonthlyRate * 100)
            .round();
    return percent > 0 ? percent : null;
  }

  Widget _buildToggle(Offering current) {
    final hasAnnual = current.annual != null;
    final savingsPercent = _annualSavingsPercent(current);
    final annualLabel = savingsPercent != null
        ? 'Annual  🔥 Save $savingsPercent%'
        : 'Annual';
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _ToggleOption(
            label: 'Monthly',
            isSelected: !_isAnnual,
            onTap: () {
              if (!_isAnnual) return;
              setState(() {
                _isAnnual = false;
                _selectedPackage = current.monthly;
              });
            },
          ),
          _ToggleOption(
            label: annualLabel,
            isSelected: _isAnnual,
            enabled: hasAnnual,
            onTap: () {
              if (_isAnnual || !hasAnnual) return;
              setState(() {
                _isAnnual = true;
                _selectedPackage = current.annual;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCards(Offering current) {
    final packages = [
      if (!_isAnnual && current.monthly != null) current.monthly!,
      if (_isAnnual && current.annual != null) current.annual!,
    ];

    if (packages.isEmpty) {
      return Text('No packages available.', style: AppTextStyles.bodySmall);
    }

    return Column(
      children: packages.map((pkg) {
        final isSelected = _selectedPackage?.identifier == pkg.identifier;
        final priceStr = pkg.storeProduct.priceString;
        final isAnnual = pkg.packageType == PackageType.annual;
        final periodSuffix = isAnnual ? '/year' : '/month';
        final trialLine = isAnnual
            ? '7-day free trial · equals ${_monthlyEquivalent(pkg)}/mo'
            : '7-day free trial · then billed monthly';

        return GestureDetector(
          onTap: () => setState(() => _selectedPackage = pkg),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryContainer : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAnnual ? 'Annual Plan' : 'Monthly Plan',
                        style: AppTextStyles.labelLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: priceStr,
                              style: AppTextStyles.headlineSmall,
                            ),
                            TextSpan(
                              text: periodSuffix,
                              style: AppTextStyles.labelLarge.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        trialLine,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAnnual)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                      ),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    ),
                    child: Text(
                      'BEST VALUE',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: Colors.white,
                        fontSize: 9,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _monthlyEquivalent(Package pkg) {
    final price = pkg.storeProduct.price;
    final monthly = price / 12;
    final symbol = pkg.storeProduct.priceString.replaceAll(RegExp(r'[\d.,]'), '').trim();
    return '$symbol${monthly.toStringAsFixed(2)}';
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelMedium.copyWith(
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown in place of the paywall when the current user already has an active
/// or trialing subscription. Surfaces their status and links out to the store
/// for billing/cancellation, plus a restore option.
class _SubscribedView extends StatelessWidget {
  final String status;
  final DateTime? expiresAt;
  final bool isBusy;
  final VoidCallback? onRestore;

  const _SubscribedView({
    required this.status,
    required this.expiresAt,
    required this.isBusy,
    required this.onRestore,
  });

  bool get _isTrial => status == 'trialing';
  bool get _isCanceled => status == 'canceled';

  String get _badgeLabel {
    if (_isCanceled) return 'CANCELED';
    if (_isTrial) return '✓ TRIAL';
    return '✓ PREMIUM';
  }

  Color get _badgeColor => _isCanceled ? AppColors.warning : AppColors.primary;

  String get _headline {
    if (_isCanceled) return 'Your subscription is ending';
    if (_isTrial) return 'Your free trial is active';
    return 'Your subscription is active';
  }

  String get _subtitle {
    if (_isCanceled) {
      return 'Auto-renew is off. You keep full access until your subscription '
          'expires, then you can resubscribe anytime.';
    }
    return 'You have full access to MindShift. Manage billing or cancel '
        'anytime through your app store account.';
  }

  /// e.g. "Renews on Jul 4, 2026" or "Access until Jul 4, 2026".
  String? get _dateLine {
    final date = expiresAt;
    if (date == null) return null;
    final formatted = AppDateUtils.formatDate(date);
    return _isCanceled ? 'Access until $formatted' : 'Renews on $formatted';
  }

  bool get _isApple => defaultTargetPlatform == TargetPlatform.iOS;

  String get _manageLabel =>
      _isApple ? 'Manage in App Store' : 'Manage in Google Play';

  Future<void> _openStore() async {
    final uri = Uri.parse(
      _isApple
          ? 'https://apps.apple.com/account/subscriptions'
          : 'https://play.google.com/store/account/subscriptions',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/dashboard'),
        ),
        title: Text('Subscription', style: AppTextStyles.headlineMedium),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPaddingH,
            vertical: AppSpacing.screenPaddingV,
          ),
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xl),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.primaryGlow,
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ).animate().scale(duration: 400.ms),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: _badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Text(
                    _badgeLabel,
                    style:
                        AppTextStyles.labelSmall.copyWith(color: _badgeColor),
                  ),
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  _headline,
                  style: AppTextStyles.displaySmall,
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 150.ms),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _subtitle,
                  style: AppTextStyles.bodyLarge
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 200.ms),
                if (_dateLine != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _dateLine!,
                    style: AppTextStyles.labelLarge
                        .copyWith(color: AppColors.textPrimary),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 250.ms),
                ],
                const SizedBox(height: AppSpacing.xxl),
                AppPrimaryButton(
                  label: _manageLabel,
                  onPressed: _openStore,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextButton(
                  label: 'Restore Purchases',
                  onPressed: onRestore,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
