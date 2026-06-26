import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/affirmation_library.dart';
import '../../models/affirmation.dart';
import '../../models/mindset_blueprint.dart';
import '../../models/goal.dart';
import '../../models/user_profile.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/invite_prompt_provider.dart';
import 'steps/step_welcome.dart';
import 'steps/step_goals.dart';
import 'steps/step_identity.dart';
import 'steps/step_blocker.dart';
import 'steps/step_ai_summary.dart';

/// Step index constants — update here if order ever changes.
///
/// Onboarding is intentionally short: collect just enough (goal, identity,
/// one blocker) to deliver a personalized "aha" via the AI analysis, then hand
/// off into the app. Deeper mindset data (trait blueprint, mental toughness,
/// full fear quiz) is collected progressively in-app afterwards.
const _kStepWelcome = 0;
const _kStepGoals = 1;
const _kStepIdentity = 2;
const _kStepBlocker = 3;
const _kStepAiAnalysis = 4;
const _kTotalSteps = 5;

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentStep = 0;

  // ── Accumulated onboarding data ────────────────────────────────────────────
  // Blueprint + mental toughness are seeded with neutral defaults here and
  // refined later via the in-app blueprint setup flow.
  final MindsetBlueprint _blueprint = const MindsetBlueprint();
  final double _mentalToughnessScore = 50.0;
  List<Goal> _goals = [];
  String _identityStatement = '';
  String _identitySituation = '';
  List<String> _identityQualities = [];
  List<String> _limitingBeliefs = [];
  List<String> _fearsDrift = [];
  String _mindsetBlueprintSummary = '';

  @override
  void initState() {
    super.initState();
    _restoreStep();
  }

  void _restoreStep() {
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    if (profile != null && profile.onboardingStep > 0) {
      final step = profile.onboardingStep.clamp(0, _kTotalSteps - 1);
      _currentStep = step;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pageController.jumpToPage(step);
      });
    }
  }

  Future<void> _goToStep(int step) async {
    // Track the step the user is leaving (i.e. the step they just completed).
    if (step > _currentStep) {
      ref
          .read(analyticsServiceProvider)
          .trackOnboardingStepCompleted(_currentStep);
    }
    try {
      await _saveStep(step);
    } catch (_) {
      // Don't block navigation on Firestore write failure
    }
    if (!mounted) return;
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
    setState(() => _currentStep = step);
  }

  Future<void> _saveStep(int step) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    await ref.read(firestoreServiceProvider).updateOnboardingStep(uid, step);
  }

  Future<void> _completeOnboarding(String summaryText) async {
    _mindsetBlueprintSummary = summaryText;

    final authUser = ref.read(authStateProvider).valueOrNull;
    final uid = authUser?.uid;
    if (uid == null) return;

    final existingProfile = ref.read(currentUserProfileProvider).valueOrNull;
    final base = existingProfile ??
        UserProfile.create(
          uid: uid,
          email: authUser?.email ?? '',
          displayName: authUser?.displayName ?? '',
        );

    final updated = base.copyWith(
      onboardingStep: _kTotalSteps,
      // Seeded neutral defaults — refined later via in-app blueprint setup.
      mindsetBlueprint: _blueprint,
      originalMindsetBaseline: _blueprint,
      mentalToughnessScore: _mentalToughnessScore,
      blueprintCompleted: false,
      limitingBeliefs: _limitingBeliefs,
      identityStatement: _identityStatement,
      identitySituation: _identitySituation,
      identityQualities: _identityQualities,
      goals: _goals,
      fearsDrift: _fearsDrift,
      mindsetBlueprintSummary: _mindsetBlueprintSummary,
      // Land new users with a ready starter deck so the affirmations practice is
      // never empty. Derived from curated content (no network call) so onboarding
      // stays instant. Preserve any affirmations a returning user already has.
      affirmations:
          base.affirmations.isEmpty ? _buildStarterAffirmations() : base.affirmations,
    );

    await ref.read(firestoreServiceProvider).updateUserProfile(updated);
    if (!mounted) return;

    // Track the final AI Summary step completion and the overall event.
    ref
        .read(analyticsServiceProvider)
        .trackOnboardingStepCompleted(_kStepAiAnalysis);
    ref.read(analyticsServiceProvider).trackOnboardingCompleted(
          goalsCount: _goals.length,
          hasIdentityStatement: _identityStatement.isNotEmpty,
        );

    await _askForNotifications();
    if (!mounted) return;

    await ref
        .read(invitePromptProvider)
        .maybeShow(context, InviteTrigger.onboarding);
    if (mounted) context.go('/dashboard');
  }

  /// Builds a small curated starter deck from the focus areas the user already
  /// shared (goal categories + identity qualities), mapped onto affirmation
  /// categories. Curated, not AI-generated, so it is instant and never fails.
  List<Affirmation> _buildStarterAffirmations() {
    final focus = <String>[
      ..._goals.map((g) => g.category),
      ..._identityQualities,
    ];
    final now = DateTime.now();
    return affirmationStarterSet(focusCategories: focus, count: 5)
        .map((e) => Affirmation(
              id: const Uuid().v4(),
              text: e.text,
              source: 'starter',
              category: e.category,
              createdAt: now,
            ))
        .toList();
  }

  Future<void> _askForNotifications() async {
    final granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Stay on track', style: AppTextStyles.headlineMedium),
        content: Text(
          'Enable notifications to receive daily practice reminders and encouragement from your accountability partner.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Not now', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Enable', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );

    if (granted == true) {
      await ref.read(notificationServiceProvider).requestPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _OnboardingProgressBar(
              currentStep: _currentStep,
              totalSteps: _kTotalSteps,
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // Step 0 — Welcome
                  StepWelcome(onNext: () => _goToStep(_kStepGoals)),

                  // Step 1 — Goals
                  StepGoals(
                    initial: _goals,
                    onNext: (goals) {
                      _goals = goals;
                      _goToStep(_kStepIdentity);
                    },
                    onBack: () => _goToStep(_kStepWelcome),
                  ),

                  // Step 2 — Identity Wizard
                  StepIdentity(
                    initial: _identityStatement,
                    blueprint: _blueprint,
                    goals: _goals,
                    onNext: (statement, situation, qualities) {
                      _identityStatement = statement;
                      _identitySituation = situation;
                      _identityQualities = qualities;
                      _goToStep(_kStepBlocker);
                    },
                    onBack: () => _goToStep(_kStepGoals),
                  ),

                  // Step 3 — Blocker (limiting belief + optional fear)
                  StepBlocker(
                    initialBeliefs: _limitingBeliefs,
                    initialFears: _fearsDrift,
                    onNext: (beliefs, fears) {
                      _limitingBeliefs = beliefs;
                      _fearsDrift = fears;
                      _goToStep(_kStepAiAnalysis);
                    },
                    onBack: () => _goToStep(_kStepIdentity),
                  ),

                  // Step 4 — AI Analysis (the "aha")
                  StepAiSummary(
                    blueprint: _blueprint,
                    limitingBeliefs: _limitingBeliefs,
                    goals: _goals,
                    identityStatement: _identityStatement,
                    fearsDrift: _fearsDrift,
                    mentalToughnessScore: _mentalToughnessScore,
                    onComplete: _completeOnboarding,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _OnboardingProgressBar({
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPaddingH,
        AppSpacing.md,
        AppSpacing.screenPaddingH,
        0,
      ),
      child: Column(
        children: [
          Row(
            children: List.generate(totalSteps, (i) {
              final isCompleted = i < currentStep;
              final isCurrent = i == currentStep;
              return Expanded(
                child: Container(
                  height: 3,
                  margin: EdgeInsets.only(right: i < totalSteps - 1 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: isCompleted || isCurrent ? AppColors.primary : AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Step ${currentStep + 1} of $totalSteps',
                style: AppTextStyles.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
