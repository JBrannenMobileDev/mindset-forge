class FutureSelfPractice {
  final DateTime sessionDate;
  final int durationSeconds;
  final int binauralFrequencyHz;

  const FutureSelfPractice({
    required this.sessionDate,
    required this.durationSeconds,
    this.binauralFrequencyHz = 10,
  });

  FutureSelfPractice copyWith({
    DateTime? sessionDate,
    int? durationSeconds,
    int? binauralFrequencyHz,
  }) {
    return FutureSelfPractice(
      sessionDate: sessionDate ?? this.sessionDate,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      binauralFrequencyHz: binauralFrequencyHz ?? this.binauralFrequencyHz,
    );
  }

  factory FutureSelfPractice.fromJson(Map<String, dynamic> json) {
    return FutureSelfPractice(
      sessionDate: DateTime.tryParse(json['sessionDate'] as String? ?? '') ?? DateTime.now(),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      binauralFrequencyHz: (json['binauralFrequencyHz'] as num?)?.toInt() ?? 10,
    );
  }

  Map<String, dynamic> toJson() => {
        'sessionDate': sessionDate.toIso8601String(),
        'durationSeconds': durationSeconds,
        'binauralFrequencyHz': binauralFrequencyHz,
      };
}
