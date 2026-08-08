package com.mindsound.mindsound

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Foreground Media Playback Service. Flutter Activity가 분리되어도 현재 재생을 유지한다.
 * (초기 버전은 프레임워크 알림 기반. Media3 MediaSessionService 연동은 후속 확장.)
 */
class PlaybackService : Service() {
    private val channelId = "mindsound_playback"
    private val notifId = 1001

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createChannel()
        startForegroundCompat()
        return START_STICKY
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NotificationManager::class.java)
            if (nm.getNotificationChannel(channelId) == null) {
                val ch = NotificationChannel(
                    channelId, "재생",
                    NotificationManager.IMPORTANCE_LOW
                )
                ch.setShowBadge(false)
                nm.createNotificationChannel(ch)
            }
        }
    }

    private fun startForegroundCompat() {
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val pi = PendingIntent.getActivity(
            this, 0, launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notif: Notification = Notification.Builder(this, channelId)
            .setContentTitle("마인드사운드")
            .setContentText("세션 재생 중")
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .setContentIntent(pi)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(notifId, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(notifId, notif)
        }
    }

    /**
     * 사용자가 최근 앱 목록에서 앱을 밀어 종료(task removed)하면 재생을 즉시 멈춘다.
     * (포그라운드 서비스가 살아남아 소리가 계속 나던 문제 해결.)
     */
    override fun onTaskRemoved(rootIntent: Intent?) {
        try {
            MindSoundAudio.engine?.stop(graceful = false)
            MindSoundAudio.engine?.dispose()
        } catch (_: Exception) {}
        MindSoundAudio.engine = null
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) stopForeground(STOP_FOREGROUND_REMOVE)
        else @Suppress("DEPRECATION") stopForeground(true)
        super.onDestroy()
    }
}
