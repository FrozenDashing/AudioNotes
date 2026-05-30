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
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Recorder Plugin for Android
 * Handles audio recording and WAV file generation only (no ASR)
 */
class RecorderPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    
    private var audioRecord: AudioRecord? = null
    private var isRecording = false
    private var recordingThread: Thread? = null
    private var wavFilePath: String? = null
    
    // Audio configuration
    private val sampleRate = 16000
    private val channelConfig = AudioFormat.CHANNEL_IN_MONO
    private val audioFormat = AudioFormat.ENCODING_PCM_16BIT
    private val bufferSize = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat) * 2
    
    private val handler = Handler(Looper.getMainLooper())
    
    companion object {
        private const val TAG = "RecorderPlugin"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.audionotes/recorder")
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "startRecording" -> handleStartRecording(result)
            "stopRecording" -> handleStopRecording(result)
            "cancelRecording" -> handleCancelRecording(result)
            "isRecording" -> handleIsRecording(result)
            "startRecordingFromIntent" -> handleStartRecordingFromIntent(result)
            else -> result.notImplemented()
        }
    }

    private fun handleStartRecordingFromIntent(result: Result) {
        if (!checkPermission()) {
            result.error("PERMISSION_DENIED", "Microphone permission not granted", null)
            return
        }
        
        if (isRecording) {
            result.error("ALREADY_RECORDING", "Already recording", null)
            return
        }
        
        try {
            // Create WAV file
            val file = createRecordingFile()
            wavFilePath = file.absolutePath
            
            Log.d(TAG, "Starting recording from intent to: ${wavFilePath}")
            
            // Initialize AudioRecord
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
            
            // Write WAV header (will be updated later with actual size)
            writeWavHeader(file, 0)
            
            // Start recording
            audioRecord?.startRecording()
            isRecording = true
            
            // Start recording thread
            recordingThread = Thread {
                val buffer = ByteArray(bufferSize)
                val outputStream = FileOutputStream(file, true)
                
                while (isRecording) {
                    val readSize = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                    if (readSize > 0) {
                        outputStream.write(buffer, 0, readSize)
                    }
                }
                
                outputStream.close()
            }
            
            recordingThread?.start()
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start recording from intent", e)
            result.error("RECORDING_FAILED", "Failed to start recording: ${e.message}", null)
        }
    }

    private fun handleStartRecording(result: Result) {
        if (!checkPermission()) {
            result.error("PERMISSION_DENIED", "Microphone permission not granted", null)
            return
        }
        
        if (isRecording) {
            result.error("ALREADY_RECORDING", "Already recording", null)
            return
        }
        
        try {
            // Create WAV file
            val file = createRecordingFile()
            wavFilePath = file.absolutePath
            
            Log.d(TAG, "Starting recording to: ${wavFilePath}")
            
            // Initialize AudioRecord
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
            
            // Write WAV header (will be updated later with actual size)
            file.parentFile?.mkdirs()
            writeWavHeader(file, 0) // Size will be updated when stopping
            
            // Start recording
            audioRecord?.startRecording()
            isRecording = true
            
            // Start capture thread
            recordingThread = Thread({
                captureAudioToFile()
            }, "AudioCaptureThread")
            recordingThread?.start()
            
            Log.d(TAG, "Recording started successfully")
            result.success(wavFilePath)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start recording", e)
            isRecording = false
            result.error("START_FAILED", e.message, null)
        }
    }

    private fun createRecordingFile(): File {
        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        val dateDir = File(File(context.filesDir, "recordings"), dateFormat.format(Date()))
        if (!dateDir.exists()) {
            dateDir.mkdirs()
        }

        val fileName = "recording_${System.currentTimeMillis()}.wav"
        return File(dateDir, fileName)
    }

    private fun handleStopRecording(result: Result) {
        if (!isRecording) {
            result.error("NOT_RECORDING", "Not currently recording", null)
            return
        }
        
        Log.d(TAG, "Stopping recording...")
        
        // Signal thread to stop
        isRecording = false
        
        // Wait for thread to finish
        try {
            recordingThread?.join(1000) // 1 second timeout
        } catch (e: InterruptedException) {
            Log.e(TAG, "Interrupted while waiting for recording thread", e)
        }
        
        // Stop and release AudioRecord
        try {
            audioRecord?.stop()
            audioRecord?.release()
            audioRecord = null
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing audio resources", e)
        }
        
        // Update WAV header with actual file size
        val filePath = wavFilePath
        if (filePath != null) {
            try {
                val file = File(filePath)
                val fileSize = file.length().toInt()
                writeWavHeader(file, fileSize - 44) // Subtract header size
                
                Log.d(TAG, "Recording stopped, file size: $fileSize bytes")
                result.success(filePath)
            } catch (e: Exception) {
                Log.e(TAG, "Error updating WAV header", e)
                result.error("WAV_ERROR", e.message, null)
            }
        } else {
            result.error("NO_FILE", "No recording file", null)
        }
        
        wavFilePath = null
    }

    private fun handleCancelRecording(result: Result) {
        if (!isRecording) {
            result.success(true)
            return
        }
        
        isRecording = false
        audioRecord?.stop()
        recordingThread?.interrupt()
        recordingThread = null
        result.success(true)
    }

    private fun handleIsRecording(result: Result) {
        result.success(isRecording)
    }

    private fun checkPermission(): Boolean {
        return ActivityCompat.checkSelfPermission(
            context,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun captureAudioToFile() {
        Log.d(TAG, "Audio capture thread started")
        
        val buffer = ShortArray(bufferSize)
        val byteBuffer = ByteBuffer.allocateDirect(buffer.size * 2)
        byteBuffer.order(ByteOrder.LITTLE_ENDIAN)
        
        var totalBytesWritten = 0
        
        try {
            // Open file in append mode to write after the WAV header (44 bytes)
            val file = File(wavFilePath!!)
            val raf = java.io.RandomAccessFile(file, "rw")
            
            // Seek to position after WAV header
            raf.seek(44)
            Log.d(TAG, "Seeked to position 44 in file: ${file.absolutePath}")
            
            while (isRecording) {
                val readSize = audioRecord?.read(buffer, 0, buffer.size) ?: 0
                
                if (readSize > 0) {
                    // Convert short array to bytes
                    byteBuffer.clear()
                    for (i in 0 until readSize) {
                        byteBuffer.putShort(buffer[i])
                    }
                    
                    // Write to file at current position (after header)
                    val bytes = byteBuffer.array()
                    raf.write(bytes, 0, readSize * 2)
                    totalBytesWritten += readSize * 2
                    
                    if (totalBytesWritten % 32000 == 0) { // Log every 1 second of audio
                        Log.d(TAG, "Captured $readSize samples, total: $totalBytesWritten bytes (${totalBytesWritten / 32000}s)")
                    }
                } else {
                    Thread.sleep(10)
                }
            }
            
            raf.close()
            Log.d(TAG, "Audio capture completed, total bytes: $totalBytesWritten, file size: ${file.length()} bytes")
        } catch (e: Exception) {
            Log.e(TAG, "Error in audio capture", e)
        }
    }

    private fun writeWavHeader(file: File, dataLength: Int) {
        val raf = java.io.RandomAccessFile(file, "rw")
        
        try {
            // RIFF header
            raf.write("RIFF".toByteArray())
            raf.write(intToLittleEndian(36 + dataLength)) // File size - 8
            raf.write("WAVE".toByteArray())
            
            // fmt chunk
            raf.write("fmt ".toByteArray())
            raf.write(intToLittleEndian(16)) // Subchunk1Size
            raf.write(shortToLittleEndian(1)) // AudioFormat (PCM)
            raf.write(shortToLittleEndian(1)) // NumChannels (Mono)
            raf.write(intToLittleEndian(sampleRate)) // SampleRate
            raf.write(intToLittleEndian(sampleRate * 2)) // ByteRate
            raf.write(shortToLittleEndian(2)) // BlockAlign
            raf.write(shortToLittleEndian(16)) // BitsPerSample
            
            // data chunk
            raf.write("data".toByteArray())
            raf.write(intToLittleEndian(dataLength)) // Subchunk2Size
            
            // No need to flush or close here as RAF handles it
        } finally {
            raf.close()
        }
    }

    private fun intToLittleEndian(value: Int): ByteArray {
        return byteArrayOf(
            (value and 0xFF).toByte(),
            ((value shr 8) and 0xFF).toByte(),
            ((value shr 16) and 0xFF).toByte(),
            ((value shr 24) and 0xFF).toByte()
        )
    }

    private fun shortToLittleEndian(value: Short): ByteArray {
        return byteArrayOf(
            (value.toInt() and 0xFF).toByte(),
            ((value.toInt() shr 8) and 0xFF).toByte()
        )
    }

}