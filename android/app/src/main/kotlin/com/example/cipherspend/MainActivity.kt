package com.example.cipherspend

import android.Manifest
import android.content.*
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.*
import android.provider.Settings
import android.telephony.SmsManager
import android.telephony.SmsMessage
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayList
import java.util.HashMap

class MainActivity : FlutterFragmentActivity() {

    private val METHOD_CHANNEL = "com.example.cipherspend/sms"
    private val EVENT_CHANNEL = "com.cipherspend/sms_stream"

    private var smsReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->

                when (call.method) {

                    "verifyLoopbackSms" -> {
                        val phone = call.argument<String>("phone")
                        if (phone != null) {
                            verifyLoopback(phone, result)
                        } else {
                            result.error("INVALID", "Phone cannot be null", null)
                        }
                    }

                    "readSmsHistory" -> {
                        val sinceTimestamp =
                            call.argument<Long>("since")
                                ?: (System.currentTimeMillis() - (180L * 24 * 60 * 60 * 1000))

                        Thread {
                            val messages = readSmsInbox(sinceTimestamp)
                            runOnUiThread { result.success(messages) }
                        }.start()
                    }

                    "getAndClearBackgroundCache" -> {
                        val prefs = getSharedPreferences("CipherSmsCache", Context.MODE_PRIVATE)
                        val cached = prefs.getString("pending_sms", "[]")
                        prefs.edit().remove("pending_sms").apply()
                        result.success(cached)
                    }

                    "openNotificationSettings" -> {
                        try {
                            startActivity(Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS").apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            })
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", "Cannot open settings", null)
                        }
                    }

                    "isNotificationListenerEnabled" -> {
                        val flat = Settings.Secure.getString(
                            contentResolver,
                            "enabled_notification_listeners"
                        )
                        result.success(flat?.contains(packageName) == true)
                    }

                    // --- SMART PROMPT LOGIC ---
                    "hasUsageAccess" -> {
                        val appOps = getSystemService(Context.APP_OPS_SERVICE) as android.app.AppOpsManager
                        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            appOps.unsafeCheckOpNoThrow(android.app.AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
                        } else {
                            @Suppress("DEPRECATION")
                            appOps.checkOpNoThrow(android.app.AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
                        }
                        result.success(mode == android.app.AppOpsManager.MODE_ALLOWED)
                    }

                    "openUsageAccessSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("UNAVAILABLE", "Usage Access Settings not available", null)
                        }
                    }

                    "getRecentUpiApp" -> {
                        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as android.app.usage.UsageStatsManager
                        val endTime = System.currentTimeMillis()
                        val startTime = endTime - (5 * 60 * 1000) // Look at the last 5 minutes

                        val stats = usageStatsManager.queryUsageStats(android.app.usage.UsageStatsManager.INTERVAL_DAILY, startTime, endTime)
                        var recentUpiApp: String? = null
                        var latestTime: Long = 0

                        val upiApps = mapOf(
                            "com.google.android.apps.nbu.paisa.user" to "GPay",
                            "com.phonepe.app" to "PhonePe",
                            "net.one97.paytm" to "Paytm",
                            "in.org.npci.upiapp" to "BHIM",
                            "com.dreamplug.androidapp" to "Cred"
                        )

                        stats?.forEach { stat ->
                            if (upiApps.containsKey(stat.packageName)) {
                                if (stat.lastTimeUsed > latestTime && stat.lastTimeUsed > startTime) {
                                    latestTime = stat.lastTimeUsed
                                    recentUpiApp = upiApps[stat.packageName]
                                }
                            }
                        }
                        result.success(recentUpiApp)
                    }

                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {

                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    registerSmsReceiver(events)
                }

                override fun onCancel(arguments: Any?) {
                    unregisterSmsReceiver()
                }
            })
    }

    private fun verifyLoopback(phone: String, result: MethodChannel.Result) {
        if (ActivityCompat.checkSelfPermission(
                this,
                Manifest.permission.SEND_SMS
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            result.error("PERMISSION", "SEND_SMS permission missing", null)
            return
        }

        val verifyPhrase = "CIPHER_VERIFY"
        var resultSent = false

        val tempReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val bundle = intent.extras ?: return
                val pdus = bundle.get("pdus") as? Array<*> ?: return

                for (pdu in pdus) {
                    val format = bundle.getString("format")
                    val msg = SmsMessage.createFromPdu(pdu as ByteArray, format)

                    if (msg.messageBody?.contains(verifyPhrase) == true) {
                        if (!resultSent) {
                            result.success(true)
                            resultSent = true
                        }
                        context.unregisterReceiver(this)
                        return
                    }
                }
            }
        }

        val filter = IntentFilter("android.provider.Telephony.SMS_RECEIVED")
        // [FIX] Android 13+ requires Exported flag for runtime receivers
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(tempReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            registerReceiver(tempReceiver, filter)
        }

        sendSMS(phone, "Verification code: $verifyPhrase")

        Handler(Looper.getMainLooper()).postDelayed({
            if (!resultSent) {
                try {
                    unregisterReceiver(tempReceiver)
                } catch (_: Exception) {}
                result.success(false)
            }
        }, 30000)
    }

    private fun sendSMS(phone: String, message: String) {
        try {
            val smsManager =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                    getSystemService(SmsManager::class.java)
                else {
                    @Suppress("DEPRECATION")
                    SmsManager.getDefault()
                }

            smsManager.sendTextMessage(phone, null, message, null, null)

        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun registerSmsReceiver(events: EventChannel.EventSink?) {
        smsReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val bundle = intent.extras ?: return
                val pdus = bundle.get("pdus") as? Array<*> ?: return

                for (pdu in pdus) {
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

        val filter = IntentFilter("android.provider.Telephony.SMS_RECEIVED")
        // [FIX] Android 13+ requires Exported flag for runtime receivers
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

    private fun readSmsInbox(since: Long): List<Map<String, Any>> {
        val list = ArrayList<Map<String, Any>>()
        val cursor: Cursor? = contentResolver.query(
            Uri.parse("content://sms/inbox"),
            arrayOf("body", "address", "date"),
            "date > ?",
            arrayOf(since.toString()),
            "date ASC"
        )

        cursor?.use {
            val bodyIdx = it.getColumnIndex("body")
            val addrIdx = it.getColumnIndex("address")
            val dateIdx = it.getColumnIndex("date")

            while (it.moveToNext()) {
                val map = HashMap<String, Any>()
                map["body"] = it.getString(bodyIdx)
                map["sender"] = it.getString(addrIdx)
                map["timestamp"] = it.getLong(dateIdx)
                list.add(map)
            }
        }
        return list
    }
}