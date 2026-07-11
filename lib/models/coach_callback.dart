/// A proactive coach "callback" surfaced when the engine detects a real,
/// traceable connection between past logged data and recent behavior.
class CoachCallback {
  final String id;
  final String message;

  /// `positive` celebrates progress; `regression` names a slip without shaming.
  final String valence;

  /// Machine-readable trigger, e.g. `consistency_breakthrough`, `streak_break_belief`.
  final String triggerType;

  /// Human-readable label for the historical anchor (belief, fear, journal, etc.).
  final String referenceLabel;

  /// yyyy-MM-dd or ISO date for the anchor event.
  final String referenceDate;

  /// Concrete measurable change, e.g. "check-ins went 2/week to 6/week".
  final String measurableChange;

  /// Model confidence 0.0–1.0 from the server-side generation pass.
  final double confidence;

  final String generatedAt;
  final String? deliveredAt;
  final String? seenAt;
  final String? respondedAt;

  const CoachCallback({
    required this.id,
    required this.message,
    required this.valence,
    required this.triggerType,
    required this.referenceLabel,
    required this.referenceDate,
    required this.measurableChange,
    required this.confidence,
    required this.generatedAt,
    this.deliveredAt,
    this.seenAt,
    this.respondedAt,
  });

  bool get isUnseen => seenAt == null;

  bool get isPositive => valence == 'positive';

  bool get hasContent => message.isNotEmpty;

  CoachCallback copyWith({
    String? id,
    String? message,
    String? valence,
    String? triggerType,
    String? referenceLabel,
    String? referenceDate,
    String? measurableChange,
    double? confidence,
    String? generatedAt,
    String? deliveredAt,
    String? seenAt,
    String? respondedAt,
  }) {
    return CoachCallback(
      id: id ?? this.id,
      message: message ?? this.message,
      valence: valence ?? this.valence,
      triggerType: triggerType ?? this.triggerType,
      referenceLabel: referenceLabel ?? this.referenceLabel,
      referenceDate: referenceDate ?? this.referenceDate,
      measurableChange: measurableChange ?? this.measurableChange,
      confidence: confidence ?? this.confidence,
      generatedAt: generatedAt ?? this.generatedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      seenAt: seenAt ?? this.seenAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }

  factory CoachCallback.fromJson(Map<String, dynamic> json) {
    return CoachCallback(
      id: json['id'] as String? ?? '',
      message: json['message'] as String? ?? '',
      valence: json['valence'] as String? ?? 'regression',
      triggerType: json['triggerType'] as String? ?? '',
      referenceLabel: json['referenceLabel'] as String? ?? '',
      referenceDate: json['referenceDate'] as String? ?? '',
      measurableChange: json['measurableChange'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      generatedAt: json['generatedAt'] as String? ?? '',
      deliveredAt: json['deliveredAt'] as String?,
      seenAt: json['seenAt'] as String?,
      respondedAt: json['respondedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'message': message,
        'valence': valence,
        'triggerType': triggerType,
        'referenceLabel': referenceLabel,
        'referenceDate': referenceDate,
        'measurableChange': measurableChange,
        'confidence': confidence,
        'generatedAt': generatedAt,
        if (deliveredAt != null) 'deliveredAt': deliveredAt,
        if (seenAt != null) 'seenAt': seenAt,
        if (respondedAt != null) 'respondedAt': respondedAt,
      };
}
