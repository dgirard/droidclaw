package com.droidclaw.app

import android.content.Intent
import android.os.IBinder
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

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? {
        return mediaSession
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
