---
title: ValidateTrackMatch compared incompatible lap fingerprints (CSV coverage vs SDK distance)
date: 2026-06-09
category: logic-errors
module: irengineer
problem_type: logic_error
component: assistant
severity: critical
symptoms:
  - "Every live SDK lap fails ValidateTrackMatch with ErrTrackMismatch and coaching analysis is skipped"
  - "Logs show ref fingerprint near 1.0 (CoveragePct) vs candidate fingerprint in thousands (LapTimeSec times avg speed)"
  - "Coach speaks only track-mismatch skip lines; no delta or corner feedback on valid laps"
  - "Unit tests pass for CSV-to-CSV pairs but production path CSV ref plus SDK lap was untested"
root_cause: logic_error
resolution_type: code_fix
tags:
  - irengineer
  - validate-track-match
  - track-fingerprint
  - csv-reference
  - sdk-laps
  - coverage-pct
related_components:
  - service_object
  - tooling
---

# ValidateTrackMatch compared incompatible lap fingerprints (CSV coverage vs SDK distance)

## Problem

`validateTrackMatch` in `irengineer/lib/domain/ref/track_match.dart` compared reference and candidate laps using a single `fingerprint()` helper that returned different physical quantities depending on whether `LapTimeSec` was set. CSV reference laps (no lap time) produced `CoveragePct` ≈ 1.0, while live SDK laps produced `LapTimeSec × avgSpeed` ≈ thousands of meters. Every live lap was rejected as a track mismatch, so the coach never ran delta analysis.

## Symptoms

- Each completed lap triggered `SkipReason: track_mismatch` and a short skip voice line instead of coaching feedback
- Logs showed errors like `ref=1.0000 cand=2700.x diff=270000%` relative to the 0.5% threshold
- `go test ./internal/ref/...` passed because tests only used CSV-style laps without `LapTimeSec`
- End-to-end behavior: coach appeared running but produced no useful lap feedback in iRacing

## What Didn't Work

- **Unified `fingerprint()` comparison** — one function returned 0..1 coverage for CSV refs and meter-scale estimates for SDK laps; dividing their difference by refFP always exceeded `trackMismatchThreshold` (0.005)
- **Setting `TrackLenM` on CSV load** — when `LapTimeSec` is zero, `LengthM()` also resolves to `CoveragePct`, so it did not fix the comparison path
- **Golden delta tests alone** — `TestGoldenDelta` compares two CSV files (both without `LapTimeSec`); it never exercises the production CSV-ref + SDK-candidate path

## Solution

Branch `ValidateTrackMatch` by whether both laps have lap times. When either side lacks `LapTimeSec` (typical CSV reference vs SDK candidate), compare `CoveragePct` only. When both have lap times, compare estimated track length in meters.

```go
func ValidateTrackMatch(ref, cand lap.Series) error {
	// When reference has no lap time (typical CSV), compare distance coverage only.
	if ref.LapTimeSec <= 0 || cand.LapTimeSec <= 0 {
		refFP := ref.CoveragePct()
		candFP := cand.CoveragePct()
		if refFP <= 0 {
			return nil
		}
		diff := math.Abs(refFP-candFP) / refFP
		if diff > trackMismatchThreshold {
		 return fmt.Errorf("%w: ref coverage=%.4f cand coverage=%.4f diff=%.2f%%",
				ErrTrackMismatch, refFP, candFP, diff*100)
		}
		return nil
	}
	refLen := ref.LapTimeSec * avgSpeedSamples(ref.Samples)
	candLen := cand.LapTimeSec * avgSpeedSamples(cand.Samples)
	// ... meter comparison when both laps timed
}
```

Add a regression test for the production path:

```go
func TestLiveLapMatchesCSVRef(t *testing.T) {
	ref := lapFromPct([]float64{0, 0.5, 1.0}, 50) // CSV-like: no LapTimeSec
	cand := lapFromPct([]float64{0, 0.5, 1.0}, 48)
	cand.LapTimeSec = 90 // SDK-like
	if err := ValidateTrackMatch(ref, cand); err != nil {
		t.Fatalf("live lap should match CSV ref coverage: %v", err)
	}
}
```

**Same code-review pass also fixed:**

| File | Change |
|------|--------|
| `cmd/coach/run.go` | `lapMu sync.Mutex` around `lapTimes` (goroutine data race) |
| `internal/coach/queue.go` | Remove duplicate `Cancel()` in `EnqueueLap` |
| `internal/cloud/client.go` | `io.LimitReader(resp.Body, 1<<20)` on LLM responses |

## Why This Works

CSV reference laps from `LoadCSV` never carry `LapTimeSec`. SDK laps from `lapBuf.ExportLastLap(snap.LapLastLapTime)` always do. The old helper mixed dimensions; the fix compares like-with-like:

- **Coverage path** — both sides expose `LapDistPct` samples; comparing max−min coverage detects truncated or wrong-track exports without needing lap time
- **Length path** — when both laps are timed, `LapTimeSec × avgSpeed` estimates are in the same units (meters)

The 0.5% threshold from requirements R2 / plan U3 now applies to meaningful quantities.

## Prevention

1. **Never compare heterogeneous fingerprints** — split helpers explicitly (`coverageFingerprint` vs `lengthFingerprint`) or branch in the validator; document which path each data source uses
2. **Test cross-source pairs** — for every validator, add at least one test where ref and cand come from different ingest paths (CSV vs SDK mock)
3. **Smoke in live sim** — after a lap, log must show `lap analyzed` with `delta_s`, not `track mismatch`
4. **Race-test concurrent paths** — run `go test -race ./...` on packages that spawn goroutines touching shared state (`cmd/coach`, `internal/coach`)

## Related Issues

- Requirements: `docs/brainstorms/2026-06-09-iracing-lap-coach-requirements.md` (R2, AE2)
- Plan: `docs/plans/2026-06-09-001-feat-iracing-lap-coach-plan.md` (U3, KTD-3)
- Code review findings (remaining): LLM async ordering, IRSDK triple-buffer rotation — see review session, not yet documented here
