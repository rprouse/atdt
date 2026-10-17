import 'package:flutter/services.dart';

/// Volume-button paging, handled natively by MainActivity. Android changes
/// the volume before Flutter can claim the key, so the activity has to
/// consume it and forward the direction here.
abstract final class VolumeKeys {
  static const channel = MethodChannel('org.prouse.atdt/volume_keys');

  /// While enabled, volume keys page instead of changing the volume.
  static Future<void> setEnabled(bool enabled) async {
    try {
      await channel.invokeMethod<void>('setEnabled', enabled);
    } on MissingPluginException {
      // Not Android (or a test without a handler): nothing to gate.
    }
  }

  /// [onPage] receives 1 for volume down (next screen), -1 for volume up.
  static void listen(void Function(int direction) onPage) =>
      channel.setMethodCallHandler((call) async {
        if (call.method == 'page') onPage(call.arguments as int);
      });

  static void stopListening() => channel.setMethodCallHandler(null);
}
