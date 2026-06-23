import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/app_button.dart';
import '../../providers/auth_provider.dart';

class PricingScreen extends ConsumerStatefulWidget {
  const PricingScreen({super.key});

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
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
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
      final isActive = result.entitlements.all['premium']?.isActive ?? false;

      if (!mounted) return;
      if (isActive) {
        // Update Firestore subscription status optimistically
        final uid = ref.read(authStateProvider).valueOrNull?.uid;
        if (uid != null) {
          await ref.read(firestoreServiceProvider).updateUserField(uid, {
            'subscriptionStatus': 'active',
          });
        }
      }
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Subscription restored!')),
          );
        }
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _buildContent(),
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
            if (current != null)
              AppPrimaryButton(
                label: _isPurchasing ? 'Processing...' : 'Start 7-Day Free Trial',
                onPressed: _isPurchasing ? null : _purchase,
                isLoading: _isPurchasing,
              ),
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
            Text(
              'Cancel anytime. No commitment.',
              style: AppTextStyles.labelSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
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

  Widget _buildToggle(Offering current) {
    final hasAnnual = current.annual != null;
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
            label: 'Annual  🔥 Save 40%',
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
        final subLabel = isAnnual ? '/year · equals ${_monthlyEquivalent(pkg)}/mo' : '/month';

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
                      Text(
                        '7-day free trial · then $priceStr$subLabel',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
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
