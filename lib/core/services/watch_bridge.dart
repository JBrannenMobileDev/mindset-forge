import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Thin bridge to the native Apple Watch companion over WatchConnectivity.
///
/// The phone pushes the slim widget payload to the watch via
/// `updateApplicationContext` (latest-state-wins, survives reachability gaps)
/// and receives glance actions (e.g. "Mark focus done") back as commands.
/// All native plumbing lives in `WatchConnectivityBridge.swift` on the iOS
/// side; this class only marshals across the method channel.
class WatchBridge {
  static const MethodChannel _channel = MethodChannel('mindsetforge/watch');

  bool get _isSupported => !kIsWeb && Platform.isIOS;

  /// Pushes the latest payload to the watch. Best-effort: failures (no paired
  /// watch, app not installed) are swallowed since the watch always renders
  /// last-known state.
  Future<void> pushPayload(Map<String, dynamic> payload) async {
    if (!_isSupported) return;
    try {
      await _channel.invokeMethod<void>('updateContext', payload);
    } catch (e) {
      debugPrint('WatchBridge.pushPayload failed: $e');
    }
  }

  /// Registers a handler for commands sent from the watch glance app.
  /// The command string (e.g. `completeFocus`) is forwarded from the native
  /// `didReceiveMessage` / `didReceiveUserInfo` delegate callbacks.
  void setCommandHandler(Future<void> Function(String command) handler) {
    if (!_isSupported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'command') {
        final command = call.arguments as String? ?? '';
        if (command.isNotEmpty) await handler(command);
      }
    });
  }
}
