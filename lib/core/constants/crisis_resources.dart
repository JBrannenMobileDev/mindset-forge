/// Crisis support resources surfaced when the coach detects a safety risk.
///
/// Defaults are US-focused with an international fallback. Centralized here so
/// they are easy to localize and update in one place.
class CrisisResource {
  final String label;
  final String description;

  /// A launchable URI: tel:, sms:, or https:.
  final String uri;

  const CrisisResource({
    required this.label,
    required this.description,
    required this.uri,
  });
}

abstract final class CrisisResources {
  /// Ordered list shown in the crisis resource card.
  static const List<CrisisResource> all = [
    CrisisResource(
      label: '988 Suicide & Crisis Lifeline',
      description: 'Call or text 988, free and confidential, 24/7.',
      uri: 'tel:988',
    ),
    CrisisResource(
      label: 'Crisis Text Line',
      description: 'Text HOME to 741741 to reach a trained counselor.',
      uri: 'sms:741741',
    ),
    CrisisResource(
      label: 'Emergency Services',
      description: 'If you are in immediate danger, call 911 now.',
      uri: 'tel:911',
    ),
    CrisisResource(
      label: 'Find a Helpline (International)',
      description: 'Free, confidential support lines around the world.',
      uri: 'https://findahelpline.com',
    ),
  ];

  /// High-recall keyword backstop. Intentionally broad: a false positive simply
  /// surfaces support resources, which is far safer than a missed crisis.
  /// Used only as a safety net behind the model's own safety classification.
  static const List<String> crisisKeywords = [
    'suicide',
    'suicidal',
    'kill myself',
    'killing myself',
    'end my life',
    'end it all',
    'want to die',
    'wanna die',
    'better off dead',
    'no reason to live',
    'nothing to live for',
    "don't want to be here",
    'dont want to be here',
    'self harm',
    'self-harm',
    'hurt myself',
    'harm myself',
    'cut myself',
    'kill him',
    'kill her',
    'kill them',
    'hurt someone',
    'hurt him',
    'hurt her',
    'hurt them',
  ];

  /// Returns true if [text] contains any crisis keyword (case-insensitive).
  static bool containsCrisisLanguage(String text) {
    final lower = text.toLowerCase();
    return crisisKeywords.any(lower.contains);
  }
}
