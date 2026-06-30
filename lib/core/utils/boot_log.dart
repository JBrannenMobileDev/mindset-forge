import 'dart:io';

import 'package:flutter/foundation.dart';

/// Temporary startup tracer for diagnosing a launch hang on device.
///
/// Writes to a file in the app's tmp sandbox (works in release builds, where
/// `debugPrint` is stripped) so the boot sequence can be pulled off the device
/// with `devicectl device copy from`. Also mirrors to `debugPrint` for the
/// `flutter run` console when a debugger is attached. Remove once diagnosed.
void bootLog(String msg) {
  final line = 'MFBOOT ${DateTime.now().toIso8601String()}: $msg';
  debugPrint(line);
  try {
    File('${Directory.systemTemp.path}/mfboot.log')
        .writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
  } catch (_) {
    // Never let diagnostics break startup.
  }
}
