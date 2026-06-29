import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../firebase_options.dart';
import '../../models/daily_completion.dart';
import '../../models/widget_payload.dart';
import '../../providers/auth_provider.dart';
import '../../providers/daily_completion_provider.dart';
import '../firebase/firestore_service.dart';
import '../utils/app_date_utils.dart';
import 'watch_bridge.dart';

/// Writes the daily-priority payload to the iOS App Group (for WidgetKit) and
/// forwards it to the Apple Watch. Centralizes all widget/watch data export so
/// the widget reflects exactly what the in-app hero shows.
class WidgetSyncService {
  WidgetSyncService(this._ref);

  final Ref _ref;

  /// App Group shared between the app, the widget extension, and the watch.
  static const String appGroupId = 'group.com.mindsetforge.mindsetforge';

  /// Must match the WidgetKit widget `kind` / extension product name.
  static const String iOSWidgetName = 'MindsetForgeWidget';

  /// Simple class name of the Android `AppWidgetProvider`.
  static const String androidWidgetName = 'FocusWidgetProvider';

  /// Fully-qualified Android provider (`package.ClassName`) for `updateWidget`.
  static const String androidQualifiedName =
      'com.mindsetforge.mindsetforge.FocusWidgetProvider';

  /// Single JSON blob key the native side decodes.
  static const String payloadKey = 'widget_payload';

  bool get _isSupported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  /// Rebuilds the payload from current providers and pushes it everywhere.
  Future<void> sync() async {
    if (!_isSupported) return;
    final profile = _ref.read(currentUserProfileProvider).valueOrNull;
    final payload = profile == null
        ? WidgetPayload.empty()
        : WidgetPayload.fromProfile(
            profile,
            completion: _ref.read(dailyCompletionProvider),
          );
    await _writeWidget(payload);
    await _ref.read(watchBridgeProvider).pushPayload(payload.toJson());
  }

  Future<void> _writeWidget(WidgetPayload payload) async {
    try {
      if (Platform.isIOS) {
        await HomeWidget.setAppGroupId(appGroupId);
      }
      await HomeWidget.saveWidgetData<String>(
        payloadKey,
        jsonEncode(payload.toJson()),
      );
      await HomeWidget.updateWidget(
        name: iOSWidgetName,
        iOSName: iOSWidgetName,
        androidName: androidWidgetName,
        qualifiedAndroidName: androidQualifiedName,
      );
    } catch (e) {
      debugPrint('WidgetSyncService._writeWidget failed: $e');
    }
  }
}

/// Provides the shared `WatchBridge` instance.
final watchBridgeProvider = Provider<WatchBridge>((_) => WatchBridge());

/// Provides the `WidgetSyncService`.
final widgetSyncServiceProvider =
    Provider<WidgetSyncService>((ref) => WidgetSyncService(ref));

// ── Interactive write-back (widget "Mark done" button, iOS 17+) ──────────────

/// Background entry point invoked by `home_widget` when the widget's
/// "Mark done" App Intent fires. Runs in a background isolate (or the app
/// process via `ForegroundContinuableIntent`), so it cannot touch Riverpod and
/// must persist directly through Firebase, mirroring `TodayHeroCard._completeFocus`.
@pragma('vm:entry-point')
Future<void> widgetInteractiveCallback(Uri? uri) async {
  // Uri hosts are lowercased; `mindsetforge://completeFocus` → `completefocus`.
  if (uri?.host == 'completefocus') {
    await _completeFocusInBackground();
  }
}

Future<void> _completeFocusInBackground() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Already initialized in this isolate — safe to ignore.
  }

  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;

  try {
    final fs = FirestoreService();
    final profile = await fs.getUserProfile(uid);
    if (profile == null) return;

    // Mirror TodayHeroCard._completeFocus: flip the profile flag and the
    // matching daily-completion flag (recording the completion timestamp).
    final today = AppDateUtils.todayStringWithGracePeriod();
    final completions = [...profile.dailyCompletions];
    final idx = completions.indexWhere((c) => c.date == today);
    final base = idx >= 0 ? completions[idx] : DailyCompletion(date: today);
    final times = Map<String, String>.from(base.completionTimes)
      ..['priorityActionsCompleted'] = DateTime.now().toIso8601String();
    final updated = base.copyWith(
      priorityActionsCompleted: true,
      completionTimes: times,
    );
    if (idx >= 0) {
      completions[idx] = updated;
    } else {
      completions.add(updated);
    }

    await fs.updateUserField(uid, {
      'dailyFocusActionCompleted': true,
      'dailyCompletions': completions.map((c) => c.toJson()).toList(),
    });

    // Rebuild the payload from the now-updated profile and refresh the widget.
    final mergedProfile = profile.copyWith(
      dailyFocusActionCompleted: true,
      dailyCompletions: completions,
    );
    final payload = WidgetPayload.fromProfile(
      mergedProfile,
      completion: updated,
    );
    if (Platform.isIOS) {
      await HomeWidget.setAppGroupId(WidgetSyncService.appGroupId);
    }
    await HomeWidget.saveWidgetData<String>(
      WidgetSyncService.payloadKey,
      jsonEncode(payload.toJson()),
    );
    await HomeWidget.updateWidget(
      name: WidgetSyncService.iOSWidgetName,
      iOSName: WidgetSyncService.iOSWidgetName,
      androidName: WidgetSyncService.androidWidgetName,
      qualifiedAndroidName: WidgetSyncService.androidQualifiedName,
    );
  } catch (e) {
    debugPrint('widgetInteractiveCallback completeFocus failed: $e');
  }
}
