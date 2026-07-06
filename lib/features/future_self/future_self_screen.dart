import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/future_self_setup.dart';
import '../../providers/future_self_provider.dart';
import 'future_self_wizard.dart';
import 'future_self_player_screen.dart';
import 'widgets/future_self_how_to.dart';
import 'widgets/future_self_scene_editor.dart';

/// Future Self Practice detail screen, the visualization half of the
/// Subconscious (Foundation) layer. Explains the practice, shows today's
/// status, and routes to the setup wizard, the scene library, and the guided
/// player.
class FutureSelfScreen extends ConsumerWidget {
  const FutureSelfScreen({super.key});

  Future<void> _openWizard(BuildContext context) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const FutureSelfWizard()),
    );
  }

  /// Picks a scene to practice: opens the chosen one directly when there's a
  /// single scene, otherwise lets the user choose today's scene.
  Future<void> _startPractice(BuildContext context, WidgetRef ref) async {
    final setup = ref.read(futureSelfProvider);
    if (setup == null || setup.scenes.isEmpty) return;

    String? sceneId;
    if (setup.scenes.length == 1) {
      sceneId = setup.scenes.first.id;
    } else {
      sceneId = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: AppColors.futureSelfSurface,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
        ),
        builder: (_) => _SceneChooserSheet(scenes: setup.scenes),
      );
    }
    if (sceneId == null || !context.mounted) return;
    await _openPlayer(context, ref, sceneId);
  }

  Future<void> _openPlayer(
      BuildContext context, WidgetRef ref, String sceneId) async {
    final setup = ref.read(futureSelfProvider);
    // Show the one-time "how to practice" primer before the first session.
    if (setup != null && !setup.hasSeenHowTo) {
      final begin = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const FutureSelfHowToScreen()),
      );
      await ref.read(futureSelfProvider.notifier).markHowToSeen();
      if (begin != true) return;
    }
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => FutureSelfPlayerScreen(sceneId: sceneId)),
    );
  }

  Future<void> _openSceneEditor(BuildContext context,
      {FutureSelfScene? scene}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.futureSelfSurface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (_) => _SceneEditorSheet(scene: scene),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(futureSelfProvider);
    final completedToday = ref.watch(futureSelfCompletedTodayProvider);
    final hasPractice = setup?.hasPractice ?? false;

    return Scaffold(
      backgroundColor: AppColors.futureSelfBackground,
      appBar: AppBar(
        backgroundColor: AppColors.futureSelfBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.futureSelfAccent),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/mindset');
            }
          },
        ),
        title: Text(
          AppStrings.futureSelf,
          style: AppTextStyles.headlineSmall
              .copyWith(color: AppColors.futureSelfAccent),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.screenPaddingH,
              AppSpacing.md, AppSpacing.screenPaddingH, AppSpacing.xxl),
          children: [
            _Hero().animate().fadeIn(duration: 400.ms),
            const SizedBox(height: AppSpacing.xl),
            if (hasPractice) ...[
              _TodayStatus(
                completed: completedToday,
                onStart: () => _startPractice(context, ref),
              ),
              const SizedBox(height: AppSpacing.md),
              _ActionButton(
                label: completedToday
                    ? AppStrings.futureSelfPracticeAgain
                    : AppStrings.futureSelfStartToday,
                icon: Icons.play_arrow_rounded,
                filled: true,
                onTap: () => _startPractice(context, ref),
              ),
              const SizedBox(height: AppSpacing.lg),
              _ScenesSection(
                setup: setup!,
                onPractice: (id) => _openPlayer(context, ref, id),
                onAdd: () => _openSceneEditor(context),
                onRefine: (scene) => _openSceneEditor(context, scene: scene),
                onDelete: (id) =>
                    ref.read(futureSelfProvider.notifier).deleteScene(id),
              ),
              const SizedBox(height: AppSpacing.md),
              _ActionButton(
                label: AppStrings.futureSelfEditIdentity,
                icon: Icons.tune_rounded,
                filled: false,
                onTap: () => _openWizard(context),
              ),
            ] else ...[
              _ActionButton(
                label: AppStrings.futureSelfCreate,
                icon: Icons.auto_awesome_rounded,
                filled: true,
                onTap: () => _openWizard(context),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Center(
              child: TextButton.icon(
                onPressed: () => context.go('/chat',
                    extra: {'initialMode': 'future_self'}),
                icon: const Icon(Icons.forum_rounded,
                    color: AppColors.futureSelfAccent, size: AppSpacing.iconMd),
                label: Text(AppStrings.futureSelfSealTalkToFutureSelf,
                    style: AppTextStyles.button
                        .copyWith(color: AppColors.futureSelfAccent)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const _HowToSection(),
            const SizedBox(height: AppSpacing.md),
            const _AboutSection(),
          ],
        ),
      ),
    );
  }
}

/// Always-available, collapsible "How to practice" guide reusing the shared
/// method content from the primer.
class _HowToSection extends StatefulWidget {
  const _HowToSection();

