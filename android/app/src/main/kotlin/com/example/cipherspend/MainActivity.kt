package com.example.cipherspend

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.telephony.SmsManager
import android.telephony.SmsMessage
import android.widget.Toast
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity: FlutterFragmentActivity() {
    private val METHOD_CHANNEL = "com.cipherspend/native"
    private val EVENT_CHANNEL = "com.cipherspend/sms_stream"
    private var smsReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Method Channel: Handle Permission & Sending SMS
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "sendLoopbackSMS") {
                val phone = call.argument<String>("phone")
                val code = call.argument<String>("code")
                if (phone != null && code != null) {
                    sendSMS(phone, code)
                    result.success("SMS Sent")
                } else {
                    result.error("ERROR", "Missing phone or code", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // 2. Event Channel: Listen for Incoming Loopback SMS
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    registerReceiver(events)
                }
                override fun onCancel(arguments: Any?) {
                    unregisterReceiver()
                }
            }
        )
    }

    private fun sendSMS(phone: String, message: String) {
        try {
            val smsManager = SmsManager.getDefault()
            smsManager.sendTextMessage(phone, null, message, null, null)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun registerReceiver(events: EventChannel.EventSink?) {
        smsReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action == "android.provider.Telephony.SMS_RECEIVED") {
                    val bundle = intent.extras
                    val pdus = bundle?.get("pdus") as Array<Any>?
                    pdus?.forEach { pdu ->
                        val format = bundle.getString("format")
                        val msg = SmsMessage.createFromPdu(pdu as ByteArray, format)
                        // Send Sender + Body back to Flutter
                        events?.success(mapOf("sender" to msg.originatingAddress, "body" to msg.messageBody))
                    }
                }
            }
        }
        registerReceiver(smsReceiver, IntentFilter("android.provider.Telephony.SMS_RECEIVED"))
    }

    private fun unregisterReceiver() {
        if (smsReceiver != null) {
            unregisterReceiver(smsReceiver)
            smsReceiver = null
        }
    }
}