class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange({required this.start, required this.end});

  bool contains(DateTime date) =>
      (date.isAfter(start) || date.isAtSameMomentAs(start)) &&
      (date.isBefore(end) || date.isAtSameMomentAs(end));

  DateRange copyWith({
    DateTime? start,
    DateTime? end,
  }) {
    return DateRange(
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  factory DateRange.fromJson(Map<String, dynamic> json) {
    return DateRange(
      start: DateTime.tryParse(json['start'] as String? ?? '') ?? DateTime.now(),
      end: DateTime.tryParse(json['end'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
      };
}
