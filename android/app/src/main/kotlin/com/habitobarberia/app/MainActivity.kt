package com.habitobarberia.app

import android.content.Context
import android.graphics.Color
import android.os.Bundle
import android.util.Log
import androidx.activity.SystemBarStyle
import androidx.activity.enableEdgeToEdge
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import com.tiktok.TikTokBusinessSdk
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val INSTALL_REFERRER_CHANNEL = "com.habitobarberia.app/install_referrer"
        private const val TIKTOK_CHANNEL = "com.habitobarberia.app/tiktok_events"
        private const val LOG_TAG = "HabitoTikTok"
    }

    private var tikTokSdkConfigured = false
    private var tikTokSdkInitialized = false

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.auto(Color.TRANSPARENT, Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.auto(Color.TRANSPARENT, Color.TRANSPARENT)
        )
        super.onCreate(savedInstanceState)
        initializeTikTokSdk()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            INSTALL_REFERRER_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstallReferrer" -> readInstallReferrer(this, result)
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            TIKTOK_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "trackEvent" -> {
                    val eventName = call.argument<String>("name")?.trim().orEmpty()
                    if (eventName.isEmpty()) {
                        result.error("INVALID_EVENT", "TikTok event name is required", null)
                        return@setMethodCallHandler
                    }

                    val parameters = call.argument<Map<String, Any?>>("parameters").orEmpty()
                    trackTikTokEvent(eventName, parameters, result)
                }
                "identify" -> {
                    identifyTikTokUser(
                        externalId = call.argument<String>("externalId").orEmpty(),
                        externalUserName = call.argument<String>("externalUserName").orEmpty(),
                        phoneNumber = call.argument<String>("phoneNumber").orEmpty(),
                        email = call.argument<String>("email").orEmpty(),
                        result = result
                    )
                }
                "logout" -> {
                    runCatching { TikTokBusinessSdk.logout() }
                        .onSuccess { result.success(true) }
                        .onFailure { result.error("TIKTOK_LOGOUT_FAILED", it.message, null) }
                }
                "flush" -> {
                    runCatching { TikTokBusinessSdk.flush() }
                        .onSuccess { result.success(true) }
                        .onFailure { result.error("TIKTOK_FLUSH_FAILED", it.message, null) }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun initializeTikTokSdk() {
        if (tikTokSdkConfigured) return
        tikTokSdkConfigured = true

        val eventsEnabled = truthy(getString(R.string.tiktok_events_enabled), defaultValue = true)
        if (!eventsEnabled) return

        val tiktokAppId = getString(R.string.tiktok_app_id).trim()
        val packageAppId = getString(R.string.tiktok_package_app_id).trim()
        if (tiktokAppId.isEmpty() || packageAppId.isEmpty()) {
            Log.w(LOG_TAG, "TikTok SDK disabled: missing app id configuration.")
            return
        }

        val config = TikTokBusinessSdk.TTConfig(applicationContext, packageAppId)
            .setTTAppId(tiktokAppId)
            .setAppId(packageAppId)

        if (!truthy(getString(R.string.tiktok_ad_tracking_enabled), defaultValue = true)) {
            config.disableAdvertiserIDCollection()
        }

        TikTokBusinessSdk.initializeSdk(
            config,
            object : TikTokBusinessSdk.TTInitCallback {
                override fun success() {
                    tikTokSdkInitialized = true
                    updateTikTokAccessToken()
                    TikTokBusinessSdk.startTrack()
                }

                override fun fail(code: Int, message: String) {
                    Log.w(LOG_TAG, "TikTok SDK init failed ($code): $message")
                }
            }
        )
    }

    private fun updateTikTokAccessToken() {
        val accessToken = getString(R.string.tiktok_access_token).trim()
        if (accessToken.isEmpty()) return

        runCatching { TikTokBusinessSdk.updateAccessToken(accessToken) }
            .onFailure { Log.w(LOG_TAG, "TikTok access token update failed: ${it.message}") }
    }

    private fun trackTikTokEvent(
        name: String,
        parameters: Map<String, Any?>,
        result: MethodChannel.Result
    ) {
        initializeTikTokSdk()

        if (!tikTokSdkInitialized) {
            Log.w(LOG_TAG, "TikTok event queued by SDK init state: $name")
        }

        runCatching {
            TikTokBusinessSdk.trackEvent(name, mapToJson(parameters))
        }.onSuccess {
            result.success(true)
        }.onFailure {
            result.error("TIKTOK_EVENT_FAILED", it.message, null)
        }
    }

    private fun identifyTikTokUser(
        externalId: String,
        externalUserName: String,
        phoneNumber: String,
        email: String,
        result: MethodChannel.Result
    ) {
        initializeTikTokSdk()

        if (externalId.isBlank()) {
            runCatching { TikTokBusinessSdk.logout() }
                .onSuccess { result.success(true) }
                .onFailure { result.error("TIKTOK_LOGOUT_FAILED", it.message, null) }
            return
        }

        runCatching {
            TikTokBusinessSdk.identify(
                externalId,
                externalUserName,
                phoneNumber,
                email
            )
        }.onSuccess {
            result.success(true)
        }.onFailure {
            result.error("TIKTOK_IDENTIFY_FAILED", it.message, null)
        }
    }

    private fun mapToJson(map: Map<*, *>): JSONObject {
        val json = JSONObject()
        map.forEach { entry ->
            val key = entry.key?.toString()?.trim().orEmpty()
            if (key.isNotEmpty()) {
                json.put(key, toJsonValue(entry.value))
            }
        }
        return json
    }

    private fun listToJson(list: List<*>): JSONArray {
        val json = JSONArray()
        list.forEach { value -> json.put(toJsonValue(value)) }
        return json
    }

    private fun toJsonValue(value: Any?): Any {
        return when (value) {
            null -> JSONObject.NULL
            is Map<*, *> -> mapToJson(value)
            is List<*> -> listToJson(value)
            is Array<*> -> listToJson(value.toList())
            is Number, is Boolean, is String -> value
            else -> value.toString()
        }
    }

    private fun truthy(value: String?, defaultValue: Boolean = false): Boolean {
        val normalized = value?.trim()?.lowercase()
        if (normalized.isNullOrEmpty()) return defaultValue
        return normalized in setOf("1", "true", "yes", "y", "on", "si")
    }

    private fun readInstallReferrer(context: Context, result: MethodChannel.Result) {
        val client = InstallReferrerClient.newBuilder(context).build()
        var completed = false

        fun finish(payload: Map<String, Any?>) {
            if (completed) return
            completed = true
            try {
                client.endConnection()
            } catch (_: Exception) {
                // The connection can already be closed on some Play Store responses.
            }
            result.success(payload)
        }

        fun finishError(code: String, message: String?) {
            if (completed) return
            completed = true
            try {
                client.endConnection()
            } catch (_: Exception) {
                // The connection can already be closed on some Play Store responses.
            }
            result.error(code, message ?: "Install referrer unavailable", null)
        }

        try {
            client.startConnection(object : InstallReferrerStateListener {
                override fun onInstallReferrerSetupFinished(responseCode: Int) {
                    when (responseCode) {
                        InstallReferrerClient.InstallReferrerResponse.OK -> {
                            try {
                                val response = client.installReferrer
                                finish(
                                    mapOf(
                                        "responseCode" to responseCode,
                                        "installReferrer" to response.installReferrer,
                                        "referrerClickTimestampSeconds" to response.referrerClickTimestampSeconds,
                                        "installBeginTimestampSeconds" to response.installBeginTimestampSeconds,
                                        "googlePlayInstantParam" to response.googlePlayInstantParam
                                    )
                                )
                            } catch (error: Exception) {
                                finishError("REFERRER_READ_FAILED", error.message)
                            }
                        }
                        else -> finish(
                            mapOf(
                                "responseCode" to responseCode,
                                "installReferrer" to ""
                            )
                        )
                    }
                }

                override fun onInstallReferrerServiceDisconnected() {
                    // Google Play may reconnect on a later attempt; Dart controls retry policy.
                }
            })
        } catch (error: Exception) {
            finishError("REFERRER_CONNECTION_FAILED", error.message)
        }
    }
}
