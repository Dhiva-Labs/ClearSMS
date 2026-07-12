package com.dhivalabs.clear_sms

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import androidx.core.app.NotificationCompat

object NotificationHelper {

    const val CHANNEL_PERSONAL = "personal"
    const val CHANNEL_OTP = "otp"
    const val CHANNEL_TRANSACTION = "transaction"
    const val CHANNEL_PROMOTION = "promotion"

    fun ensureChannels(context: Context) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        fun channel(id: String, name: String, importance: Int, desc: String) =
            NotificationChannel(id, name, importance).apply { description = desc }

        nm.createNotificationChannels(
            listOf(
                channel(
                    CHANNEL_PERSONAL, "Personal messages",
                    NotificationManager.IMPORTANCE_HIGH,
                    "Messages from people"
                ),
                channel(
                    CHANNEL_OTP, "OTP & verification codes",
                    NotificationManager.IMPORTANCE_HIGH,
                    "One-time passwords with quick copy"
                ),
                channel(
                    CHANNEL_TRANSACTION, "Transactions & alerts",
                    NotificationManager.IMPORTANCE_DEFAULT,
                    "Bank, bills and service alerts"
                ),
                // Promotions are silent by design: visible in the shade if you
                // pull it down, but they never buzz or ping.
                channel(
                    CHANNEL_PROMOTION, "Promotions (silent)",
                    NotificationManager.IMPORTANCE_LOW,
                    "Offers and marketing, delivered silently"
                ),
            )
        )
    }

    fun notifyIncoming(
        context: Context,
        sender: String,
        displayName: String,
        body: String,
        category: String,
        threadId: Long,
    ) {
        ensureChannels(context)
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val notificationId = (threadId % Int.MAX_VALUE).toInt()

        val openIntent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            putExtra("thread_id", threadId)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val contentPi = PendingIntent.getActivity(
            context, notificationId, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val otp = if (category == SmsClassifier.CATEGORY_OTP) SmsClassifier.extractOtp(body) else null

        val channel = when (category) {
            SmsClassifier.CATEGORY_OTP -> CHANNEL_OTP
            SmsClassifier.CATEGORY_TRANSACTION -> CHANNEL_TRANSACTION
            SmsClassifier.CATEGORY_PROMOTION -> CHANNEL_PROMOTION
            else -> CHANNEL_PERSONAL
        }

        val builder = NotificationCompat.Builder(context, channel)
            .setSmallIcon(android.R.drawable.stat_notify_chat)
            .setContentIntent(contentPi)
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)

        if (otp != null) {
            // OTP: lead with the code so it's readable at a glance,
            // and offer one-tap copy without opening the app.
            val copyIntent = Intent(context, NotificationActionReceiver::class.java).apply {
                action = NotificationActionReceiver.ACTION_COPY_OTP
                putExtra("otp", otp)
                putExtra("notification_id", notificationId)
            }
            val copyPi = PendingIntent.getBroadcast(
                context, notificationId, copyIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            builder
                .setContentTitle("$otp — your code")
                .setContentText("From $displayName")
                .setStyle(NotificationCompat.BigTextStyle().bigText("$body"))
                .setColor(Color.parseColor("#3D5AFE"))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .addAction(0, "Copy code", copyPi)
        } else {
            builder
                .setContentTitle(displayName)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setPriority(
                    when (category) {
                        SmsClassifier.CATEGORY_PROMOTION -> NotificationCompat.PRIORITY_LOW
                        SmsClassifier.CATEGORY_PERSONAL -> NotificationCompat.PRIORITY_HIGH
                        else -> NotificationCompat.PRIORITY_DEFAULT
                    }
                )
            if (category == SmsClassifier.CATEGORY_PROMOTION) {
                builder.setSilent(true)
            }
        }

        nm.notify(notificationId, builder.build())
    }
}
