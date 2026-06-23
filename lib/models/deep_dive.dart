/// The five Deep Dive module IDs — must match what DeepDiveScreen writes.
const kDeepDiveModuleIds = [
  'mindset_patterns',
  'motivation_style',
  'fear_inventory',
  'identity_assessment',
  'social_influence',
];

class DeepDive {
  final String coreWound;
  final String coreDesire;
  final List<String> selfSabotagePatterns;
  final String aiSummary;
  final DateTime lastUpdated;
  /// Per-module completion data, keyed by module id.
  /// Each entry: { 'insight': String, 'completedAt': ISO8601 String }
  final Map<String, Map<String, dynamic>> modules;

  const DeepDive({
    this.coreWound = '',
    this.coreDesire = '',
    this.selfSabotagePatterns = const [],
    this.aiSummary = '',
    required this.lastUpdated,
    this.modules = const {},
  });

  /// Returns true when all 5 modules have a non-empty completedAt.
  bool get isFullyComplete => kDeepDiveModuleIds.every(
        (id) => (modules[id]?['completedAt'] as String?)?.isNotEmpty == true,
      );

  bool isModuleComplete(String moduleId) =>
      (modules[moduleId]?['completedAt'] as String?)?.isNotEmpty == true;

  String? moduleInsight(String moduleId) =>
      modules[moduleId]?['insight'] as String?;

  DeepDive copyWith({
    String? coreWound,
    String? coreDesire,
    List<String>? selfSabotagePatterns,
    String? aiSummary,
    DateTime? lastUpdated,
    Map<String, Map<String, dynamic>>? modules,
  }) {
    return DeepDive(
      coreWound: coreWound ?? this.coreWound,
      coreDesire: coreDesire ?? this.coreDesire,
      selfSabotagePatterns: selfSabotagePatterns ?? this.selfSabotagePatterns,
      aiSummary: aiSummary ?? this.aiSummary,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      modules: modules ?? this.modules,
    );
  }

  factory DeepDive.initial() => DeepDive(lastUpdated: DateTime.now());

  factory DeepDive.fromJson(Map<String, dynamic> json) {
    // Extract per-module data from the top-level deepDive map.
    final modulesMap = <String, Map<String, dynamic>>{};
    for (final id in kDeepDiveModuleIds) {
      final raw = json[id];
      if (raw is Map) {
        modulesMap[id] = Map<String, dynamic>.from(raw);
      }
    }

    return DeepDive(
      coreWound: json['coreWound'] as String? ?? '',
      coreDesire: json['coreDesire'] as String? ?? '',
      selfSabotagePatterns: List<String>.from(
        json['selfSabotagePatterns'] as List<dynamic>? ?? [],
      ),
      aiSummary: json['aiSummary'] as String? ?? '',
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : DateTime.now(),
      modules: modulesMap,
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'coreWound': coreWound,
      'coreDesire': coreDesire,
      'selfSabotagePatterns': selfSabotagePatterns,
      'aiSummary': aiSummary,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
    for (final entry in modules.entries) {
      json[entry.key] = entry.value;
    }
    return json;
  }
}
