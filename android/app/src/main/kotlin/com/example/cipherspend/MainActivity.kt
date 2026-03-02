package com.example.cipherspend

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
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
    // Matched to the Dart VerificationScreen Channel
    private val METHOD_CHANNEL = "com.example.cipherspend/sms"
    private val EVENT_CHANNEL = "com.cipherspend/sms_stream"
    private var smsReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                // 1. The Real Verification Loopback Process
                "verifyLoopbackSms" -> {
                    val phone = call.argument<String>("phone")
                    if (phone != null) {
                        verifyLoopback(phone, result)
                    } else {
                        result.error("INVALID", "Phone cannot be null", null)
                    }
                }
                
                // --- [CHANGED] 2. Original Historical Sync (Now accepts 'since' timestamp) ---
                "readSmsHistory" -> {
                    val sinceTimestamp = call.argument<Long>("since") ?: (System.currentTimeMillis() - (180L * 24 * 60 * 60 * 1000))
                    Thread {
                        val messages = readSmsInbox(sinceTimestamp)
                        runOnUiThread { result.success(messages) }
                    }.start()
                }

                // --- [NEW] 3. Background Cache Retrieval ---
                "getAndClearBackgroundCache" -> {
                    val prefs = getSharedPreferences("CipherSmsCache", Context.MODE_PRIVATE)
                    val cachedData = prefs.getString("pending_sms", "[]")
                    
                    // Clear the cache immediately so we don't process them twice
                    prefs.edit().remove("pending_sms").apply()

                    result.success(cachedData)
                }
                else -> result.notImplemented()
            }
        }

        // Live SMS Stream
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

    // --- LOOPBACK VERIFICATION LOGIC ---
    private fun verifyLoopback(phone: String, result: MethodChannel.Result) {
        val verifyPhrase = "CIPHER_VERIFY" // Secret phrase to detect
        var isVerified = false

        // 1. Setup a temporary receiver to listen for this exact message
        val tempReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action == "android.provider.Telephony.SMS_RECEIVED") {
                    val bundle = intent.extras
                    val pdus = bundle?.get("pdus") as Array<*>?
                    
                    pdus?.forEach { pdu ->
                        val format = bundle.getString("format")
                        val msg = SmsMessage.createFromPdu(pdu as ByteArray, format)
                        
                        if (msg.messageBody?.contains(verifyPhrase) == true) {
                            // Match Found!
                            isVerified = true
                            context.unregisterReceiver(this)
                            result.success(true)
                            return
                        }
                    }
                }
            }
        }

        // 2. Register the temporary receiver safely for Android 14+
        val filter = IntentFilter("android.provider.Telephony.SMS_RECEIVED")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(tempReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(tempReceiver, filter)
        }

        // 3. Send the message to the user's own phone
        sendSMS(phone, "Do not share this code. $verifyPhrase")

        // 4. Timeout after 30 Seconds (Prevent infinite loading)
        Handler(Looper.getMainLooper()).postDelayed({
            if (!isVerified) {
                try {
                    unregisterReceiver(tempReceiver)
                    result.success(false) // Timed out
                } catch (e: Exception) {
                    // Receiver might already be unregistered, ignore
                }
            }
        }, 30000)
    }

    // --- SMS SENDING UTILITY ---
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

    // --- LIVE SMS LISTENER (Dashboard) ---
    private fun registerSmsReceiver(events: EventChannel.EventSink?) {
        smsReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action == "android.provider.Telephony.SMS_RECEIVED") {
                    val bundle = intent.extras
                    val pdus = bundle?.get("pdus") as Array<*>?
                    
                    pdus?.forEach { pdu ->
                        val format = bundle.getString("format")
                        val msg = SmsMessage.createFromPdu(pdu as ByteArray, format)
                        
                        val data = HashMap<String, Any>()
                        data["sender"] = msg.originatingAddress ?: "Unknown"
                        data["body"] = msg.messageBody ?: ""
                        data["timestamp"] = msg.timestampMillis
                        events?.success(data)
                    }
                }
            }
        }
        
        // Register safely for Android 14+
        val filter = IntentFilter("android.provider.Telephony.SMS_RECEIVED")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(smsReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(smsReceiver, filter)
        }
    }

    private fun unregisterSmsReceiver() {
        smsReceiver?.let {
            unregisterReceiver(it)
            smsReceiver = null
        }
    }

    // --- [CHANGED] HISTORICAL SCANNER (Accepts dynamic timestamp and sorts ASC) ---
    private fun readSmsInbox(sinceTimestamp: Long): List<Map<String, Any>> {
        val messages = ArrayList<Map<String, Any>>()
        val uri = Uri.parse("content://sms/inbox")
        val projection = arrayOf("body", "address", "date")
        val selection = "date > ?"
        val selectionArgs = arrayOf(sinceTimestamp.toString())
        val sortOrder = "date ASC" // Parse oldest missing messages first

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