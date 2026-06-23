import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_profile.dart';
import '../../models/journal_entry.dart';
import '../../models/chat_session.dart';
import '../../models/chat_message.dart';

class FirestoreService {
  FirestoreService() {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  }

  final _db = FirebaseFirestore.instance;

  // ─── Collections ──────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _journals =>
      _db.collection('journals');
  CollectionReference<Map<String, dynamic>> get _chatSessions =>
      _db.collection('chat_sessions');

  // ─── UserProfile ──────────────────────────────────────────────────────────

  Stream<UserProfile?> streamUserProfile(String uid) {
    return _users.doc(uid).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return UserProfile.fromJson({'uid': uid, ...snap.data()!});
    });
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    final snap = await _users.doc(uid).get();
    if (!snap.exists || snap.data() == null) return null;
    return UserProfile.fromJson({'uid': uid, ...snap.data()!});
  }

  Future<void> createUserProfile(UserProfile profile) async {
    await _users.doc(profile.uid).set(profile.toJson());
  }

  Future<void> updateUserProfile(UserProfile profile) async {
    await _users.doc(profile.uid).set(profile.toJson(), SetOptions(merge: true));
  }

  Future<void> updateUserField(String uid, Map<String, dynamic> fields) async {
    await _users.doc(uid).update(fields);
  }

  Future<void> updateOnboardingStep(String uid, int step) async {
    await _users.doc(uid).set({'onboardingStep': step}, SetOptions(merge: true));
  }

  // ─── JournalEntry ─────────────────────────────────────────────────────────

  Stream<List<JournalEntry>> streamJournalEntries(String uid) {
    return _journals
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) =>
                JournalEntry.fromJson({'id': doc.id, ...doc.data()}))
            .toList());
  }

  Future<void> saveJournalEntry(JournalEntry entry) async {
    await _journals.doc(entry.id).set(entry.toJson());
  }

  Future<void> deleteJournalEntry(String entryId) async {
    await _journals.doc(entryId).delete();
  }

  // ─── ChatSession ──────────────────────────────────────────────────────────

  Stream<List<ChatSession>> streamChatSessions(String uid, String mode) {
    return _chatSessions
        .where('uid', isEqualTo: uid)
        .where('mode', isEqualTo: mode)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) =>
                ChatSession.fromJson({'id': doc.id, ...doc.data()}))
            .toList());
  }

  Future<void> saveChatSession(ChatSession session) async {
    await _chatSessions.doc(session.id).set(session.toJson());
  }

  Future<void> updateChatMessages(
      String sessionId, List<ChatMessage> messages) async {
    await _chatSessions.doc(sessionId).update({
      'messages': messages.map((m) => m.toJson()).toList(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteChatSession(String sessionId) async {
    await _chatSessions.doc(sessionId).delete();
  }
}
