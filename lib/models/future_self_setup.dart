/// Configuration for the Future Self embodiment practice, mirroring the base44
/// wizard. This is the visualization half of the Subconscious (Foundation)
/// layer: the user defines who they are in the future, then a fixed script is
/// generated once and replayed each day ("return to the same scene").
class FutureSelfSetup {
  /// "I am someone who ..." — the core identity statement of the future self.
  final String identityAnchor;

  /// How far into the future, e.g. "1 year", "3 years", "5 years", "10 years".
  final String futureTimeline;

  /// Ids of existing goals the user treats as already achieved in this future.
  final List<String> achievedGoalIds;

  /// Free-text achieved goals not tied to an existing goal record.
  final List<String> customGoals;

  /// A normalized day in the future, morning to evening.
  final String dailySnapshot;

  /// Where the future self lives (optional).
  final String envLocation;

  /// How the environment feels (optional).
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

  /// The generated embodiment script. Generated once and reused daily.
  final String? generatedScript;

  /// Whether binaural beats are enabled by default in the player.
  final bool beatsEnabled;

  /// Preferred binaural frequency in Hz (4 / 7 / 10 / 15 / 40).
  final int binauralHz;

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
    this.generatedScript,
    this.beatsEnabled = true,
    this.binauralHz = 7,
    this.hasSeenHowTo = false,
    required this.createdAt,
  });

  /// True once a script has been generated (the practice is ready to run).
  bool get hasPractice =>
      generatedScript != null && generatedScript!.trim().isNotEmpty;

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
    String? generatedScript,
    bool? beatsEnabled,
    int? binauralHz,
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
      generatedScript: generatedScript ?? this.generatedScript,
      beatsEnabled: beatsEnabled ?? this.beatsEnabled,
      binauralHz: binauralHz ?? this.binauralHz,
      hasSeenHowTo: hasSeenHowTo ?? this.hasSeenHowTo,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory FutureSelfSetup.fromJson(Map<String, dynamic> json) {
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
      generatedScript: json['generatedScript'] as String?,
      beatsEnabled: json['beatsEnabled'] as bool? ?? true,
      binauralHz: (json['binauralHz'] as num?)?.toInt() ?? 7,
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
        'generatedScript': generatedScript,
        'beatsEnabled': beatsEnabled,
        'binauralHz': binauralHz,
        'hasSeenHowTo': hasSeenHowTo,
        'createdAt': createdAt.toIso8601String(),
      };
}
