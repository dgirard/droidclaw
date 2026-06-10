package com.droidclaw.app

import android.content.Intent
import android.os.IBinder
import android.os.Process
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService

/**
 * Background media playback service for Radio France HLS streams.
 *
 * Uses Media3 MediaSessionService which auto-manages:
 * - Foreground service promotion/demotion
 * - Media-style notification with play/pause/stop buttons
 * - Audio focus handling
 * - MediaSession for external controllers (Bluetooth, car, etc.)
 */
class RadioPlaybackService : MediaSessionService() {

    private var mediaSession: MediaSession? = null

    companion object {
        /**
         * System packages allowed to obtain the session in addition to the
         * app's own process and the system server:
         * - System UI renders the media notification / output switcher.
         * - The Bluetooth stack relays AVRCP (headset/car) media commands.
         */
        private val TRUSTED_SYSTEM_PACKAGES = setOf(
            "com.android.systemui",
            "com.android.bluetooth",
        )
    }

    override fun onCreate() {
        super.onCreate()

        val player = ExoPlayer.Builder(this)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(C.USAGE_MEDIA)
                    .setContentType(C.AUDIO_CONTENT_TYPE_MUSIC)
                    .build(),
                /* handleAudioFocus= */ true,
            )
            .setHandleAudioBecomingNoisy(true)
            .build()

        mediaSession = MediaSession.Builder(this, player)
            .setCallback(object : MediaSession.Callback {
                // Accept all controllers (local app connections)
                override fun onConnect(
                    session: MediaSession,
                    controller: MediaSession.ControllerInfo,
                ): MediaSession.ConnectionResult {
                    return MediaSession.ConnectionResult.AcceptedResultBuilder(session)
                        .setAvailablePlayerCommands(
                            Player.Commands.Builder()
                                .addAll(
                                    Player.COMMAND_PLAY_PAUSE,
                                    Player.COMMAND_STOP,
                                    Player.COMMAND_SET_MEDIA_ITEM,
                                    Player.COMMAND_GET_CURRENT_MEDIA_ITEM,
                                    Player.COMMAND_GET_MEDIA_ITEMS_METADATA,
                                )
                                .build()
                        )
                        .build()
                }
            })
            .build()
    }

    /**
     * SECURITY: the service is exported (required for MediaSessionService —
     * the system binds to it for media notifications and media-button
     * routing), so gate session access here. Returning null rejects the
     * caller's connection. Allowed callers:
     * - this app itself (UID check — covers the media3 notification controller),
     * - the system server (UID 1000 — framework media-button / headset dispatch),
     * - System UI and the Bluetooth stack (package allowlist).
     */
    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? {
        return if (isTrustedCaller(controllerInfo)) mediaSession else null
    }

    private fun isTrustedCaller(controllerInfo: MediaSession.ControllerInfo): Boolean {
        return controllerInfo.uid == Process.myUid() ||
            controllerInfo.uid == Process.SYSTEM_UID ||
            controllerInfo.packageName == packageName ||
            controllerInfo.packageName in TRUSTED_SYSTEM_PACKAGES
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // Live radio: no resume point, stop cleanly when app is swiped away
        mediaSession?.player?.let { player ->
            if (!player.playWhenReady || player.mediaItemCount == 0) {
                stopSelf()
            }
        }
    }

    override fun onDestroy() {
        mediaSession?.run {
            player.release()
            release()
        }
        mediaSession = null
        super.onDestroy()
    }
}
