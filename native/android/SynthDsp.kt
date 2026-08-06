package com.mindsound.mindsound

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.exp
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * 실시간 합성 DSP 코어. Python 검증 코어(tools/audio_verify/dsp.py) 및
 * Dart 레퍼런스(lib/core/audio/dsp_reference.dart)와 동일한 알고리즘·상수(v1).
 *
 * 오디오 콜백 안에서 객체 생성/힙 할당을 하지 않는다(사전 할당 재사용).
 * 위상은 Double 정밀도로 유지하고 버퍼 경계에서 초기화하지 않으며 [0,2π)로 wrap.
 */
object DspConst {
    const val TWO_PI = 2.0 * PI
    const val LIMITER_CEILING_DB = -1.0
    fun dbToLin(db: Double): Double = Math.pow(10.0, db / 20.0)
    fun limiterCeilingLin(): Double = dbToLin(LIMITER_CEILING_DB)
}

/** 선형 파라미터 램프(게인/주파수 공용). */
class Ramp(value: Double) {
    var current: Double = value
    var target: Double = value
    private var step: Double = 0.0

    fun setTarget(v: Double, sampleRate: Double, ms: Double) {
        target = v
        val rampSamples = maxOf(1.0, sampleRate * ms / 1000.0)
        step = (target - current) / rampSamples
    }

    fun snap(v: Double) { current = v; target = v; step = 0.0 }

    fun next(): Double {
        if (step == 0.0 || (step > 0 && current >= target) || (step < 0 && current <= target)) {
            current = target; step = 0.0; return current
        }
        current += step
        return current
    }
}

/** 위상 보존 사인 오실레이터. */
class PhaseOsc(var phase: Double = 0.0) {
    fun next(freqHz: Double, sampleRate: Double): Double {
        val s = sin(phase)
        phase += DspConst.TWO_PI * freqHz / sampleRate
        if (phase >= DspConst.TWO_PI) phase -= DspConst.TWO_PI
        else if (phase < 0) phase += DspConst.TWO_PI
        return s
    }
}

/** 소프트 리미터(tanh). NaN/Inf 세이프티. */
class SoftLimiter(ceilingDb: Double = DspConst.LIMITER_CEILING_DB) {
    val ceil = DspConst.dbToLin(ceilingDb)
    fun process(x: Double): Double {
        var v = x
        if (v.isNaN() || v.isInfinite()) v = 0.0
        val e2 = exp(2.0 * (v / ceil))
        val t = if (v / ceil > 20) 1.0 else if (v / ceil < -20) -1.0 else (e2 - 1) / (e2 + 1)
        var y = ceil * t
        if (y > ceil) y = ceil
        if (y < -ceil) y = -ceil
        return y
    }
}

fun headroomScale(activeLayers: Int): Double =
    if (activeLayers <= 1) 1.0 else 1.0 / sqrt(activeLayers.toDouble())

/** 드론: Sub/Main/Air 보이스 + 느린 LFO + 스테레오 폭. 좌/우 독립 위상. */
class DroneVoices {
    private val subL = PhaseOsc(0.0); private val subR = PhaseOsc(0.3)
    private val mainL = PhaseOsc(1.1); private val mainR = PhaseOsc(1.4)
    private val airL = PhaseOsc(2.2); private val airR = PhaseOsc(2.5)
    private val lfoL = PhaseOsc(0.0); private val lfoR = PhaseOsc(PI / 2)

    /** outLR[0]=L, outLR[1]=R 에 기록(할당 없음). */
    fun next(
        outLR: DoubleArray, sampleRate: Double, centerHz: Double,
        subRatio: Double, mainRatio: Double, airRatio: Double,
        movementHz: Double, stereoWidth: Double, linGain: Double
    ) {
        val nyq = sampleRate * 0.5
        val airHz = centerHz * 2.0
        val airOn = airHz < nyq * 0.98
        val ll = 0.925 + 0.075 * lfoL.next(movementHz, sampleRate)
        val lr = 0.925 + 0.075 * lfoR.next(movementHz, sampleRate)
        var l = subRatio * subL.next(centerHz * 0.5, sampleRate)
        var r = subRatio * subR.next(centerHz * 0.5, sampleRate)
        l += mainRatio * mainL.next(centerHz, sampleRate)
        r += mainRatio * mainR.next(centerHz, sampleRate)
        if (airOn) {
            l += airRatio * airL.next(airHz, sampleRate)
            r += airRatio * airR.next(airHz, sampleRate)
        }
        l *= ll * linGain
        r *= lr * linGain
        val mid = 0.5 * (l + r)
        val side = 0.5 * (l - r) * (1.0 + stereoWidth)
        outLR[0] = mid + side
        outLR[1] = mid - side
    }
}

/** 바이노럴: 좌우 독립 위상, 모노 합산 없음. */
class BinauralVoice {
    private val left = PhaseOsc(0.0)
    private val right = PhaseOsc(0.0)
    fun next(outLR: DoubleArray, sampleRate: Double, carrier: Double, beat: Double,
             invert: Boolean, linGain: Double) {
        val lhz = if (invert) carrier + beat else carrier
        val rhz = if (invert) carrier else carrier + beat
        outLR[0] = left.next(lhz, sampleRate) * linGain
        outLR[1] = right.next(rhz, sampleRate) * linGain
    }
}

/** 진폭 펄스: 주파수 변경 없이 사인형 진폭 변조. */
class PulseVoice {
    private val carrier = PhaseOsc(0.0)
    private var modPhase = 0.0
    fun next(outLR: DoubleArray, sampleRate: Double, carrierHz: Double, rateHz: Double,
             depth: Double, alternate: Boolean, linGain: Double) {
        val c = carrier.next(carrierHz, sampleRate)
        val envL = (1.0 - depth) + depth * (0.5 + 0.5 * cos(modPhase))
        val envR = if (alternate) (1.0 - depth) + depth * (0.5 + 0.5 * cos(modPhase + PI)) else envL
        modPhase += DspConst.TWO_PI * rateHz / sampleRate
        if (modPhase >= DspConst.TWO_PI) modPhase -= DspConst.TWO_PI
        outLR[0] = c * envL * linGain
        outLR[1] = c * envR * linGain
    }
}
