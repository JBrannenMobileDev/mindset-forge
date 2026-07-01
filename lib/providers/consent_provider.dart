import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/analytics_service.dart';
import '../core/services/consent_service.dart';
import 'auth_provider.dart';

/// Web cookie/analytics consent state.
///
/// - [unknown]: user hasn't chosen yet (web only) — show the banner.
/// - [granted]: analytics may load.
/// - [denied]: analytics stay off.
///
/// On non-web platforms this is always [granted] (analytics are not gated by a
/// cookie banner there; mobile relies on app-store consent flows).
enum AnalyticsConsent { unknown, granted, denied }

class ConsentNotifier extends StateNotifier<AnalyticsConsent> {
  final Ref _ref;

  ConsentNotifier(this._ref) : super(_initialState());

  static AnalyticsConsent _initialState() {
    if (!kIsWeb) return AnalyticsConsent.granted;
    if (!ConsentService.decided) return AnalyticsConsent.unknown;
    return ConsentService.granted
        ? AnalyticsConsent.granted
        : AnalyticsConsent.denied;
  }

  /// User accepted cookies: persist, start analytics now, and identify the
  /// current user so their session is attributed immediately.
  Future<void> accept() async {
    await ConsentService.set(true);
    state = AnalyticsConsent.granted;
    await AnalyticsService.init();
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    final profile = _ref.read(currentUserProfileProvider).valueOrNull;
    if (uid != null && profile != null) {
      _ref.read(analyticsServiceProvider).identify(uid, profile);
    }
  }

  /// User declined: persist the choice and leave analytics uninitialized.
  Future<void> decline() async {
    await ConsentService.set(false);
    state = AnalyticsConsent.denied;
  }
}

final consentProvider =
    StateNotifierProvider<ConsentNotifier, AnalyticsConsent>(
  (ref) => ConsentNotifier(ref),
);
