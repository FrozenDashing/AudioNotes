package com.audionotes.audio_notes

import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.vosk.LibVosk
import org.vosk.LogLevel
import org.vosk.Model
import org.vosk.Recognizer
import java.io.File
import java.io.FileInputStream
import java.io.IOException
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * Recognition Plugin for Android
 * Handles Vosk speech recognition only (no recording)
 */
class RecognitionPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    
    // Vosk model (singleton, loaded once)
    private var model: Model? = null
    private var isModelLoaded = false
    
    // Thread pool for recognition tasks
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    
    companion object {
        private const val TAG = "RecognitionPlugin"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.audionotes/recognition")
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
        // Do not initialize Vosk at startup; defer to explicit reloadModel or user's action.
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "recognize" -> handleRecognize(call, result)
            "isModelReady" -> handleIsModelReady(result)
            "reloadModel" -> handleReloadModel(result)
            else -> result.notImplemented()
        }
    }

    private fun handleRecognize(call: MethodCall, result: Result) {
        val wavPath = call.argument<String>("wav_path")
        
        if (wavPath == null || wavPath.isEmpty()) {
            result.error("INVALID_PATH", "WAV file path is required", null)
            return
        }
        
        val file = File(wavPath)
        if (!file.exists()) {
            result.error("FILE_NOT_FOUND", "WAV file not found: $wavPath", null)
            return
        }
        
        Log.d(TAG, "Recognition request for file: $wavPath, size: ${file.length()} bytes")
        
        if (!isModelLoaded || model == null) {
            Log.e(TAG, "Model not loaded! isModelLoaded=$isModelLoaded, model=$model")
            result.error("MODEL_NOT_LOADED", "Vosk model not loaded", null)
            return
        }
        
        // Submit recognition task to thread pool
        executor.submit {
            try {
                Log.d(TAG, "Starting recognition for: $wavPath")
                
                // Read WAV file
                val audioData = readWavFile(file)
                
                if (audioData == null || audioData.isEmpty()) {
                    Log.e(TAG, "Failed to read audio data from file")
                    handler.post {
                        result.error("READ_FAILED", "Failed to read WAV file", null)
                    }
                    return@submit
                }
                
                Log.d(TAG, "Audio data size: ${audioData.size} bytes, duration: ${audioData.size / 32000.0}s")
                
                // Create recognizer
                val recognizer = Recognizer(model!!, 16000f)
                
                // Process audio data
                val hasResult = recognizer.acceptWaveForm(audioData, audioData.size)
                Log.d(TAG, "acceptWaveForm returned: $hasResult")
                
                // Get final result
                val finalResult = recognizer.result
                Log.d(TAG, "Final result: $finalResult")
                
                // Clean up
                recognizer.close()
                
                if (finalResult != null && finalResult.isNotEmpty()) {
                    val json = org.json.JSONObject(finalResult)
                    val text = json.optString("text", "")
                    
                    Log.d(TAG, "Recognition result text: '$text'")
                    
                    handler.post {
                        result.success(text)
                    }
                } else {
                    Log.w(TAG, "Empty recognition result")
                    handler.post {
                        result.success("")
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Recognition failed with exception", e)
                handler.post {
                    result.error("RECOGNITION_FAILED", e.message, null)
                }
            }
        }
    }

    private fun handleIsModelReady(result: Result) {
        result.success(isModelLoaded && model != null)
    }

    private fun handleReloadModel(result: Result) {
        executor.submit {
            try {
                Log.d(TAG, "Reloading Vosk model...")
                
                LibVosk.setLogLevel(LogLevel.WARNINGS)
                
                val modelPath = getModelPath()
                if (modelPath != null) {
                    model?.close()
                    model = Model(modelPath)
                    isModelLoaded = true
                    
                    Log.d(TAG, "Model reloaded successfully from: $modelPath")
                    handler.post {
                        result.success(true)
                    }
                } else {
                    Log.e(TAG, "Model not found during reload!")
                    isModelLoaded = false
                    handler.post {
                        result.error("MODEL_NOT_FOUND", "Model not found", null)
                    }
                }
            } catch (t: Throwable) {
                Log.e(TAG, "Failed to reload model", t)
                isModelLoaded = false
                handler.post {
                    result.error("RELOAD_FAILED", t.message, null)
                }
            }
        }
    }

    private fun initializeVosk() {
        try {
            Log.d(TAG, "Initializing Vosk model...")

            LibVosk.setLogLevel(LogLevel.WARNINGS)

            val modelPath = getModelPath()
            if (modelPath != null) {
                model = Model(modelPath)
                isModelLoaded = true
                Log.d(TAG, "Vosk model loaded successfully from: $modelPath")
            } else {
                Log.e(TAG, "Vosk model not found!")
                isModelLoaded = false
            }
        } catch (t: Throwable) {
            // Catch Throwable to avoid native Errors like UnsatisfiedLinkError crashing the app
            Log.e(TAG, "Failed to load Vosk model (caught Throwable)", t)
            isModelLoaded = false
        }
    }

    private fun getModelPath(): String? {
        // Flutter uses getApplicationDocumentsDirectory() which maps to app_flutter directory
        val documentsDir = File(context.filesDir.parent, "app_flutter")
        
        // Try large Chinese model first
        val largeModelPath = File(documentsDir, "vosk-model-cn-0.22")
        if (largeModelPath.exists()) {
            Log.d(TAG, "Found large model at: ${largeModelPath.absolutePath}")
            return largeModelPath.absolutePath
        }
        
        // Try small Chinese model as fallback
        val smallModelPath = File(documentsDir, "vosk-model-small-cn-0.22")
        if (smallModelPath.exists()) {
            Log.d(TAG, "Found small model at: ${smallModelPath.absolutePath}")
            return smallModelPath.absolutePath
        }
        
        Log.e(TAG, "Model not found in: ${documentsDir.absolutePath}")
        return null
    }

    private fun readWavFile(file: File): ByteArray? {
        try {
            val fis = FileInputStream(file)
            val data = fis.readBytes()
            fis.close()
            
            // Skip WAV header (44 bytes) and return PCM data
            if (data.size > 44) {
                return data.copyOfRange(44, data.size)
            }
            
            return data
        } catch (e: IOException) {
            Log.e(TAG, "Error reading WAV file", e)
            return null
        }
    }

    private val handler = android.os.Handler(android.os.Looper.getMainLooper())

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        
        // Shutdown thread pool
        executor.shutdown()
        
        // Clean up model
        try {
            model?.close()
            model = null
            isModelLoaded = false
        } catch (t: Throwable) {
            Log.e(TAG, "Error closing model", t)
        }
    }
}
