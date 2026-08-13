import 'dart:io';

import 'package:android_play_install_referrer/android_play_install_referrer.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds marketing attribution resolved before the user has an account, so it
/// can be stamped onto their profile once they sign up.
///
/// Only Android can supply this deterministically: the Play Install Referrer
/// API hands back the `referrer` string from the Play Store URL that produced
/// the install. iOS has no equivalent that survives the App Store, which is
/// why the onboarding question exists at all.
///
/// Mirrors [PendingInviteStore]: a synchronous in-memory copy backed by
/// SharedPreferences, loaded once at app start.
class PendingReferralStore {
  PendingReferralStore._();

  static const _sourceKey = 'pending_referral_source';
  static const _detailKey = 'pending_referral_detail';
  static const _checkedKey = 'pending_referral_checked';

  static String? _source;
  static String? _detail;

  /// Attribution source id (e.g. `partner_john`), when one was resolved.
  static String? get source => _source;

  /// Raw referrer payload, kept verbatim for auditing.
  static String? get detail => _detail;

  static bool get hasPending => _source != null && _source!.isNotEmpty;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _source = prefs.getString(_sourceKey);
    _detail = prefs.getString(_detailKey);
  }

  /// Queries the Play Install Referrer once per install and caches the result.
  ///
  /// Safe to call on every launch and on every platform: it no-ops off Android
  /// and after the first successful check. Any failure is swallowed, since the
  /// onboarding question is the fallback path anyway.
  static Future<void> resolveInstallReferrer() async {
    if (kIsWeb || !Platform.isAndroid) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_checkedKey) ?? false) return;

    try {
      final details = await AndroidPlayInstallReferrer.installReferrer;
      final raw = details.installReferrer;
      // Mark checked even on an empty referrer: organic installs return one,
      // and retrying on every launch would never succeed.
      await prefs.setBool(_checkedKey, true);
      if (raw == null || raw.isEmpty) return;

      _detail = raw;
      await prefs.setString(_detailKey, raw);

      final source = _parseSource(raw);
      if (source == null) return;
      _source = source;
      await prefs.setString(_sourceKey, source);
    } catch (e) {
      debugPrint('PendingReferralStore.resolveInstallReferrer failed: $e');
    }
  }

  /// Extracts the campaign from a referrer string, which arrives URL-encoded
  /// in query-string form (e.g. `utm_source=partner_john&utm_medium=social`).
  ///
  /// Only `utm_source` is honoured. The vanity links built for partners set it
  /// to the campaign id, and anything else (Play's own organic values, other
  /// campaigns) is left for the onboarding question to resolve.
  static String? _parseSource(String raw) {
    try {
      final params = Uri.splitQueryString(raw);
      final source = params['utm_source'];
      if (source == null || source.isEmpty) return null;
      return source;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    _source = null;
    _detail = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sourceKey);
    await prefs.remove(_detailKey);
  }
}
