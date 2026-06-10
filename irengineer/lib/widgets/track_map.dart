import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../features/review/models.dart';

class TrackMap extends StatelessWidget {
  const TrackMap({
    super.key,
    required this.refLap,
    required this.candLap,
    required this.highlightedPct,
    this.onHighlight,
  });

  final ImportedLap? refLap;
  final ImportedLap? candLap;
  final double highlightedPct;
  final ValueChanged<double>? onHighlight;

  @override
  Widget build(BuildContext context) {
    final ref = refLap;
    final cand = candLap;
    if (ref == null || !ref.hasGps) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            ref == null ? '选择圈速后显示地图' : 'CSV 无 GPS 列，地图已隐藏',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final refPoints = _toLatLng(ref.lats, ref.lons);
    final candPoints = cand != null && cand.hasGps
        ? _toLatLng(cand.lats, cand.lons)
        : <LatLng>[];
    final all = [...refPoints, ...candPoints];
    if (all.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('无有效 GPS 坐标'),
        ),
      );
    }

    final bounds = LatLngBounds.fromPoints(all);
    final center = bounds.center;
    final marker = _interpPoint(ref, highlightedPct);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 220,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 15,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onTap: (tapPos, latLng) {
              final pct = _pctFromTap(ref, latLng);
              if (pct != null) {
                onHighlight?.call(pct);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.iracingcoach.app',
            ),
            if (candPoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: candPoints,
                    color: Colors.orange.withValues(alpha: 0.85),
                    strokeWidth: 3,
                  ),
                ],
              ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: refPoints,
                  color: Colors.blue.withValues(alpha: 0.9),
                  strokeWidth: 3,
                ),
              ],
            ),
            if (marker != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: marker,
                    width: 16,
                    height: 16,
                    child: const Icon(
                      Icons.place,
                      color: Colors.amber,
                      size: 20,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  List<LatLng> _toLatLng(List<double> lats, List<double> lons) {
    final out = <LatLng>[];
    for (var i = 0; i < lats.length; i++) {
      out.add(LatLng(lats[i], lons[i]));
    }
    return out;
  }

  LatLng? _interpPoint(ImportedLap lap, double pct) {
    final samples = lap.series.samples;
    if (samples.length < 2 ||
        lap.lats.length != samples.length ||
        lap.lons.length != samples.length) {
      final idx = (pct * (lap.lats.length - 1)).round().clamp(0, lap.lats.length - 1);
      if (lap.lats.isEmpty) {
        return null;
      }
      return LatLng(lap.lats[idx], lap.lons[idx]);
    }
    for (var i = 1; i < samples.length; i++) {
      final b = samples[i];
      final a = samples[i - 1];
      if (b.lapDistPct >= pct) {
        final span = b.lapDistPct - a.lapDistPct;
        final t = span > 0 ? (pct - a.lapDistPct) / span : 0.0;
        final lat = a.lapDistPct == pct
            ? lap.lats[i - 1]
            : _lerp(lap.lats[i - 1], lap.lats[i], t);
        final lon = a.lapDistPct == pct
            ? lap.lons[i - 1]
            : _lerp(lap.lons[i - 1], lap.lons[i], t);
        return LatLng(lat, lon);
      }
    }
    return LatLng(lap.lats.last, lap.lons.last);
  }

  double? _pctFromTap(ImportedLap lap, LatLng tap) {
    final samples = lap.series.samples;
    if (lap.lats.length < 2 || lap.lons.length != lap.lats.length) {
      return null;
    }
    var bestIdx = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < lap.lats.length; i++) {
      final d = _planarDist2(
        tap.latitude,
        tap.longitude,
        lap.lats[i],
        lap.lons[i],
      );
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    if (bestIdx < samples.length) {
      return samples[bestIdx].lapDistPct.clamp(0.0, 1.0);
    }
    return (bestIdx / (lap.lats.length - 1)).clamp(0.0, 1.0);
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  double _planarDist2(double lat1, double lon1, double lat2, double lon2) {
    final dLat = lat2 - lat1;
    final dLon = lon2 - lon1;
    return dLat * dLat + dLon * dLon;
  }
}
