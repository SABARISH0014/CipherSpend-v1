package com.example.cipherspend

import android.app.Notification
import android.content.Context
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject

class NotificationService : NotificationListenerService() {

    // 1. Solving Source Identification via Package Name
    private val UPI_APPS = mapOf(
        "com.google.android.apps.nbu.paisa.user" to "GPay",
        "com.phonepe.app" to "PhonePe",
        "net.one97.paytm" to "Paytm",
        "in.org.npci.upiapp" to "BHIM",
        "com.freecharge.android" to "Freecharge",
        "com.amazon.mShop.android.shopping" to "AmazonPay"
    )

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val packageName = sbn.packageName
        
        // 2. Filter: Only listen to financial apps
        if (!UPI_APPS.containsKey(packageName)) return

        val extras = sbn.notification.extras
        val title = extras.getString(Notification.EXTRA_TITLE) ?: ""
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""
        
        // 3. Filter: Only capture transaction confirmations (Ignore "Check balance", "Offers")
        // We look for currency symbols or specific keywords
        if (isValidTransaction(title, text)) {
            
            // 4. Solving the "Missing Date" Problem: Use System Timestamp
            val preciseTimestamp = sbn.postTime 
            
            // 5. Normalizing the Source
            val senderName = UPI_APPS[packageName] ?: "UPI"

            // 6. Persistence: Save to the SAME cache SMS uses (Hybrid Redundancy)
            cacheData(senderName, "$title $text", preciseTimestamp)
        }
    }

    private fun isValidTransaction(title: String, text: String): Boolean {
        val combined = "$title $text".lowercase()
        // Must contain money symbol OR "paid/sent" AND digits
        val hasMoney = combined.contains("₹") || combined.contains("rs.") || combined.contains("inr")
        val hasAction = combined.contains("paid") || combined.contains("sent") || combined.contains("debited")
        return hasMoney && hasAction
    }

    private fun cacheData(sender: String, body: String, timestamp: Long) {
        val prefs = getSharedPreferences("CipherSmsCache", Context.MODE_PRIVATE)
        val existingCache = prefs.getString("pending_sms", "[]")

        try {
            val jsonArray = JSONArray(existingCache)
            val newMsg = JSONObject()

            // We format this exactly like an SMS so the Flutter side 
            // doesn't know (or care) where it came from.
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