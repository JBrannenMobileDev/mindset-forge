import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/analytics_service.dart';
import '../models/journal_entry.dart';
import 'auth_provider.dart';

class JournalNotifier extends StateNotifier<List<JournalEntry>> {
  final Ref _ref;

  JournalNotifier(this._ref) : super([]);

  Future<void> saveEntry(JournalEntry entry) async {
    await _ref.read(firestoreServiceProvider).saveJournalEntry(entry);
    final wordCount = entry.content.trim().split(RegExp(r'\s+')).length;
    final hasTags = entry.limitingBeliefsShifted.isNotEmpty ||
        entry.fearsOutwitted.isNotEmpty;
    _ref.read(analyticsServiceProvider).trackJournalEntrySaved(
          mode: entry.mode,
          wordCount: wordCount,
          hasTags: hasTags,
        );
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
