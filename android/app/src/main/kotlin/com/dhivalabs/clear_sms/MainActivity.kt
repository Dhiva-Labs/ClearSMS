package com.dhivalabs.clear_sms

import android.app.Activity
import android.app.role.RoleManager
import android.content.Intent
import android.os.Build
import android.provider.Telephony
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "clear_sms/core"
        private const val REQ_DEFAULT_SMS = 4201

        // Set while the activity is alive so SmsDeliverReceiver can push
        // live updates into Flutter.
        @Volatile
        private var instance: MainActivity? = null

        fun notifyNewSms(threadId: Long) {
            val activity = instance ?: return
            activity.runOnUiThread {
                activity.channel?.invokeMethod("onSmsReceived", mapOf("threadId" to threadId))
            }
        }
    }

    private var channel: MethodChannel? = null
    private val scope = CoroutineScope(Dispatchers.Main)
    private var pendingThreadId: Long = -1

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        instance = this
        NotificationHelper.ensureChannels(this)
        pendingThreadId = intent?.getLongExtra("thread_id", -1) ?: -1

        scope.launch {
            val deleted = withContext(Dispatchers.IO) {
                PromoCleaner.cleanup(this@MainActivity)
            }
            if (deleted > 0) channel?.invokeMethod("onSmsReceived", null)
        }

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isDefaultSmsApp" -> result.success(isDefaultSmsApp())
                "requestDefaultSmsApp" -> {
                    requestDefaultSmsApp()
                    result.success(null)
                }
                "requestPermissions" -> {
                    requestRuntimePermissions()
                    result.success(null)
                }
                "getConversations" -> scope.launch {
                    val data = withContext(Dispatchers.IO) {
                        try {
                            SmsRepository.getConversations(this@MainActivity)
                        } catch (e: Exception) {
                            null
                        }
                    }
                    if (data != null) result.success(data)
                    else result.error("QUERY_FAILED", "Could not read SMS store", null)
                }
                "getMessages" -> {
                    val threadId = (call.argument<Number>("threadId"))?.toLong()
                    if (threadId == null) {
                        result.error("BAD_ARGS", "threadId required", null)
                        return@setMethodCallHandler
                    }
                    scope.launch {
                        val data = withContext(Dispatchers.IO) {
                            try {
                                SmsRepository.getMessages(this@MainActivity, threadId)
                            } catch (e: Exception) {
                                null
                            }
                        }
                        if (data != null) result.success(data)
                        else result.error("QUERY_FAILED", "Could not read messages", null)
                    }
                }
                "sendSms" -> {
                    val address = call.argument<String>("address")
                    val body = call.argument<String>("body")
                    if (address.isNullOrBlank() || body.isNullOrBlank()) {
                        result.error("BAD_ARGS", "address and body required", null)
                        return@setMethodCallHandler
                    }
                    scope.launch {
                        val threadId = withContext(Dispatchers.IO) {
                            try {
                                SmsRepository.sendSms(this@MainActivity, address, body)
                            } catch (e: Exception) {
                                -1L
                            }
                        }
                        if (threadId >= 0) result.success(threadId)
                        else result.error("SEND_FAILED", "Could not send SMS", null)
                    }
                }
                "markThreadRead" -> {
                    val threadId = (call.argument<Number>("threadId"))?.toLong()
                    if (threadId != null) {
                        scope.launch(Dispatchers.IO) {
                            SmsRepository.markThreadRead(this@MainActivity, threadId)
                        }
                    }
                    result.success(null)
                }
                "deleteThread" -> {
                    val threadId = (call.argument<Number>("threadId"))?.toLong()
                    if (threadId == null) {
                        result.error("BAD_ARGS", "threadId required", null)
                        return@setMethodCallHandler
                    }
                    scope.launch {
                        val ok = withContext(Dispatchers.IO) {
                            SmsRepository.deleteThread(this@MainActivity, threadId)
                        }
                        result.success(ok)
                    }
                }
                "consumeLaunchThreadId" -> {
                    val id = pendingThreadId
                    pendingThreadId = -1
                    result.success(if (id >= 0) id else null)
                }
                "getSettings" -> result.success(AppSettings.asMap(this))
                "openDefaultAppsSettings" -> {
                    startActivity(
                        Intent(android.provider.Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS)
                    )
                    result.success(null)
                }
                "updateSettings" -> {
                    @Suppress("UNCHECKED_CAST")
                    val values = call.arguments as? Map<String, Any?> ?: emptyMap()
                    AppSettings.update(this, values)
                    scope.launch {
                        // Apply a new retention/toggle immediately.
                        val deleted = withContext(Dispatchers.IO) {
                            PromoCleaner.cleanup(this@MainActivity, force = true)
                        }
                        result.success(deleted)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val threadId = intent.getLongExtra("thread_id", -1)
        if (threadId >= 0) {
            channel?.invokeMethod("onOpenThread", mapOf("threadId" to threadId))
        }
    }

    override fun onDestroy() {
        if (instance === this) instance = null
        super.onDestroy()
    }

    private fun isDefaultSmsApp(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(RoleManager::class.java)
            return roleManager.isRoleAvailable(RoleManager.ROLE_SMS) &&
                roleManager.isRoleHeld(RoleManager.ROLE_SMS)
        }
        return Telephony.Sms.getDefaultSmsPackage(this) == packageName
    }

    private fun requestDefaultSmsApp() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(RoleManager::class.java)
            if (roleManager.isRoleAvailable(RoleManager.ROLE_SMS) &&
                !roleManager.isRoleHeld(RoleManager.ROLE_SMS)
            ) {
                startActivityForResult(
                    roleManager.createRequestRoleIntent(RoleManager.ROLE_SMS),
                    REQ_DEFAULT_SMS
                )
            }
        } else {
            @Suppress("DEPRECATION")
            val intent = Intent(Telephony.Sms.Intents.ACTION_CHANGE_DEFAULT).apply {
                putExtra(Telephony.Sms.Intents.EXTRA_PACKAGE_NAME, packageName)
            }
            startActivityForResult(intent, REQ_DEFAULT_SMS)
        }
    }

    private fun requestRuntimePermissions() {
        val permissions = mutableListOf(
            android.Manifest.permission.READ_SMS,
            android.Manifest.permission.SEND_SMS,
            android.Manifest.permission.RECEIVE_SMS,
            android.Manifest.permission.READ_CONTACTS,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions.add(android.Manifest.permission.POST_NOTIFICATIONS)
        }
        val missing = permissions.filter {
            checkSelfPermission(it) != android.content.pm.PackageManager.PERMISSION_GRANTED
        }
        if (missing.isNotEmpty()) {
            requestPermissions(missing.toTypedArray(), 4202)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_DEFAULT_SMS) {
            channel?.invokeMethod(
                "onDefaultSmsAppChanged",
                mapOf("granted" to (resultCode == Activity.RESULT_OK || isDefaultSmsApp()))
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 4202) {
            channel?.invokeMethod("onPermissionsChanged", null)
        }
    }
}
