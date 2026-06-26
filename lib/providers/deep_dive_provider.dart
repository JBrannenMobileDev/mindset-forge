import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/analytics_service.dart';
import 'auth_provider.dart';

/// Action-only notifier for Deep Dive module persistence.
///
/// The UI state (saving indicator, insight text) lives in
/// [_ModuleScreenState]; this notifier exists solely to move the Firestore
/// write out of the widget layer and into a testable, architecture-compliant
/// provider.
class DeepDiveNotifier extends StateNotifier<void> {
  final Ref _ref;

  DeepDiveNotifier(this._ref) : super(null);

  /// Persists [insight] and completion timestamp for [moduleId].
  /// Throws on Firestore failure so the caller can surface an error.
  Future<void> saveInsight(String moduleId, String insight) async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    try {
      await _ref.read(firestoreServiceProvider).updateUserField(uid, {
        'deepDive.$moduleId.insight': insight,
        'deepDive.$moduleId.completedAt': DateTime.now().toIso8601String(),
      });
      _ref.read(analyticsServiceProvider).trackDeepDiveModuleCompleted(moduleId);
    } catch (e) {
      debugPrint('DeepDiveNotifier.saveInsight failed: $e');
      rethrow;
    }
  }
}

final deepDiveProvider =
    StateNotifierProvider<DeepDiveNotifier, void>((ref) => DeepDiveNotifier(ref));
