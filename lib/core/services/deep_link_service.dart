import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';

/// Handles incoming deep links for:
///   mindsetforge://partner-invite/{inviteId}
///   https://mindsetforge.app/partner-invite/{inviteId}
class DeepLinkService {
  final GoRouter _router;
  final _appLinks = AppLinks();

  DeepLinkService(this._router);

  Future<void> init() async {
    // Handle deep link that launched the app (cold start)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) _handleUri(initialUri);
    } catch (e) {
      debugPrint('DeepLinkService initial link error: $e');
    }

    // Handle deep links while the app is running (warm start)
    _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (e) => debugPrint('DeepLinkService stream error: $e'),
    );

    // Android widget taps open the app via home_widget's launch mechanism
    // (not an app_links VIEW intent). iOS widgets use the URL scheme handled
    // above, so this is gated to Android to avoid double navigation.
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final launchedUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
        if (launchedUri != null) _handleUri(launchedUri);
      } catch (e) {
        debugPrint('DeepLinkService home widget launch error: $e');
      }
      HomeWidget.widgetClicked.listen(
        (uri) {
          if (uri != null) _handleUri(uri);
        },
        onError: (e) => debugPrint('DeepLinkService widgetClicked error: $e'),
      );
    }
  }

  void _handleUri(Uri uri) {
    debugPrint('Deep link received: $uri');
    final segments = uri.pathSegments;

    // https://app.mindsetforge.app/partner-invite/{inviteId}
    if (segments.length >= 2 && segments[0] == 'partner-invite') {
      _router.push('/partner-invite/${segments[1]}');
      return;
    }

    // mindsetforge://partner-invite/{inviteId}
    // (custom scheme puts "partner-invite" in the host, the id in the path)
    if (uri.host == 'partner-invite' && segments.isNotEmpty) {
      _router.push('/partner-invite/${segments[0]}');
      return;
    }

    // Widget / watch deep links — all land on the dashboard where the hero
    // lives. `mindsetforge://focus` (tap the priority card) asks the dashboard
    // to open the Plan Day sheet when no focus is set; `mindsetforge://action/
    // <field>` asks it to fire the matching routine action; `mindsetforge://
    // dashboard` is a generic open. (custom scheme puts the destination in the
    // host, with any field in the first path segment)
    if (uri.host == 'focus') {
      _router.go('/dashboard?focus=plan');
    } else if (uri.host == 'action') {
      final field = segments.isNotEmpty ? segments.first : '';
      _router.go(field.isEmpty ? '/dashboard' : '/dashboard?action=$field');
    } else if (uri.host == 'dashboard') {
      _router.go('/dashboard');
    }
  }
}
