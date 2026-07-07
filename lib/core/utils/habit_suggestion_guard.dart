import '../constants/app_routines.dart';
import '../../models/user_profile.dart';

/// Client-side guardrails for AI-generated habit suggestions.
///
/// Prompting reduces duplicates, but this catches stubborn output (e.g.
/// "read your identity statement each morning") before it reaches the UI.
abstract final class HabitSuggestionGuard {
  static String _combinedText(Map<String, String> suggestion) {
    return '${suggestion['name'] ?? ''} ${suggestion['trigger'] ?? ''}'
        .trim()
        .toLowerCase();
  }

  /// True when the suggestion overlaps a native app routine keyword.
  static bool duplicatesBuiltInRoutine(Map<String, String> suggestion) {
    final text = _combinedText(suggestion);
    if (text.isEmpty) return false;

    for (final routine in kBuiltInAppRoutines) {
      for (final keyword in routine.excludeKeywords) {
        if (text.contains(keyword.toLowerCase())) return true;
      }
    }
    return false;
  }

  /// True when the suggestion matches an active user habit by name.
  static bool duplicatesExistingHabit(
    Map<String, String> suggestion,
    UserProfile profile,
  ) {
    final name = (suggestion['name'] ?? '').trim().toLowerCase();
    if (name.isEmpty) return false;

    for (final habit in profile.habits.where((h) => h.state == 'active')) {
      final existing = habit.name.trim().toLowerCase();
      if (existing.isEmpty) continue;
      if (existing == name || existing.contains(name) || name.contains(existing)) {
        return true;
      }
    }
    return false;
  }

  static bool isInvalidSuggestion(
    Map<String, String> suggestion,
    UserProfile profile,
  ) {
    return duplicatesBuiltInRoutine(suggestion) ||
        duplicatesExistingHabit(suggestion, profile);
  }

  static List<Map<String, String>> filterValid(
    List<Map<String, String>> suggestions,
    UserProfile profile,
  ) {
    return suggestions
        .where((s) => !isInvalidSuggestion(s, profile))
        .toList();
  }
}
