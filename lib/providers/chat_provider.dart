import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/analytics_service.dart';
import '../models/chat_session.dart';
import '../models/chat_message.dart';
import 'auth_provider.dart';

final chatSessionsProvider =
    StreamProvider.family<List<ChatSession>, String>((ref, mode) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return const Stream.empty();
  // Surface query failures (e.g. a missing Firestore composite index) instead
  // of letting `.valueOrNull ?? []` silently render an empty history.
  return ref.watch(firestoreServiceProvider).streamChatSessions(uid, mode).handleError(
        (Object e) => debugPrint('chatSessionsProvider($mode) failed: $e'),
      );
});

class ActiveChatNotifier extends StateNotifier<ChatSession?> {
  final Ref _ref;

  ActiveChatNotifier(this._ref) : super(null);

  void setSession(ChatSession session) => state = session;

  void clearSession() => state = null;

  Future<void> addMessage(ChatMessage message) async {
    if (state == null) return;
    final updated = state!.copyWith(
      messages: [...state!.messages, message],
      updatedAt: DateTime.now(),
    );
    state = updated;
    await _ref
        .read(firestoreServiceProvider)
        .updateChatMessages(updated.id, updated.messages);

    if (message.isUser) {
      final userMessageCount =
          updated.messages.where((m) => m.isUser).length;
      _ref.read(analyticsServiceProvider).trackCoachMessageSent(
            mode: updated.mode,
            sessionLength: userMessageCount,
          );
    }
  }

  Future<void> removeMessage(String messageId) async {
    if (state == null) return;
    final messages = state!.messages.where((m) => m.id != messageId).toList();
    final updated = state!.copyWith(messages: messages, updatedAt: DateTime.now());
    state = updated;
    await _ref
        .read(firestoreServiceProvider)
        .updateChatMessages(updated.id, messages);
  }

  Future<void> updateMessageFeedback(String messageId, int feedback) async {
    if (state == null) return;
    final messages = state!.messages.map((m) {
      if (m.id == messageId) return m.copyWith(feedback: feedback);
      return m;
    }).toList();
    final updated = state!.copyWith(messages: messages, updatedAt: DateTime.now());
    state = updated;
    await _ref
        .read(firestoreServiceProvider)
        .updateChatMessages(updated.id, messages);
  }

  Future<void> saveSession(ChatSession session) async {
    state = session;
    await _ref.read(firestoreServiceProvider).saveChatSession(session);
  }
}

final activeChatProvider =
    StateNotifierProvider<ActiveChatNotifier, ChatSession?>(
  (ref) => ActiveChatNotifier(ref),
);
