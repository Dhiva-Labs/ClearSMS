package com.dhivalabs.clear_sms

import android.content.Context
import android.provider.Telephony

/**
 * Deletes promotional messages older than the configured retention period.
 * Only inbox messages classified as promotions are touched; anything from a
 * saved contact is never deleted. Requires the default-SMS-app role to
 * actually delete (the provider silently refuses otherwise).
 */
object PromoCleaner {

    private const val THROTTLE_MS = 6 * 60 * 60 * 1000L // at most every 6 hours

    /** Returns the number of messages deleted. */
    fun cleanup(context: Context, force: Boolean = false): Int {
        if (!AppSettings.autoDeletePromos(context)) return 0
        val now = System.currentTimeMillis()
        if (!force && now - AppSettings.lastCleanup(context) < THROTTLE_MS) return 0
        AppSettings.setLastCleanup(context, now)

        val cutoff = now - AppSettings.promoRetentionDays(context) * 86_400_000L
        val ids = ArrayList<Long>()
        try {
            context.contentResolver.query(
                Telephony.Sms.CONTENT_URI,
                arrayOf(Telephony.Sms._ID, Telephony.Sms.ADDRESS, Telephony.Sms.BODY),
                "${Telephony.Sms.DATE} < ? AND ${Telephony.Sms.TYPE} = ?",
                arrayOf(cutoff.toString(), Telephony.Sms.MESSAGE_TYPE_INBOX.toString()),
                null
            )?.use { c ->
                while (c.moveToNext()) {
                    val address = c.getString(1) ?: continue
                    val body = c.getString(2) ?: ""
                    if (SmsRepository.lookupContactName(context, address) != null) continue
                    if (SmsClassifier.classify(address, body) ==
                        SmsClassifier.CATEGORY_PROMOTION
                    ) {
                        ids.add(c.getLong(0))
                    }
                }
            }
        } catch (_: Exception) {
            return 0
        }
        if (ids.isEmpty()) return 0

        var deleted = 0
        for (chunk in ids.chunked(200)) {
            try {
                deleted += context.contentResolver.delete(
                    Telephony.Sms.CONTENT_URI,
                    "${Telephony.Sms._ID} IN (${chunk.joinToString(",")})",
                    null
                )
            } catch (_: Exception) {
                // Not default SMS app; nothing we can do.
            }
        }
        return deleted
    }
}
