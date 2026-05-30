package com.audionotes.audio_notes

import com.audionotes.audio_notes.widgets.WidgetRefreshPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register plugins
        flutterEngine.plugins.add(RecorderPlugin())
        flutterEngine.plugins.add(RecognitionPlugin())
        flutterEngine.plugins.add(StorageUtils(this))
        flutterEngine.plugins.add(WidgetRefreshPlugin())
    }
}
