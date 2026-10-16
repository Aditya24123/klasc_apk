package com.klasc.klasc

import io.flutter.embedding.android.FlutterActivity
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var ready = false
    private val pending = java.util.ArrayDeque<Map<String, String>>()

    private fun shared(intent: Intent?): Map<String, String>? {
        if (intent?.action != Intent.ACTION_SEND || intent.type != "text/plain") return null
        val text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString() ?: return null
        if (text.isBlank()) return null
        return mapOf("text" to text,
            "subject" to (intent.getCharSequenceExtra(Intent.EXTRA_SUBJECT)?.toString() ?: "").take(120))
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ready = false
        shared(intent)?.let { pending.addLast(it) }
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "klasc/share")
        channel!!.setMethodCallHandler { call, result ->
            if (call.method == "takeShares") {
                ready = true
                result.success(pending.toList())
                pending.clear()
            } else result.notImplemented()
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val data = shared(intent) ?: return
        if (ready) channel?.invokeMethod("received", data) else pending.addLast(data)
    }
}
