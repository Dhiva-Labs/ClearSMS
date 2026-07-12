package com.dhivalabs.clear_sms

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.Toast

class NotificationActionReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_COPY_OTP = "com.dhivalabs.clear_sms.COPY_OTP"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_COPY_OTP -> {
                val otp = intent.getStringExtra("otp") ?: return
                val clipboard =
                    context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                clipboard.setPrimaryClip(
                    ClipData.newPlainText("OTP", otp).apply {
                        description.extras = android.os.PersistableBundle().apply {
                            putBoolean("android.content.extra.IS_SENSITIVE", true)
                        }
                    }
                )
                // Android 13+ shows its own clipboard confirmation overlay.
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                    Toast.makeText(context, "Code copied", Toast.LENGTH_SHORT).show()
                }
                val notificationId = intent.getIntExtra("notification_id", -1)
                if (notificationId != -1) {
                    val nm = context.getSystemService(Context.NOTIFICATION_SERVICE)
                        as NotificationManager
                    nm.cancel(notificationId)
                }
            }
        }
    }
}
