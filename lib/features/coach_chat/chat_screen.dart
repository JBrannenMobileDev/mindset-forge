import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/crisis_resources.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../models/chat_session.dart';
import '../../models/chat_message.dart';
import '../../models/coach_reply.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/claude_provider.dart';
import '../../providers/coach_memory_provider.dart';
import '../../providers/daily_completion_provider.dart';
import '../../providers/partner_limits_provider.dart';
import '../goals_habits/goal_form_modal.dart';
import '../goals_habits/habits_tab.dart';
import '../mindset/affirmations_tab.dart';
import '../future_self/future_self_wizard.dart';
import 'widgets/crisis_resource_card.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String? journalContext;
  final String? journalPrompt;

  const ChatScreen({super.key, this.journalContext, this.journalPrompt});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _coachMode = 'coach';
  final _futureSelfMode = 'future_self';
  bool _disclaimerShown = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  /// One-time, non-dismissible coach disclaimer. Shown the first time a user
  /// opens the chat until they acknowledge it (persisted on the profile).
  Future<void> _showCoachDisclaimer() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: AppColors.scrim,
      useRootNavigator: true,
      builder: (dialogContext) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (ctx, setLocalState) => Dialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              side: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 40,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                        child: const Icon(Icons.favorite_rounded,
                            size: 18, color: AppColors.primary),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(AppStrings.coachDisclaimerTitle,
                            style: AppTextStyles.headlineSmall),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    AppStrings.coachDisclaimerBody,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  GestureDetector(
                    onTap: () => ctx.push('/terms'),
                    child: Text(
                      AppStrings.coachDisclaimerReadMore,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppPrimaryButton(
                    label: AppStrings.coachDisclaimerCta,
                    isLoading: isSaving,
                    onPressed: () async {
                      setLocalState(() => isSaving = true);
                      try {
                        await ref
                            .read(firestoreServiceProvider)
                            .updateUserField(uid, {
                          'coachDisclaimerAcceptedAt':
                              DateTime.now().toIso8601String(),
                        });
                      } catch (_) {
                        // Non-blocking: allow the user through even if the
                        // write fails; it will retry on next open.
                      }
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _startNewSession(String mode) {
    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    final session = ChatSession(
      id: const Uuid().v4(),
      uid: uid,
      mode: mode,
      topic: mode == _coachMode ? 'Coaching Session' : 'Future Self',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    ref.read(activeChatProvider.notifier).saveSession(session);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;

    if (profile != null &&
        !profile.hasAcceptedCoachDisclaimer &&
        !_disclaimerShown) {
      _disclaimerShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showCoachDisclaimer();
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ResponsiveLayout(
          maxWidth: 680,
          child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPaddingH,
                AppSpacing.md,
                AppSpacing.screenPaddingH,
                AppSpacing.sm,
              ),
              child: AnimatedBuilder(
                animation: _tabCtrl,
                builder: (context, _) {
                  final modeIndex = _tabCtrl.index;
                  return Row(
                    children: [
                      _HeaderIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        tooltip: AppStrings.back,
                        onTap: () => context.go('/dashboard'),
                      ),
                      Expanded(
                        child: Center(
                          child: _ModeSwitch(
                            selectedIndex: modeIndex,
                            onSelect: (i) => _tabCtrl.animateTo(i),
                          ),
                        ),
                      ),
                      _HeaderIconButton(
                        icon: Icons.history_rounded,
                        tooltip: AppStrings.sessions,
                        onTap: () => _showSessionsDrawer(context),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _HeaderIconButton(
                        icon: Icons.add_rounded,
                        tooltip: AppStrings.newSession,
                        onTap: () => _startNewSession(
                          modeIndex == 0 ? _coachMode : _futureSelfMode,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _ChatView(
                    mode: _coachMode,
                    onNewSession: () => _startNewSession(_coachMode),
                    profile: profile,
                    journalContext: widget.journalContext,
                    journalPrompt: widget.journalPrompt,
                  ),
                  _FutureSelfChatView(
                    mode: _futureSelfMode,
                    onNewSession: () => _startNewSession(_futureSelfMode),
                    profile: profile,
                  ),
                ],
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  void _showSessionsDrawer(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
        child: _SessionsSheet(
          onSelectSession: (session) {
            ref.read(activeChatProvider.notifier).setSession(session);
          },
        ),
      ),
    );
  }
}

class _ChatView extends ConsumerStatefulWidget {
  final String mode;
  final VoidCallback onNewSession;
  final dynamic profile;
  final String? journalContext;
  final String? journalPrompt;

  const _ChatView({
    required this.mode,
    required this.onNewSession,
    required this.profile,
    this.journalContext,
    this.journalPrompt,
  });

  @override
  ConsumerState<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<_ChatView> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isTyping = false;
  bool _firstMessageSent = false;

  // Session opener
  String? _openerText;
  List<String> _quickPrompts = [];
  bool _loadingOpener = false;

  @override
  void initState() {
    super.initState();
    if (widget.mode == 'coach') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.journalContext != null) {
          _autoStartFromJournal();
        } else {
          _loadOpener();
        }
      });
    }
  }

  Future<void> _loadOpener() async {
    if (!mounted) return;
    setState(() => _loadingOpener = true);
    try {
      final profile = widget.profile;
      if (profile == null) return;
      final result = await ref.read(claudeServiceProvider).generateSessionOpener(
            profile,
            journalContext: widget.journalContext,
          );
      if (!mounted) return;
      setState(() {
        _openerText = result['opener'] as String?;
        _quickPrompts = List<String>.from(result['prompts'] as List? ?? []);
        _loadingOpener = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingOpener = false);
    }
  }

  /// Journal path: skip opener/chips, auto-create session, auto-send journal content.
  /// The coach's reply will naturally end with a follow-up question per the system prompt.
  Future<void> _autoStartFromJournal() async {
    if (!mounted) return;
    if (ref.read(activeChatProvider) == null) {
      widget.onNewSession();
      // Let the provider update before sending.
      await Future.delayed(Duration.zero);
      if (!mounted) return;
    }
    final prompt = widget.journalPrompt;
    _inputCtrl.text = prompt != null && prompt.isNotEmpty
        ? 'I want to discuss my journal entry.\n\nToday\'s prompt: $prompt\n\nMy response: ${widget.journalContext}'
        : 'I want to discuss my journal entry:\n\n${widget.journalContext}';
    await _send();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _useQuickPrompt(String prompt) {
    _inputCtrl.text = prompt;
    _inputCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: prompt.length),
    );
    _send();
  }

  /// Opens the exact creation flow a coach action pill maps to, prefilled with
  /// the AI's suggested [payload]. Each action corresponds to a real in-app
  /// feature; there is no generic-navigation fallback.
  void _handleCoachAction(CoachActionType type, String payload) {
    switch (type) {
      case CoachActionType.goal:
        GoalFormModal.show(context, ref, initialTitle: payload);
      case CoachActionType.habit:
        HabitFormModal.show(context, ref, initialName: payload);
      case CoachActionType.affirmation:
        final profile = ref.read(currentUserProfileProvider).valueOrNull;
        if (profile == null) return;
        AffirmationFormModal.show(
          context,
          ref,
          profile: profile,
          initialText: payload,
        );
      case CoachActionType.futureSelf:
        context.push('/future-self');
    }
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    // Free partner accounts get a limited number of coach messages per week.
    final allowed = await ref
        .read(partnerLimitsProvider)
        .tryConsume(context, PartnerFeature.chat);
    if (!allowed || !mounted) return;

    final session = ref.read(activeChatProvider);
    if (session == null) {
      widget.onNewSession();
      return;
    }

    final userMsg = ChatMessage(
      id: const Uuid().v4(),
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    );

    _inputCtrl.clear();
    // Collapse the keyboard so the full coach response is visible.
    FocusManager.instance.primaryFocus?.unfocus();
    await ref.read(activeChatProvider.notifier).addMessage(userMsg);
    if (!mounted) return;
    _scrollToBottom();
    setState(() => _isTyping = true);
    _scrollToBottom();

    if (!_firstMessageSent) {
      _firstMessageSent = true;
      await ref.read(dailyCompletionProvider.notifier).toggle('chatCompleted', true);
      if (!mounted) return;
    }

    try {
      final profile = widget.profile;
      final messages = session.messages;
      late final ChatMessage aiMsg;

      if (widget.mode == 'coach') {
        final reply = await ref
            .read(claudeServiceProvider)
            .generateCoachResponse(profile, messages, text);

        // High-recall safety backstop: if the user's own message contains
        // crisis language, force the crisis treatment regardless of the model.
        final keywordCrisis = CrisisResources.containsCrisisLanguage(text);
        final isCrisis = reply.safety == CoachSafety.crisis || keywordCrisis;

        aiMsg = ChatMessage(
          id: const Uuid().v4(),
          role: 'assistant',
          content: reply.response,
          timestamp: DateTime.now(),
          mode: reply.modeLabel,
          safety: isCrisis
              ? 'crisis'
              : (reply.safety == CoachSafety.concern ? 'concern' : 'none'),
        );

        // Persist coaching memory unless we're in a crisis (no coaching).
        if (!isCrisis && !reply.memory.isEmpty) {
          await ref
              .read(coachMemoryWriterProvider)
              .applyUpdate(reply.memory);
        }
      } else {
        final response = await ref
            .read(claudeServiceProvider)
            .generateFutureSelfResponse(profile, messages, text);
        aiMsg = ChatMessage(
          id: const Uuid().v4(),
          role: 'assistant',
          content: response,
          timestamp: DateTime.now(),
        );
      }

      await ref.read(activeChatProvider.notifier).addMessage(aiMsg);
      if (mounted) _scrollToBottom();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.errorAI)),
        );
      }
    } finally {
      if (mounted) setState(() => _isTyping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeChatProvider);

    if (session == null || session.mode != widget.mode) {
      return EmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: AppStrings.noSessions,
        subtitle: AppStrings.noSessionsSubtitle,
        ctaLabel: AppStrings.newSession,
        onCta: widget.onNewSession,
      );
    }

    final messages = session.messages;
    final showOpener = messages.isEmpty &&
        widget.mode == 'coach' &&
        widget.journalContext == null;

    return Column(
      children: [
        Expanded(
          // Tapping the transcript dismisses the keyboard for a focused read.
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: ListView.builder(
              controller: _scrollCtrl,
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPaddingH,
                vertical: AppSpacing.md,
              ),
              itemCount: (showOpener ? 1 : 0) +
                  messages.length +
                  (_isTyping ? 1 : 0),
              itemBuilder: (_, i) {
                // Opener slot
                if (showOpener && i == 0) {
                  return _SessionOpener(
                    openerText: _openerText,
                    quickPrompts: _quickPrompts,
                    isLoading: _loadingOpener,
                    onPromptTap: _useQuickPrompt,
                  );
                }
                final msgIdx = showOpener ? i - 1 : i;
                if (msgIdx == messages.length && _isTyping) {
                  return const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.lg),
                    child: _TypingIndicator(),
                  ).animate().fadeIn(duration: 250.ms);
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: _ChatBubble(
                    message: messages[msgIdx],
                    mode: widget.mode,
                    onAction: _handleCoachAction,
                    onFeedback: (feedback) async {
                      await ref
                          .read(activeChatProvider.notifier)
                          .updateMessageFeedback(
                            messages[msgIdx].id,
                            feedback,
                          );
                    },
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
                );
              },
            ),
          ),
        ),
        _ChatInput(
          controller: _inputCtrl,
          onSend: _send,
          mode: widget.mode,
        ),
      ],
    );
  }
}

