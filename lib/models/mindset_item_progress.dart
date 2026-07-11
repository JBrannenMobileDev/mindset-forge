/// Lifecycle tracking for a limiting belief or fear-to-outwit item.
class MindsetItemProgress {
  final String id;
  final String text;
  final String kind; // `belief` | `fear`
  final String status; // `active` | `softening` | `overcome`
  final String addedAt;
  final String? softeningSince;
  final String? overcameAt;
  final int journalSignalDays;
  final String? lastJournalSignalDate;
  final bool coachCorroborated;
  final int generation;

  const MindsetItemProgress({
    required this.id,
    required this.text,
    required this.kind,
    this.status = 'active',
    required this.addedAt,
    this.softeningSince,
    this.overcameAt,
    this.journalSignalDays = 0,
    this.lastJournalSignalDate,
    this.coachCorroborated = false,
    this.generation = 1,
  });

  bool get isBelief => kind == 'belief';
  bool get isFear => kind == 'fear';
  bool get isActive => status == 'active';
  bool get isSoftening => status == 'softening';
  bool get isOvercome => status == 'overcome';

  MindsetItemProgress copyWith({
    String? id,
    String? text,
    String? kind,
    String? status,
    String? addedAt,
    String? softeningSince,
    String? overcameAt,
    int? journalSignalDays,
    String? lastJournalSignalDate,
    bool? coachCorroborated,
    int? generation,
  }) {
    return MindsetItemProgress(
      id: id ?? this.id,
      text: text ?? this.text,
      kind: kind ?? this.kind,
      status: status ?? this.status,
      addedAt: addedAt ?? this.addedAt,
      softeningSince: softeningSince ?? this.softeningSince,
      overcameAt: overcameAt ?? this.overcameAt,
      journalSignalDays: journalSignalDays ?? this.journalSignalDays,
      lastJournalSignalDate:
          lastJournalSignalDate ?? this.lastJournalSignalDate,
      coachCorroborated: coachCorroborated ?? this.coachCorroborated,
      generation: generation ?? this.generation,
    );
  }

  factory MindsetItemProgress.fromJson(Map<String, dynamic> json) {
    return MindsetItemProgress(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      kind: json['kind'] as String? ?? 'belief',
      status: json['status'] as String? ?? 'active',
      addedAt: json['addedAt'] as String? ?? '',
      softeningSince: json['softeningSince'] as String?,
      overcameAt: json['overcameAt'] as String?,
      journalSignalDays: (json['journalSignalDays'] as num?)?.toInt() ?? 0,
      lastJournalSignalDate: json['lastJournalSignalDate'] as String?,
      coachCorroborated: json['coachCorroborated'] as bool? ?? false,
      generation: (json['generation'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'kind': kind,
        'status': status,
        'addedAt': addedAt,
        if (softeningSince != null) 'softeningSince': softeningSince,
        if (overcameAt != null) 'overcameAt': overcameAt,
        'journalSignalDays': journalSignalDays,
        if (lastJournalSignalDate != null)
          'lastJournalSignalDate': lastJournalSignalDate,
        'coachCorroborated': coachCorroborated,
        'generation': generation,
      };
}
