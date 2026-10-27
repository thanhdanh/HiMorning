package com.himorning.android.platform

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer

enum class CaptureError { PERMISSION_REQUIRED, UNSUPPORTED, RECOGNITION_FAILED, CAMERA_UNAVAILABLE, TRACKING_LOST, TIMEOUT }

/** Uses an on-device recognizer; each listener belongs to exactly one capture attempt. */
class SpeechCapture(private val context: Context) {
    private var recognizer: SpeechRecognizer? = null
    private var generation = 0
    fun start(language: String, onTranscript: (String) -> Unit, onFinal: (String) -> Unit, onError: (CaptureError) -> Unit) {
        destroy()
        val token = generation
        if (context.checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
            onError(CaptureError.PERMISSION_REQUIRED); return
        }
        if (!SpeechRecognizer.isOnDeviceRecognitionAvailable(context)) { onError(CaptureError.UNSUPPORTED); return }
        runCatching {
            recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(context).also { speech ->
                speech.setRecognitionListener(object : RecognitionListener {
                    private fun valid() = token == generation
                    override fun onReadyForSpeech(params: Bundle?) = Unit
                    override fun onBeginningOfSpeech() = Unit
                    override fun onRmsChanged(rmsdB: Float) = Unit
                    override fun onBufferReceived(buffer: ByteArray?) = Unit
                    override fun onEndOfSpeech() = Unit
                    override fun onEvent(eventType: Int, params: Bundle?) = Unit
                    override fun onError(error: Int) { if (valid()) { generation++; onError(CaptureError.RECOGNITION_FAILED) } }
                    override fun onResults(results: Bundle?) {
                        if (!valid()) return
                        generation++
                        val text = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty()
                        onTranscript(text); onFinal(text)
                    }
                    override fun onPartialResults(partialResults: Bundle?) {
                        if (valid()) onTranscript(partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty())
                    }
                })
                speech.startListening(Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, if (language.startsWith("vi", true)) "vi-VN" else "en-US")
                    putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                })
            }
        }.onFailure { destroy(); onError(CaptureError.RECOGNITION_FAILED) }
    }
    fun stop() { generation++; recognizer?.cancel() }
    fun destroy() { generation++; recognizer?.cancel(); recognizer?.destroy(); recognizer = null }
}
