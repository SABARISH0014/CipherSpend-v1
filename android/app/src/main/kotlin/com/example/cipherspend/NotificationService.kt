package com.example.cipherspend

import android.app.Notification
import android.content.Context
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject

class NotificationService : NotificationListenerService() {

    private val UPI_APPS = mapOf(
        // UPI Apps
        "com.google.android.apps.nbu.paisa.user" to "GPay",
        "com.phonepe.app" to "PhonePe",
        "net.one97.paytm" to "Paytm",
        "in.org.npci.upiapp" to "BHIM",
        // Bank Apps (The Safety Net)
        "com.sbi.SBIFreedomPlus" to "SBI YONO",
        "com.snapwork.hdfc" to "HDFC Bank",
        "com.csam.icici.bank.imobile" to "ICICI iMobile",
        "com.dreamplug.androidapp" to "Cred"
    )

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val packageName = sbn.packageName
        if (!UPI_APPS.containsKey(packageName)) return

        val extras = sbn.notification.extras
        val title = extras.getString(Notification.EXTRA_TITLE) ?: ""
        var text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        
        // [FIX] Android 13+ often hides the full payment string in expanded BIG_TEXT
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString() ?: ""
        if (bigText.isNotEmpty() && bigText.length > text.length) {
            text = bigText
        }

        if (isValidTransaction(title, text)) {
            val preciseTimestamp = sbn.postTime 
            val senderName = UPI_APPS[packageName] ?: "UPI"
            cacheData(senderName, "$title $text", preciseTimestamp)
        }
    }

    private fun isValidTransaction(title: String, text: String): Boolean {
        val combined = "$title $text".lowercase()
        val hasMoney = combined.contains("₹") || combined.contains("rs") || combined.contains("inr")
        // Added 'payment' and 'successful' to catch all GPay formats
        val hasAction = combined.contains("paid") || 
                        combined.contains("sent") || 
                        combined.contains("debited") || 
                        combined.contains("payment") || 
                        combined.contains("successful")
        return hasMoney && hasAction
    }

    private fun cacheData(sender: String, body: String, timestamp: Long) {
        val prefs = getSharedPreferences("CipherSmsCache", Context.MODE_PRIVATE)
        val existingCache = prefs.getString("pending_sms", "[]")

        try {
            val jsonArray = JSONArray(existingCache)
            val newMsg = JSONObject()

            newMsg.put("sender", sender)
            newMsg.put("body", body)
            newMsg.put("timestamp", timestamp)

            jsonArray.put(newMsg)
            prefs.edit().putString("pending_sms", jsonArray.toString()).apply()
            
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}