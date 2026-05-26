package com.audionotes.audio_notes

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register RecorderPlugin and RecognitionPlugin
        flutterEngine.plugins.add(RecorderPlugin())
        flutterEngine.plugins.add(RecognitionPlugin())
    }
}
