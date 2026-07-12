import '../core/constants/future_self_voices.dart';

/// Catalog of the scene focuses a user can choose for a Future Self scene.
/// A scene is anchored either to a time of day or to a specific moment-type
/// (the moment where resistance normally shows up). Kept as pure data so both
/// the wizard and the hub can render the same options.
class FutureSelfSceneCatalog {
  /// Time-of-day framing options as (focus key, label) pairs.
  static const List<(String, String)> timeOfDay = [
    ('morning', 'Morning'),
    ('midday', 'Midday'),
    ('evening', 'Evening'),
  ];

  /// Moment-type framing options as (focus key, label) pairs. These target the
  /// exact moment where hesitation usually appears.
  static const List<(String, String)> momentType = [
    ('startingDeepWork', 'Starting deep work'),
    ('makingADecision', 'Making a decision'),
    ('handlingPressure', 'Handling pressure'),
    ('windingDown', 'Winding down'),
  ];

  /// Resolves the human label for a focus key across both framings, falling
  /// back to the raw key so a legacy/unknown value never renders blank.
  static String labelFor(String focus) {
    for (final (key, label) in [...timeOfDay, ...momentType]) {
      if (key == focus) return label;
    }
    return focus.isEmpty ? 'Scene' : focus;
  }
}

/// A single, repeatable Future Self scene — a specific, vivid vision of your
/// accomplished future. Authored by the user as a [title], a [setting], the
/// [people] present, an ordered [beats] flow (the choreography of the moment),
/// optional [sensory] anchors, and the goals already real in it. From those
/// inputs a vivid, present-tense narration is generated and synthesized to a
/// cached neural voice for daily replay.
class FutureSelfScene {
  final String id;

  /// User's name for the scene, e.g. "Morning in my dream home".
  final String title;

  /// Where the scene takes place.
  final String setting;

  /// Who is present in the scene.
  final String people;

  /// The ordered flow of the scene — one beat/moment per entry. This is the
  /// narration's spine; the generator follows it in order.
  final List<String> beats;

  /// Optional sensory anchors (what you see / hear / smell / feel).
  final String sensory;

  /// Ids of the user's goals that are already accomplished in this scene.
  final List<String> goalIds;

  /// Free-text accomplishments not tied to a goal record.
  final List<String> customAccomplishments;

  // ── Legacy framing (pre-builder scenes; kept for back-compat) ─────────────
  final String framing;
  final String focus;
  final String focusLabel;
  final String sceneNote;

  /// The generated embodiment script for this scene.
  final String? script;

  /// Stable hash of the inputs the script was generated from. When it changes
  /// (e.g. after a refine), the narration is regenerated.
  final String? scriptHash;

  /// Download URL for the cached neural-voice narration of [script].
  final String? narrationUrl;

  /// The TTS voice the narration was synthesized with.
  final String narrationVoice;

  final DateTime createdAt;

  const FutureSelfScene({
    required this.id,
    this.title = '',
    this.setting = '',
    this.people = '',
    this.beats = const [],
    this.sensory = '',
    this.goalIds = const [],
    this.customAccomplishments = const [],
    this.framing = 'timeOfDay',
    this.focus = '',
    this.focusLabel = '',
    this.sceneNote = '',
    this.script,
    this.scriptHash,
    this.narrationUrl,
    this.narrationVoice = '',
    required this.createdAt,
  });

  /// Display name: the user's title, falling back to a legacy label.
  String get displayTitle => title.trim().isNotEmpty
      ? title.trim()
      : (focusLabel.trim().isNotEmpty ? focusLabel.trim() : 'Scene');

  bool get hasScript => script != null && script!.trim().isNotEmpty;

  bool get hasNarration =>
      narrationUrl != null && narrationUrl!.trim().isNotEmpty;

  /// True when cached narration exists and can be used for [voiceId].
  ///
  /// Legacy scenes were cached before the TTS voice id was persisted, so a
  /// non-empty [narrationUrl] with an empty [narrationVoice] is trusted as-is
  /// (and back-filled elsewhere) rather than forcing a costly re-synthesis.
  bool narrationMatchesVoice(String voiceId) {
    if (!hasNarration) return false;
    if (narrationVoice.isEmpty) return true;
    return narrationVoice == voiceId;
  }

