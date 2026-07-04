import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/services/analytics_service.dart';
import '../core/utils/app_date_utils.dart';
import '../models/future_self_setup.dart';
import '../models/future_self_completion.dart';
import '../models/user_profile.dart';
import 'auth_provider.dart';
import 'claude_provider.dart';
import 'daily_completion_provider.dart';

/// Owns the Future Self practice setup and completion history. The setup holds
/// the shared identity context plus a small library of short, repeatable
/// scenes; completions feed `visualizationDays` in manifestation scoring via
/// the `futureSelfCompleted` daily flag.
class FutureSelfNotifier extends StateNotifier<FutureSelfSetup?> {
  final Ref _ref;
  static const _uuid = Uuid();

  FutureSelfNotifier(this._ref) : super(null);

  void _loadFromProfile(UserProfile? profile) {
    state = profile?.futureSelfSetup;
  }

  /// Saves the full setup (shared config + scene library) to Firestore.
  Future<void> saveSetup(FutureSelfSetup setup) async {
    state = setup;
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    await _ref.read(firestoreServiceProvider).updateUserField(uid, {
      'futureSelfSetup': setup.toJson(),
    });
  }

  /// The voice to keep consistent across a user's scenes (reuse the first
  /// scene's voice so the library sounds like one narrator).
  String? get _libraryVoice {
    final scenes = state?.scenes ?? const [];
    for (final s in scenes) {
      if (s.narrationVoice.isNotEmpty) return s.narrationVoice;
    }
    return null;
  }

  /// Generates a scene's script from the shared setup context. Narration is
  /// synthesized lazily on first practice via [ensureSceneReady].
  Future<FutureSelfScene> _generateScene(
    FutureSelfScene scene,
    FutureSelfSetup setup,
    UserProfile profile,
  ) async {
    final claude = _ref.read(claudeServiceProvider);
    final script =
        await claude.generateFutureSelfSceneScript(scene, setup, profile);
    return scene.copyWith(script: script);
  }

  /// Creates a new scene from Vision Scene Builder inputs: generates its script
  /// and appends it to the library. Narration is cached on first practice.
  /// Returns the created scene, or null if there's no setup / profile or the
  /// library is full.
  Future<FutureSelfScene?> createScene({
    required String title,
    String setting = '',
    String people = '',
    List<String> beats = const [],
    String sensory = '',
    List<String> goalIds = const [],
    List<String> customAccomplishments = const [],
  }) async {
    final setup = state;
    if (setup == null || !setup.canAddScene) return null;
    final profile = _ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null) return null;

    final scene = await _generateScene(
      FutureSelfScene(
        id: _uuid.v4(),
        title: title,
        setting: setting,
        people: people,
        beats: beats,
        sensory: sensory,
        goalIds: goalIds,
        customAccomplishments: customAccomplishments,
        createdAt: DateTime.now(),
      ),
      setup,
      profile,
    );

