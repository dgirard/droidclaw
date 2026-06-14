// ignore_for_file: avoid_print — CLI spike harness, prints ARE the output.

// U7 / Spike S2 — wake word (sherpa_onnx KeywordSpotter) on-device viability.
//
// THIS IS A SPIKE, RUN ON THE TARGET DEVICE BY THE USER. It is NOT part of the
// test suite and NOT shipped in the app. It exists to produce the verdict that
// gates U7: the wake word ships behind a toggle that stays OFF until this
// spike confirms on-device viability (see tool/SPIKE_WAKE_WORD.md for the
// checklist + how to read the verdict from logs).
//
// What the spike must answer (plan U7 "Approach", Risks "Indicateur micro"):
//   (a) Does a microphone-type FGS started FROM THE FOREGROUND keep capturing
//       after the app is backgrounded on the target device? (Android 14+ +
//       OEM-specific FGS killing.)  → manual, observed on device (see doc).
//   (b) KeywordSpotter detection rate / false-wake rate on the chosen keyword.
//   (c) RAM/CPU and 24 h battery in duty-cycle.
//       → battery gate: AppConstants.wakeWordMaxBatteryPctPerDay (3 %/day).
//
// HOW TO RUN
//   Desktop smoke (no model, no mic — checks the harness + seam shapes only):
//     dart run tool/spike_wake_word.dart
//   On device (real engine + real mic) the same KeywordDetector /
//   AudioSource seams used by lib/core/services/wake_word_service.dart are
//   bound to sherpa_onnx + the platform mic; wire them in the app's debug
//   build and watch logcat (see the doc). The arbitration + routing logic is
//   already unit-tested (test/services/wake_word_arbitration_test.dart) — the
//   spike only measures what unit tests CANNOT: real capture and battery.

import 'dart:typed_data';

import 'package:droidclaw/core/services/wake_word_service.dart';
import 'package:droidclaw/shared/constants.dart';

/// A scripted [KeywordDetector] for the desktop smoke run: it "detects" the
/// keyword on the Nth frame so the harness can exercise the wake routing path
/// without a real ONNX model. On device, swap for the sherpa binding (see
/// _SherpaKeywordDetector sketch below).
class _ScriptedDetector implements KeywordDetector {
  final String hitOn;
  int _frames = 0;
  String? _keyword;

  _ScriptedDetector({this.hitOn = 'never'});

  @override
  Future<void> start({required String keyword}) async {
    _keyword = keyword;
    print('[spike] detector.start(keyword="$keyword")');
  }

  @override
  String? acceptWaveform(Int16List frame) {
    _frames++;
    if (hitOn == 'frame3' && _frames == 3) return _keyword;
    return null;
  }

  @override
  void reset() => print('[spike] detector.reset()');

  @override
  Future<void> stop() async => print('[spike] detector.stop()');
}

/// A finite synthetic [AudioSource] for the desktop smoke run: emits a handful
/// of silent PCM frames then completes. On device, swap for a mic-backed
/// source feeding the dedicated microphone FGS capture.
class _SyntheticAudioSource implements AudioSource {
  final int frameCount;
  final _controller = _SimpleController();

  _SyntheticAudioSource({this.frameCount = 5});

  @override
  Stream<Int16List> get frames => _controller.stream;

  @override
  Future<void> start() async {
    print('[spike] audio.start() — emitting $frameCount synthetic frames');
    for (var i = 0; i < frameCount; i++) {
      _controller.add(Int16List(AppConstants.wakeWordFrameSamples));
    }
  }

  @override
  Future<void> stop() async {
    print('[spike] audio.stop()');
    _controller.close();
  }
}

// Minimal broadcast-stream wrapper to avoid importing dart:async ceremony.
class _SimpleController {
  final _subs = <void Function(Int16List)>[];
  Stream<Int16List> get stream => Stream.multi((c) {
        void on(Int16List f) => c.add(f);
        _subs.add(on);
      });
  void add(Int16List f) {
    for (final s in List.of(_subs)) {
      s(f);
    }
  }

