package com.dhivalabs.clear_sms

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.provider.ContactsContract
import android.provider.Telephony
import android.telephony.SmsManager

object SmsRepository {

    private val contactCache = HashMap<String, String?>()

    fun lookupContactName(context: Context, address: String): String? {
        contactCache[address]?.let { return it }
        if (contactCache.containsKey(address)) return null
        var name: String? = null
        try {
            val uri = Uri.withAppendedPath(
                ContactsContract.PhoneLookup.CONTENT_FILTER_URI, Uri.encode(address)
            )
            context.contentResolver.query(
                uri, arrayOf(ContactsContract.PhoneLookup.DISPLAY_NAME), null, null, null
            )?.use { c -> if (c.moveToFirst()) name = c.getString(0) }
        } catch (_: Exception) {
            // No contacts permission or lookup failure: fall back to raw address.
        }
        contactCache[address] = name
        return name
    }

    /**
     * One entry per thread: latest message, unread count, contact name and
     * category (classified from the latest message).
     */
    fun getConversations(context: Context): List<Map<String, Any?>> {
        data class Thread(
            var address: String,
            var body: String,
            var date: Long,
            var unread: Int,
            var latestIsIncoming: Boolean,
        )

        val threads = LinkedHashMap<Long, Thread>()
        context.contentResolver.query(
            Telephony.Sms.CONTENT_URI,
            arrayOf(
                Telephony.Sms.THREAD_ID, Telephony.Sms.ADDRESS, Telephony.Sms.BODY,
                Telephony.Sms.DATE, Telephony.Sms.READ, Telephony.Sms.TYPE
            ),
            null, null,
            "${Telephony.Sms.DATE} DESC"
        )?.use { c ->
            val iThread = c.getColumnIndexOrThrow(Telephony.Sms.THREAD_ID)
            val iAddr = c.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
            val iBody = c.getColumnIndexOrThrow(Telephony.Sms.BODY)
            val iDate = c.getColumnIndexOrThrow(Telephony.Sms.DATE)
            val iRead = c.getColumnIndexOrThrow(Telephony.Sms.READ)
            val iType = c.getColumnIndexOrThrow(Telephony.Sms.TYPE)
            while (c.moveToNext()) {
                val threadId = c.getLong(iThread)
                val address = c.getString(iAddr) ?: continue
                val isIncoming = c.getInt(iType) == Telephony.Sms.MESSAGE_TYPE_INBOX
                val isUnread = isIncoming && c.getInt(iRead) == 0
                val existing = threads[threadId]
                if (existing == null) {
                    // Rows come newest-first, so the first row per thread is its latest.
                    threads[threadId] = Thread(
                        address = address,
                        body = c.getString(iBody) ?: "",
                        date = c.getLong(iDate),
                        unread = if (isUnread) 1 else 0,
                        latestIsIncoming = isIncoming,
                    )
                } else if (isUnread) {
                    existing.unread++
                }
            }
        }

        return threads.map { (threadId, t) ->
            val name = lookupContactName(context, t.address)
            // A saved contact is always personal, whatever the content looks like.
            val category = if (name != null) {
                SmsClassifier.CATEGORY_PERSONAL
            } else {
                SmsClassifier.classify(t.address, t.body)
            }
            mapOf(
                "threadId" to threadId,
                "address" to t.address,
                "displayName" to (name ?: t.address),
                "isContact" to (name != null),
                "snippet" to t.body,
                "date" to t.date,
                "unread" to t.unread,
                "category" to category,
            )
        }
    }

    fun getMessages(context: Context, threadId: Long): List<Map<String, Any?>> {
        val messages = ArrayList<Map<String, Any?>>()
        context.contentResolver.query(
            Telephony.Sms.CONTENT_URI,
            arrayOf(
                Telephony.Sms._ID, Telephony.Sms.ADDRESS, Telephony.Sms.BODY,
                Telephony.Sms.DATE, Telephony.Sms.TYPE, Telephony.Sms.STATUS
            ),
            "${Telephony.Sms.THREAD_ID} = ?",
            arrayOf(threadId.toString()),
            "${Telephony.Sms.DATE} ASC"
        )?.use { c ->
            val iId = c.getColumnIndexOrThrow(Telephony.Sms._ID)
            val iAddr = c.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
            val iBody = c.getColumnIndexOrThrow(Telephony.Sms.BODY)
            val iDate = c.getColumnIndexOrThrow(Telephony.Sms.DATE)
            val iType = c.getColumnIndexOrThrow(Telephony.Sms.TYPE)
            while (c.moveToNext()) {
                val body = c.getString(iBody) ?: ""
                messages.add(
                    mapOf(
                        "id" to c.getLong(iId),
                        "address" to (c.getString(iAddr) ?: ""),
                        "body" to body,
                        "date" to c.getLong(iDate),
                        "isIncoming" to (c.getInt(iType) == Telephony.Sms.MESSAGE_TYPE_INBOX),
                        "otp" to SmsClassifier.extractOtp(body),
                    )
                )
            }
        }
        return messages
    }

    fun sendSms(context: Context, address: String, body: String): Long {
        val smsManager = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            context.getSystemService(SmsManager::class.java)
        } else {
            @Suppress("DEPRECATION")
            SmsManager.getDefault()
        }
        val parts = smsManager.divideMessage(body)
        if (parts.size > 1) {
            smsManager.sendMultipartTextMessage(address, null, parts, null, null)
        } else {
            smsManager.sendTextMessage(address, null, body, null, null)
        }
        // As (or aspiring to be) the default app, persist to the Sent box so
        // the thread reflects what was sent.
        val values = ContentValues().apply {
            put(Telephony.Sms.ADDRESS, address)
            put(Telephony.Sms.BODY, body)
            put(Telephony.Sms.DATE, System.currentTimeMillis())
            put(Telephony.Sms.READ, 1)
            put(Telephony.Sms.TYPE, Telephony.Sms.MESSAGE_TYPE_SENT)
        }
        val uri = context.contentResolver.insert(Telephony.Sms.Sent.CONTENT_URI, values)
        var threadId = 0L
        if (uri != null) {
            context.contentResolver.query(
                uri, arrayOf(Telephony.Sms.THREAD_ID), null, null, null
            )?.use { c -> if (c.moveToFirst()) threadId = c.getLong(0) }
        }
        return threadId
    }

    fun markThreadRead(context: Context, threadId: Long) {
        val values = ContentValues().apply {
            put(Telephony.Sms.READ, 1)
            put(Telephony.Sms.SEEN, 1)
        }
        try {
            context.contentResolver.update(
                Telephony.Sms.CONTENT_URI, values,
                "${Telephony.Sms.THREAD_ID} = ? AND ${Telephony.Sms.READ} = 0",
                arrayOf(threadId.toString())
            )
        } catch (_: Exception) {
            // Only the default SMS app may write; ignore otherwise.
        }
    }

    fun deleteThread(context: Context, threadId: Long): Boolean {
        return try {
            context.contentResolver.delete(
                Telephony.Sms.CONTENT_URI,
                "${Telephony.Sms.THREAD_ID} = ?",
                arrayOf(threadId.toString())
            ) > 0
        } catch (_: Exception) {
            false
        }
    }
}
