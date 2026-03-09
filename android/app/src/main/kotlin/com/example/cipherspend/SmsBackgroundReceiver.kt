package com.example.cipherspend

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.SmsMessage
import org.json.JSONArray
import org.json.JSONObject

class SmsBackgroundReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "android.provider.Telephony.SMS_RECEIVED") {
            val bundle = intent.extras
            val pdus = bundle?.get("pdus") as? Array<*>

            pdus?.forEach { pdu ->
                val format = bundle.getString("format")
                val msg = SmsMessage.createFromPdu(pdu as ByteArray, format)

                val sender = msg.originatingAddress ?: "Unknown"
                val body = msg.messageBody ?: ""
                val timestamp = msg.timestampMillis

                // Instantly cache the raw message natively before the user can swipe or delete it
                cacheMessageNatively(context, sender, body, timestamp)
            }
        }
    }

    private fun cacheMessageNatively(context: Context, sender: String, body: String, timestamp: Long) {
        val prefs = context.getSharedPreferences("CipherSmsCache", Context.MODE_PRIVATE)
        // Retrieve the existing array of missed messages, or start a new empty array
        val existingCache = prefs.getString("pending_sms", "[]")
        
        try {
            val jsonArray = JSONArray(existingCache)
            val newMsg = JSONObject()
            
            newMsg.put("sender", sender)
            newMsg.put("body", body)
            newMsg.put("timestamp", timestamp)
            
            jsonArray.put(newMsg)

            // Save the updated list back to native storage instantly
            prefs.edit().putString("pending_sms", jsonArray.toString()).apply()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}