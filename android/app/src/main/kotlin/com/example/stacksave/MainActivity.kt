package com.example.stacksave

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        val action = intent.action
        val data = intent.data

        if (Intent.ACTION_VIEW == action && data != null) {
            // Log deep link for debugging
            println("🔗 Deep link received: $data")

            // Flutter's PluginRegistry will automatically forward this to url_launcher
            // But we ensure the intent is set as the current intent
            setIntent(intent)
        }
    }
}