  void close() => _subs.clear();
}

Future<void> main() async {
  print('=== U7 wake word spike (S2) — desktop smoke run ===');
  print('Battery gate: <= ${AppConstants.wakeWordMaxBatteryPctPerDay}%/day');
  print('Frame: ${AppConstants.wakeWordFrameSamples} samples @ '
      '${AppConstants.wakeWordSampleRate} Hz');
  print('');

  var wakes = 0;
  final service = WakeWordService(
    detector: _ScriptedDetector(hitOn: 'frame3'),
    audio: _SyntheticAudioSource(frameCount: 5),
    keyword: AppConstants.wakeWordDefaultKeyword,
    onWake: (intent) {
      wakes++;
      print('[spike] WAKE #$wakes — modality=${intent.modality.name} '
          'keyword="${intent.keyword}"');
    },
  );

  await service.start();
  // Give the synthetic frames a microtask to drain.
  await Future<void>.delayed(const Duration(milliseconds: 50));

  print('');
  print('[spike] arbitration smoke: suspend(sttActive) then resume');
  await service.suspend(WakeWordSuspendReason.sttActive);
  print('[spike]   canListen while suspended = ${service.canListen}');
  await service.resume(WakeWordSuspendReason.sttActive);
  print('[spike]   canListen after resume    = ${service.canListen}');

  await service.stop();
  service.dispose();

  print('');
  print('[spike] desktop smoke complete — wakes routed: $wakes');
  print('[spike] On-device measurements (capture survival, detection/false-'
      'wake rate, battery) are MANUAL — see tool/SPIKE_WAKE_WORD.md.');
}

// ---------------------------------------------------------------------------
// ON-DEVICE BINDING SKETCH (spike-gated — do NOT wire into the app until the
// spike verdict is positive). Implements the production seams against
// sherpa_onnx. Kept here as a reference so the spike runner can paste it into
// a debug build; commented out so this file stays runnable on the desktop
// without the native libs.
// ---------------------------------------------------------------------------
//
// import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
//
// class SherpaKeywordDetector implements KeywordDetector {
//   final String modelDir;            // ModelDownloadManager.modelDir(wakeWordKws)
//   sherpa.KeywordSpotter? _spotter;
//   sherpa.OnlineStream? _stream;
//
//   SherpaKeywordDetector(this.modelDir);
//
//   @override
//   Future<void> start({required String keyword}) async {
//     sherpa.initBindings();
//     final cfg = sherpa.KeywordSpotterConfig(
//       model: sherpa.OnlineModelConfig(
//         transducer: sherpa.OnlineTransducerModelConfig(
//           encoder: '$modelDir/${AppConstants.wakeWordEncoderFilename}',
//           decoder: '$modelDir/${AppConstants.wakeWordDecoderFilename}',
//           joiner:  '$modelDir/${AppConstants.wakeWordJoinerFilename}',
//         ),
//         tokens: '$modelDir/${AppConstants.wakeWordTokensFilename}',
//       ),
//     );
//     _spotter = sherpa.KeywordSpotter(cfg);
//     // Open-vocabulary: keyword is supplied as a tokenized phrase line.
//     _stream = _spotter!.createStream(keywords: keyword);
//   }
//
//   @override
//   String? acceptWaveform(Int16List frame) {
//     final s = _stream!, sp = _spotter!;
//     final f = Float32List(frame.length);
//     for (var i = 0; i < frame.length; i++) f[i] = frame[i] / 32768.0;
//     s.acceptWaveform(samples: f, sampleRate: AppConstants.wakeWordSampleRate);
//     while (sp.isReady(s)) sp.decode(s);
//     final r = sp.getResult(s);
//     return r.keyword.isEmpty ? null : r.keyword;
//   }
//
//   @override
//   void reset() => _spotter!.reset(_stream!);
//
//   @override
//   Future<void> stop() async {
//     _stream?.free();
//     _spotter?.free();
//     _stream = null;
//     _spotter = null;
//   }
// }
