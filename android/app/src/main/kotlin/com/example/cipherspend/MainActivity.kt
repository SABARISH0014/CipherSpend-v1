package com.example.cipherspend

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.database.Cursor
import android.net.Uri
import android.os.Build
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

        // 1. Method Channel: SMS History & Loopback Testing
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendLoopbackSMS" -> {
                    val phone = call.argument<String>("phone")
                    val message = call.argument<String>("message")
                    sendSMS(phone, message)
                    result.success("SMS Sent")
                }
                "readSmsHistory" -> {
                    // Running heavy content resolver query on a background thread 
                    // to prevent UI jank on i3-processor laptops.
                    Thread {
                        val messages = readSmsInbox()
                        runOnUiThread { result.success(messages) }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }

        // 2. Event Channel: Live SMS Stream (Observer Pattern)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    registerSmsReceiver(events)
                }
                override fun onCancel(arguments: Any?) {
                    unregisterSmsReceiver()
                }
            }
        )
    }

    // --- SMS SENDING (Updated for Android 12+) ---
    private fun sendSMS(phone: String?, message: String?) {
        if (phone == null || message == null) return
        try {
            val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                this.getSystemService(SmsManager::class.java)
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }
            smsManager.sendTextMessage(phone, null, message, null, null)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    // --- LIVE SMS LISTENER (With SIM Identification) ---
    private fun registerSmsReceiver(events: EventChannel.EventSink?) {
        smsReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action == "android.provider.Telephony.SMS_RECEIVED") {
                    val bundle = intent.extras
                    val pdus = bundle?.get("pdus") as Array<*>?
                    val subId = bundle?.getInt("subscription", -1) ?: -1
                    
                    pdus?.forEach { pdu ->
                        val format = bundle.getString("format")
                        val msg = SmsMessage.createFromPdu(pdu as ByteArray, format)
                        
                        val data = HashMap<String, Any>()
                        data["sender"] = msg.originatingAddress ?: "Unknown"
                        data["body"] = msg.messageBody ?: ""
                        data["timestamp"] = msg.timestampMillis
                        data["sim_slot"] = subId // Helpful for identifying which bank/SIM
                        
                        events?.success(data)
                    }
                }
            }
        }
        val filter = IntentFilter("android.provider.Telephony.SMS_RECEIVED")
        registerReceiver(smsReceiver, filter)
    }

    private fun unregisterSmsReceiver() {
        smsReceiver?.let {
            unregisterReceiver(it)
            smsReceiver = null
        }
    }

    // --- HISTORICAL SCANNER (6-Month Range) ---
    private fun readSmsInbox(): List<Map<String, Any>> {
        val messages = ArrayList<Map<String, Any>>()
        val uri = Uri.parse("content://sms/inbox")

        // 180 days history for comprehensive AI training/sync
        val filterDate = System.currentTimeMillis() - (180L * 24 * 60 * 60 * 1000)

        val projection = arrayOf("body", "address", "date")
        val selection = "date > ?"
        val selectionArgs = arrayOf(filterDate.toString())
        val sortOrder = "date DESC"

        try {
            val cursor: Cursor? = contentResolver.query(uri, projection, selection, selectionArgs, sortOrder)
            cursor?.use {
                val bodyIdx = it.getColumnIndex("body")
                val addrIdx = it.getColumnIndex("address")
                val dateIdx = it.getColumnIndex("date")

                while (it.moveToNext()) {
                    val map = HashMap<String, Any>()
                    map["body"] = it.getString(bodyIdx)
                    map["sender"] = it.getString(addrIdx)
                    map["timestamp"] = it.getLong(dateIdx)
                    messages.add(map)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return messages
    }
}