package com.droidclaw.app

import android.content.ComponentName
import android.content.Context
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import com.google.common.util.concurrent.ListenableFuture
import com.google.common.util.concurrent.MoreExecutors
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter plugin that bridges Dart to [RadioPlaybackService] via MediaController.
 *
 * MethodChannel: play, pause, resume, stop, getState
 * EventChannel:  streams playback state changes to Dart
 */
class RadioPlayerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context

    private var controllerFuture: ListenableFuture<MediaController>? = null
    private var controller: MediaController? = null
    private var eventSink: EventChannel.EventSink? = null

    private val playerListener = object : Player.Listener {
        override fun onIsPlayingChanged(isPlaying: Boolean) = pushState()
        override fun onPlaybackStateChanged(playbackState: Int) = pushState()
        override fun onPlayerError(error: androidx.media3.common.PlaybackException) {
            eventSink?.success(
                mapOf(
                    "type" to "error",
                    "code" to error.errorCode,
                    "message" to (error.message ?: "Unknown playback error"),
                )
            )
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, "com.droidclaw.app/radio")
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "com.droidclaw.app/radio_events")
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        releaseController()
    }

    // -- MethodChannel --

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "play" -> {
                val url = call.argument<String>("url")
                val title = call.argument<String>("title")
                if (url == null) {
                    result.error("INVALID_ARG", "Missing 'url' argument", null)
                    return
                }
                ensureController {
                    play(url, title ?: "Radio")
                    result.success(null)
                }
            }
            "pause" -> {
                controller?.pause()
                result.success(null)
            }
            "resume" -> {
                controller?.play()
                result.success(null)
            }
            "stop" -> {
                controller?.let {
                    it.stop()
                    it.clearMediaItems()
                }
                result.success(null)
            }
            "getState" -> {
                val ctrl = controller
                if (ctrl == null || !ctrl.isConnected) {
                    result.success(
                        mapOf(
                            "state" to "idle",
                            "isPlaying" to false,
                            "station" to null,
                        )
                    )
                } else {
                    result.success(buildStateMap(ctrl))
                }
            }
            else -> result.notImplemented()
        }
    }

    // -- EventChannel --

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    // -- Internals --

    private fun ensureController(onReady: () -> Unit) {
        val existing = controller
        if (existing != null && existing.isConnected) {
            onReady()
            return
        }

        val token = SessionToken(context, ComponentName(context, RadioPlaybackService::class.java))
        controllerFuture = MediaController.Builder(context, token).buildAsync().also { future ->
            future.addListener({
                val ctrl = future.get()
                controller = ctrl
                ctrl.addListener(playerListener)
                onReady()
            }, MoreExecutors.directExecutor())
        }
    }

    private fun play(url: String, title: String) {
        controller?.let { ctrl ->
            val mediaItem = MediaItem.Builder()
                .setUri(url)
                .setMediaMetadata(
                    MediaMetadata.Builder()
                        .setTitle(title)
                        .setIsPlayable(true)
                        .build()
                )
                .build()
            ctrl.setMediaItem(mediaItem)
            ctrl.prepare()
            ctrl.play()
        }
    }

    private fun pushState() {
        val ctrl = controller ?: return
        eventSink?.success(buildStateMap(ctrl))
    }

    private fun buildStateMap(ctrl: MediaController): Map<String, Any?> {
        val stateName = when (ctrl.playbackState) {
            Player.STATE_IDLE -> "idle"
            Player.STATE_BUFFERING -> "buffering"
            Player.STATE_READY -> if (ctrl.isPlaying) "playing" else "paused"
            Player.STATE_ENDED -> "ended"
            else -> "unknown"
        }
        val title = ctrl.currentMediaItem?.mediaMetadata?.title?.toString()
        return mapOf(
            "type" to "state",
            "state" to stateName,
            "isPlaying" to ctrl.isPlaying,
            "station" to title,
        )
    }

    private fun releaseController() {
        controller?.removeListener(playerListener)
        controllerFuture?.let { MediaController.releaseFuture(it) }
        controller = null
        controllerFuture = null
    }
}
