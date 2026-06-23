class IdentityReadLog {
  final String date;
  final DateTime readAt;

  const IdentityReadLog({
    required this.date,
    required this.readAt,
  });

  IdentityReadLog copyWith({
    String? date,
    DateTime? readAt,
  }) {
    return IdentityReadLog(
      date: date ?? this.date,
      readAt: readAt ?? this.readAt,
    );
  }

  factory IdentityReadLog.fromJson(Map<String, dynamic> json) {
    return IdentityReadLog(
      date: json['date'] as String? ?? '',
      readAt: DateTime.tryParse(json['readAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'readAt': readAt.toIso8601String(),
      };
}
