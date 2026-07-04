import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/mindset_blueprint.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/auth_provider.dart';
import '../onboarding/steps/step_assessment.dart';
import '../onboarding/steps/step_mental_toughness.dart';
import '../onboarding/steps/step_fears.dart';

/// In-app "deepen your blueprint" flow surfaced after the lightweight onboarding.
///
/// Reuses the deferred onboarding steps (trait sliders + limiting beliefs,
/// mental toughness, fear quiz) and persists them in one pass, flipping
/// [UserProfile.blueprintCompleted] so the Getting Started checklist and Mindset
/// tab reflect completion.
class BlueprintSetupScreen extends ConsumerStatefulWidget {
  const BlueprintSetupScreen({super.key});

  @override
  ConsumerState<BlueprintSetupScreen> createState() =>
      _BlueprintSetupScreenState();
}

class _BlueprintSetupScreenState extends ConsumerState<BlueprintSetupScreen> {
  final _pageController = PageController();

  MindsetBlueprint _blueprint = const MindsetBlueprint();
  List<String> _beliefs = [];
  double _toughness = 50.0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    if (profile != null) {
      _blueprint = profile.mindsetBlueprint;
      _beliefs = List.from(profile.limitingBeliefs);
      _toughness = profile.mentalToughnessScore;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  /// Persists current in-memory state without marking blueprintCompleted.
  /// Called after each step so partial progress survives app restarts.
  Future<void> _savePartial() async {
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null) return;
    final updated = profile.copyWith(
      mindsetBlueprint: _blueprint,
      limitingBeliefs: _beliefs,
      mentalToughnessScore: _toughness,
    );
    try {
      await ref.read(firestoreServiceProvider).updateUserProfile(updated);
    } catch (e) {
      debugPrint('BlueprintSetupScreen._savePartial failed: $e');
    }
  }

  Future<void> _finish(List<String> fears) async {
    if (_saving) return;
    setState(() => _saving = true);

    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null) {
      if (mounted) context.pop();
      return;
    }

    final isFirstCompletion = !profile.blueprintCompleted;
    final now = DateTime.now().toIso8601String();
    final updated = profile.copyWith(
      mindsetBlueprint: _blueprint,
      // Frozen on first completion only — future snapshots never overwrite baseline.
      originalMindsetBaseline: isFirstCompletion
          ? _blueprint
          : profile.originalMindsetBaseline,
      limitingBeliefs: _beliefs,
      mentalToughnessScore: _toughness,
      fearsDrift: fears,
      blueprintCompleted: true,
      blueprintCalibrationStartedAt:
          isFirstCompletion ? now : profile.blueprintCalibrationStartedAt,
      mindsetBlueprintSnapshotAt:
          isFirstCompletion ? now : profile.mindsetBlueprintSnapshotAt,
    );

    try {
      await ref.read(firestoreServiceProvider).updateUserProfile(updated);
      ref.read(analyticsServiceProvider).trackBlueprintCompleted();
    } catch (_) {
      // Optimistic UX — the stream will reconcile; surface a soft failure.
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Your Mindset Blueprint is complete.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    context.pop();
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
          onPressed: () => context.pop(),
        ),
        title: Text('Build Your Blueprint', style: AppTextStyles.headlineMedium),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // Page 0 — trait sliders + limiting beliefs
            StepAssessment(
              initialBlueprint: _blueprint,
              initialBeliefs: _beliefs,
              onNext: (blueprint, beliefs) {
                _blueprint = blueprint;
                _beliefs = beliefs;
                _savePartial();
                _goToPage(1);
              },
              onBack: () => context.pop(),
            ),

            // Page 1 — mental toughness
            StepMentalToughness(
              blueprint: _blueprint,
              initial: _toughness,
              onNext: (score) {
                _toughness = score;
                _savePartial();
                _goToPage(2);
              },
              onBack: () => _goToPage(0),
            ),

            // Page 2 — fear quiz
            StepFears(
              initial: const [],
              onNext: _finish,
              onBack: () => _goToPage(1),
            ),
          ],
        ),
      ),
    );
  }
}
