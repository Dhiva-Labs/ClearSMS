package com.dhivalabs.clear_sms

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Required component for the default-SMS-app role. Full MMS download is not
 * implemented yet; the receiver must exist for the role to be grantable.
 */
class MmsDeliverReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // MMS handling not yet implemented.
    }
}
