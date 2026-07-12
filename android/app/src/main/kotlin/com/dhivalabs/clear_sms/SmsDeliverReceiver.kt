package com.dhivalabs.clear_sms

import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/**
 * Fires only while ClearSMS is the default SMS app. As default app we are
 * responsible for persisting the incoming message to the Telephony provider.
 */
class SmsDeliverReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_DELIVER_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        if (messages.isEmpty()) return

        val sender = messages[0].displayOriginatingAddress ?: return
        val body = messages.joinToString(separator = "") { it.displayMessageBody ?: "" }
        val timestamp = messages[0].timestampMillis

        val values = ContentValues().apply {
            put(Telephony.Sms.ADDRESS, sender)
            put(Telephony.Sms.BODY, body)
            put(Telephony.Sms.DATE, timestamp)
            put(Telephony.Sms.READ, 0)
            put(Telephony.Sms.SEEN, 0)
            put(Telephony.Sms.TYPE, Telephony.Sms.MESSAGE_TYPE_INBOX)
        }
        val uri = context.contentResolver.insert(Telephony.Sms.Inbox.CONTENT_URI, values)

        var threadId = 0L
        if (uri != null) {
            context.contentResolver.query(
                uri, arrayOf(Telephony.Sms.THREAD_ID), null, null, null
            )?.use { c -> if (c.moveToFirst()) threadId = c.getLong(0) }
        }

        val category = SmsClassifier.classify(sender, body)
        val displayName = SmsRepository.lookupContactName(context, sender) ?: sender

        NotificationHelper.notifyIncoming(
            context, sender, displayName, body, category, threadId
        )

        // Nudge the UI if it's in the foreground.
        MainActivity.notifyNewSms(threadId)

        // Piggyback promo cleanup on message arrival (throttled internally),
        // so retention works even if the app is never opened.
        val pending = goAsync()
        Thread {
            try {
                PromoCleaner.cleanup(context.applicationContext)
            } catch (_: Exception) {
            } finally {
                pending.finish()
            }
        }.start()
    }
}