  FutureSelfScene copyWith({
    String? id,
    String? title,
    String? setting,
    String? people,
    List<String>? beats,
    String? sensory,
    List<String>? goalIds,
    List<String>? customAccomplishments,
    String? framing,
    String? focus,
    String? focusLabel,
    String? sceneNote,
    String? script,
    String? scriptHash,
    String? narrationUrl,
    String? narrationVoice,
    DateTime? createdAt,
    bool clearScript = false,
    bool clearNarration = false,
  }) {
    return FutureSelfScene(
      id: id ?? this.id,
      title: title ?? this.title,
      setting: setting ?? this.setting,
      people: people ?? this.people,
      beats: beats ?? this.beats,
      sensory: sensory ?? this.sensory,
      goalIds: goalIds ?? this.goalIds,
      customAccomplishments:
          customAccomplishments ?? this.customAccomplishments,
      framing: framing ?? this.framing,
      focus: focus ?? this.focus,
      focusLabel: focusLabel ?? this.focusLabel,
      sceneNote: sceneNote ?? this.sceneNote,
      script: clearScript ? null : (script ?? this.script),
      scriptHash: clearNarration ? null : (scriptHash ?? this.scriptHash),
      narrationUrl: clearNarration ? null : (narrationUrl ?? this.narrationUrl),
      narrationVoice:
          clearNarration ? '' : (narrationVoice ?? this.narrationVoice),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory FutureSelfScene.fromJson(Map<String, dynamic> json) {
    return FutureSelfScene(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      setting: json['setting'] as String? ?? '',
      people: json['people'] as String? ?? '',
      beats: List<String>.from(json['beats'] as List<dynamic>? ?? const []),
      sensory: json['sensory'] as String? ?? '',
      goalIds:
          List<String>.from(json['goalIds'] as List<dynamic>? ?? const []),
      customAccomplishments: List<String>.from(
          json['customAccomplishments'] as List<dynamic>? ?? const []),
      framing: json['framing'] as String? ?? 'timeOfDay',
      focus: json['focus'] as String? ?? '',
      focusLabel: json['focusLabel'] as String? ?? '',
      sceneNote: json['sceneNote'] as String? ?? '',
      script: json['script'] as String?,
      scriptHash: json['scriptHash'] as String?,
      narrationUrl: json['narrationUrl'] as String?,
      narrationVoice: json['narrationVoice'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'setting': setting,
        'people': people,
        'beats': beats,
        'sensory': sensory,
        'goalIds': goalIds,
        'customAccomplishments': customAccomplishments,
        'framing': framing,
        'focus': focus,
        'focusLabel': focusLabel,
        'sceneNote': sceneNote,
        'script': script,
        'scriptHash': scriptHash,
        'narrationUrl': narrationUrl,
        'narrationVoice': narrationVoice,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// Configuration for the Future Self embodiment practice. Holds the shared
/// identity context (who the future self is, their tone, voice, etc.) plus a
/// small library of short [scenes]. Practice is audio-first: each scene is
/// narrated in a neural voice and replayed daily ("return to the same scene").
class FutureSelfSetup {
  /// "I am someone who ..." — the core identity statement of the future self.
  final String identityAnchor;

  /// How far into the future, e.g. "1 year", "3 years", "5 years", "10 years".
  final String futureTimeline;

  /// Legacy: ids of goals treated as already achieved in this future. No longer
  /// collected in setup — goals are now captured per-scene ([FutureSelfScene.goalIds]).
  /// Retained for back-compat with accounts created before scene-level goals.
  final List<String> achievedGoalIds;

  /// Legacy free-text achieved goals not tied to a goal record. Superseded by
  /// per-scene [FutureSelfScene.customAccomplishments]; kept for back-compat.
  final List<String> customGoals;

  /// Legacy free-text "normalized day" snapshot. No longer collected — the chat
  /// persona now derives daily-life context from the scene library. Kept for
  /// back-compat with older accounts.
  final String dailySnapshot;

  /// Legacy: where the future self lives. No longer collected (the scene's
  /// setting captures this); kept for back-compat.
  final String envLocation;

  /// Legacy: how the environment feels. No longer collected (the scene captures
  /// this); kept for back-compat.
  final String envFeel;

  /// What the future self spends most of their time doing.
  final String workPurpose;

  /// The dominant operational/emotional tone (Calm, Confident, Focused...).
  final String emotionalTone;

  /// Up to 3 trait "amplifiers" woven into the script implicitly.
  final List<String> amplifiers;

  /// Voice style preset for the script narration.
  final String voiceStyle;

  /// Optional custom voice sample when [voiceStyle] is the custom option.
  final String customVoice;

  /// Preferred Google TTS voice id for scene narration (e.g. Aoede or Charon).
  final String preferredNarrationVoice;

  /// The user's library of short, repeatable scenes.
  final List<FutureSelfScene> scenes;

  /// Whether binaural beats are enabled by default in the player.
  final bool beatsEnabled;

  /// Whether guided narration plays during practice (default on).
  final bool narrationEnabled;

  /// Preferred binaural frequency in Hz (4 / 7 / 10 / 15 / 40).
  final int binauralHz;

  /// Binaural beat bed volume (0.0–1.0) for the practice player.
  final double beatsVolume;

  /// Narration voice volume (0.0–1.0) for the practice player.
  final double narrationVolume;

  /// Whether the user has seen the one-time "how to practice" primer.
  final bool hasSeenHowTo;

  final DateTime createdAt;

  const FutureSelfSetup({
    this.identityAnchor = '',
    this.futureTimeline = '5 years',
    this.achievedGoalIds = const [],
    this.customGoals = const [],
    this.dailySnapshot = '',
    this.envLocation = '',
    this.envFeel = '',
    this.workPurpose = '',
    this.emotionalTone = '',
    this.amplifiers = const [],
    this.voiceStyle = '',
    this.customVoice = '',
    this.preferredNarrationVoice = '',
    this.scenes = const [],
    this.beatsEnabled = true,
    this.narrationEnabled = true,
    this.binauralHz = 7,
    this.beatsVolume = 0.3,
    this.narrationVolume = 1.0,
    this.hasSeenHowTo = false,
    required this.createdAt,
  });

  /// Max scenes in a user's library.
  static const int maxScenes = 3;

  /// True once at least one scene has a script (the practice is ready to run).
  bool get hasPractice => scenes.any((s) => s.hasScript);

  /// True when the library still has room for another scene.
  bool get canAddScene => scenes.length < maxScenes;

  /// The TTS voice used for narration, with a safe default for legacy setups.
  String get resolvedNarrationVoice =>
      FutureSelfVoices.resolve(preferredNarrationVoice);

  FutureSelfSetup copyWith({
    String? identityAnchor,
    String? futureTimeline,
    List<String>? achievedGoalIds,
    List<String>? customGoals,
    String? dailySnapshot,
    String? envLocation,
    String? envFeel,
    String? workPurpose,
    String? emotionalTone,
    List<String>? amplifiers,
    String? voiceStyle,
    String? customVoice,
    String? preferredNarrationVoice,
    List<FutureSelfScene>? scenes,
    bool? beatsEnabled,
    bool? narrationEnabled,
    int? binauralHz,
    double? beatsVolume,
    double? narrationVolume,
    bool? hasSeenHowTo,
    DateTime? createdAt,
  }) {
    return FutureSelfSetup(
      identityAnchor: identityAnchor ?? this.identityAnchor,
      futureTimeline: futureTimeline ?? this.futureTimeline,
      achievedGoalIds: achievedGoalIds ?? this.achievedGoalIds,
      customGoals: customGoals ?? this.customGoals,
      dailySnapshot: dailySnapshot ?? this.dailySnapshot,
      envLocation: envLocation ?? this.envLocation,
      envFeel: envFeel ?? this.envFeel,
      workPurpose: workPurpose ?? this.workPurpose,
      emotionalTone: emotionalTone ?? this.emotionalTone,
      amplifiers: amplifiers ?? this.amplifiers,
      voiceStyle: voiceStyle ?? this.voiceStyle,
      customVoice: customVoice ?? this.customVoice,
      preferredNarrationVoice:
          preferredNarrationVoice ?? this.preferredNarrationVoice,
      scenes: scenes ?? this.scenes,
      beatsEnabled: beatsEnabled ?? this.beatsEnabled,
      narrationEnabled: narrationEnabled ?? this.narrationEnabled,
      binauralHz: binauralHz ?? this.binauralHz,
      beatsVolume: beatsVolume ?? this.beatsVolume,
      narrationVolume: narrationVolume ?? this.narrationVolume,
      hasSeenHowTo: hasSeenHowTo ?? this.hasSeenHowTo,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory FutureSelfSetup.fromJson(Map<String, dynamic> json) {
    final rawScenes = json['scenes'] as List<dynamic>?;
    List<FutureSelfScene> scenes = rawScenes != null
        ? rawScenes
            .map((e) => FutureSelfScene.fromJson(e as Map<String, dynamic>))
            .toList()
        : const [];

    // Migration: earlier versions stored a single full-day `generatedScript`.
    // Load it as the first scene so existing users keep their practice.
    if (scenes.isEmpty) {
      final legacy = json['generatedScript'] as String?;
      if (legacy != null && legacy.trim().isNotEmpty) {
        scenes = [
          FutureSelfScene(
            id: 'legacy',
            title: 'Your day',
            framing: 'timeOfDay',
            focus: 'wholeDay',
            focusLabel: 'Your day',
            script: legacy,
            createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
                DateTime.now(),
          ),
        ];
      }
    }

    return FutureSelfSetup(
      identityAnchor: json['identityAnchor'] as String? ?? '',
      futureTimeline: json['futureTimeline'] as String? ?? '5 years',
      achievedGoalIds:
          List<String>.from(json['achievedGoalIds'] as List<dynamic>? ?? []),
      customGoals:
          List<String>.from(json['customGoals'] as List<dynamic>? ?? []),
      dailySnapshot: json['dailySnapshot'] as String? ?? '',
      envLocation: json['envLocation'] as String? ?? '',
      envFeel: json['envFeel'] as String? ?? '',
      workPurpose: json['workPurpose'] as String? ?? '',
      emotionalTone: json['emotionalTone'] as String? ?? '',
      amplifiers:
          List<String>.from(json['amplifiers'] as List<dynamic>? ?? []),
      voiceStyle: json['voiceStyle'] as String? ?? '',
      customVoice: json['customVoice'] as String? ?? '',
      preferredNarrationVoice: json['preferredNarrationVoice'] as String? ?? '',
      scenes: scenes,
      beatsEnabled: json['beatsEnabled'] as bool? ?? true,
      narrationEnabled: json['narrationEnabled'] as bool? ?? true,
      binauralHz: (json['binauralHz'] as num?)?.toInt() ?? 7,
      beatsVolume: _clampVolume((json['beatsVolume'] as num?)?.toDouble() ?? 0.3),
      narrationVolume:
          _clampVolume((json['narrationVolume'] as num?)?.toDouble() ?? 1.0),
      hasSeenHowTo: json['hasSeenHowTo'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'identityAnchor': identityAnchor,
        'futureTimeline': futureTimeline,
        'achievedGoalIds': achievedGoalIds,
        'customGoals': customGoals,
        'dailySnapshot': dailySnapshot,
        'envLocation': envLocation,
        'envFeel': envFeel,
        'workPurpose': workPurpose,
        'emotionalTone': emotionalTone,
        'amplifiers': amplifiers,
        'voiceStyle': voiceStyle,
        'customVoice': customVoice,
        'preferredNarrationVoice': preferredNarrationVoice,
        'scenes': scenes.map((s) => s.toJson()).toList(),
        'beatsEnabled': beatsEnabled,
        'narrationEnabled': narrationEnabled,
        'binauralHz': binauralHz,
        'beatsVolume': beatsVolume,
        'narrationVolume': narrationVolume,
        'hasSeenHowTo': hasSeenHowTo,
        'createdAt': createdAt.toIso8601String(),
      };
}

double _clampVolume(double value) => value.clamp(0.0, 1.0);