    await saveSetup(setup.copyWith(scenes: [...setup.scenes, scene]));
    return scene;
  }

  /// Refines an existing scene (regenerates its script) from edited builder
  /// inputs. Narration is re-synthesized on next practice.
  Future<void> refineScene(
    String sceneId, {
    String? title,
    String? setting,
    String? people,
    List<String>? beats,
    String? sensory,
    List<String>? goalIds,
    List<String>? customAccomplishments,
  }) async {
    final setup = state;
    if (setup == null) return;
    final profile = _ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null) return;
    final idx = setup.scenes.indexWhere((s) => s.id == sceneId);
    if (idx < 0) return;

    final base = setup.scenes[idx].copyWith(
      title: title,
      setting: setting,
      people: people,
      beats: beats,
      sensory: sensory,
      goalIds: goalIds,
      customAccomplishments: customAccomplishments,
      // Clear stale narration so the player doesn't play the old audio if
      // regeneration fails midway.
      script: null,
      scriptHash: null,
      narrationUrl: null,
    );
    final refined = await _generateScene(base, setup, profile);

    final scenes = [...setup.scenes];
    scenes[idx] = refined;
    await saveSetup(setup.copyWith(scenes: scenes));
  }

  /// Removes a scene from the library.
  Future<void> deleteScene(String sceneId) async {
    final setup = state;
    if (setup == null) return;
    final scenes = setup.scenes.where((s) => s.id != sceneId).toList();
    await saveSetup(setup.copyWith(scenes: scenes));
  }

  /// Ensures a scene has a script and narration, generating them lazily if the
  /// player opens a scene that was saved without audio (e.g. synthesis failed
  /// at create time, or a migrated legacy script). Returns the ready scene, or
  /// the original if generation isn't possible.
  Future<FutureSelfScene?> ensureSceneReady(String sceneId) async {
    final setup = state;
    if (setup == null) return null;
    final idx = setup.scenes.indexWhere((s) => s.id == sceneId);
    if (idx < 0) return null;
    var scene = setup.scenes[idx];
    if (scene.hasScript && scene.hasNarration) return scene;

    final profile = _ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null) return scene;
    final claude = _ref.read(claudeServiceProvider);

    if (!scene.hasScript) {
      final script =
          await claude.generateFutureSelfSceneScript(scene, setup, profile);
      scene = scene.copyWith(script: script);
    }
    if (!scene.hasNarration && scene.hasScript) {
      final narration =
          await claude.synthesizeNarration(scene.script!, voice: _libraryVoice);
      if (narration != null) {
        scene = scene.copyWith(
          narrationUrl: narration.url,
          narrationVoice: narration.voice,
          scriptHash: narration.scriptHash,
        );
      }
    }

    final scenes = [...setup.scenes];
    scenes[idx] = scene;
    await saveSetup(setup.copyWith(scenes: scenes));
    return scene;
  }

  /// Marks the one-time "how to practice" primer as seen.
  Future<void> markHowToSeen() async {
    final current = state;
    if (current == null || current.hasSeenHowTo) return;
    await saveSetup(current.copyWith(hasSeenHowTo: true));
  }

  /// Records today's completion in the history list AND flips the daily-win
  /// flag so the Subconscious alignment score reflects the session.
  Future<void> recordCompletion(int durationSeconds) async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    final profile = _ref.read(currentUserProfileProvider).valueOrNull;
    if (profile == null) return;

    final today = AppDateUtils.todayStringWithGracePeriod();
    final completions = [...profile.futureSelfCompletions];
    final entry = FutureSelfCompletion(
      date: today,
      completed: true,
      durationSeconds: durationSeconds,
      completionTime: DateTime.now(),
    );
    final idx = completions.indexWhere((c) => c.date == today);
    if (idx >= 0) {
      completions[idx] = entry;
    } else {
      completions.add(entry);
    }

    await _ref.read(firestoreServiceProvider).updateUserField(uid, {
      'futureSelfCompletions': completions.map((c) => c.toJson()).toList(),
    });

    await _ref
        .read(dailyCompletionProvider.notifier)
        .toggle('futureSelfCompleted', true);

    _ref
        .read(analyticsServiceProvider)
        .trackFutureSelfSessionCompleted(durationSeconds);
  }
}

final futureSelfProvider =
    StateNotifierProvider<FutureSelfNotifier, FutureSelfSetup?>((ref) {
  final notifier = FutureSelfNotifier(ref);
  ref.listen(currentUserProfileProvider, (_, next) {
    next.whenData((profile) => notifier._loadFromProfile(profile));
  });
  ref.read(currentUserProfileProvider).whenData(
        (profile) => notifier._loadFromProfile(profile),
      );
  return notifier;
});

/// Picks the scene to pre-select for "right now". Uses a soft keyword hint from
/// the scene title matching the current part of the day (e.g. a "morning" scene
/// in the morning), otherwise the first scene. Returns null with no scenes.
FutureSelfScene? defaultSceneForNow(
  List<FutureSelfScene> scenes, [
  DateTime? now,
]) {
  if (scenes.isEmpty) return null;
  final hour = (now ?? DateTime.now()).hour;
  final hint = hour < 12
      ? 'morning'
      : hour < 17
          ? 'midday'
          : 'evening';
  for (final s in scenes) {
    if (s.displayTitle.toLowerCase().contains(hint)) return s;
  }
  return scenes.first;
}

/// Whether the Future Self practice has been completed today (grace-period
/// aware), derived from the profile completion history.
final futureSelfCompletedTodayProvider = Provider<bool>((ref) {
  final profile = ref.watch(currentUserProfileProvider).valueOrNull;
  if (profile == null) return false;
  final today = AppDateUtils.todayStringWithGracePeriod();
  return profile.futureSelfCompletions
      .any((c) => c.date == today && c.completed);
});

/// Today's rotating "embodiment trait" — one of the Future Self trait
/// amplifiers, chosen deterministically per calendar day so it stays stable all
/// day but shifts daily. This is the lens the user carries into today's choices
/// ("act like someone who is ..."). Falls back to the emotional tone, and is
/// null when there is no practice or no traits to surface.
final embodimentTraitTodayProvider = Provider<String?>((ref) {
  final setup = ref.watch(futureSelfProvider);
  if (setup == null) return null;

  final traits = setup.amplifiers
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();
  if (traits.isEmpty) {
    final tone = setup.emotionalTone.trim();
    return tone.isEmpty ? null : tone;
  }

  // Days since a fixed epoch → a stable, daily-advancing index into the traits.
  final dayOrdinal = DateTime.now().difference(DateTime(2000)).inDays;
  return traits[dayOrdinal % traits.length];
});
