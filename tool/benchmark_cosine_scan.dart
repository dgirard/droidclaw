// ignore_for_file: avoid_print — CLI benchmark script, prints are the output.

// U14 decision benchmark: inline cosine scan vs Isolate.run for the
// knowledge-graph vector path (queryRelevant).
//
// Run manually (NOT part of the test suite):
//   dart run tool/benchmark_cosine_scan.dart
//
// Measures, at 1K and 5K entities x 768-dim Float32 embeddings:
//   1. inline scan  — deserialize each BLOB + cosine, on the calling isolate
//      (exactly what KnowledgeService._scanEmbeddings does per page).
//   2. Isolate.run  — same scan, but the full List<Uint8List> of BLOBs is
//      shipped to a fresh isolate (includes the send/copy cost) and the
//      score map shipped back.
//
// CAVEAT: numbers are from the dev machine (Apple Silicon), not a mid-range
// Android phone. Expect the phone to be ~5-10x slower on the scalar scan and
// at least as much slower on the isolate message copy; the RATIO between the
// two strategies is what drives the decision, and the copy overhead only
// grows on slower memory subsystems.
//
// RECORDED RESULT (2026-06-10, Apple Silicon dev machine, Dart 3.x AOT-less):
//   1000 x 768 (2.9 MB):  inline 1.13 ms   Isolate.run 1.58 ms
//   5000 x 768 (14.6 MB): inline 5.54 ms   Isolate.run 11.05 ms
// Isolate.run is ~2x WORSE at 5K — the blob copy dominates the scan itself.
// U14 decision: keep the scan inline on the agent isolate, but restructure it
// as a keyset-paged scan in the DB layer (bounded memory, covers ALL
// entities, no 1000-row cap, no retained 3-15 MB embedding list). sqlite-vec
// stays out (native dependency; not needed at these timings).

import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

const dims = 768;

/// Verbatim copy of [MemoryClusterer.cosineSimilarity] so this script has no
/// package imports (the app package pulls plugins that `dart run` cannot
/// resolve outside a Flutter build). Keep in sync if the original changes.
double cosineSimilarity(Float32List a, Float32List b) {
  if (a.length != b.length || a.isEmpty) return 0.0;
  var dot = 0.0;
  var normA = 0.0;
  var normB = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }
  final denom = sqrt(normA) * sqrt(normB);
  if (denom == 0) return 0.0;
  return dot / denom;
}
const iterations = 20;

List<Uint8List> makeBlobs(int count, Random rng) {
  return List.generate(count, (_) {
    final v = Float32List.fromList(
      List.generate(dims, (_) => rng.nextDouble() * 2 - 1),
    );
    return v.buffer.asUint8List();
  });
}

Map<int, double> scan(List<Uint8List> blobs, Float32List queryVec) {
  final scores = <int, double>{};
  for (var i = 0; i < blobs.length; i++) {
    final entVec = Float32List.view(Uint8List.fromList(blobs[i]).buffer);
    if (entVec.length != queryVec.length) continue;
    final sim = cosineSimilarity(queryVec, entVec);
    if (sim > 0.5) scores[i] = sim;
  }
  return scores;
}

Future<double> timeMs(Future<void> Function() body) async {
  // Warm-up.
  await body();
  await body();
  final sw = Stopwatch();
  final samples = <double>[];
  for (var i = 0; i < iterations; i++) {
    sw
      ..reset()
      ..start();
    await body();
    sw.stop();
    samples.add(sw.elapsedMicroseconds / 1000.0);
  }
  samples.sort();
  return samples[samples.length ~/ 2]; // median
}

Future<void> main() async {
  final rng = Random(42);
  final queryVec = Float32List.fromList(
    List.generate(dims, (_) => rng.nextDouble() * 2 - 1),
  );

  for (final count in [1000, 5000]) {
    final blobs = makeBlobs(count, rng);
    final bytes = count * dims * 4;

    final inlineMs = await timeMs(() async {
      scan(blobs, queryVec);
    });

    final isolateMs = await timeMs(() async {
      await Isolate.run(() => scan(blobs, queryVec));
    });

    print('--- $count entities x $dims dims '
        '(${(bytes / 1024 / 1024).toStringAsFixed(1)} MB of embeddings) ---');
    print('inline scan        median: ${inlineMs.toStringAsFixed(2)} ms');
    print('Isolate.run total  median: ${isolateMs.toStringAsFixed(2)} ms '
        '(includes blob copy to isolate + result copy back)');
  }
}
