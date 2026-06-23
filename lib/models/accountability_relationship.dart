class AccountabilityRelationship {
  final String id;
  final String type; // 'primary' | 'partner'
  // If type == 'primary': the partner's info
  final String? partnerUid;
  final String? partnerEmail;
  final String? partnerName;
  // If type == 'partner': the primary user's info
  final String? primaryUid;
  final String? primaryEmail;
  final String? primaryName;
  final String status; // 'active' | 'pending' | 'removed'
  final String acceptedAt;

  const AccountabilityRelationship({
    required this.id,
    required this.type,
    this.partnerUid,
    this.partnerEmail,
    this.partnerName,
    this.primaryUid,
    this.primaryEmail,
    this.primaryName,
    this.status = 'active',
    required this.acceptedAt,
  });

  bool get isPrimary => type == 'primary';
  bool get isPartner => type == 'partner';

  String get otherUserUid => isPrimary ? (partnerUid ?? '') : (primaryUid ?? '');
  String get otherUserName =>
      isPrimary ? (partnerName ?? 'Partner') : (primaryName ?? 'Primary');
  String get otherUserEmail =>
      isPrimary ? (partnerEmail ?? '') : (primaryEmail ?? '');

  AccountabilityRelationship copyWith({
    String? id,
    String? type,
    String? partnerUid,
    String? partnerEmail,
    String? partnerName,
    String? primaryUid,
    String? primaryEmail,
    String? primaryName,
    String? status,
    String? acceptedAt,
  }) {
    return AccountabilityRelationship(
      id: id ?? this.id,
      type: type ?? this.type,
      partnerUid: partnerUid ?? this.partnerUid,
      partnerEmail: partnerEmail ?? this.partnerEmail,
      partnerName: partnerName ?? this.partnerName,
      primaryUid: primaryUid ?? this.primaryUid,
      primaryEmail: primaryEmail ?? this.primaryEmail,
      primaryName: primaryName ?? this.primaryName,
      status: status ?? this.status,
      acceptedAt: acceptedAt ?? this.acceptedAt,
    );
  }

  factory AccountabilityRelationship.fromJson(Map<String, dynamic> json) {
    return AccountabilityRelationship(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'primary',
      partnerUid: json['partnerUid'] as String?,
      partnerEmail: json['partnerEmail'] as String?,
      partnerName: json['partnerName'] as String?,
      primaryUid: json['primaryUid'] as String?,
      primaryEmail: json['primaryEmail'] as String?,
      primaryName: json['primaryName'] as String?,
      status: json['status'] as String? ?? 'active',
      acceptedAt:
          json['acceptedAt'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'partnerUid': partnerUid,
        'partnerEmail': partnerEmail,
        'partnerName': partnerName,
        'primaryUid': primaryUid,
        'primaryEmail': primaryEmail,
        'primaryName': primaryName,
        'status': status,
        'acceptedAt': acceptedAt,
      };
}
