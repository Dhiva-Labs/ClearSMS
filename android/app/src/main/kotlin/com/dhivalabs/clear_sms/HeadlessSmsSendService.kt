package com.dhivalabs.clear_sms

import android.app.Service
import android.content.Intent
import android.os.IBinder

/**
 * Required component for the default-SMS-app role: handles "respond via
 * message" quick replies from the in-call screen.
 */
class HeadlessSmsSendService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val recipient = intent?.data?.schemeSpecificPart
        val body = intent?.getStringExtra(Intent.EXTRA_TEXT)
        if (!recipient.isNullOrBlank() && !body.isNullOrBlank()) {
            SmsRepository.sendSms(this, recipient, body)
        }
        stopSelf(startId)
        return START_NOT_STICKY
    }
}