// ── Session opener with quick prompts ─────────────────────────────────────

class _SessionOpener extends StatelessWidget {
  final String? openerText;
  final List<String> quickPrompts;
  final bool isLoading;
  final void Function(String) onPromptTap;

  const _SessionOpener({
    required this.openerText,
    required this.quickPrompts,
    required this.isLoading,
    required this.onPromptTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Opener bubble
          if (isLoading)
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: AppColors.primary, size: 16),
                ),
                const SizedBox(width: AppSpacing.sm),
                const _TypingIndicator(),
              ],
            )
          else if (openerText != null && openerText!.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: AppColors.primary, size: 16),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(AppSpacing.radiusLg),
                        bottomLeft: Radius.circular(AppSpacing.radiusLg),
                        bottomRight: Radius.circular(AppSpacing.radiusLg),
                      ),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      openerText!,
                      style: AppTextStyles.bodyMedium.copyWith(height: 1.6),
                    ),
                  ).animate().fadeIn(duration: 400.ms),
                ),
              ],
            ),
            if (quickPrompts.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                AppStrings.quickPromptsLabel,
                style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: quickPrompts
                    .map((p) => GestureDetector(
                          onTap: () => onPromptTap(p),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusFull),
                              border: Border.all(
                                color: AppColors.primary
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              p,
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primary),
                            ),
                          ),
                        ))
                    .toList(),
              ).animate().fadeIn(delay: 200.ms, duration: 350.ms),
            ],
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _FutureSelfChatView extends ConsumerWidget {
  final String mode;
  final VoidCallback onNewSession;
  final dynamic profile;

  const _FutureSelfChatView({
    required this.mode,
    required this.onNewSession,
    required this.profile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (profile?.futureSelfSetup == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome_rounded, color: AppColors.futureSelfAccent, size: 48),
            const SizedBox(height: AppSpacing.lg),
            Text(AppStrings.futureSelfSetupTitle, style: AppTextStyles.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              AppStrings.futureSelfSetupSubtitle,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppPrimaryButton(
              label: AppStrings.futureSelfSetupTitle,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FutureSelfWizard()),
              ),
            ),
          ],
        ),
      );
    }

    return _ChatView(mode: mode, onNewSession: onNewSession, profile: profile);
  }
}

