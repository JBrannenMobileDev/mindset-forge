import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_session.dart';
import '../models/chat_message.dart';
import 'auth_provider.dart';

final chatSessionsProvider =
    StreamProvider.family<List<ChatSession>, String>((ref, mode) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(firestoreServiceProvider).streamChatSessions(uid, mode);
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
