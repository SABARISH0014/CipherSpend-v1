import 'package:flutter/services.dart';

class SMSBridge {
  static const MethodChannel _methodChannel =
      MethodChannel('com.cipherspend/native');
  static const EventChannel _eventChannel =
      EventChannel('com.cipherspend/sms_stream');

  // Send the loopback SMS
  static Future<void> sendLoopback(String phone, String code) async {
    try {
      await _methodChannel.invokeMethod('sendLoopbackSMS', {
        'phone': phone,
        'code': "CipherSpend Identity Check: $code",
      });
    } catch (e) {
      print("Error sending SMS: $e");
    }
  }

  // Listen for the incoming SMS
  static Stream<dynamic> get smsStream {
    return _eventChannel.receiveBroadcastStream();
  }
}