/// The four — and only four — in-app actions a coach reply can surface a
/// button for. Anything else the AI emits is dropped (text only, no pill).
enum CoachActionType { goal, habit, affirmation, futureSelf }

/// A parsed inline coach action: [[ACTION:Type:Payload]].
///
/// [payload] is the literal item text used to prefill the matching creation
/// form (goal title / habit name / affirmation sentence). It is unused for
/// [CoachActionType.futureSelf].
class _CoachAction {
  final CoachActionType type;
  final String payload;
  const _CoachAction(this.type, this.payload);

  /// Fixed, accurate button label per type — never free-form AI text.
  String get label => switch (type) {
        CoachActionType.goal => 'Set as a goal',
        CoachActionType.habit => 'Create this habit',
        CoachActionType.affirmation => 'Add this affirmation',
        CoachActionType.futureSelf => 'Start a Future Self practice',
      };
}

/// Maps a marker type word to a [CoachActionType], tolerating case and the
/// legacy plural / `futureself` spellings. Returns null for anything that is
/// not one of the four supported flows.
CoachActionType? _coachActionTypeFrom(String raw) {
  switch (raw.toLowerCase().trim().replaceAll(' ', '')) {
    case 'goal':
    case 'goals':
      return CoachActionType.goal;
    case 'habit':
    case 'habits':
      return CoachActionType.habit;
    case 'affirmation':
    case 'affirmations':
      return CoachActionType.affirmation;
    case 'futureself':
      return CoachActionType.futureSelf;
    default:
      return null;
  }
}

