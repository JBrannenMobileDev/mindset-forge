import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/scene_draft_store.dart';
import '../../../models/future_self_setup.dart';
import '../../../providers/auth_provider.dart';

/// The user-authored inputs for a Future Self scene, emitted by
/// [VisionSceneBuilder] as its fields change.
class SceneDraft {
  final String title;
  final String setting;
  final String people;
  final String flowText;
  final List<String> beats;
  final String sensory;
  final List<String> goalIds;

  const SceneDraft({
    this.title = '',
    this.setting = '',
    this.people = '',
    this.flowText = '',
    this.beats = const [],
    this.sensory = '',
    this.goalIds = const [],
  });

  /// A scene needs a name and a non-empty flow description.
  bool get isValid =>
      title.trim().isNotEmpty && flowText.trim().isNotEmpty;

  /// What's still missing before the user can create the scene.
  String? get validationHint {
    if (title.trim().isEmpty) return AppStrings.futureSelfBuilderNeedsTitle;
    if (flowText.trim().isEmpty) return AppStrings.futureSelfBuilderNeedsFlow;
    return null;
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'setting': setting,
        'people': people,
        'flowText': flowText,
        'sensory': sensory,
        'goalIds': goalIds,
      };

  factory SceneDraft.fromJson(Map<String, dynamic> json) => SceneDraft(
        title: json['title'] as String? ?? '',
        setting: json['setting'] as String? ?? '',
        people: json['people'] as String? ?? '',
        flowText: json['flowText'] as String? ?? '',
        sensory: json['sensory'] as String? ?? '',
        goalIds: List<String>.from(json['goalIds'] as List<dynamic>? ?? const []),
      );
}

/// Guided builder for a vivid, specific Future Self scene. The parent owns the
/// resulting [SceneDraft] via [onChanged]; this widget manages its own fields
/// and goal linking. Every field starts blank — the user writes their own scene
/// rather than editing a generic template.
class VisionSceneBuilder extends ConsumerStatefulWidget {
  final FutureSelfScene? initial;
  final ValueChanged<SceneDraft> onChanged;

  /// When true (add-scene sheet only), saves in-progress drafts locally.
  final bool persistDraft;

  const VisionSceneBuilder({
    super.key,
    this.initial,
    required this.onChanged,
    this.persistDraft = false,
  });

  @override
  ConsumerState<VisionSceneBuilder> createState() => _VisionSceneBuilderState();
}

class _VisionSceneBuilderState extends ConsumerState<VisionSceneBuilder> {
  final _titleCtrl = TextEditingController();
  final _settingCtrl = TextEditingController();
  final _peopleCtrl = TextEditingController();
  final _flowCtrl = TextEditingController();
  final _sensoryCtrl = TextEditingController();
  final Set<String> _goalIds = {};
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    if (s != null) {
      _titleCtrl.text = s.title;
      _settingCtrl.text = s.setting;
      _peopleCtrl.text = s.people;
      _flowCtrl.text = _flowTextFromScene(s);
      _sensoryCtrl.text = s.sensory;
      _goalIds.addAll(s.goalIds);
    } else if (widget.persistDraft) {
      _loadSavedDraft();
    }
    for (final c in [
      _titleCtrl,
      _settingCtrl,
      _peopleCtrl,
      _flowCtrl,
      _sensoryCtrl,
    ]) {
      c.addListener(_emit);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  String _flowTextFromScene(FutureSelfScene scene) {
    final beats =
        scene.beats.map((b) => b.trim()).where((b) => b.isNotEmpty).toList();
    if (beats.isEmpty) return '';
    if (beats.length == 1) return beats.first;
    return beats.join('\n\n');
  }

  Future<void> _loadSavedDraft() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    final draft = await SceneDraftStore.load(uid);
    if (!mounted || draft == null) return;
    _titleCtrl.text = draft.title;
    _settingCtrl.text = draft.setting;
    _peopleCtrl.text = draft.people;
    _flowCtrl.text = draft.flowText;
    _sensoryCtrl.text = draft.sensory;
    _goalIds
      ..clear()
      ..addAll(draft.goalIds);
    _emit();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _titleCtrl.dispose();
    _settingCtrl.dispose();
    _peopleCtrl.dispose();
    _flowCtrl.dispose();
    _sensoryCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    final flow = _flowCtrl.text;
    final draft = SceneDraft(
      title: _titleCtrl.text.trim(),
      setting: _settingCtrl.text.trim(),
      people: _peopleCtrl.text.trim(),
      flowText: flow,
      beats: flow.trim().isNotEmpty ? [flow.trim()] : const [],
      sensory: _sensoryCtrl.text.trim(),
      goalIds: _goalIds.toList(),
    );
    widget.onChanged(draft);

    if (widget.persistDraft && widget.initial == null) {
      _saveDebounce?.cancel();
      _saveDebounce = Timer(const Duration(milliseconds: 400), () {
        final uid = ref.read(authStateProvider).valueOrNull?.uid;
        if (uid == null) return;
        unawaited(SceneDraftStore.save(uid, draft));
      });
    }
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
        _field(_flowCtrl, AppStrings.futureSelfSceneFlowHint, maxLines: 8),
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
