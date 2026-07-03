import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/mindset_blueprint.dart';
import '../../providers/auth_provider.dart';
import '../../providers/blueprint_provider.dart';
import '../onboarding/steps/step_assessment.dart';

/// Streamlined trait-only flow for saving a new Blueprint snapshot.
class BlueprintSnapshotScreen extends ConsumerStatefulWidget {
  const BlueprintSnapshotScreen({super.key});

  @override
  ConsumerState<BlueprintSnapshotScreen> createState() =>
      _BlueprintSnapshotScreenState();
}

class _BlueprintSnapshotScreenState
    extends ConsumerState<BlueprintSnapshotScreen> {
  bool _saving = false;

  Future<void> _saveSnapshot(MindsetBlueprint blueprint) async {
    if (_saving) return;

    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null) {
      if (mounted) context.pop();
      return;
    }

    setState(() => _saving = true);
    final ok = await ref
        .read(blueprintSavingProvider.notifier)
        .saveSnapshot(profile, blueprint);
    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.blueprintSnapshotSaved),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.errorGeneric),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final isSaving = _saving || ref.watch(blueprintSavingProvider);

    if (profile == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: isSaving ? null : () => context.pop(),
        ),
        title: Text(
          AppStrings.blueprintNewSnapshot,
          style: AppTextStyles.headlineMedium,
        ),
      ),
      body: Stack(
        children: [
          StepAssessment(
            traitsOnly: true,
            initialBlueprint: profile.mindsetBlueprint,
            initialBeliefs: const [],
            onNext: (blueprint, _) => _saveSnapshot(blueprint),
            onBack: () => context.pop(),
          ),
          if (isSaving)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x660A0A0F),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
