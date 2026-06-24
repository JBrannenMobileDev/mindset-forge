import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/belief_pattern.dart';
import '../models/coach_memory.dart';
import '../models/coach_reply.dart';
import 'auth_provider.dart';

/// Persists the structured `memory_updates` the coach returns after each turn
/// into the user's [CoachMemory] and belief pattern history, so the coach feels
/// continuous across sessions.
class CoachMemoryWriter {
  final Ref _ref;
  const CoachMemoryWriter(this._ref);

  static const _maxPatterns = 12;
  static const _maxKeyMoments = 12;

  Future<void> applyUpdate(CoachMemoryUpdate update) async {
    if (update.isEmpty) return;

    final profile = _ref.read(currentUserProfileProvider).valueOrNull;
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (profile == null || uid == null) return;

    final now = DateTime.now();
    final current = profile.coachMemory;
    const uuid = Uuid();

    // Commitments: mark fulfilled ones, then append new ones.
    final commitments = current.openCommitments.map((c) {
      final isFulfilled = update.fulfilledCommitments.any(
        (f) => _looselyMatches(c.text, f),
      );
      return isFulfilled ? c.copyWith(fulfilled: true) : c;
    }).toList();

    for (final text in update.newCommitments) {
      if (text.trim().isEmpty) continue;
      final exists = commitments.any((c) => _looselyMatches(c.text, text));
      if (exists) continue;
      commitments.add(CoachCommitment(
        id: uuid.v4(),
        text: text.trim(),
        createdAt: now,
      ));
    }

    final patterns = _mergeCapped(
      current.recurringPatterns,
      update.patterns,
      _maxPatterns,
    );
    final keyMoments = _mergeCapped(
      current.keyMoments,
      update.keyMoments,
      _maxKeyMoments,
    );

    final updatedMemory = current.copyWith(
      longTermSummary: update.longTermSummary.isNotEmpty
          ? update.longTermSummary
          : current.longTermSummary,
      lastSessionSummary: update.sessionSummary.isNotEmpty
          ? update.sessionSummary
          : current.lastSessionSummary,
      lastSessionAt: now,
      openCommitments: commitments,
      recurringPatterns: patterns,
      keyMoments: keyMoments,
    );

    // Belief reframes are appended to the existing belief pattern history.
    final beliefHistory = [...profile.beliefPatternHistory];
    for (final r in update.beliefReframes) {
      final dup = beliefHistory.any((b) => _looselyMatches(b.belief, r.belief));
      if (dup) continue;
      beliefHistory.add(BeliefPattern(
        id: uuid.v4(),
        belief: r.belief,
        reframe: r.reframe,
        identifiedAt: now,
      ));
    }

    try {
      await _ref.read(firestoreServiceProvider).updateUserField(uid, {
        'coachMemory': updatedMemory.toJson(),
        if (update.beliefReframes.isNotEmpty)
          'beliefPatternHistory':
              beliefHistory.map((b) => b.toJson()).toList(),
      });
    } catch (e) {
      debugPrint('CoachMemoryWriter.applyUpdate failed: $e');
    }
  }

  static bool _looselyMatches(String a, String b) {
    final na = a.toLowerCase().trim();
    final nb = b.toLowerCase().trim();
    if (na.isEmpty || nb.isEmpty) return false;
    return na == nb || na.contains(nb) || nb.contains(na);
  }

  static List<String> _mergeCapped(
    List<String> existing,
    List<String> incoming,
    int cap,
  ) {
    final merged = [...existing];
    for (final item in incoming) {
      final t = item.trim();
      if (t.isEmpty) continue;
      final dup = merged.any((e) => _looselyMatches(e, t));
      if (!dup) merged.add(t);
    }
    // Keep the most recent items if over cap.
    if (merged.length > cap) {
      return merged.sublist(merged.length - cap);
    }
    return merged;
  }
}

final coachMemoryWriterProvider = Provider<CoachMemoryWriter>(
  (ref) => CoachMemoryWriter(ref),
);
