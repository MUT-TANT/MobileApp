package com.example.stacksave

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var eventSink: EventChannel.EventSink? = null
    private var initialLink: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // EventChannel for streaming deep links to Flutter
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "deep_link_events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    println("✅ EventChannel connected")

                    // Send initial link if we received one before Flutter was ready
                    initialLink?.let {
                        println("📤 Sending initial link to Flutter: $it")
                        eventSink?.success(it)
                        initialLink = null
                    }
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    println("❌ EventChannel disconnected")
                }
            })

        // MethodChannel for getting initial link
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "deep_link_channel")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialLink" -> {
                        result.success(initialLink)
                        initialLink = null
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        val action = intent.action
        val data = intent.data

        if (Intent.ACTION_VIEW == action && data != null) {
            val link = data.toString()
            println("🔗 Deep link received: $link")

            // Set the intent for url_launcher compatibility
            setIntent(intent)

            // Send to Flutter via EventChannel (if connected)
            if (eventSink != null) {
                println("📤 Sending deep link to Flutter: $link")
                eventSink?.success(link)
            } else {
                // Store for later if Flutter isn't ready yet
                println("💾 Storing initial link for later: $link")
                initialLink = link
            }
        }
    }
}