  @override
  State<_HowToSection> createState() => _HowToSectionState();
}

class _HowToSectionState extends State<_HowToSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.futureSelfSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
            color: AppColors.futureSelfAccent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                const Icon(Icons.self_improvement_rounded,
                    color: AppColors.futureSelfAccent, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(AppStrings.futureSelfHowToTitle,
                      style: AppTextStyles.headlineSmall),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? const Padding(
                    padding: EdgeInsets.only(top: AppSpacing.lg),
                    child: FutureSelfHowToContent(showIntro: false),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
                colors: [AppColors.futureSelfAccent, AppColors.warning]),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: AppColors.futureSelfGlow,
                  blurRadius: 28,
                  spreadRadius: 6),
            ],
          ),
          child: const Icon(Icons.visibility_rounded,
              color: Colors.white, size: 34),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(AppStrings.futureSelfPracticeTitle,
            style: AppTextStyles.headlineMedium
                .copyWith(color: AppColors.futureSelfAccent),
            textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xs),
        Text(AppStrings.futureSelfPracticeSubtitle,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center),
      ],
    );
  }
}

class _TodayStatus extends StatelessWidget {
  final bool completed;
  final VoidCallback onStart;

  const _TodayStatus({required this.completed, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: completed
            ? AppColors.success.withValues(alpha: 0.10)
            : AppColors.futureSelfSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: completed
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            completed
                ? Icons.check_circle_rounded
                : Icons.visibility_outlined,
            color: completed ? AppColors.success : AppColors.textMuted,
            size: 24,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.futureSelfTodayTitle,
                    style: AppTextStyles.labelLarge),
                const SizedBox(height: 2),
                Text(
                  completed
                      ? AppStrings.futureSelfCompletedStatus
                      : AppStrings.futureSelfNotCompletedStatus,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The scene library: the small set of moments the user returns to. Lists each
/// scene with practice / refine / remove actions and an add-scene affordance.
class _ScenesSection extends StatelessWidget {
  final FutureSelfSetup setup;
  final ValueChanged<String> onPractice;
  final VoidCallback onAdd;
  final ValueChanged<FutureSelfScene> onRefine;
  final ValueChanged<String> onDelete;

  const _ScenesSection({
    required this.setup,
    required this.onPractice,
    required this.onAdd,
    required this.onRefine,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.futureSelfSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.futureSelfScenesTitle,
              style: AppTextStyles.headlineSmall
                  .copyWith(color: AppColors.futureSelfAccent)),
          const SizedBox(height: AppSpacing.xs),
          Text(AppStrings.futureSelfScenesSubtitle,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.md),
          ...setup.scenes.map((s) => _SceneTile(
                scene: s,
                onPractice: () => onPractice(s.id),
                onRefine: () => onRefine(s),
                onDelete: () => _confirmDelete(context, s),
              )),
          const SizedBox(height: AppSpacing.xs),
          if (setup.canAddScene)
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded,
                  color: AppColors.futureSelfAccent, size: AppSpacing.iconMd),
              label: Text(AppStrings.futureSelfAddScene,
                  style: AppTextStyles.button
                      .copyWith(color: AppColors.futureSelfAccent)),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(AppStrings.futureSelfSceneLimitReached,
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                      fontStyle: FontStyle.italic)),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, FutureSelfScene scene) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.scrim,
      builder: (_) => Dialog(
        backgroundColor: AppColors.futureSelfSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          side: BorderSide(
              color: AppColors.futureSelfAccent.withValues(alpha: 0.25)),
        ),
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppStrings.futureSelfDeleteScene,
                  style: AppTextStyles.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(AppStrings.futureSelfDeleteSceneConfirm,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(AppStrings.cancel,
                          style: AppTextStyles.button
                              .copyWith(color: AppColors.textSecondary)),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(AppStrings.futureSelfDeleteScene,
                          style: AppTextStyles.button
                              .copyWith(color: AppColors.error)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true) onDelete(scene.id);
  }
}

class _SceneTile extends StatelessWidget {
  final FutureSelfScene scene;
  final VoidCallback onPractice;
  final VoidCallback onRefine;
  final VoidCallback onDelete;

