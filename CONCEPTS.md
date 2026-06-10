# Concepts

> Shared domain vocabulary for this project — entities, named processes, and status concepts with project-specific meaning. Seeded with core domain vocabulary, then accretes as ce-compound and ce-compound-refresh process learnings; direct edits are fine. Glossary only, not a spec or catch-all.

## LapSeries

Internal normalized lap sample sequence used by both CSV reference loading and iRacing SDK export. Each sample carries distance progress, speed, brake, throttle, steer, and lateral acceleration on a 0..1 distance axis.

## LapDistPct wrap

Start/finish crossover row at the end of a Garage 61 single-lap CSV export: `LapDistPct` drops from near 1.0 back to near 0.0 on the final sample. Allowed by monotonic validation but must be trimmed before grid resampling, or interpolation treats almost the entire lap as that one early-straight sample.

## Review analysis grid

Uniform 0..1 resample of a lap series used by review charts, delta curves, and corner segmentation. Built from `interpolateAt` over trimmed samples; incorrect tail rows flatten throttle, brake, and speed traces and hide braking zones.

## CSVLapTime

Reference lap duration derived from CSV telemetry, not the Garage 61 filename. Priority: explicit LapTime/SessionTime columns when present; otherwise GPS Lat/Lon track length plus speed–distance integration (Σ Δpct × length / speed). Filename `MM.SS.mmm` is fallback only when CSV yields no positive lap time. Live lap time always comes from iRacing SDK `LapLastLapTime`; total lap delta is live minus reference CSV lap time.

## CoachReport

Structured coaching output after delta analysis and rule matching. Holds total lap delta, per-corner advice, top-three loss corners, optional race summary, and skip reason when a lap is invalid.

## ValidateTrackMatch

Reference-lap validator that rejects candidate laps whose track fingerprint diverges from the loaded CSV beyond 0.5%. Uses distance coverage when either lap lacks a lap time; uses estimated lap length in meters when both laps are timed.

## CoveragePct

Lap distance coverage derived from telemetry samples: the span of `LapDistPct` from minimum to maximum in a lap series. Used as the track fingerprint when lap time is unavailable (typical external CSV reference laps).

## ErrTrackMismatch

Error returned when reference and candidate lap fingerprints differ beyond threshold. Triggers a skip voice line instead of delta analysis — must not fire on valid CSV-ref versus SDK-lap pairs.

## Coach

The local voice coaching pipeline: ingest telemetry and reference CSV, compute delta at lap end, render template speech, optionally append race pace and cloud explanation.

## Speaker

Abstraction for lap-end text-to-speech: synthesize template text to audio, play on Windows, and support Cancel when a new lap preempts the queue. Implementations must not load neural models inside the coach process.

## TTS Engine

The local speech synthesis backend selected by configuration. Default product direction is Sherpa-ONNX offline CLI with Piper-compatible Chinese neural models; Windows SAPI is an optional low-quality fallback only.

## TTSSidecar

Deferred optional long-running local service that keeps a TTS model warm in memory to reduce first-sentence latency. Not required for v1.1 when subprocess plus WAV cache meets lap-end timing goals.

## SettingsStore

Machine-managed JSON persistence for coach preferences at `%LocalAppData%/irengineer/settings.json`. Replaces user-edited YAML; written only by the settings UI or install actions.

## VoiceModelDir

Default TTS asset root beside the application executable at `voice_model/` (`bin/` for Sherpa runtime, `models/` for Piper-compatible ONNX). Override via `tts_root_dir` in settings. Installs may also use `%LocalAppData%/irengineer/tts/`. Model choice (`tts_model_choice`, e.g. `huayan-medium`, `xiao_ya-medium`) is selected in the settings UI before install.

## SetupWizard

First-run flow in the settings UI: apply built-in defaults, then require reference CSV selection and one-click TTS engine install before coaching starts.

## LinuxPracticeStub

Practice tab behavior on Linux desktop builds: the tab remains in navigation for UI parity with Windows, but the page shows that live coaching requires Windows and iRacing. No SDK polling, TTS, or ReadyGate blocking on Linux.

## AgentFixtureLoad

Deterministic CSV import path for Cloud Agent and CI on Linux, bypassing the native file dialog. Loads known samples from the repo `data/` directory via environment variable, launch argument, or maintainer-only entry so the review golden path is reproducible without manual file picking.
