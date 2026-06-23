import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

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
  }

  void _handleUri(Uri uri) {
    debugPrint('Deep link received: $uri');
    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments[0] == 'partner-invite') {
      final inviteId = segments[1];
      _router.push('/partner-invite/$inviteId');
    }
  }
}
