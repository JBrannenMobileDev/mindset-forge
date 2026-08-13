/// A selectable answer in the onboarding "How did you hear about us?" question.
///
/// The live list is served from the `app_config/attribution_sources` Firestore
/// doc rather than compiled into the app, so a new referral partner can be
/// added the day they sign instead of waiting on an App Store release.
class AttributionSource {
  /// Stable machine id persisted to `UserProfile.referralSource` and sent to
  /// RevenueCat as a subscriber attribute. Partner ids are conventionally
  /// prefixed `partner_` (e.g. `partner_john`) so partner-driven signups are
  /// trivially separable from generic channels when reporting.
  final String id;

  /// Display label shown to the user. For a partner this should be the handle
  /// their audience actually recognizes, not a legal name.
  final String label;

  const AttributionSource({required this.id, required this.label});

  factory AttributionSource.fromJson(Map<String, dynamic> json) =>
      AttributionSource(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'id': id, 'label': label};

  /// Guards against a malformed config row rendering a blank, unselectable tile.
  bool get isValid => id.isNotEmpty && label.isNotEmpty;
}
