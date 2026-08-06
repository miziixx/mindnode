package com.mindsound.mindsound

import android.content.Context
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * 로컬 WAV 음원을 stereo Float PCM 으로 디코딩(백그라운드 스레드에서 로드).
 * 오디오 렌더 콜백 안에서는 절대 로드/디코딩하지 않는다.
 * int16 / float32 PCM 지원. 모노는 스테레오로 복제. 필요시 간이 리샘플.
 */
class DecodedClip(val left: FloatArray, val right: FloatArray, val sampleRate: Int) {
    val frames: Int get() = left.size
}

object WavDecoder {
    /** flutter asset key(예: assets/audio/pads/warm_air_placeholder.wav)로 로드. */
    fun loadFlutterAsset(context: Context, assetKey: String, targetRate: Int): DecodedClip? {
        return try {
            val input = context.assets.open("flutter_assets/$assetKey")
            val bytes = input.use { it.readBytesCompat() }
            decode(bytes, targetRate)
        } catch (e: Exception) {
            null
        }
    }

    private fun java.io.InputStream.readBytesCompat(): ByteArray {
        val out = ByteArrayOutputStream()
        val buf = ByteArray(8192)
        while (true) {
            val n = read(buf)
            if (n < 0) break
            out.write(buf, 0, n)
        }
        return out.toByteArray()
    }

    private fun decode(bytes: ByteArray, targetRate: Int): DecodedClip? {
        if (bytes.size < 44) return null
        val bb = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        if (bytes[0] != 'R'.code.toByte() || bytes[1] != 'I'.code.toByte()) return null
        var pos = 12
        var fmt = 1
        var channels = 2
        var rate = targetRate
        var bits = 16
        var dataOffset = -1
        var dataSize = 0
        while (pos + 8 <= bytes.size) {
            val id = String(bytes, pos, 4, Charsets.US_ASCII)
            val size = bb.getInt(pos + 4)
            if (id == "fmt ") {
                fmt = bb.getShort(pos + 8).toInt() and 0xffff
                channels = bb.getShort(pos + 10).toInt() and 0xffff
                rate = bb.getInt(pos + 12)
                bits = bb.getShort(pos + 22).toInt() and 0xffff
            } else if (id == "data") {
                dataOffset = pos + 8
                dataSize = size
            }
            pos += 8 + size + (size and 1)
        }
        if (dataOffset < 0) return null
        dataSize = minOf(dataSize, bytes.size - dataOffset)
        val bytesPerSample = bits / 8
        val frameSize = bytesPerSample * channels
        val frames = dataSize / frameSize
        val left = FloatArray(frames)
        val right = FloatArray(frames)
        val db = ByteBuffer.wrap(bytes, dataOffset, dataSize).order(ByteOrder.LITTLE_ENDIAN)
        for (i in 0 until frames) {
            val l: Float
            val r: Float
            if (fmt == 3 && bits == 32) {
                l = db.getFloat(dataOffset + i * frameSize)
                r = if (channels >= 2) db.getFloat(dataOffset + i * frameSize + 4) else l
            } else {
                val li = db.getShort(dataOffset + i * frameSize).toInt()
                l = li / 32768f
                r = if (channels >= 2)
                    db.getShort(dataOffset + i * frameSize + 2).toInt() / 32768f else l
            }
            left[i] = l
            right[i] = r
        }
        val clip = DecodedClip(left, right, rate)
        return if (rate != targetRate) resample(clip, targetRate) else clip
    }

    /** 간이 선형 리샘플(품질보다 정합 우선). */
    private fun resample(clip: DecodedClip, targetRate: Int): DecodedClip {
        val ratio = targetRate.toDouble() / clip.sampleRate
        val n = (clip.frames * ratio).toInt()
        val l = FloatArray(n)
        val r = FloatArray(n)
        for (i in 0 until n) {
            val src = i / ratio
            val i0 = src.toInt()
            val frac = (src - i0).toFloat()
            val i1 = minOf(i0 + 1, clip.frames - 1)
            l[i] = clip.left[i0] * (1 - frac) + clip.left[i1] * frac
            r[i] = clip.right[i0] * (1 - frac) + clip.right[i1] * frac
        }
        return DecodedClip(l, r, targetRate)
    }
}

/** 루프/원샷 재생 커서. 렌더 스레드에서 할당 없이 읽는다. */
class ClipPlayer(var clip: DecodedClip?, val loop: Boolean) {
    @Volatile var active: Boolean = false
    private var cursor: Int = 0

    fun trigger() { cursor = 0; active = true }
    fun stop() { active = false }

    /** 한 프레임 읽어 outLR 에 누적(gain 적용). 원샷 종료 시 active=false. */
    fun mixInto(outLR: DoubleArray, gain: Double) {
        val c = clip ?: return
        if (!active || c.frames == 0) return
        outLR[0] += c.left[cursor] * gain
        outLR[1] += c.right[cursor] * gain
        cursor++
        if (cursor >= c.frames) {
            if (loop) cursor = 0 else active = false
        }
    }
}
