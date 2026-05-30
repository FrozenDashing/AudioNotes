package com.audionotes.audio_notes

import android.content.Context
import android.os.StatFs
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class StorageUtils(private val context: Context) : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.audionotes/storage")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getFreeBytes" -> {
                val freeBytes = getFreeStorageSpace()
                result.success(freeBytes)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

private fun getFreeStorageSpace(): Long {
    val path = context.filesDir?.absolutePath ?: return 100 * 1024 * 1024L // Fallback 100MB
        
    val statFs = StatFs(path)
        
        return if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.JELLY_BEAN_MR2) {
            statFs.availableBytes
        } else {
            // For older Android versions
            statFs.availableBlocksLong * statFs.blockSizeLong
        }
    }
}