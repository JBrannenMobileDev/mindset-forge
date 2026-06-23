import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../models/affirmation.dart';
import '../../models/user_profile.dart';
import '../../providers/affirmations_provider.dart';
import '../../providers/claude_provider.dart';

// ─── Affirmation categories ───────────────────────────────────────────────────

const _categories = [
  'general',
  'confidence',
  'discipline',
  'abundance',
  'resilience',
  'decisiveness',
  'health',
  'relationships',
];

// ─── Public helper: launch session from anywhere ──────────────────────────────

void launchAffirmationSession({
  required BuildContext context,
  required WidgetRef ref,
  required List<Affirmation> affirmations,
  required String sessionType,
}) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: AppColors.scrim,
    builder: (_) => ProviderScope(
      parent: ProviderScope.containerOf(context),
      child: AffirmationSessionSheet(
        affirmations: affirmations,
        sessionType: sessionType,
        onComplete: () => ref
            .read(affirmationsProvider.notifier)
            .recordSessionCompletion(sessionType),
      ),
    ),
  );
}

// ─── Main tab widget ──────────────────────────────────────────────────────────

class AffirmationsTab extends ConsumerStatefulWidget {
  final UserProfile profile;

  const AffirmationsTab({super.key, required this.profile});

  @override
  ConsumerState<AffirmationsTab> createState() => _AffirmationsTabState();
}

class _AffirmationsTabState extends ConsumerState<AffirmationsTab> {
  bool _starterTriggered = false;
  bool _starterLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoStart());
  }

  Future<void> _maybeAutoStart() async {
    if (_starterTriggered) return;
    final affirmations = ref.read(affirmationsProvider);
    if (affirmations.isNotEmpty) return;
    _starterTriggered = true;

    if (!mounted) return;
    setState(() => _starterLoading = true);

    try {
      final results = await ref
          .read(claudeServiceProvider)
          .generateAffirmations(widget.profile);
      // Use only first 2 for the starter set
      final starters = results.take(2).toList();
      for (final text in starters) {
        if (!mounted) return;
        await ref.read(affirmationsProvider.notifier).addAffirmation(
              Affirmation(
                id: const Uuid().v4(),
                text: text,
                source: 'ai',
                createdAt: DateTime.now(),
              ),
            );
      }
    } catch (_) {
      // Silent failure — user can generate manually
    }

    if (mounted) setState(() => _starterLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final affirmations = ref.watch(affirmationsProvider);
    final active = affirmations.where((a) => a.isActive).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPaddingH,
              AppSpacing.lg,
              AppSpacing.screenPaddingH,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _SessionButton(
                    label: AppStrings.morningSession,
                    icon: Icons.wb_sunny_rounded,
                    color: AppColors.warning,
                    onTap: active.isEmpty
                        ? null
                        : () => launchAffirmationSession(
                              context: context,
                              ref: ref,
                              affirmations: active,
                              sessionType: 'morning',
                            ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _SessionButton(
                    label: AppStrings.eveningSession,
                    icon: Icons.nightlight_round,
                    color: AppColors.secondary,
                    onTap: active.isEmpty
                        ? null
                        : () => launchAffirmationSession(
                              context: context,
                              ref: ref,
                              affirmations: active,
                              sessionType: 'evening',
                            ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingH,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                AppTextButton(
                  label: AppStrings.addAffirmation,
                  onPressed: () => _showAddModal(context, ref),
                ),
                const Spacer(),
                AppTextButton(
                  label: AppStrings.generateAffirmations,
                  onPressed: () => _showGenerateModal(context, ref),
                ),
              ],
            ),
          ),
          Expanded(
            child: _starterLoading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: AppSpacing.md),
                        Text(
                          'Creating your personalized affirmations…',
                          style: TextStyle(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : affirmations.isEmpty
                    ? EmptyState(
                        icon: Icons.format_quote_rounded,
                        title: AppStrings.noAffirmations,
                        subtitle: AppStrings.noAffirmationsSubtitle,
                        ctaLabel: AppStrings.generateAffirmations,
                        onCta: () => _showGenerateModal(context, ref),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenPaddingH,
                          0,
                          AppSpacing.screenPaddingH,
                          100,
                        ),
                        itemCount: affirmations.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (_, i) => _AffirmationTile(
                          affirmation: affirmations[i],
                          onToggle: () => ref
                              .read(affirmationsProvider.notifier)
                              .toggleActive(affirmations[i].id),
                          onDelete: () => ref
                              .read(affirmationsProvider.notifier)
                              .deleteAffirmation(affirmations[i].id),
                        )
                            .animate()
                            .fadeIn(
                                delay: Duration(milliseconds: i * 50),
                                duration: 300.ms),
                      ),
          ),
        ],
      ),
    );
  }

  void _showAddModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _AddAffirmationModal(profile: widget.profile),
      ),
    );
  }

  void _showGenerateModal(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _GenerateAffirmationsSheet(profile: widget.profile),
      ),
    );
  }
}

