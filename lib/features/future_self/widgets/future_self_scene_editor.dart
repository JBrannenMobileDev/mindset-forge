import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../models/future_self_setup.dart';
import '../../../providers/auth_provider.dart';

/// The user-authored inputs for a Future Self scene, emitted by
/// [VisionSceneBuilder] as its fields change.
class SceneDraft {
  final String title;
  final String setting;
  final String people;
  final List<String> beats;
  final String sensory;
  final List<String> goalIds;

  const SceneDraft({
    this.title = '',
    this.setting = '',
    this.people = '',
    this.beats = const [],
    this.sensory = '',
    this.goalIds = const [],
  });

  /// A scene needs a name and at least a couple of beats to be worth generating.
  bool get isValid => title.trim().isNotEmpty && beats.length >= 2;
}

/// Guided builder for a vivid, specific Future Self scene. The parent owns the
/// resulting [SceneDraft] via [onChanged]; this widget manages its own fields,
/// optional starter templates, and goal linking.
class VisionSceneBuilder extends ConsumerStatefulWidget {
  final FutureSelfScene? initial;
  final ValueChanged<SceneDraft> onChanged;

  const VisionSceneBuilder({
    super.key,
    this.initial,
    required this.onChanged,
  });

  @override
  ConsumerState<VisionSceneBuilder> createState() => _VisionSceneBuilderState();
}

class _VisionSceneBuilderState extends ConsumerState<VisionSceneBuilder> {
  final _titleCtrl = TextEditingController();
  final _settingCtrl = TextEditingController();
  final _peopleCtrl = TextEditingController();
  final _beatsCtrl = TextEditingController();
  final _sensoryCtrl = TextEditingController();
  final Set<String> _goalIds = {};
  String? _activeTemplateKey;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    if (s != null) {
      _titleCtrl.text = s.title;
      _settingCtrl.text = s.setting;
      _peopleCtrl.text = s.people;
      _beatsCtrl.text = s.beats.join('\n');
      _sensoryCtrl.text = s.sensory;
      _goalIds.addAll(s.goalIds);
    }
    for (final c in [
      _titleCtrl,
      _settingCtrl,
      _peopleCtrl,
      _beatsCtrl,
      _sensoryCtrl,
    ]) {
      c.addListener(_emit);
    }
    // Emit initial validity after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _settingCtrl.dispose();
    _peopleCtrl.dispose();
    _beatsCtrl.dispose();
    _sensoryCtrl.dispose();
    super.dispose();
  }

  List<String> get _beats => _beatsCtrl.text
      .split('\n')
      .map((b) => b.trim())
      .where((b) => b.isNotEmpty)
      .toList();

  void _emit() {
    widget.onChanged(SceneDraft(
      title: _titleCtrl.text.trim(),
      setting: _settingCtrl.text.trim(),
      people: _peopleCtrl.text.trim(),
      beats: _beats,
      sensory: _sensoryCtrl.text.trim(),
      goalIds: _goalIds.toList(),
    ));
  }

  void _applyTemplate(FutureSelfSceneTemplate t) {
    setState(() => _activeTemplateKey = t.key);
    _titleCtrl.text = t.label;
    _settingCtrl.text = t.setting;
    _peopleCtrl.text = t.people;
    _beatsCtrl.text = t.beats.join('\n');
    _sensoryCtrl.text = t.sensory;
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final goals = ref.watch(currentUserProfileProvider).valueOrNull?.goals ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.futureSelfBuilderIntro,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Optional starter templates
        _label(AppStrings.futureSelfBuilderTemplatesLabel),
        const SizedBox(height: AppSpacing.xs),
        Text(AppStrings.futureSelfBuilderTemplatesHint,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: FutureSelfSceneTemplates.all
              .map((t) => _Chip(
                    label: t.label,
                    selected: _activeTemplateKey == t.key,
                    onTap: () => _applyTemplate(t),
                  ))
              .toList(),
        ),
        const SizedBox(height: AppSpacing.xl),

        _label(AppStrings.futureSelfSceneTitleLabel),
        const SizedBox(height: AppSpacing.sm),
        _field(_titleCtrl, AppStrings.futureSelfSceneTitleHint),
        const SizedBox(height: AppSpacing.lg),

        _label(AppStrings.futureSelfSceneWhereLabel),
        const SizedBox(height: AppSpacing.xs),
        Text(AppStrings.futureSelfSceneWhereHelper,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: AppSpacing.sm),
        _field(_settingCtrl, AppStrings.futureSelfSceneWhereHint, maxLines: 3),
        const SizedBox(height: AppSpacing.lg),

        _label(AppStrings.futureSelfScenePeopleLabel),
        const SizedBox(height: AppSpacing.xs),
        Text(AppStrings.futureSelfScenePeopleHelper,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: AppSpacing.sm),
        _field(_peopleCtrl, AppStrings.futureSelfScenePeopleHint, maxLines: 2),
        const SizedBox(height: AppSpacing.lg),

        _label(AppStrings.futureSelfSceneFlowLabel),
        const SizedBox(height: AppSpacing.xs),
        Text(AppStrings.futureSelfSceneFlowHelper,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: AppSpacing.sm),
        _field(_beatsCtrl, AppStrings.futureSelfSceneFlowHint, maxLines: 8),
        const SizedBox(height: AppSpacing.lg),

        _label(AppStrings.futureSelfSceneSensoryLabel),
        const SizedBox(height: AppSpacing.sm),
        _field(_sensoryCtrl, AppStrings.futureSelfSceneSensoryHint, maxLines: 3),

        if (goals.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _label(AppStrings.futureSelfSceneGoalsLabel),
          const SizedBox(height: AppSpacing.xs),
          Text(AppStrings.futureSelfSceneGoalsHint,
              style:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: goals
                .map((g) => _Chip(
                      label: g.title,
                      selected: _goalIds.contains(g.id),
                      onTap: () {
                        setState(() {
                          if (!_goalIds.remove(g.id)) _goalIds.add(g.id);
                        });
                        _emit();
                      },
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _label(String text) => Text(text,
      style: AppTextStyles.labelLarge.copyWith(color: AppColors.futureSelfAccent));

  Widget _field(TextEditingController controller, String hint,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      style: AppTextStyles.bodyMedium,
      cursorColor: AppColors.futureSelfAccent,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
        filled: true,
        fillColor: AppColors.futureSelfSurface,
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
          borderSide:
              const BorderSide(color: AppColors.futureSelfAccent, width: 1.5),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.futureSelfAccent.withValues(alpha: 0.15)
              : AppColors.futureSelfSurface,
          border: Border.all(
            color: selected ? AppColors.futureSelfAccent : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color:
                selected ? AppColors.futureSelfAccent : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
