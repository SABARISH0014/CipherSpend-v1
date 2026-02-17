package com.example.cipherspend

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.database.Cursor
import android.net.Uri
import android.telephony.SmsManager
import android.telephony.SmsMessage
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayList
import java.util.HashMap

class MainActivity: FlutterFragmentActivity() {
    private val METHOD_CHANNEL = "com.cipherspend/native"
    private val EVENT_CHANNEL = "com.cipherspend/sms_stream"
    private var smsReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Method Channel: Sending Loopback & Reading History
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "sendLoopbackSMS") {
                val phone = call.argument<String>("phone")
                val code = call.argument<String>("code")
                sendSMS(phone, code)
                result.success("SMS Sent")
            } else if (call.method == "readSmsHistory") {
                // Run heavy DB query on a background thread
                Thread {
                    val messages = readSmsInbox()
                    runOnUiThread { result.success(messages) }
                }.start()
            } else {
                result.notImplemented()
            }
        }

        // 2. Event Channel: Live Incoming SMS Stream
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

    // --- SMS SENDING ---
    private fun sendSMS(phone: String?, message: String?) {
        try {
            val smsManager = SmsManager.getDefault()
            smsManager.sendTextMessage(phone, null, message, null, null)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    // --- LIVE PDU PARSING (With SIM ID) ---
    private fun registerReceiver(events: EventChannel.EventSink?) {
        smsReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action == "android.provider.Telephony.SMS_RECEIVED") {
                    val bundle = intent.extras
                    // [WEEK 2 REQ] Extract Subscription ID (SIM Slot Index)
                    val subId = bundle?.getInt("subscription", -1) ?: -1
                    
                    val pdus = bundle?.get("pdus") as Array<Any>?
                    pdus?.forEach { pdu ->
                        val format = bundle.getString("format")
                        val msg = SmsMessage.createFromPdu(pdu as ByteArray, format)
                        
                        val data = HashMap<String, Any>()
                        data["sender"] = msg.originatingAddress ?: "Unknown"
                        data["body"] = msg.messageBody ?: ""
                        data["timestamp"] = msg.timestampMillis
                        data["subscription_id"] = subId // Identifying which SIM received it
                        
                        events?.success(data)
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

    // --- HISTORY READER (Strict 90-Day Filter) ---
    private fun readSmsInbox(): List<Map<String, Any>> {
        val messages = ArrayList<Map<String, Any>>()
        val uri = Uri.parse("content://sms/inbox")

        // [WEEK 2 REQ] Calculate timestamp for 90 Days Ago
        // Current Time - (90 Days * 24 Hours * 60 Mins * 60 Secs * 1000 Ms)
        val ninetyDaysAgo = System.currentTimeMillis() - (90L * 24 * 60 * 60 * 1000)

        // Query: Select body, address, date WHERE date > 90_days_ago
        val projection = arrayOf("body", "address", "date")
        val selection = "date > ?"
        val selectionArgs = arrayOf(ninetyDaysAgo.toString())
        val sortOrder = "date DESC" // Newest first

        val cursor: Cursor? = contentResolver.query(
            uri, 
            projection, 
            selection, 
            selectionArgs, 
            sortOrder
        )

        cursor?.use {
            val bodyIndex = it.getColumnIndex("body")
            val addressIndex = it.getColumnIndex("address")
            val dateIndex = it.getColumnIndex("date")

            while (it.moveToNext()) {
                val map = HashMap<String, Any>()
                map["body"] = it.getString(bodyIndex)
                map["sender"] = it.getString(addressIndex)
                map["timestamp"] = it.getLong(dateIndex)
                messages.add(map)
            }
        }
        return messages
    }
}