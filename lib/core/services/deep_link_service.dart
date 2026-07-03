import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:home_widget/home_widget.dart';

/// Handles incoming deep links for:
///   mindsetforge://partner-invite/{inviteId}
///   https://mindsetforge.app/partner-invite/{inviteId}
///   mindsetforge://focus | action/<field> | dashboard (widget / watch)
class DeepLinkService {
  DeepLinkService(this._router);

  final GoRouter _router;
  final _appLinks = AppLinks();

  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<Uri?>? _widgetSubscription;

  AppLifecycleState _lifecycle =
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;

  /// URI received while the app was not yet [AppLifecycleState.resumed].
  Uri? _pendingUri;

  /// Dedupes stream + resume poll firing for the same tap.
  String? _lastHandledUriKey;
  DateTime? _lastHandledAt;

  static const _dedupeWindow = Duration(seconds: 2);

  /// Navigation hosts handled by this service (excludes background-only URIs).
  static const _widgetHosts = {'focus', 'action', 'dashboard', 'partner-invite'};

  Future<void> init() async {
    // Subscribe before awaiting cold-start links so early events aren't missed.
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _onUriReceived,
      onError: (e) => debugPrint('DeepLinkService stream error: $e'),
    );

    if (!kIsWeb && Platform.isAndroid) {
      _widgetSubscription = HomeWidget.widgetClicked.listen(
        (uri) {
          if (uri != null) _onUriReceived(uri);
        },
        onError: (e) => debugPrint('DeepLinkService widgetClicked error: $e'),
      );
    }

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) _tryHandleUri(initialUri);
    } catch (e) {
      debugPrint('DeepLinkService initial link error: $e');
    }

    // Android widget taps open via home_widget's launch intent (not app_links).
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final launchedUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
        if (launchedUri != null) _tryHandleUri(launchedUri);
      } catch (e) {
        debugPrint('DeepLinkService home widget launch error: $e');
      }
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
    _widgetSubscription?.cancel();
  }

  void onLifecycleStateChanged(AppLifecycleState state) {
    _lifecycle = state;
  }

  /// Re-check link sources after foreground resume. Catches widget taps that
  /// arrived while the app was backgrounded and the stream event was missed.
  Future<void> handleLinksOnResume() async {
    if (kIsWeb) return;

    final pending = _pendingUri;
    if (pending != null) {
      _pendingUri = null;
      _tryHandleUri(pending, bypassQueue: true);
    }

    try {
      final latestUri = await _appLinks.getLatestLink();
      if (latestUri != null) {
        _tryHandleUri(latestUri, bypassQueue: true);
      }
    } catch (e) {
      debugPrint('DeepLinkService getLatestLink error: $e');
    }

    if (Platform.isAndroid) {
      try {
        final widgetUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
        if (widgetUri != null) {
          _tryHandleUri(widgetUri, bypassQueue: true);
        }
      } catch (e) {
        debugPrint('DeepLinkService home widget resume error: $e');
      }
    }
  }

  void _onUriReceived(Uri uri) => _tryHandleUri(uri);

  void _tryHandleUri(Uri uri, {bool bypassQueue = false}) {
    if (!_isNavigableUri(uri)) return;
    if (_shouldDedupe(uri)) return;

    if (!bypassQueue && _lifecycle != AppLifecycleState.resumed) {
      _pendingUri = uri;
      debugPrint('DeepLinkService queued (lifecycle=$_lifecycle): $uri');
      return;
    }

    _navigate(uri);
    _markHandled(uri);
  }

  bool _isNavigableUri(Uri uri) {
    // Background widget action — handled by widgetInteractiveCallback, not here.
    if (uri.host == 'completeFocus') return false;

    if (uri.scheme == 'mindsetforge' && _widgetHosts.contains(uri.host)) {
      return true;
    }
    if (uri.scheme == 'https' &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments.first == 'partner-invite') {
      return true;
    }
    return false;
  }

  bool _shouldDedupe(Uri uri) {
    final key = uri.toString();
    if (_lastHandledUriKey != key || _lastHandledAt == null) return false;
    return DateTime.now().difference(_lastHandledAt!) < _dedupeWindow;
  }

  void _markHandled(Uri uri) {
    _lastHandledUriKey = uri.toString();
    _lastHandledAt = DateTime.now();
  }

  void _navigate(Uri uri) {
    debugPrint('Deep link navigating: $uri');
    final segments = uri.pathSegments;

    // https://app.mindsetforge.app/partner-invite/{inviteId}
    if (segments.length >= 2 && segments[0] == 'partner-invite') {
      _router.push('/partner-invite/${segments[1]}');
      return;
    }

    // mindsetforge://partner-invite/{inviteId}
    if (uri.host == 'partner-invite' && segments.isNotEmpty) {
      _router.push('/partner-invite/${segments[0]}');
      return;
    }

    // Widget / watch deep links — all land on the dashboard where the hero
    // lives. `mindsetforge://focus` opens the Plan Day sheet when no focus is
    // set; `mindsetforge://action/<field>` fires the matching routine action;
    // `mindsetforge://dashboard` is a generic open.
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
