package com.audionotes.audio_notes

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.ActivityCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.vosk.LibVosk
import org.vosk.LogLevel
import org.vosk.Model
import org.vosk.Recognizer
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.ByteBuffer
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

/**
 * ASR Plugin for Android
 * Handles audio recording, VAD, and Vosk speech recognition
 */
class AsrPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    
    private var audioRecord: AudioRecord? = null
    private var isRecording = false
    private var recordingThread: Thread? = null
    
    // Vosk recognizer
    private var model: Model? = null
    private var recognizer: Recognizer? = null
    private var isModelLoaded = false
    
    // VAD parameters
    private var shortPauseMs = 600
    private var longPauseMs = 1500
    private var energyThreshold = 0.3
    
    // Audio buffer
    private val sampleRate = 16000
    private val channelConfig = AudioFormat.CHANNEL_IN_MONO
    private val audioFormat = AudioFormat.ENCODING_PCM_16BIT
    private val bufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)
    
    private val handler = Handler(Looper.getMainLooper())
    private var audioBuffer: ByteArrayOutputStream? = null
    
    companion object {
        private const val TAG = "AsrPlugin"
        private const val REQUEST_RECORD_AUDIO_PERMISSION = 200
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.audionotes/asr")
        channel.setMethodCallHandler(this)
        
        // Initialize Vosk in background thread to avoid blocking UI
        Thread {
            initializeVosk()
        }.start()
    }

    private fun initializeVosk() {
        try {
            // Set log level
            LibVosk.setLogLevel(LogLevel.WARNINGS)
            
            // Load model from assets or app files directory
            val modelPath = getModelPath()
            if (modelPath != null) {
                model = Model(modelPath)
                isModelLoaded = true
                Log.d(TAG, "Vosk model loaded successfully from: $modelPath")
            } else {
                Log.e(TAG, "Vosk model not found!")
                isModelLoaded = false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize Vosk", e)
            isModelLoaded = false
        }
    }

    private fun getModelPath(): String? {
        // Flutter uses getApplicationDocumentsDirectory() which maps to context's documents directory
        // On Android, this is typically: /data/data/<package>/app_flutter/
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

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "start" -> handleStart(call, result)
            "stop" -> handleStop(result)
            "cancel" -> handleCancel(result)
            "reRecord" -> handleReRecord(call, result)
            "setVADParams" -> handleSetVADParams(call, result)
            "reloadModel" -> handleReloadModel(result)
            else -> result.notImplemented()
        }
    }

    private fun handleStart(call: MethodCall, result: Result) {
        if (!checkPermission()) {
            result.error("PERMISSION_DENIED", "Microphone permission not granted", null)
            return
        }
        
        // Check if model is loaded
        if (model == null || !isModelLoaded) {
            Log.e(TAG, "Vosk model not loaded. Current state: model=${model != null}, isModelLoaded=$isModelLoaded")
            result.error("MODEL_NOT_LOADED", "Vosk model not loaded. Please download the model first.", null)
            return
        }
        
        try {
            // Extract VAD parameters if provided
            call.argument<Int>("short_pause_ms")?.let { shortPauseMs = it }
            call.argument<Int>("long_pause_ms")?.let { longPauseMs = it }
            call.argument<Double>("energy_threshold")?.let { energyThreshold = it }
            
            // Initialize recognizer for this session
            recognizer = Recognizer(model!!, sampleRate.toFloat())
            
            startRecording()
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error starting recording", e)
            result.error("START_FAILED", e.message, null)
        }
    }

    private fun handleStop(result: Result) {
        stopRecording()
        result.success(true)
    }

    private fun handleCancel(result: Result) {
        cancelRecording()
        result.success(true)
    }

    private fun handleReRecord(call: MethodCall, result: Result) {
        val segmentId = call.argument<String>("segment_id")
        if (segmentId.isNullOrEmpty()) {
            result.error("INVALID_SEGMENT", "Segment ID is required", null)
            return
        }
        
        // TODO: Implement re-record logic
        result.success(true)
    }

    private fun handleSetVADParams(call: MethodCall, result: Result) {
        call.argument<Int>("short_pause_ms")?.let { shortPauseMs = it }
        call.argument<Int>("long_pause_ms")?.let { longPauseMs = it }
        call.argument<Double>("energy_threshold")?.let { energyThreshold = it }
        result.success(true)
    }

    private fun handleReloadModel(result: Result) {
        // Reload model in background thread
        Thread {
            try {
                Log.d(TAG, "Reloading Vosk model...")
                
                // Set log level
                LibVosk.setLogLevel(LogLevel.WARNINGS)
                
                // Load model from files directory
                val modelPath = getModelPath()
                if (modelPath != null) {
                    model = Model(modelPath)
                    isModelLoaded = true
                    Log.d(TAG, "Vosk model reloaded successfully from: $modelPath")
                    handler.post {
                        result.success(true)
                    }
                } else {
                    Log.e(TAG, "Vosk model not found during reload!")
                    isModelLoaded = false
                    handler.post {
                        result.error("MODEL_NOT_FOUND", "Model not found in app files directory", null)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to reload Vosk model", e)
                isModelLoaded = false
                handler.post {
                    result.error("RELOAD_FAILED", e.message, null)
                }
            }
        }.start()
    }

    private fun checkPermission(): Boolean {
        return ActivityCompat.checkSelfPermission(
            context,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun startRecording() {
        if (isRecording) {
            Log.w(TAG, "Already recording")
            return
        }
        
        Log.d(TAG, "Starting recording...")
        
        try {
            // Create AudioRecord with larger buffer for better performance
            val minBufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)
            val bufferSize = maxOf(minBufferSize * 2, 8192)
            
            Log.d(TAG, "Creating AudioRecord: sampleRate=$sampleRate, bufferSize=$bufferSize")
            
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                sampleRate,
                channelConfig,
                audioFormat,
                bufferSize
            )
            
            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                throw IllegalStateException("AudioRecord initialization failed")
            }
            
            Log.d(TAG, "AudioRecord initialized successfully")
            
            // Initialize audio buffer to store raw PCM data
            audioBuffer = ByteArrayOutputStream()
            
            audioRecord?.startRecording()
            isRecording = true
            
            // Start recording thread - just capture audio, no recognition yet
            recordingThread = Thread({
                captureAudioStream()
            }, "AudioCaptureThread")
            recordingThread?.start()
            
            Log.d(TAG, "Recording started, thread state: ${recordingThread?.state}")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start recording", e)
            isRecording = false
            sendErrorEvent("Failed to start recording: ${e.message}")
            throw e
        }
    }

    private fun captureAudioStream() {
        Log.d(TAG, "Audio capture thread started")
        
        val buffer = ShortArray(bufferSize)
        var frameCount = 0
        
        try {
            while (isRecording) {
                val readSize = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                
                if (readSize > 0) {
                    frameCount++
                    
                    // Write raw PCM data to buffer (no recognition yet)
                    for (i in 0 until readSize) {
                        val lowByte = (buffer[i].toInt() and 0xFF).toByte()
                        val highByte = ((buffer[i].toInt() shr 8) and 0xFF).toByte()
                        audioBuffer?.write(lowByte.toInt())
                        audioBuffer?.write(highByte.toInt())
                    }
                    
                    // Log progress every 100 frames
                    if (frameCount % 100 == 0) {
                        Log.d(TAG, "Captured $frameCount frames, buffer size: ${audioBuffer?.size()} bytes")
                    }
                } else {
                    Log.w(TAG, "Read size is 0 or negative: $readSize")
                    Thread.sleep(10) // Small delay to avoid busy waiting
                }
            }
            
            Log.d(TAG, "Audio capture thread exited normally, total frames: $frameCount")
        } catch (e: Exception) {
            Log.e(TAG, "Error in audio capture loop", e)
            sendErrorEvent("Audio capture error: ${e.message}")
        }
    }

    private fun processAudioStream() {
        Log.d(TAG, "Audio processing thread started")
        
        val buffer = ShortArray(bufferSize)
        var silenceStartTime: Long = -1
        var segmentStartTime = System.currentTimeMillis()
        var frameCount = 0
        
        // Reuse ByteBuffer to avoid excessive allocations
        val byteBuffer = ByteBuffer.allocate(bufferSize * 2)
        
        try {
            while (isRecording) {
                val readSize = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                
                if (readSize > 0) {
                    frameCount++
                    
                    // Clear and prepare ByteBuffer for reuse
                    byteBuffer.clear()
                    byteBuffer.asShortBuffer().put(buffer, 0, readSize)
                    
                    // Send audio data to Vosk for recognition
                    val voskResult = recognizer?.acceptWaveForm(byteBuffer.array(), readSize * 2)
                    
                    // Get partial result during speech
                    val partialResult = recognizer?.partialResult
                    
                    // Calculate energy for VAD
                    val energy = calculateEnergy(buffer, readSize)
                    val isSpeech = energy > energyThreshold
                    
                    if (isSpeech) {
                        silenceStartTime = -1
                        
                        // Send partial transcript if available
                        if (partialResult != null && !partialResult.isEmpty()) {
                            try {
                                val json = org.json.JSONObject(partialResult)
                                val text = json.optString("partial", "")
                                if (text.isNotEmpty()) {
                                    sendPartialTranscript(text)
                                }
                            } catch (e: Exception) {
                                Log.e(TAG, "Error parsing partial result", e)
                            }
                        }
                    } else {
                        if (silenceStartTime == -1L) {
                            silenceStartTime = System.currentTimeMillis()
                        } else {
                            val silenceDuration = System.currentTimeMillis() - silenceStartTime
                            
                            if (silenceDuration >= longPauseMs) {
                                Log.d(TAG, "Long pause detected (${silenceDuration}ms), finalizing segment")
                                
                                // Get final result from Vosk
                                val finalResult = recognizer?.result
                                
                                if (finalResult != null && !finalResult.isEmpty()) {
                                    try {
                                        val json = org.json.JSONObject(finalResult)
                                        val text = json.optString("text", "")
                                        
                                        if (text.isNotEmpty()) {
                                            Log.d(TAG, "Final result: $text")
                                            // Finalize segment with recognized text
                                            finalizeSegment(
                                                text,
                                                segmentStartTime,
                                                System.currentTimeMillis()
                                            )
                                        }
                                    } catch (e: Exception) {
                                        Log.e(TAG, "Error parsing final result", e)
                                    }
                                }
                                
                                segmentStartTime = System.currentTimeMillis()
                                silenceStartTime = -1
                            }
                        }
                    }
                    
                    // Log progress every 100 frames
                    if (frameCount % 100 == 0) {
                        Log.d(TAG, "Processed $frameCount frames, isRecording=$isRecording")
                    }
                } else {
                    Log.w(TAG, "Read size is 0 or negative: $readSize")
                    Thread.sleep(10) // Small delay to avoid busy waiting
                }
            }
            
            Log.d(TAG, "Audio processing thread exited normally")
        } catch (e: Exception) {
            Log.e(TAG, "Error in audio processing loop", e)
            sendErrorEvent("Audio processing error: ${e.message}")
        }
    }

    private fun calculateEnergy(buffer: ShortArray, size: Int): Double {
        var sum = 0.0
        for (i in 0 until size) {
            sum += buffer[i] * buffer[i]
        }
        return Math.sqrt(sum / size) / 32768.0
    }

    private fun sendPartialTranscript(text: String) {
        handler.post {
            val event = mapOf(
                "event" to "partial_transcript",
                "text" to text,
                "timestamp" to System.currentTimeMillis()
            )
            channel.invokeMethod("onEvent", event)
        }
    }

    private fun finalizeSegment(text: String, startTime: Long, endTime: Long) {
        val segmentId = UUID.randomUUID().toString()
        val audioPath = saveAudioSegment(segmentId)
        
        handler.post {
            val event = mapOf(
                "event" to "final_segment",
                "segment_id" to segmentId,
                "text" to text,
                "start_ts" to startTime,
                "end_ts" to endTime,
                "audio_path" to audioPath,
                "confidence" to 0.85
            )
            channel.invokeMethod("onEvent", event)
        }
    }

    private fun saveAudioSegment(segmentId: String): String {
        val audioDir = File(context.filesDir, "audio/${java.text.SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())}")
        if (!audioDir.exists()) {
            audioDir.mkdirs()
        }
        
        val audioFile = File(audioDir, "$segmentId.pcm")
        // TODO: Actually write audio data to file
        return audioFile.absolutePath
    }

    private fun stopRecording() {
        if (!isRecording) return
        
        Log.d(TAG, "Stopping recording...")
        
        // Signal the thread to stop
        isRecording = false
        
        // Wait for thread to finish with timeout (avoid blocking forever)
        try {
            recordingThread?.join(500) // 500ms timeout
        } catch (e: InterruptedException) {
            Log.e(TAG, "Interrupted while waiting for recording thread", e)
        }
        
        // Release audio resources
        try {
            audioRecord?.stop()
            audioRecord?.release()
            audioRecord = null
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing audio resources", e)
        }
        
        // Process recorded audio in background thread
        Thread {
            processRecordedAudio()
        }.start()
        
        Log.d(TAG, "Recording stopped, processing audio in background...")
    }

    private fun processRecordedAudio() {
        Log.d(TAG, "Processing recorded audio...")
        
        try {
            val audioData = audioBuffer?.toByteArray()
            if (audioData == null || audioData.isEmpty()) {
                Log.e(TAG, "No audio data to process")
                sendErrorEvent("没有录制到音频数据")
                return
            }
            
            Log.d(TAG, "Audio data size: ${audioData.size} bytes (${String.format("%.2f", audioData.size / 32000.0)}s)")
            
            // Create a new recognizer for this session
            val recognizer = Recognizer(model!!, sampleRate.toFloat())
            
            // Process the entire audio data at once
            // acceptWaveForm takes the full byte array and its length
            recognizer.acceptWaveForm(audioData, audioData.size)
            
            // Get the final recognition result
            val finalResult = recognizer.result
            
            if (finalResult != null && !finalResult.isEmpty()) {
                try {
                    val json = org.json.JSONObject(finalResult)
                    val text = json.optString("text", "")
                    
                    if (text.isNotEmpty()) {
                        Log.d(TAG, "Recognition result: $text")
                        
                        // Calculate duration from audio size
                        val durationMs = (audioData.size.toDouble() / (sampleRate * 2)) * 1000
                        
                        // Send final transcript
                        handler.post {
                            finalizeSegment(
                                text,
                                System.currentTimeMillis() - durationMs.toLong(),
                                System.currentTimeMillis()
                            )
                        }
                    } else {
                        Log.w(TAG, "Empty recognition result")
                        handler.post {
                            sendErrorEvent("未能识别语音内容，请确保说话清晰")
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error parsing recognition result", e)
                    handler.post {
                        sendErrorEvent("解析识别结果失败")
                    }
                }
            } else {
                Log.w(TAG, "No recognition result")
                handler.post {
                    sendErrorEvent("未检测到语音内容")
                }
            }
            
            // Clean up
            recognizer.close()
            audioBuffer?.close()
            audioBuffer = null
            
            Log.d(TAG, "Audio processing completed successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error processing recorded audio", e)
            handler.post {
                sendErrorEvent("音频处理失败: ${e.message}")
            }
        }
    }

    private fun cancelRecording() {
        stopRecording()
        // Delete any temporary audio files
        Log.d(TAG, "Recording cancelled")
    }

    private fun sendErrorEvent(message: String) {
        handler.post {
            val event = mapOf(
                "event" to "error",
                "message" to message
            )
            channel.invokeMethod("onEvent", event)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        cancelRecording()
    }
}
