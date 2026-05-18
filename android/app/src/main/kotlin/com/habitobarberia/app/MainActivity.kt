package com.habitobarberia.app

import android.content.Context
import android.graphics.Color
import android.os.Bundle
import androidx.activity.SystemBarStyle
import androidx.activity.enableEdgeToEdge
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val INSTALL_REFERRER_CHANNEL = "com.habitobarberia.app/install_referrer"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.auto(Color.TRANSPARENT, Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.auto(Color.TRANSPARENT, Color.TRANSPARENT)
        )
        super.onCreate(savedInstanceState)
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
