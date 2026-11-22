package com.himorning.android.platform

import android.content.Context
import android.media.MediaPlayer
import java.security.MessageDigest

/**
 * Plays pre-generated neural TTS (.m4a AAC) clips bundled in `assets/voice/`.
 * Uses the exact same deterministic SHA-256 naming scheme as iOS `NeuralVoicePlayer.swift`.
 */
class NeuralVoicePlayer(private val context: Context) {
    private var player: MediaPlayer? = null

    fun play(language: String, text: String): Boolean {
        val assetPath = "voice/${clipResourceName(language, text)}.m4a"
        return runCatching {
            val afd = context.assets.openFd(assetPath)
            stop()
            val mediaPlayer = MediaPlayer().apply {
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()
                setOnCompletionListener { releasePlayer(it) }
                setOnErrorListener { mp, _, _ -> releasePlayer(mp); true }
                prepare()
                start()
            }
            player = mediaPlayer
            true
        }.getOrElse { false }
    }

    fun stop() {
        player?.let { mp ->
            runCatching { if (mp.isPlaying) mp.stop() }
            runCatching { mp.release() }
        }
        player = null
    }

    private fun releasePlayer(mp: MediaPlayer) {
        if (player === mp) player = null
        runCatching { mp.release() }
    }

    companion object {
        fun clipResourceName(language: String, text: String): String {
            val lang = if (language.startsWith("vi", ignoreCase = true)) "vi" else "en"
            val trimmed = text.trim()
            val digest = MessageDigest.getInstance("SHA-256")
                .digest("$lang:$trimmed".toByteArray(Charsets.UTF_8))
            val hex = digest.take(8).joinToString("") { "%02x".format(it) }
            return "voice_${lang}_$hex"
        }
    }
}
