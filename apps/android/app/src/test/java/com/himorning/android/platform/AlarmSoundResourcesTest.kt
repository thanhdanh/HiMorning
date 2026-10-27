package com.himorning.android.platform

import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder

class AlarmSoundResourcesTest {
    @Test fun customSoundsHaveStableAndroidResourceNamesAndPlayableWaveHeaders() {
        val ids = listOf("sunrise", "soft_chime", "pizzicato_dawn", "pizzicato_steps", "pizzicato_rise", "pizzicato_bloom", "steel_shimmer", "steel_breeze", "steel_morning", "steel_sparkle", "sax_hello", "sax_stroll", "sax_glow", "sax_daybreak")
        val directory = File("src/main/res/raw")
        ids.forEach { id ->
            val bytes = File(directory, "$id.wav").readBytes()
            assertTrue("$id RIFF header", String(bytes, 0, 4, Charsets.US_ASCII) == "RIFF")
            assertTrue("$id WAVE header", String(bytes, 8, 4, Charsets.US_ASCII) == "WAVE")
            val sampleRate = ByteBuffer.wrap(bytes, 24, 4).order(ByteOrder.LITTLE_ENDIAN).int
            val channels = ByteBuffer.wrap(bytes, 22, 2).order(ByteOrder.LITTLE_ENDIAN).short.toInt()
            assertTrue("$id has a supported PCM sample rate", sampleRate in 22_050..48_000)
            assertTrue("$id is mono or stereo", channels in 1..2)
        }
        assertTrue("Kenney CC0 notice is bundled", File(directory, "kenney_music_jingles_license.txt").isFile)
    }
}
