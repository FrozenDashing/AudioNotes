package com.audionotes.audio_notes

import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import com.audionotes.audio_notes.widgets.WidgetRefreshPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var launchChannel: MethodChannel? = null
    private var pendingWidgetRecordLaunch = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        flutterEngine.plugins.add(RecorderPlugin())
        flutterEngine.plugins.add(RecognitionPlugin())
        flutterEngine.plugins.add(StorageUtils(this))
        flutterEngine.plugins.add(WidgetRefreshPlugin())

        launchChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.audionotes/launch")
        if (pendingWidgetRecordLaunch || hasWidgetRecordLaunchFlag()) {
            emitWidgetRecordLaunch()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        consumeLaunchIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        consumeLaunchIntent(intent)
    }

    private fun consumeLaunchIntent(intent: Intent?) {
        if (intent?.action != ACTION_WIDGET_RECORD) {
            return
        }

        pendingWidgetRecordLaunch = true
        storeWidgetRecordLaunchFlag(true)
        emitWidgetRecordLaunch()
    }

    private fun emitWidgetRecordLaunch() {
        val channel = launchChannel
        if (channel == null) {
            return
        }

        pendingWidgetRecordLaunch = false
        storeWidgetRecordLaunchFlag(true)
        Handler(Looper.getMainLooper()).post {
            channel.invokeMethod("startRecordingFromWidget", null)
        }
    }

    private fun hasWidgetRecordLaunchFlag(): Boolean {
        return getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            .getBoolean(PREF_WIDGET_RECORD_LAUNCH, false)
    }


    private fun storeWidgetRecordLaunchFlag(enabled: Boolean) {
        getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            .edit()
            .putBoolean(PREF_WIDGET_RECORD_LAUNCH, enabled)
            .apply()
    }

    companion object {
        private const val ACTION_WIDGET_RECORD = "com.audionotes.audio_notes.RECORD_AUDIO"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val PREF_WIDGET_RECORD_LAUNCH = "flutter.widget.launch.recording"
    }
}