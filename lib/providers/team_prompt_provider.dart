import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/app_date_utils.dart';
import '../models/team_daily_prompt.dart';
import 'auth_provider.dart';

/// Team id of the signed-in account, or null when they are not on a team, which
/// is every self-serve account. This is the single gate that keeps the whole
/// team-prompt feature inert: while it is null nothing below it touches
/// Firestore.
final _teamIdProvider = Provider<String?>((ref) {
  final teamId = ref.watch(currentUserProfileProvider).valueOrNull?.teamId;
  if (teamId == null || teamId.isEmpty) return null;
  return teamId;
});

/// Today's coach-assigned prompt, or null when there is none. "Today" uses the
/// same 4 AM–4 AM active day as `dailyCompletionProvider`, so the prompt lookup
/// and the "first entry of the day" check can never disagree about the date.
///
/// Auto-disposed so the date is resolved fresh every time the journal flow opens
/// and no listener outlives the screen.
final teamPromptProvider =
    StreamProvider.autoDispose<TeamDailyPrompt?>((ref) {
  final teamId = ref.watch(_teamIdProvider);
  if (teamId == null) return Stream.value(null);
  return ref.watch(firestoreServiceProvider).streamTeamDailyPrompt(
        teamId,
        AppDateUtils.todayStringWithGracePeriod(),
      );
});

/// Today's team prompt resolved to a plain value so the journal flow never has
/// to juggle an [AsyncValue]. Loading and error states collapse to "no team
/// prompt", which is exactly the pre-existing behavior.
///
/// The app never forces a player to use their coach's prompt. It is offered as
/// the coach's prompt for the day and the player can always choose a blank page
/// instead; the expectation to complete it comes from the coach, not from here.
class TeamPromptState {
  final TeamDailyPrompt? prompt;

  const TeamPromptState({this.prompt});

  /// A usable prompt exists for today.
  TeamDailyPrompt? get usablePrompt {
    final p = prompt;
    if (p == null || !p.isUsable) return null;
    return p;
  }
}

const _noTeamPrompt = TeamPromptState();

/// The single entry point for the journal flow. Returns the shared const
/// "no team" state for accounts without a `teamId`, without subscribing to the
/// Firestore-backed provider.
final teamPromptStateProvider = Provider.autoDispose<TeamPromptState>((ref) {
  if (ref.watch(_teamIdProvider) == null) return _noTeamPrompt;
  return TeamPromptState(prompt: ref.watch(teamPromptProvider).valueOrNull);
});
