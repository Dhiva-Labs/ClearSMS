package com.dhivalabs.clear_sms

import android.content.Context
import android.content.SharedPreferences

/**
 * Shared app settings. Lives in Android SharedPreferences (not Flutter-side)
 * so the SMS receiver and cleanup can read them with no Flutter engine running.
 */
object AppSettings {
    private const val PREFS = "clear_sms_settings"

    const val KEY_AUTO_DELETE_PROMOS = "auto_delete_promos"
    const val KEY_PROMO_RETENTION_DAYS = "promo_retention_days"
    const val KEY_FOCUS_CATEGORIES = "focus_categories"
    private const val KEY_LAST_CLEANUP = "last_promo_cleanup"

    val DEFAULT_FOCUS = setOf(
        SmsClassifier.CATEGORY_PERSONAL,
        SmsClassifier.CATEGORY_TRANSACTION,
        SmsClassifier.CATEGORY_OTP,
    )

    fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun autoDeletePromos(context: Context): Boolean =
        prefs(context).getBoolean(KEY_AUTO_DELETE_PROMOS, true)

    fun promoRetentionDays(context: Context): Int =
        prefs(context).getInt(KEY_PROMO_RETENTION_DAYS, 14)

    fun focusCategories(context: Context): Set<String> =
        prefs(context).getStringSet(KEY_FOCUS_CATEGORIES, DEFAULT_FOCUS) ?: DEFAULT_FOCUS

    fun lastCleanup(context: Context): Long =
        prefs(context).getLong(KEY_LAST_CLEANUP, 0L)

    fun setLastCleanup(context: Context, time: Long) =
        prefs(context).edit().putLong(KEY_LAST_CLEANUP, time).apply()

    fun asMap(context: Context): Map<String, Any> = mapOf(
        "autoDeletePromos" to autoDeletePromos(context),
        "promoRetentionDays" to promoRetentionDays(context),
        "focusCategories" to focusCategories(context).toList(),
    )

    fun update(context: Context, values: Map<String, Any?>) {
        val editor = prefs(context).edit()
        (values["autoDeletePromos"] as? Boolean)?.let {
            editor.putBoolean(KEY_AUTO_DELETE_PROMOS, it)
        }
        (values["promoRetentionDays"] as? Number)?.let {
            editor.putInt(KEY_PROMO_RETENTION_DAYS, it.toInt())
        }
        @Suppress("UNCHECKED_CAST")
        (values["focusCategories"] as? List<String>)?.let {
            editor.putStringSet(KEY_FOCUS_CATEGORIES, it.toSet())
        }
        editor.apply()
    }
}
