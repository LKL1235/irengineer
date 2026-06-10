---
title: Garage 61 CSV lap wrap flattens review telemetry and breaks map interaction
date: 2026-06-10
category: logic-errors
module: irengineer-review
problem_type: logic_error
component: frontend_stimulus
symptoms:
  - "Review charts show throttle pegged at 1 and brake at 0 for the entire lap despite valid Garage 61 CSV data"
  - "Speed trace shows ~50 with label m/s while drivers expect km/h-scale values"
  - "Corner segmentation reports no braking zones; delta coaching signals are wrong"
  - "Track map crashes with flutter_map cameraConstraint assertion or does not move the review cursor on tap"
root_cause: logic_error
resolution_type: code_fix
severity: high
tags:
  - garage-61
  - csv-import
  - lap-dist-pct
  - telemetry-resample
  - flutter-map
  - review-charts
related_components:
  - tooling
  - assistant
---

# Garage 61 CSV lap wrap flattens review telemetry and breaks map interaction

## Problem

After importing Garage 61 single-lap CSVs into the Flutter **Review** page, speed/brake/throttle traces looked wrong (flat inputs, m/s labeling), corner detection failed, and the GPS map either crashed or could not drive the shared lap cursor. Raw CSV parsing was correct; the failure happened during grid resampling and map wiring.

## Symptoms

- Throttle chart: horizontal line at 1.0 for nearly the full lap; brake chart flat at 0
- Speed labeled **m/s** (~50) instead of familiar **km/h** (~180)
- **未检测到赛道分段** — no corners because `brake > brakeThreshold` never fired on the resampled grid
- Map red error: `MapCamera is no longer within the cameraConstraint after an option change` (`flutter_map`)
- Clicking the map did not update the yellow cursor shared with trace charts

## What Didn't Work

- **Assuming wrong CSV column mapping** — runtime logs showed `brake:4`, `throttle:5` with thousands of samples where throttle &lt; 0.99 and brake &gt; 0.01; parsing was fine
- **Expecting 0–100% pedal values** — Garage 61 exports normalized 0–1 inputs; the flat charts were not a display-scale issue
- **Keeping `cameraConstraint: CameraConstraint.contain(bounds)`** — caused assertion failures when map options or bounds updated after analysis
- **Parent `GestureDetector` alone for map clicks** — `FlutterMap` consumes pointer events; map needed its own `onTap` → `onHighlight` path

## Solution

### 1. Trim the lap-wrap row on CSV import

Garage 61 CSV ends with a start/finish crossover row: `LapDistPct` drops from ~0.999 to ~0.00009. `_validateMonotonic` allows this wrap, but `interpolateAt` treats `pct >= samples.last.lapDistPct` as “use last sample.” Because the last row’s pct ≈ 0, **almost every grid point** resolved to that row (straight, full throttle).

After monotonic validation, detect `prev > 0.9 && cur < 0.1` and remove the wrapped tail row (and aligned GPS extras):

```dart
void _trimLapWraparound(List<LapSample> samples, CsvParseExtras extras) {
  final trimAt = _lapWrapTrimIndex(samples);
  if (trimAt >= samples.length) return;
  samples.removeRange(trimAt, samples.length);
  _trimExtrasFrom(trimAt, extras);
}
```

File: `irengineer/lib/domain/ref/csv.dart`

### 2. Display speed in km/h

Garage 61 `Speed` is iRacing-native m/s. Multiply by 3.6 in the chart selector and label **速度 (km/h)**.

File: `irengineer/lib/widgets/review_charts_panel.dart`

### 3. Fix map crash and cursor sync

- Remove `cameraConstraint` from `MapOptions`
- Add `onHighlight` to `TrackMap`; on map tap, find nearest GPS sample and call `onHighlight` with its `lapDistPct`

File: `irengineer/lib/widgets/track_map.dart`

### Regression test

```dart
test('trims Garage 61 lap wrap row at end', () {
  const csv = 'LapDistPct,Speed,Brake,Throttle\n'
      '0,40,0,1\n0.5,60,0.5,0\n0.99,50,0,1\n0.01,40,0,1\n';
  final s = parseCsvString(csv);
  expect(s.samples.length, 3);
  expect(s.samples.last.lapDistPct, closeTo(0.99, 0.001));
});
```

File: `irengineer/test/domain/ref/csv_test.dart`

## Why This Works

`resample()` builds a uniform 0..1 grid via `interpolateAt()`. When the final sample sits at pct ≈ 0, the early-exit branch `if (pct >= last.lapDistPct)` fires for ~99.9% of grid indices, cloning one telemetry frame across the lap. Trimming the wrap row leaves `last.lapDistPct` near 1.0, so interpolation spans the full lap. Map fixes are orthogonal: constraint removal stops the camera assertion; explicit `onTap` wiring connects map interaction to the shared highlight state.

**Before fix (analysis grid, ref lap):** `throttleMinMax: [1.0, 1.0]`, `brakeMinMax: [0.0, 0.0]`, `speedMinMax: [48.9, 49.4]`  
**After CSV parse (raw samples):** `throttleBelow099: 1465`, `brakeAbove001: 639`, `speedMinMax: [20.1, 57.5]`

## Prevention

- When adding CSV sources, inspect the **last rows** for `LapDistPct` wrap (0.99+ → &lt; 0.1) before trusting resampled grids
- Add a unit test whenever a new export format includes a start/finish duplicate row
- After `resample()`, assert grid `min(max(throttle)) > 0` or `min(max(brake)) > 0` on known braking laps in fixture tests
- For `flutter_map`, avoid tight `cameraConstraint` on dynamic bounds unless camera is reset when bounds change
- Wire new review widgets into the shared `onHighlight` callback (KTD-6) instead of relying on parent gesture detectors over interactive children

## Related Issues

- [ValidateTrackMatch compared incompatible lap fingerprints](iracing-coach-track-fingerprint-mismatch.md) — separate CSV reference validation issue in the same product domain; both affect Garage 61 CSV ingestion but different code paths