  const _SceneTile({
    required this.scene,
    required this.onPractice,
    required this.onRefine,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.futureSelfBackground,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.futureSelfAccent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(scene.displayTitle, style: AppTextStyles.labelLarge),
                if (scene.setting.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(scene.setting,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.textMuted)),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: AppStrings.futureSelfRefine,
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.textSecondary, size: 20),
            onPressed: onRefine,
          ),
          IconButton(
            tooltip: AppStrings.futureSelfDeleteScene,
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.textMuted, size: 20),
            onPressed: onDelete,
          ),
          IconButton(
            tooltip: AppStrings.futureSelfScenePractice,
            icon: const Icon(Icons.play_circle_fill_rounded,
                color: AppColors.futureSelfAccent, size: 30),
            onPressed: onPractice,
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet to choose which scene to practice when the library has more
/// than one, pre-highlighting the one that fits the current time of day.
class _SceneChooserSheet extends StatelessWidget {
  final List<FutureSelfScene> scenes;

  const _SceneChooserSheet({required this.scenes});

  @override
  Widget build(BuildContext context) {
    final suggested = defaultSceneForNow(scenes);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(AppStrings.futureSelfChooseSceneTitle,
                style: AppTextStyles.headlineSmall
                    .copyWith(color: AppColors.futureSelfAccent)),
            const SizedBox(height: AppSpacing.md),
            ...scenes.map((s) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.play_circle_outline_rounded,
                    color: s.id == suggested?.id
                        ? AppColors.futureSelfAccent
                        : AppColors.textSecondary,
                  ),
                  title: Text(s.displayTitle, style: AppTextStyles.labelLarge),
                  subtitle: s.setting.isNotEmpty
                      ? Text(s.setting,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textMuted))
                      : null,
                  onTap: () => Navigator.of(context).pop(s.id),
                )),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for adding a new scene or refining an existing one. Owns the
/// generation lifecycle so the hub stays declarative.
class _SceneEditorSheet extends ConsumerStatefulWidget {
  final FutureSelfScene? scene;

  const _SceneEditorSheet({this.scene});

  @override
  ConsumerState<_SceneEditorSheet> createState() => _SceneEditorSheetState();
}

class _SceneEditorSheetState extends ConsumerState<_SceneEditorSheet> {
  SceneDraft? _draft;
  bool _busy = false;

  bool get _isRefine => widget.scene != null;

  Future<void> _submit() async {
    final draft = _draft;
    if (draft == null || !draft.isValid) return;
    setState(() => _busy = true);
    final notifier = ref.read(futureSelfProvider.notifier);
    if (_isRefine) {
      await notifier.refineScene(
        widget.scene!.id,
        title: draft.title,
        setting: draft.setting,
        people: draft.people,
        beats: draft.beats,
        sensory: draft.sensory,
        goalIds: draft.goalIds,
      );
    } else {
      await notifier.createScene(
        title: draft.title,
        setting: draft.setting,
        people: draft.people,
        beats: draft.beats,
        sensory: draft.sensory,
        goalIds: draft.goalIds,
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_busy)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Column(
                  children: [
                    const CircularProgressIndicator(
                        color: AppColors.futureSelfAccent),
                    const SizedBox(height: AppSpacing.lg),
                    Text(AppStrings.futureSelfSceneBuilding,
                        style: AppTextStyles.headlineSmall,
                        textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.sm),
                    Text(AppStrings.futureSelfSceneBuildingNote,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center),
                  ],
                ),
              )
            else ...[
              Text(
                  _isRefine
                      ? AppStrings.futureSelfRefineSceneTitle
                      : AppStrings.futureSelfNewSceneTitle,
                  style: AppTextStyles.headlineSmall
                      .copyWith(color: AppColors.futureSelfAccent)),
              const SizedBox(height: AppSpacing.lg),
              VisionSceneBuilder(
                initial: widget.scene,
                onChanged: (d) => setState(() => _draft = d),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                height: AppSpacing.buttonHeight,
                child: ElevatedButton(
                  onPressed: (_draft?.isValid ?? false) ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.futureSelfAccent,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor:
                        AppColors.futureSelfAccent.withValues(alpha: 0.4),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  child: Text(
                    _isRefine
                        ? AppStrings.futureSelfRegenerateScene
                        : AppStrings.futureSelfCreateScene,
                    style: AppTextStyles.button.copyWith(color: Colors.black),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.futureSelfSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
            color: AppColors.futureSelfAccent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: AppColors.futureSelfAccent, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(AppStrings.futureSelfWhatTitle,
                    style: AppTextStyles.headlineSmall),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(AppStrings.futureSelfWhatBody,
              style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary, height: 1.6)),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.futureSelfAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.futureSelfWhatExampleTitle,
                    style: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.futureSelfAccent)),
                const SizedBox(height: AppSpacing.xs),
                Text(AppStrings.futureSelfWhatExample,
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(AppStrings.futureSelfPrinciplesTitle,
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.futureSelfAccent)),
          const SizedBox(height: AppSpacing.sm),
          ...AppStrings.futureSelfPrinciples.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.circle, size: 6, color: AppColors.futureSelfAccent),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                      child: Text(p,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.textSecondary))),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(AppStrings.futureSelfBestTimeTitle,
              style: AppTextStyles.labelLarge
                  .copyWith(color: AppColors.futureSelfAccent)),
          const SizedBox(height: AppSpacing.xs),
          Text(AppStrings.futureSelfBestTimeBody,
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary, height: 1.5)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.buttonHeight,
      child: filled
          ? ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: AppSpacing.iconMd),
              label: Text(label,
                  style: AppTextStyles.button.copyWith(color: Colors.black)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.futureSelfAccent,
                foregroundColor: Colors.black,
                elevation: 0,
                minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: AppSpacing.iconMd),
              label: Text(label, style: AppTextStyles.button),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
            ),
    );
  }
}