final _actionMarkerRegex = RegExp(r'\[\[ACTION:([^:\]]+):([^\]]+)\]\]');

({String text, List<_CoachAction> actions}) _parseCoachContent(String raw) {
  final actions = <_CoachAction>[];
  for (final m in _actionMarkerRegex.allMatches(raw)) {
    final type = _coachActionTypeFrom(m.group(1)!);
    if (type == null) continue; // unknown type -> no button
    actions.add(_CoachAction(type, m.group(2)!.trim()));
  }
  // Always strip every marker from the visible text, even unsupported ones.
  final text = raw.replaceAll(_actionMarkerRegex, '').trim();
  return (text: text, actions: actions);
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final String mode;
  final void Function(int) onFeedback;
  final void Function(CoachActionType type, String payload)? onAction;

  const _ChatBubble({
    required this.message,
    required this.mode,
    required this.onFeedback,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final isFutureSelf = mode == 'future_self';
    final parsed =
        isUser ? (text: message.content, actions: const <_CoachAction>[]) : _parseCoachContent(message.content);
    final showModeCue = !isUser &&
        !message.isCrisis &&
        message.mode != null &&
        message.mode!.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Cap bubble width so messages never span edge-to-edge, giving both
        // sides symmetric breathing room. Alignment is handled by the Row.
        final maxBubbleWidth = constraints.maxWidth * 0.78;
        return Row(
      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isUser) ...[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: isFutureSelf
                  ? const LinearGradient(colors: [AppColors.futureSelfAccent, AppColors.warning])
                  : const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFutureSelf ? Icons.auto_awesome_rounded : Icons.psychology_rounded,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: GestureDetector(
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: parsed.text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text(AppStrings.messageCopied)),
              );
            },
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showModeCue) ...[
                  _ModeCue(label: message.mode!),
                  const SizedBox(height: AppSpacing.xs),
                ],
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.primary
                        : isFutureSelf
                            ? AppColors.futureSelfSurface
                            : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(AppSpacing.radiusLg),
                      topRight: const Radius.circular(AppSpacing.radiusLg),
                      bottomLeft: Radius.circular(isUser ? AppSpacing.radiusLg : 4),
                      bottomRight: Radius.circular(isUser ? 4 : AppSpacing.radiusLg),
                    ),
                    border: isUser
                        ? null
                        : Border.all(
                            color: isFutureSelf
                                ? AppColors.futureSelfAccent.withValues(alpha: 0.2)
                                : AppColors.border,
                          ),
                  ),
                  child: Text(
                    parsed.text,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isUser ? Colors.white : AppColors.textPrimary,
                      height: 1.6,
                    ),
                  ),
                ),
                if (message.isCrisis) const CrisisResourceCard(),
                if (!isUser && parsed.actions.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: parsed.actions
                        .map((a) => _ActionPill(
                              label: a.label,
                              onTap: () =>
                                  onAction?.call(a.type, a.payload),
                            ))
                        .toList(),
                  ),
                ],
                if (!isUser && !message.isCrisis) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      _FeedbackButton(
                        icon: Icons.thumb_up_rounded,
                        isSelected: message.feedback == 1,
                        onTap: () => onFeedback(1),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _FeedbackButton(
                        icon: Icons.thumb_down_rounded,
                        isSelected: message.feedback == -1,
                        onTap: () => onFeedback(-1),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          ),
        ),
      ],
        );
      },
    );
  }
}

