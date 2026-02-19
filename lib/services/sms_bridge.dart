import 'package:flutter/services.dart';

class SmsBridge {
  static const MethodChannel _methodChannel =
      MethodChannel('com.cipherspend/native');
  static const EventChannel _eventChannel =
      EventChannel('com.cipherspend/sms_stream');

  Future<List<Map<dynamic, dynamic>>> readSmsHistory() async {
    try {
      final List<dynamic> result =
          await _methodChannel.invokeMethod('readSmsHistory');
      return result.cast<Map<dynamic, dynamic>>();
    } on PlatformException catch (_) {
      return [];
    }
  }

  Stream<dynamic> get smsStream => _eventChannel.receiveBroadcastStream();
}
