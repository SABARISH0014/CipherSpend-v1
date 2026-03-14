import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
class SmsBridge {
  static const MethodChannel _methodChannel =
      MethodChannel('com.example.cipherspend/sms');

  static const EventChannel _eventChannel =
      EventChannel('com.cipherspend/sms_stream');

  /// 1. Fetch History (Now supports 'since' for fast delta-syncing)
  Future<List<dynamic>> readSmsHistory({int? since}) async {
    try {
      // If 'since' is provided, pass it to Kotlin. Otherwise, pass null.
      final arguments = since != null ? {'since': since} : null;

      final List<dynamic> result =
          await _methodChannel.invokeMethod('readSmsHistory', arguments);
      return result;
    } on PlatformException catch (e) {
      debugPrint("Native Bridge Error (History): $e");
      return [];
    }
  }

  /// 2. [NEW] Fetch the intercepted background messages
  Future<String?> getAndClearBackgroundCache() async {
    try {
      final String? result =
          await _methodChannel.invokeMethod('getAndClearBackgroundCache');
      return result;
    } on PlatformException catch (e) {
      debugPrint("Native Bridge Error (Cache): $e");
      return null;
    }
  }

  /// 3. Live Stream for Dashboard listening
  Stream<dynamic> get smsStream => _eventChannel.receiveBroadcastStream();
}