/// Subtle coaching-mode cue shown above a coach bubble.
class _ModeCue extends StatelessWidget {
  final String label;
  const _ModeCue({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.primary,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// Tappable pill that deep-links an inline coach action into the app.
class _ActionPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ActionPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          boxShadow: const [
            BoxShadow(color: AppColors.primaryGlow, blurRadius: 12),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded, size: 14, color: Colors.white),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackButton extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FeedbackButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? AppColors.primary : AppColors.textMuted,
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _ctrs;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _ctrs = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );
    _anims = _ctrs.map((c) => Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(parent: c, curve: Curves.easeInOut),
        )).toList();

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 180), () {
        if (mounted) _ctrs[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _ctrs) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.psychology_rounded, size: 16, color: Colors.white),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              return AnimatedBuilder(
                animation: _anims[i],
                builder: (_, __) {
                  final t = _anims[i].value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                    child: Opacity(
                      opacity: 0.35 + 0.65 * t,
                      child: Transform.scale(
                        scale: 0.7 + 0.3 * t,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: Color.lerp(
                              AppColors.textMuted,
                              AppColors.primary,
                              t,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final String mode;

  const _ChatInput({
    required this.controller,
    required this.onSend,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    // The chat is full-screen (no floating nav), so the composer pins to the
    // very bottom and only pads for the keyboard or the device safe area.
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final bottomInset = keyboardOpen
        ? AppSpacing.sm
        : MediaQuery.of(context).padding.bottom + AppSpacing.sm;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screenPaddingH,
        right: AppSpacing.screenPaddingH,
        top: AppSpacing.sm,
        bottom: bottomInset,
      ),
      // Single rounded pill: text field on the left, send embedded on the right.
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.xs,
          AppSpacing.xs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: TextField(
                  controller: controller,
                  style: AppTextStyles.bodyMedium,
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  cursorColor: AppColors.primary,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    hintText: mode == 'coach'
                        ? AppStrings.typeMessage
                        : AppStrings.futureSelfPlaceholder,
                    hintStyle: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textMuted),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            GestureDetector(
              onTap: onSend,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: AppColors.primaryGlow, blurRadius: 12),
                  ],
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact square icon button used in the chat header (sessions, new chat).
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, color: AppColors.textSecondary, size: 18),
        ),
      ),
    );
  }
}

/// Compact segmented control for switching between Coach and Future Self.
/// Replaces the full-width TabBar to reclaim vertical space.
class _ModeSwitch extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _ModeSwitch({required this.selectedIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(AppStrings.coachMode, 0),
          _segment(AppStrings.futureSelfMode, 1),
        ],
      ),
    );
  }

  Widget _segment(String label, int index) {
    final selected = index == selectedIndex;
    return GestureDetector(
      onTap: () => onSelect(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SessionsSheet extends ConsumerWidget {
  final void Function(ChatSession) onSelectSession;

  const _SessionsSheet({required this.onSelectSession});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coachSessions = ref.watch(chatSessionsProvider('coach')).valueOrNull ?? [];
    final allSessions = [...coachSessions]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(AppStrings.sessions, style: AppTextStyles.headlineMedium),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (allSessions.isEmpty)
            Text(
              AppStrings.noSavedSessions,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            )
          else
            ...allSessions.map((s) => ListTile(
                  onTap: () {
                    onSelectSession(s);
                    Navigator.pop(context);
                  },
                  title: Text(s.topic, style: AppTextStyles.labelLarge),
                  subtitle: Text(
                    s.lastMessagePreview,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    s.mode == 'coach' ? 'Coach' : 'Future Self',
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
                  ),
                )),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
