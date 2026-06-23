import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/journal_entry.dart';
import 'auth_provider.dart';

class JournalNotifier extends StateNotifier<List<JournalEntry>> {
  final Ref _ref;

  JournalNotifier(this._ref) : super([]);

  Future<void> saveEntry(JournalEntry entry) async {
    await _ref.read(firestoreServiceProvider).saveJournalEntry(entry);
  }

  Future<void> deleteEntry(String entryId) async {
    await _ref.read(firestoreServiceProvider).deleteJournalEntry(entryId);
  }
}

final journalEntriesProvider = StreamProvider<List<JournalEntry>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(firestoreServiceProvider).streamJournalEntries(uid);
});

final journalProvider = StateNotifierProvider<JournalNotifier, List<JournalEntry>>(
  (ref) => JournalNotifier(ref),
);
