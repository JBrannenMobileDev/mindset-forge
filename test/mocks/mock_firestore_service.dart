import 'package:firebase_auth/firebase_auth.dart';
import 'package:mockito/mockito.dart';
import 'package:mindsetforge/core/firebase/firestore_service.dart';
import 'package:mindsetforge/models/user_profile.dart';
import 'package:mindsetforge/models/journal_entry.dart';
import 'package:mindsetforge/models/chat_session.dart';
import 'package:mindsetforge/models/chat_message.dart';

/// Hand-crafted mock for [FirestoreService].
///
/// Avoids [build_runner] code generation — useful when Firebase isn't
/// initialised in the test environment. All calls default to [noSuchMethod]
/// stubs via the [Mock] superclass; stub individual methods with [when] in
/// each test.
class MockFirestoreService extends Mock implements FirestoreService {
  @override
  Stream<UserProfile?> streamUserProfile(String uid) =>
      super.noSuchMethod(
        Invocation.method(#streamUserProfile, [uid]),
        returnValue: const Stream.empty(),
        returnValueForMissingStub: const Stream.empty(),
      ) as Stream<UserProfile?>;

  @override
  Future<UserProfile?> getUserProfile(String uid) =>
      super.noSuchMethod(
        Invocation.method(#getUserProfile, [uid]),
        returnValue: Future.value(null),
        returnValueForMissingStub: Future.value(null),
      ) as Future<UserProfile?>;

  @override
  Future<void> createUserProfile(UserProfile profile) =>
      super.noSuchMethod(
        Invocation.method(#createUserProfile, [profile]),
        returnValue: Future.value(),
        returnValueForMissingStub: Future.value(),
      ) as Future<void>;

  @override
  Future<void> updateUserProfile(UserProfile profile) =>
      super.noSuchMethod(
        Invocation.method(#updateUserProfile, [profile]),
        returnValue: Future.value(),
        returnValueForMissingStub: Future.value(),
      ) as Future<void>;

  @override
  Future<void> updateUserField(String uid, Map<String, dynamic> fields) =>
      super.noSuchMethod(
        Invocation.method(#updateUserField, [uid, fields]),
        returnValue: Future.value(),
        returnValueForMissingStub: Future.value(),
      ) as Future<void>;

  @override
  Future<void> updateOnboardingStep(String uid, int step) =>
      super.noSuchMethod(
        Invocation.method(#updateOnboardingStep, [uid, step]),
        returnValue: Future.value(),
        returnValueForMissingStub: Future.value(),
      ) as Future<void>;

  @override
  Stream<List<JournalEntry>> streamJournalEntries(String uid) =>
      super.noSuchMethod(
        Invocation.method(#streamJournalEntries, [uid]),
        returnValue: const Stream.empty(),
        returnValueForMissingStub: const Stream.empty(),
      ) as Stream<List<JournalEntry>>;

  @override
  Future<void> saveJournalEntry(JournalEntry entry) =>
      super.noSuchMethod(
        Invocation.method(#saveJournalEntry, [entry]),
        returnValue: Future.value(),
        returnValueForMissingStub: Future.value(),
      ) as Future<void>;

  @override
  Future<void> deleteJournalEntry(String entryId) =>
      super.noSuchMethod(
        Invocation.method(#deleteJournalEntry, [entryId]),
        returnValue: Future.value(),
        returnValueForMissingStub: Future.value(),
      ) as Future<void>;

  @override
  Stream<List<ChatSession>> streamChatSessions(String uid, String mode) =>
      super.noSuchMethod(
        Invocation.method(#streamChatSessions, [uid, mode]),
        returnValue: const Stream.empty(),
        returnValueForMissingStub: const Stream.empty(),
      ) as Stream<List<ChatSession>>;

  @override
  Future<void> saveChatSession(ChatSession session) =>
      super.noSuchMethod(
        Invocation.method(#saveChatSession, [session]),
        returnValue: Future.value(),
        returnValueForMissingStub: Future.value(),
      ) as Future<void>;

  @override
  Future<void> updateChatMessages(
          String sessionId, List<ChatMessage> messages) =>
      super.noSuchMethod(
        Invocation.method(#updateChatMessages, [sessionId, messages]),
        returnValue: Future.value(),
        returnValueForMissingStub: Future.value(),
      ) as Future<void>;

  @override
  Future<void> deleteChatSession(String sessionId) =>
      super.noSuchMethod(
        Invocation.method(#deleteChatSession, [sessionId]),
        returnValue: Future.value(),
        returnValueForMissingStub: Future.value(),
      ) as Future<void>;
}

/// Minimal [User] fake — provides only [uid]; all other members throw
/// [UnimplementedError] if called (via [Fake]).
class FakeUser extends Fake implements User {
  FakeUser(this.uid);

  @override
  final String uid;
}
