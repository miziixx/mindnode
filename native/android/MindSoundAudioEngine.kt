package com.mindsound.mindsound

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import java.util.concurrent.atomic.AtomicReference

/**
 * 실시간 오디오 엔진(Android). AudioTrack MODE_STREAM, PCM Float, Stereo.
 * 주파수/드론/바이노럴/펄스를 실시간 생성하고 로컬 WAV(자연음/패드/차임)와 믹싱한다.
 *
 * - 렌더는 전용 스레드에서 수행. 콜백 안에서 파일/네트워크/할당/락 없음.
 * - 파라미터는 렌더 스레드에서 안전히 읽는 불변 스냅샷(AtomicReference)으로 전달.
 * - 모든 실시간 변경은 샘플 단위 램프(클릭 방지).
 */
class MindSoundAudioEngine(
    private val context: Context,
    private val listener: (Map<String, Any?>) -> Unit
) {
    // ── 파라미터 스냅샷(불변, 렌더 스레드가 읽음) ──
    data class ToneParams(val enabled: Boolean, val freq: Double, val gainDb: Double, val pan: Double)
    data class DroneParams(val enabled: Boolean, val center: Double, val gainDb: Double,
                           val movement: Double, val width: Double,
                           val sub: Double, val main: Double, val air: Double)
    data class BinauralParams(val enabled: Boolean, val carrier: Double, val beat: Double,
                              val invert: Boolean, val gainDb: Double)
    data class PulseParams(val enabled: Boolean, val freq: Double, val rate: Double,
                           val depth: Double, val alternate: Boolean, val gainDb: Double)

    class Stage {
        var title = ""
        var durationSec = 0
        var primary = ToneParams(false, 528.0, -26.0, 0.0)
        var secondary = ToneParams(false, 741.0, -34.0, 0.0)
        var drone = DroneParams(false, 528.0, -24.0, 0.05, 0.25, 0.35, 0.55, 0.10)
        var binaural = BinauralParams(false, 220.0, 10.0, false, -30.0)
        var pulse = PulseParams(false, 432.0, 7.83, 0.2, false, -30.0)
        var natureAssetId: String? = null
        var natureAssetKey: String? = null
        var padAssetId: String? = null
        var padAssetKey: String? = null
        var chimeAssetId: String? = null
        var chimeAssetKey: String? = null
        var chimeIntervalSec = 0
        var transitionSec = 1.5
    }

    private var sampleRate = 48000
    private var track: AudioTrack? = null
    private var renderThread: Thread? = null
    @Volatile private var running = false
    @Volatile private var paused = false

    private val loaderThread = HandlerThread("mindsound-loader").apply { start() }
    private val loader = Handler(loaderThread.looper)
    private val main = Handler(Looper.getMainLooper())

    // 스테이지/타이밍
    private var stages: List<Stage> = emptyList()
    @Volatile private var stageIndex = 0
    private var totalDurationSec = 0
    private var startFadeMs = 3000
    private var endFadeMs = 10000

    // 렌더 스레드 소유 상태(다른 스레드 접근 금지)
    private val primaryOsc = PhaseOsc()
    private val secondaryOsc = PhaseOsc()
    private val drone = DroneVoices()
    private val binaural = BinauralVoice()
    private val pulse = PulseVoice()
    private val limiter = SoftLimiter()
    private val droneOut = DoubleArray(2)
    private val binOut = DoubleArray(2)
    private val pulseOut = DoubleArray(2)
    private val clipOut = DoubleArray(2)

    private val primaryFreq = Ramp(528.0)
    private val secondaryFreq = Ramp(741.0)
    private val masterGain = Ramp(0.0)
    private val primaryGain = Ramp(0.0)
    private val secondaryGain = Ramp(0.0)
    private val droneGain = Ramp(0.0)
    private val binauralGain = Ramp(0.0)
    private val pulseGain = Ramp(0.0)
    private val natureGain = Ramp(0.0)
    private val padGain = Ramp(0.0)

    private var naturePlayer = ClipPlayer(null, loop = true)
    private var padPlayer = ClipPlayer(null, loop = true)
    private var chimePlayer = ClipPlayer(null, loop = false)

    // 렌더 스레드가 읽는 목표 스냅샷
    private val snapshot = AtomicReference(Stage())
    @Volatile private var targetMaster = 0.15
    @Volatile private var stopRequested = false
    @Volatile private var gracefulStop = true

    private var framesRendered = 0L
    private var stageStartFrame = 0L
    private var lastChimeFrame = 0L
    private var lastEventFrame = 0L

    fun sampleRateHz(): Int = sampleRate

    // ── 공개 명령 ──
    fun initialize() {
        sampleRate = AudioTrack.getNativeOutputSampleRate(AudioManager.STREAM_MUSIC)
        if (sampleRate <= 0) sampleRate = 48000
        emit(mapOf("type" to "engineReady", "sampleRate" to sampleRate.toDouble()))
    }

    fun loadPreset(preset: Map<String, Any?>, assetPaths: Map<String, String>,
                   startFadeMs: Int, endFadeMs: Int, masterGain01: Double) {
        this.startFadeMs = startFadeMs
        this.endFadeMs = endFadeMs
        targetMaster = masterGain01
        val stageList = (preset["stages"] as? List<*>)?.mapNotNull { parseStage(it, assetPaths) } ?: emptyList()
        stages = stageList
        totalDurationSec = stageList.sumOf { it.durationSec }
        stageIndex = 0
        if (stageList.isNotEmpty()) applyStageSnapshot(stageList[0], instant = true)
        // 자산 프리로드(백그라운드)
        loader.post { preloadStageAssets(0) }
        emit(mapOf("type" to "playbackStateChanged", "state" to "ready"))
    }

    fun start() {
        if (running) { paused = false; return }
        stopRequested = false
        ensureTrack()
        masterGain.snap(0.0)
        masterGain.setTarget(targetMaster, sampleRate.toDouble(), startFadeMs.toDouble())
        running = true
        paused = false
        framesRendered = 0
        stageStartFrame = 0
        lastChimeFrame = 0
        naturePlayer.trigger(); padPlayer.trigger()
        renderThread = Thread({ renderLoop() }, "mindsound-render").also { it.start() }
        emit(mapOf("type" to "playbackStateChanged", "state" to "playing"))
    }

    fun pause() { paused = true; emit(mapOf("type" to "playbackStateChanged", "state" to "paused")) }
    fun resume() { paused = false; emit(mapOf("type" to "playbackStateChanged", "state" to "playing")) }

    fun stop(graceful: Boolean) {
        gracefulStop = graceful
        if (graceful) {
            masterGain.setTarget(0.0, sampleRate.toDouble(), endFadeMs.toDouble())
            stopRequested = true // 페이드 후 렌더 루프가 종료
        } else {
            running = false
        }
    }

    fun seekToStage(index: Int) { changeStage(index.coerceIn(0, stages.size - 1)) }
    fun nextStage() { if (stageIndex < stages.size - 1) changeStage(stageIndex + 1) }
    fun previousStage() { if (stageIndex > 0) changeStage(stageIndex - 1) }

    fun setMasterGain(g01: Double) {
        targetMaster = g01
        masterGain.setTarget(g01, sampleRate.toDouble(), 30.0)
    }

    fun setFrequency(hz: Double) { primaryFreq.setTarget(hz, sampleRate.toDouble(), 30.0) }
    fun setSecondaryFrequency(hz: Double) { secondaryFreq.setTarget(hz, sampleRate.toDouble(), 30.0) }

    fun setLayerEnabled(layerId: String, enabled: Boolean) {
        val sr = sampleRate.toDouble()
        val ramp = when (layerId) {
            "primary" -> primaryGain; "secondary" -> secondaryGain
            "drone" -> droneGain; "binaural" -> binauralGain
            "pulse" -> pulseGain; "nature" -> natureGain; "pad" -> padGain
            else -> null
        }
        val cur = snapshot.get()
        ramp?.setTarget(if (enabled) gainFor(layerId, cur) else 0.0, sr, 100.0)
    }

    fun setLayerGain(layerId: String, gainDb: Double) {
        val lin = DspConst.dbToLin(gainDb)
        val ramp = when (layerId) {
            "primary" -> primaryGain; "secondary" -> secondaryGain
            "drone" -> droneGain; "binaural" -> binauralGain
            "pulse" -> pulseGain; "nature" -> natureGain; "pad" -> padGain
            else -> null
        }
        ramp?.setTarget(lin, sampleRate.toDouble(), 30.0)
    }

    fun triggerChime(assetKey: String?) {
        if (assetKey == null) return
        loader.post {
            val clip = WavDecoder.loadFlutterAsset(context, assetKey, sampleRate)
            if (clip != null) { chimePlayer.clip = clip; chimePlayer.trigger() }
        }
    }

    /// 재생 중 자연음 교체(백그라운드 로드 후 스왑 + 게인 램프).
    fun setNatureAsset(assetId: String?, assetKey: String?) {
        if (assetKey == null) {
            naturePlayer.stop()
            natureGain.setTarget(0.0, sampleRate.toDouble(), 100.0)
            return
        }
        loader.post {
            val clip = WavDecoder.loadFlutterAsset(context, assetKey, sampleRate)
            if (clip != null) {
                naturePlayer = ClipPlayer(clip, loop = true).also { it.trigger() }
                natureGain.setTarget(DspConst.dbToLin(-20.0), sampleRate.toDouble(), 200.0)
            }
        }
    }

    fun setPadAsset(assetId: String?, assetKey: String?) {
        if (assetKey == null) {
            padPlayer.stop()
            padGain.setTarget(0.0, sampleRate.toDouble(), 100.0)
            return
        }
        loader.post {
            val clip = WavDecoder.loadFlutterAsset(context, assetKey, sampleRate)
            if (clip != null) {
                padPlayer = ClipPlayer(clip, loop = true).also { it.trigger() }
                padGain.setTarget(DspConst.dbToLin(-24.0), sampleRate.toDouble(), 200.0)
            }
        }
    }

    fun dispose() {
        running = false
        try { renderThread?.join(500) } catch (_: Exception) {}
        track?.release(); track = null
        loaderThread.quitSafely()
    }

    // ── 내부 ──
    private fun gainFor(layerId: String, s: Stage): Double = when (layerId) {
        "primary" -> if (s.primary.enabled) DspConst.dbToLin(s.primary.gainDb) else 0.0
        "secondary" -> if (s.secondary.enabled) DspConst.dbToLin(s.secondary.gainDb) else 0.0
        "drone" -> if (s.drone.enabled) DspConst.dbToLin(s.drone.gainDb) else 0.0
        "binaural" -> if (s.binaural.enabled) DspConst.dbToLin(s.binaural.gainDb) else 0.0
        "pulse" -> if (s.pulse.enabled) DspConst.dbToLin(s.pulse.gainDb) else 0.0
        "nature" -> if (s.natureAssetId != null) DspConst.dbToLin(-20.0) else 0.0
        "pad" -> if (s.padAssetId != null) DspConst.dbToLin(-24.0) else 0.0
        else -> 0.0
    }

    private fun applyStageSnapshot(s: Stage, instant: Boolean) {
        snapshot.set(s)
        val sr = sampleRate.toDouble()
        val ramp = if (instant) 0.0 else (s.transitionSec * 1000.0)
        if (instant) {
            primaryFreq.snap(s.primary.freq); secondaryFreq.snap(s.secondary.freq)
            primaryGain.snap(gainFor("primary", s)); secondaryGain.snap(gainFor("secondary", s))
            droneGain.snap(gainFor("drone", s)); binauralGain.snap(gainFor("binaural", s))
            pulseGain.snap(if (s.pulse.enabled) DspConst.dbToLin(s.pulse.gainDb) else 0.0)
            natureGain.snap(gainFor("nature", s)); padGain.snap(gainFor("pad", s))
        } else {
            primaryFreq.setTarget(s.primary.freq, sr, ramp)
            secondaryFreq.setTarget(s.secondary.freq, sr, ramp)
            primaryGain.setTarget(gainFor("primary", s), sr, ramp)
            secondaryGain.setTarget(gainFor("secondary", s), sr, ramp)
            droneGain.setTarget(gainFor("drone", s), sr, ramp)
            binauralGain.setTarget(gainFor("binaural", s), sr, ramp)
            pulseGain.setTarget(if (s.pulse.enabled) DspConst.dbToLin(s.pulse.gainDb) else 0.0, sr, ramp)
            natureGain.setTarget(gainFor("nature", s), sr, ramp)
            padGain.setTarget(gainFor("pad", s), sr, ramp)
        }
    }

    private fun changeStage(index: Int) {
        stageIndex = index
        stageStartFrame = framesRendered
        lastChimeFrame = framesRendered
        val s = stages.getOrNull(index) ?: return
        applyStageSnapshot(s, instant = false)
        loader.post { preloadStageAssets(index) }
        emit(mapOf("type" to "currentStageChanged", "stageIndex" to index,
            "stageCount" to stages.size,
            "frequencyHz" to (displayFreq(s)), "title" to s.title))
    }

    private fun preloadStageAssets(index: Int) {
        val s = stages.getOrNull(index) ?: return
        s.natureAssetKey?.let {
            val c = WavDecoder.loadFlutterAsset(context, it, sampleRate)
            naturePlayer = ClipPlayer(c, loop = true).also { p -> p.trigger() }
        } ?: run { naturePlayer.stop() }
        s.padAssetKey?.let {
            val c = WavDecoder.loadFlutterAsset(context, it, sampleRate)
            padPlayer = ClipPlayer(c, loop = true).also { p -> p.trigger() }
        } ?: run { padPlayer.stop() }
        s.chimeAssetKey?.let {
            chimePlayer = ClipPlayer(WavDecoder.loadFlutterAsset(context, it, sampleRate), loop = false)
        }
    }

    private fun ensureTrack() {
        if (track != null) return
        val minBuf = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_STEREO,
            AudioFormat.ENCODING_PCM_FLOAT
        ).coerceAtLeast(4096)
        track = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(sampleRate)
                    .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO)
                    .build()
            )
            .setTransferMode(AudioTrack.MODE_STREAM)
            // 언더런(끊김) 방지를 위해 넉넉한 버퍼.
            .setBufferSizeInBytes(minBuf * 4)
            .build()
    }

    private val blockFrames = 256
    private val buffer = FloatArray(blockFrames * 2)
    private val silence = FloatArray(blockFrames * 2)

    private fun renderLoop() {
        val t = track ?: return
        t.play()
        val sr = sampleRate.toDouble()
        while (running) {
            if (paused) {
                // 일시정지 중에도 무음을 계속 공급해 AudioTrack 언더런/글리치 방지.
                t.write(silence, 0, silence.size, AudioTrack.WRITE_BLOCKING)
                continue
            }
            val s = snapshot.get()
            // 팬 게인은 블록당 1회만 계산(샘플마다 Pair 할당 금지 → 끊김 방지).
            val panA = (s.primary.pan + 1.0) / 2.0 * Math.PI / 2.0
            val panL = Math.cos(panA)
            val panR = Math.sin(panA)
            var i = 0
            while (i < blockFrames) {
                var l = 0.0; var r = 0.0
                var active = 0
                // primary
                run {
                    val g = primaryGain.next()
                    val f = primaryFreq.next()
                    if (g > 1e-6) {
                        val v = primaryOsc.next(f, sr) * g
                        l += v * panL; r += v * panR; active++
                    } else primaryOsc.next(f, sr)
                }
                // secondary
                run {
                    val g = secondaryGain.next()
                    val f = secondaryFreq.next()
                    if (g > 1e-6) {
                        val v = secondaryOsc.next(f, sr) * g
                        l += v; r += v; active++
                    } else secondaryOsc.next(f, sr)
                }
                // drone
                run {
                    val g = droneGain.next()
                    drone.next(droneOut, sr, s.drone.center, s.drone.sub, s.drone.main,
                        s.drone.air, s.drone.movement, s.drone.width, g)
                    if (g > 1e-6) { l += droneOut[0]; r += droneOut[1]; active++ }
                }
                // binaural
                run {
                    val g = binauralGain.next()
                    binaural.next(binOut, sr, s.binaural.carrier, s.binaural.beat, s.binaural.invert, g)
                    if (g > 1e-6) { l += binOut[0]; r += binOut[1]; active++ }
                }
                // pulse
                run {
                    val g = pulseGain.next()
                    pulse.next(pulseOut, sr, s.pulse.freq, s.pulse.rate, s.pulse.depth, s.pulse.alternate, g)
                    if (g > 1e-6) { l += pulseOut[0]; r += pulseOut[1]; active++ }
                }
                // nature/pad/chime
                clipOut[0] = 0.0; clipOut[1] = 0.0
                naturePlayer.mixInto(clipOut, natureGain.next())
                padPlayer.mixInto(clipOut, padGain.next())
                chimePlayer.mixInto(clipOut, DspConst.dbToLin(-24.0))
                if (clipOut[0] != 0.0 || clipOut[1] != 0.0) { l += clipOut[0]; r += clipOut[1]; active++ }

                val hs = headroomScale(if (active < 1) 1 else active)
                val m = masterGain.next()
                buffer[i * 2] = limiter.process(l * hs * m).toFloat()
                buffer[i * 2 + 1] = limiter.process(r * hs * m).toFloat()
                i++
            }
            t.write(buffer, 0, buffer.size, AudioTrack.WRITE_BLOCKING)
            framesRendered += blockFrames

            // 시간·단계·차임은 Dart 틱커가 단일 권위로 관리한다(네이티브는 audio 만).
            // 여기서는 graceful 페이드아웃 완료만 감지해 종료한다.
            if (stopRequested && masterGain.current <= 1e-5) { running = false }
        }
        try { t.stop() } catch (_: Exception) {}
        val completed = !stopRequested
        main.post {
            emit(mapOf("type" to "playbackStateChanged", "state" to "idle"))
            if (completed) emit(mapOf("type" to "sessionCompleted"))
        }
    }

    private fun displayFreq(s: Stage): Double? = when {
        s.primary.enabled -> s.primary.freq
        s.drone.enabled -> s.drone.center
        s.pulse.enabled -> s.pulse.freq
        s.binaural.enabled -> s.binaural.carrier
        else -> null
    }

    private fun emit(map: Map<String, Any?>) { main.post { listener(map) } }

    @Suppress("UNCHECKED_CAST")
    private fun parseStage(raw: Any?, assetPaths: Map<String, String>): Stage? {
        val m = raw as? Map<String, Any?> ?: return null
        val s = Stage()
        s.title = m["title"] as? String ?: ""
        s.durationSec = (m["durationSec"] as? Number)?.toInt() ?: 600
        s.transitionSec = (m["transitionDurationSec"] as? Number)?.toDouble() ?: 1.5
        (m["primaryTone"] as? Map<String, Any?>)?.let { s.primary = tone(it, -26.0) }
        (m["secondaryTone"] as? Map<String, Any?>)?.let { s.secondary = tone(it, -34.0) }
        (m["drone"] as? Map<String, Any?>)?.let { d ->
            s.drone = DroneParams(
                d["enabled"] as? Boolean ?: false,
                (d["centerHz"] as? Number)?.toDouble() ?: 528.0,
                (d["gainDb"] as? Number)?.toDouble() ?: -24.0,
                (d["movementRateHz"] as? Number)?.toDouble() ?: 0.05,
                (d["stereoWidth"] as? Number)?.toDouble() ?: 0.25,
                (d["subVoiceRatio"] as? Number)?.toDouble() ?: 0.35,
                (d["mainVoiceRatio"] as? Number)?.toDouble() ?: 0.55,
                (d["airVoiceRatio"] as? Number)?.toDouble() ?: 0.10
            )
        }
        (m["binaural"] as? Map<String, Any?>)?.let { b ->
            s.binaural = BinauralParams(
                b["enabled"] as? Boolean ?: false,
                (b["carrierHz"] as? Number)?.toDouble() ?: 220.0,
                (b["beatHz"] as? Number)?.toDouble() ?: 10.0,
                b["invert"] as? Boolean ?: false,
                (b["gainDb"] as? Number)?.toDouble() ?: -30.0
            )
        }
        (m["pulse"] as? Map<String, Any?>)?.let { p ->
            s.pulse = PulseParams(
                p["enabled"] as? Boolean ?: false,
                (p["frequencyHz"] as? Number)?.toDouble() ?: 432.0,
                (p["rateHz"] as? Number)?.toDouble() ?: 7.83,
                (p["depth"] as? Number)?.toDouble() ?: 0.2,
                (p["stereoMode"] as? String) == "alternate",
                (p["gainDb"] as? Number)?.toDouble() ?: -30.0
            )
        }
        s.natureAssetId = m["natureAssetId"] as? String
        s.natureAssetKey = assetPaths[s.natureAssetId]
        s.padAssetId = m["padAssetId"] as? String
        s.padAssetKey = assetPaths[s.padAssetId]
        s.chimeAssetId = m["chimeAssetId"] as? String
        s.chimeAssetKey = assetPaths[s.chimeAssetId]
        s.chimeIntervalSec = (m["chimeIntervalSec"] as? Number)?.toInt() ?: 0
        return s
    }

    private fun tone(m: Map<String, Any?>, defGain: Double) = ToneParams(
        m["enabled"] as? Boolean ?: false,
        (m["frequencyHz"] as? Number)?.toDouble() ?: 528.0,
        (m["gainDb"] as? Number)?.toDouble() ?: defGain,
        (m["pan"] as? Number)?.toDouble() ?: 0.0
    )
}