// ─── Add affirmation modal (with category, AI enhance, suggestions) ───────────

class _AddAffirmationModal extends ConsumerStatefulWidget {
  final UserProfile profile;

  const _AddAffirmationModal({required this.profile});

  @override
  ConsumerState<_AddAffirmationModal> createState() =>
      _AddAffirmationModalState();
}

class _AddAffirmationModalState extends ConsumerState<_AddAffirmationModal> {
  final _ctrl = TextEditingController();
  String _category = 'general';
  bool _enhancing = false;
  bool _loadingSuggestions = false;
  List<String> _suggestions = [];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _enhance() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _enhancing = true);
    try {
      final enhanced = await ref
          .read(claudeServiceProvider)
          .enhanceAffirmation(text, widget.profile);
      _ctrl.text = enhanced;
      _ctrl.selection =
          TextSelection.collapsed(offset: enhanced.length);
    } catch (_) {
      // Silent — user keeps original text
    }
    if (mounted) setState(() => _enhancing = false);
  }

  Future<void> _getSuggestions() async {
    setState(() {
      _loadingSuggestions = true;
      _suggestions = [];
    });
    try {
      final results = await ref
          .read(claudeServiceProvider)
          .getAffirmationSuggestions(widget.profile);
      if (mounted) setState(() => _suggestions = results.take(4).toList());
    } catch (_) {
      // Silent
    }
    if (mounted) setState(() => _loadingSuggestions = false);
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.length < 5 || text.length > 500) return;
    ref.read(affirmationsProvider.notifier).addAffirmation(
          Affirmation(
            id: const Uuid().v4(),
            text: text,
            category: _category,
            createdAt: DateTime.now(),
          ),
        );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final charCount = _ctrl.text.length;
    final isValid = charCount >= 5 && charCount <= 500;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              Text(AppStrings.addAffirmation,
                  style: AppTextStyles.headlineMedium),
              const SizedBox(height: AppSpacing.lg),

              // Category dropdown
              DropdownButtonFormField<String>(
                value: _category,
                dropdownColor: AppColors.surface,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                ),
                style: AppTextStyles.bodyMedium,
                items: _categories
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(
                            c[0].toUpperCase() + c.substring(1),
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _category = v ?? 'general'),
              ),
              const SizedBox(height: AppSpacing.md),

              // Text field
              TextField(
                controller: _ctrl,
                autofocus: true,
                maxLines: 4,
                maxLength: 500,
                style: AppTextStyles.bodyLarge,
                cursorColor: AppColors.primary,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText:
                      'I am confident and capable of achieving my goals',
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  counterText: '$charCount / 500',
                  counterStyle: AppTextStyles.bodySmall.copyWith(
                    color: charCount > 500
                        ? AppColors.error
                        : AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // AI Enhance + Get Suggestions row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _enhancing ? null : _enhance,
                      icon: _enhancing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : const Icon(Icons.auto_fix_high_rounded,
                              size: 16),
                      label: const Text('Enhance'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loadingSuggestions ? null : _getSuggestions,
                      icon: _loadingSuggestions
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : const Icon(Icons.lightbulb_outline_rounded,
                              size: 16),
                      label: const Text('Suggestions'),
                    ),
                  ),
                ],
              ),

              // Suggestion chips
              if (_suggestions.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: _suggestions
                      .map((s) => GestureDetector(
                            onTap: () {
                              _ctrl.text = s;
                              _ctrl.selection =
                                  TextSelection.collapsed(offset: s.length);
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusFull),
                                border: Border.all(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.3)),
                              ),
                              child: Text(s,
                                  style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.primary)),
                            ),
                          ))
                      .toList(),
                ),
              ],

              const SizedBox(height: AppSpacing.lg),
              AppPrimaryButton(
                label: AppStrings.addAffirmation,
                onPressed: isValid ? _submit : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Affirmation tile ─────────────────────────────────────────────────────────

class _AffirmationTile extends StatelessWidget {
  final Affirmation affirmation;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _AffirmationTile({
    required this.affirmation,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: affirmation.isActive
                  ? AppColors.primary
                  : AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  affirmation.text,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: affirmation.isActive
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                    fontStyle: affirmation.isActive
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
                if (affirmation.category != 'general') ...[
                  const SizedBox(height: 4),
                  Text(
                    affirmation.category[0].toUpperCase() +
                        affirmation.category.substring(1),
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.primary),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: affirmation.isActive,
            onChanged: (_) => onToggle(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.textMuted, size: 20),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

// ─── Session launch button ────────────────────────────────────────────────────

class _SessionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _SessionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: onTap != null
              ? color.withValues(alpha: 0.1)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(
              color: onTap != null
                  ? color.withValues(alpha: 0.3)
                  : AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: onTap != null ? color : AppColors.textMuted, size: 18),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: onTap != null ? color : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Affirmation session dialog (public — used by dashboard card + tab) ───────

class AffirmationSessionSheet extends StatefulWidget {
  final List<Affirmation> affirmations;
  final String sessionType;
  final Future<void> Function() onComplete;

  const AffirmationSessionSheet({
    super.key,
    required this.affirmations,
    required this.sessionType,
    required this.onComplete,
  });

  @override
  State<AffirmationSessionSheet> createState() =>
      _AffirmationSessionSheetState();
}

class _AffirmationSessionSheetState extends State<AffirmationSessionSheet>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _completing = false;
  late final ConfettiController _confettiCtrl;
  late final AnimationController _successCtrl;
  late final Animation<double> _successScale;

  bool get _isMorning => widget.sessionType == 'morning';
  bool get _isLast => _currentIndex == widget.affirmations.length - 1;
  Color get _accent => _isMorning ? AppColors.warning : AppColors.secondary;
  Color get _accentGlow =>
      _isMorning ? AppColors.warningContainer : AppColors.secondaryContainer;

  @override
  void initState() {
    super.initState();
    _confettiCtrl =
        ConfettiController(duration: const Duration(milliseconds: 1600));
    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _successScale = CurvedAnimation(
      parent: _successCtrl,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  void _previous() {
    if (_currentIndex > 0) setState(() => _currentIndex--);
  }

  void _next() {
    if (!_isLast) setState(() => _currentIndex++);
  }

  Future<void> _complete() async {
    if (_completing) return;
    setState(() => _completing = true);
    await widget.onComplete();
    _confettiCtrl.play();
    _successCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final affirmation = widget.affirmations[_currentIndex];
    final count = widget.affirmations.length;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Dialog(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            side: BorderSide(
              color: _accent.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ───────────────────────────────────────────────
                Row(
                  children: [
                    // Session icon badge
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _accentGlow,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                      child: Icon(
                        _isMorning
                            ? Icons.wb_sunny_rounded
                            : Icons.nightlight_round,
                        color: _accent,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _isMorning
                            ? 'Morning Affirmations'
                            : 'Evening Affirmations',
                        style: AppTextStyles.headlineSmall,
                      ),
                    ),
                    // Close without completing
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusFull),
                        ),
                        child: const Icon(Icons.close_rounded,
                            size: 16, color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // ── Progress dots ────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(count, (i) {
                    final isActive = i == _currentIndex;
                    final isPast = i < _currentIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin:
                          const EdgeInsets.symmetric(horizontal: 3),
                      width: isActive ? 20 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: (isActive || isPast)
                            ? _accent
                            : AppColors.border,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusFull),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ── Affirmation card ─────────────────────────────────────
                _completing
                    ? ScaleTransition(
                        scale: _successScale,
                        child: Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            color: _accentGlow,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusLg),
                            border: Border.all(
                                color: _accent.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  color: _accent, size: 52),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'Session Complete!',
                                style: AppTextStyles.headlineSmall
                                    .copyWith(color: _accent),
                              ),
                            ],
                          ),
                        ),
                      )
                    : AnimatedSwitcher(
                        duration: const Duration(milliseconds: 320),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.05, 0),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: anim,
                              curve: Curves.easeOut,
                            )),
                            child: child,
                          ),
                        ),
                        child: Container(
                          key: ValueKey(_currentIndex),
                          width: double.infinity,
                          constraints:
                              const BoxConstraints(minHeight: 200),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusLg),
                            border: Border.all(
                              color: _accent.withValues(alpha: 0.2),
                            ),
                          ),
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Glow accent line
                              Container(
                                width: 32,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: _accent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Text(
                                affirmation.text,
                                style: AppTextStyles.headlineSmall.copyWith(
                                  fontStyle: FontStyle.italic,
                                  height: 1.7,
                                  color: AppColors.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),

                const SizedBox(height: AppSpacing.sm),

                // Counter label
                Text(
                  '${_currentIndex + 1} of $count',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textMuted),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ── Navigation buttons ───────────────────────────────────
                if (!_completing)
                  Row(
                    children: [
                      // Previous
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              _currentIndex > 0 ? _previous : null,
                          icon: const Icon(
                              Icons.arrow_back_ios_rounded,
                              size: 14),
                          label: const Text('Previous'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(
                                color: AppColors.border),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMd),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // Next / Complete
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _isLast ? _complete : _next,
                          icon: Icon(
                            _isLast
                                ? Icons.check_rounded
                                : Icons.arrow_forward_ios_rounded,
                            size: 14,
                          ),
                          label:
                              Text(_isLast ? 'Complete' : 'Next'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMd),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),

        // ── Confetti (overlay, fires from top of dialog) ─────────────
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiCtrl,
            blastDirectionality: BlastDirectionality.explosive,
            colors: [
              AppColors.primary,
              _accent,
              AppColors.secondary,
              Colors.white,
            ],
            numberOfParticles: 50,
            gravity: 0.25,
          ),
        ),
      ],
    );
  }
}

