# Spike S2 — Wake word (sherpa_onnx) on-device viability

U7 is **gated** on this spike. The wake word ships behind a toggle that stays
**OFF by default** (Settings → Voice & wake word). This spike produces the
verdict that decides whether the wake word can be recommended/enabled — a
non-viable wake word must never degrade the app.

This is run **on the target device by you**. The arbitration state machine,
detection routing, and `stopServiceIfIdle` accounting are already covered by
unit tests (`test/services/wake_word_arbitration_test.dart`). The spike only
measures what unit tests **cannot**: real microphone capture and battery.

---

## What the spike must answer

| # | Question | How | Pass condition |
|---|----------|-----|----------------|
| (a) | Does a `microphone`-type FGS started **from the foreground** keep capturing after the app is backgrounded? | Start the wake word from the app (foreground), press Home, observe logcat for continued frame logs. | Frames keep arriving while backgrounded; the green mic dot stays in the status bar. |
| (b) | KeywordSpotter detection rate / false-wake rate on the chosen keyword | Say the keyword N=30 times in varied conditions; leave it running through normal speech/TV for 1 h. | Detection ≥ ~90%; false wakes ≤ ~1/hour for a distinctive phrase. |
| (c) | RAM / CPU and 24 h battery in duty-cycle | Leave enabled 24 h with normal use; read battery historian / `dumpsys batterystats`. | Battery cost ≤ `AppConstants.wakeWordMaxBatteryPctPerDay` (**3 %/day**). |

If (a) fails on the target OEM → document the OEM and fall back to
"screen-on only" wake or abandon. If (c) fails (> 3 %/day) → same fallback.
Either way the **toggle stays OFF by default**; the spike verdict only changes
the recommendation, never the default.

---

## How to run

### Desktop smoke (harness + seam shapes only — no model, no mic)

```bash
dart run tool/spike_wake_word.dart
```

This exercises the production seams (`KeywordDetector`, `AudioSource`) and the
`WakeWordService` routing/arbitration with a scripted detector and synthetic
audio. It proves the wiring compiles and the wake intent carries the voice
modality. It does NOT touch a real model or mic.

> Caveat: since `sherpa_onnx` is now a project dependency, a plain `dart run`
> on a desktop may fail with "Package(s) [objective_c] require the native
> assets feature" — that is the dependency graph resolving native assets, not a
> problem with the spike. The same logic is fully covered headless by
> `flutter test test/services/wake_word_arbitration_test.dart`; run that for
> the desktop smoke, and use the on-device path below for real measurements.

### On device (real engine + real mic)

1. Download the KWS model: Settings → Voice & wake word → enable → Download
   model. (Reuses `ModelDownloadManager`; files land in
   `<documents>/droidclaw_models/sherpa-kws-zipformer-en/`.)
2. In a **debug build**, bind the production seams to sherpa_onnx + the
   platform mic. The `SherpaKeywordDetector` reference implementation is at the
   bottom of `tool/spike_wake_word.dart` (commented out). The mic source feeds
   the dedicated microphone FGS (see manifest `.WakeWordService`).
3. Enable the wake word from the app foreground.

---

## How to read the verdict from logs

All wake word logs use `LogSource.app` with the `[WakeWord]` prefix
(visible in Settings → Logs and via logcat):

```bash
adb logcat -s flutter | grep '\[WakeWord\]'
```

Key lines:

- `[WakeWord] starting listener (keyword="...")` — start requested (foreground).
- `[WakeWord] listening` — mic engaged, consuming audio. **(a)** = keep seeing
  frame activity after pressing Home.
- `[WakeWord] suspend (sttActive|narratorSpeaking|radioPlaying|phoneCall)` /
  `[WakeWord] resume (...)` — arbitration transitions (verify the mic releases
  during STT / TTS / radio / calls).
- `[WakeWord] DETECTED "<keyword>" — waking` — a detection. Count these against
  the number of times you actually said the keyword for **(b)**.

For **(c)**, after a 24 h run:

```bash
adb shell dumpsys batterystats --charged com.droidclaw.app | grep -i "Computed drain\|Estimated"
```

Compare the per-day drain attributed to the app against **3 %/day**
(`wakeWordMaxBatteryPctPerDay`).

---

## Record the verdict here

| Date | Device / OEM / Android | (a) capture survives bg | (b) detection / false-wake | (c) battery %/day | Verdict |
|------|------------------------|-------------------------|----------------------------|-------------------|---------|
| _TODO_ | | | | | |

Verdict options:
- **viable** — recommend enabling; pin the model SHA-256 hashes in
  `AppConstants` (replace the `modelSha256Placeholder` values; the manager logs
  the computed hashes on first download).
- **screen-on only** — keep the toggle, restrict listening to screen-on.
- **deferred / abandoned** — document why; the toggle remains but shows
  "unavailable on this build".

> Note: the native microphone foreground service (`.WakeWordService` in the
> manifest) and the Dart↔native PCM bridge are **spike-gated**: the manifest
> entry is reserved (commented) and the engine binding is a documented
> reference. Ship them only once this verdict is positive.
