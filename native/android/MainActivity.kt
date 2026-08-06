package com.mindsound.mindsound

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/** 엔진 싱글턴(액티비티/서비스 공유, 백그라운드에서도 재생 유지). */
object MindSoundAudio {
    var engine: MindSoundAudioEngine? = null
    var eventSink: EventChannel.EventSink? = null
    fun emit(map: Map<String, Any?>) { eventSink?.success(map) }
}

class MainActivity : FlutterActivity() {
    private val methodChannelName = "com.mindsound.app/audio"
    private val eventChannelName = "com.mindsound.app/audio_events"

    private var noisyReceiver: BroadcastReceiver? = null
    private var audioManager: AudioManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        val engine = MindSoundAudio.engine ?: MindSoundAudioEngine(applicationContext) { map ->
            MindSoundAudio.emit(map)
        }.also { MindSoundAudio.engine = it }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    MindSoundAudio.eventSink = events
                }
                override fun onCancel(arguments: Any?) { MindSoundAudio.eventSink = null }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
            .setMethodCallHandler { call, result ->
                try {
                    handle(call.method, call.arguments, engine)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("engine_error", e.message, null)
                }
            }
    }

    @Suppress("UNCHECKED_CAST")
    private fun handle(method: String, args: Any?, engine: MindSoundAudioEngine) {
        val a = args as? Map<String, Any?> ?: emptyMap()
        when (method) {
            "initialize" -> engine.initialize()
            "loadPreset" -> engine.loadPreset(
                a["preset"] as Map<String, Any?>,
                (a["assetPaths"] as? Map<String, String>) ?: emptyMap(),
                (a["startFadeMs"] as? Number)?.toInt() ?: 3000,
                (a["endFadeMs"] as? Number)?.toInt() ?: 10000,
                (a["masterGain01"] as? Number)?.toDouble() ?: 0.15
            )
            "start" -> { startService(); engine.start(); registerNoisy() }
            "pause" -> engine.pause()
            "resume" -> engine.resume()
            "stop" -> { engine.stop(a["graceful"] as? Boolean ?: true); unregisterNoisy() }
            "seekToStage" -> engine.seekToStage((a["index"] as? Number)?.toInt() ?: 0)
            "nextStage" -> engine.nextStage()
            "previousStage" -> engine.previousStage()
            "setMasterGain" -> engine.setMasterGain((a["gain01"] as? Number)?.toDouble() ?: 0.15)
            "setFrequency" -> engine.setFrequency((a["hz"] as? Number)?.toDouble() ?: 440.0)
            "setSecondaryFrequency" -> engine.setSecondaryFrequency((a["hz"] as? Number)?.toDouble() ?: 440.0)
            "setLayerEnabled" -> engine.setLayerEnabled(a["layerId"] as String, a["enabled"] as Boolean)
            "setLayerGain" -> engine.setLayerGain(a["layerId"] as String, (a["gainDb"] as? Number)?.toDouble() ?: -24.0)
            "setNatureAsset" -> {} // 스테이지 스냅샷 기반; 재로드는 loadPreset/stage 전환에서 처리
            "setPadAsset" -> {}
            "triggerChime" -> engine.triggerChime(a["assetPath"] as? String)
            "setDroneParameters", "setBinauralParameters", "setPulseParameters", "setTimer" -> {}
            "dispose" -> { engine.dispose(); MindSoundAudio.engine = null; stopService() }
        }
    }

    private fun startService() {
        val intent = Intent(this, PlaybackService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent)
        else startService(intent)
    }

    private fun stopService() { stopService(Intent(this, PlaybackService::class.java)) }

    private fun registerNoisy() {
        if (noisyReceiver != null) return
        noisyReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) {
                    MindSoundAudio.engine?.pause()
                    MindSoundAudio.emit(mapOf("type" to "routeChanged",
                        "reason" to "becomingNoisy", "headphonesConnected" to false))
                }
            }
        }
        registerReceiver(noisyReceiver, IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY))
    }

    private fun unregisterNoisy() {
        noisyReceiver?.let { try { unregisterReceiver(it) } catch (_: Exception) {} }
        noisyReceiver = null
    }

    override fun onDestroy() {
        unregisterNoisy()
        super.onDestroy()
    }
}