// ─── Generate affirmations sheet (with error UX + retry) ─────────────────────

class _GenerateAffirmationsSheet extends ConsumerStatefulWidget {
  final UserProfile profile;

  const _GenerateAffirmationsSheet({required this.profile});

  @override
  ConsumerState<_GenerateAffirmationsSheet> createState() =>
      _GenerateAffirmationsSheetState();
}

class _GenerateAffirmationsSheetState
    extends ConsumerState<_GenerateAffirmationsSheet> {
  List<String> _suggestions = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Set<int> _added = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final result = await ref
          .read(claudeServiceProvider)
          .generateAffirmations(widget.profile);
      if (mounted) {
        setState(() {
          _suggestions = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Could not generate affirmations. Check your connection and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Affirmations', style: AppTextStyles.headlineMedium),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_isLoading)
            const Center(
                child:
                    CircularProgressIndicator(color: AppColors.primary))
          else if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.error, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(_errorMessage!,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.error)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppPrimaryButton(
              label: 'Retry',
              onPressed: _load,
            ),
          ] else
            ..._suggestions.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              final isAdded = _added.contains(i);
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s,
                          style: AppTextStyles.bodyMedium
                              .copyWith(fontStyle: FontStyle.italic),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: isAdded
                            ? const Icon(
                                Icons.check_circle_rounded,
                                key: ValueKey('check'),
                                color: AppColors.success,
                              )
                            : IconButton(
                                key: const ValueKey('add'),
                                icon: const Icon(Icons.add_circle_rounded,
                                    color: AppColors.primary),
                                onPressed: () {
                                  ref
                                      .read(affirmationsProvider.notifier)
                                      .addAffirmation(
                                        Affirmation(
                                          id: const Uuid().v4(),
                                          text: s,
                                          source: 'ai',
                                          createdAt: DateTime.now(),
                                        ),
                                      );
                                  setState(() => _added.add(i));
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
