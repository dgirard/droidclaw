package com.droidclaw.app

import android.content.Context
import android.media.AudioManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter plugin that exposes Android AudioManager via a MethodChannel.
 *
 * Supports getting/setting volume per stream and reading ringer mode.
 * Uses applicationContext so it works from both Activity and Service contexts.
 */
class AudioChannelPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var audioManager: AudioManager

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        audioManager = binding.applicationContext
            .getSystemService(Context.AUDIO_SERVICE) as AudioManager
        channel = MethodChannel(binding.binaryMessenger, "com.droidclaw.app/audio")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getStreamVolume" -> {
                val stream = call.argument<Int>("stream")
                if (stream == null) {
                    result.error("INVALID_ARG", "Missing 'stream' argument", null)
                    return
                }
                result.success(audioManager.getStreamVolume(stream))
            }
            "getStreamMaxVolume" -> {
                val stream = call.argument<Int>("stream")
                if (stream == null) {
                    result.error("INVALID_ARG", "Missing 'stream' argument", null)
                    return
                }
                result.success(audioManager.getStreamMaxVolume(stream))
            }
            "setStreamVolume" -> {
                val stream = call.argument<Int>("stream")
                val volume = call.argument<Int>("volume")
                if (stream == null || volume == null) {
                    result.error("INVALID_ARG", "Missing 'stream' or 'volume' argument", null)
                    return
                }
                val flags = call.argument<Int>("flags") ?: 0
                audioManager.setStreamVolume(stream, volume, flags)
                result.success(null)
            }
            "getRingerMode" -> {
                result.success(audioManager.ringerMode)
            }
            else -> result.notImplemented()
        }
    }
}
