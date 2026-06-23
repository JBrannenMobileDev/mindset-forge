import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../models/chat_session.dart';
import '../../models/chat_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/claude_provider.dart';
import '../../providers/daily_completion_provider.dart';
import 'future_self_setup_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String? journalContext;

  const ChatScreen({super.key, this.journalContext});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _coachMode = 'coach';
  final _futureSelfMode = 'future_self';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
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
                AppSpacing.lg,
                AppSpacing.screenPaddingH,
                0,
              ),
              child: Row(
                children: [
                  Text('Chat', style: AppTextStyles.headlineLarge),
                  const Spacer(),
                  _SessionsButton(
                    onTap: () => _showSessionsDrawer(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPaddingH),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(color: AppColors.border),
                ),
                child: TabBar(
                  controller: _tabCtrl,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd - 2),
                  ),
                  dividerColor: Colors.transparent,
                  labelStyle: AppTextStyles.labelLarge.copyWith(color: Colors.white),
                  unselectedLabelStyle: AppTextStyles.labelMedium,
                  unselectedLabelColor: AppColors.textSecondary,
                  tabs: const [
                    Tab(text: AppStrings.coachMode),
                    Tab(text: AppStrings.futureSelfMode),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _ChatView(
                    mode: _coachMode,
                    onNewSession: () => _startNewSession(_coachMode),
                    profile: profile,
                    journalContext: widget.journalContext,
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

  const _ChatView({
    required this.mode,
    required this.onNewSession,
    required this.profile,
    this.journalContext,
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadOpener());
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
    setState(() {});
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

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
    await ref.read(activeChatProvider.notifier).addMessage(userMsg);
    if (!mounted) return;
    _scrollToBottom();
    setState(() => _isTyping = true);

    if (!_firstMessageSent) {
      _firstMessageSent = true;
      await ref.read(dailyCompletionProvider.notifier).toggle('chatCompleted', true);
      if (!mounted) return;
    }

    try {
      final profile = widget.profile;
      final messages = session.messages;
      String response;

      if (widget.mode == 'coach') {
        response = await ref.read(claudeServiceProvider).generateCoachResponse(
              profile,
              messages,
              text,
            );
      } else {
        response = await ref.read(claudeServiceProvider).generateFutureSelfResponse(
              profile,
              messages,
              text,
            );
      }

      final aiMsg = ChatMessage(
        id: const Uuid().v4(),
        role: 'assistant',
        content: response,
        timestamp: DateTime.now(),
      );

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
    final showOpener = messages.isEmpty && widget.mode == 'coach';

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
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
                  padding: EdgeInsets.only(bottom: AppSpacing.md),
                  child: _TypingIndicator(),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _ChatBubble(
                  message: messages[msgIdx],
                  mode: widget.mode,
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
        _ChatInput(
          controller: _inputCtrl,
          onSend: _send,
          mode: widget.mode,
          onNewSession: widget.onNewSession,
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
                MaterialPageRoute(builder: (_) => const FutureSelfSetupScreen()),
              ),
            ),
          ],
        ),
      );
    }

    return _ChatView(mode: mode, onNewSession: onNewSession, profile: profile);
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final String mode;
  final void Function(int) onFeedback;

  const _ChatBubble({
    required this.message,
    required this.mode,
    required this.onFeedback,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final isFutureSelf = mode == 'future_self';

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
          child: GestureDetector(
            onLongPress: () {
              Clipboard.setData(ClipboardData(text: message.content));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Message copied')),
              );
            },
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
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
                    message.content,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isUser ? Colors.white : AppColors.textPrimary,
                      height: 1.6,
                    ),
                  ),
                ),
                if (!isUser) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      _FeedbackButton(
                        icon: Icons.thumb_up_rounded,
                        isSelected: message.feedback == 1,
                        onTap: () => onFeedback(1),
                      ),
                      const SizedBox(width: AppSpacing.xs),
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
        if (isUser) const SizedBox(width: AppSpacing.xl + AppSpacing.sm),
      ],
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
      child: Icon(
        icon,
        size: 14,
        color: isSelected ? AppColors.primary : AppColors.textMuted,
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
    _anims = _ctrs.map((c) => Tween<double>(begin: 0, end: 8).animate(
          CurvedAnimation(parent: c, curve: Curves.easeInOut),
        )).toList();

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
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
                builder: (_, __) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Transform.translate(
                    offset: Offset(0, -_anims[i].value),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
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
  final VoidCallback onNewSession;

  const _ChatInput({
    required this.controller,
    required this.onSend,
    required this.mode,
    required this.onNewSession,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.screenPaddingH,
        right: AppSpacing.screenPaddingH,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md + AppSpacing.bottomNavHeight,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: onNewSession,
            color: AppColors.textMuted,
          ),
          Expanded(
            child: TextField(
              controller: controller,
              style: AppTextStyles.bodyMedium,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              cursorColor: AppColors.primary,
              decoration: InputDecoration(
                hintText: mode == 'coach'
                    ? AppStrings.typeMessage
                    : 'Ask your future self...',
                hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                boxShadow: [BoxShadow(color: AppColors.primaryGlow, blurRadius: 12)],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionsButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SessionsButton({required this.onTap});

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
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.history_rounded, color: AppColors.textSecondary, size: 16),
            const SizedBox(width: AppSpacing.xs),
            Text(AppStrings.sessions, style: AppTextStyles.labelSmall),
          ],
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
              'No saved sessions yet.',
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
