import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:irengineer/features/review/csv_import.dart';
import 'package:irengineer/widgets/track_map.dart';
import 'package:latlong2/latlong.dart';

import '../testutil/data.dart';

/// 1x1 white PNG for widget tests (avoids OSM network tiles).
final _testTileImage = MemoryImage(
  Uint8List.fromList(const <int>[
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4, 0x89, 0x00, 0x00, 0x00,
    0x0a, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9c, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0d, 0x0a, 0x2d, 0xb4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
  ]),
);

class _TestTileProvider extends TileProvider {
  @override
  ImageProvider<Object> getImage(
    TileCoordinates coordinates,
    TileLayer options,
  ) =>
      _testTileImage;
}

Widget _mapPanel({
  required double highlightedPct,
  ValueChanged<double>? onHighlight,
}) {
  final lap = loadLapSync(fixturePath('ref_lap_gps.csv'));
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 260,
        child: SingleChildScrollView(
          child: TrackMap(
            refLap: lap,
            candLap: null,
            highlightedPct: highlightedPct,
            onHighlight: onHighlight,
            tileProvider: _TestTileProvider(),
          ),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pctFromMapTap', () {
    test('maps nearest GPS point to lap pct', () {
      final lap = loadLapSync(fixturePath('ref_lap_gps.csv'));
      final pct = pctFromMapTap(lap, const LatLng(36.584300, -121.753200));
      expect(pct, closeTo(0.5, 0.01));
    });
  });

  group('isTrackMapTap', () {
    test('accepts small movement', () {
      expect(isTrackMapTap(Offset.zero, const Offset(4, 4)), isTrue);
    });

    test('rejects drag-sized movement', () {
      expect(isTrackMapTap(Offset.zero, const Offset(0, 80)), isFalse);
    });
  });

  testWidgets('pointer up on map updates highlight inside scroll view',
      (tester) async {
    double? tappedPct;
    await tester.pumpWidget(
      _mapPanel(
        highlightedPct: 0.0,
        onHighlight: (p) => tappedPct = p,
      ),
    );
    await tester.pump();

    final map = find.byType(FlutterMap);
    expect(map, findsOneWidget);

    final mapBox = tester.renderObject(map) as RenderBox;
    final center = mapBox.localToGlobal(
      Offset(mapBox.size.width / 2, mapBox.size.height / 2),
    );

    final gesture = await tester.startGesture(center);
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tappedPct, isNotNull);
    expect(tappedPct!, inInclusiveRange(0.0, 1.0));
  });

  testWidgets('drag on map does not update highlight', (tester) async {
    double? tappedPct;
    await tester.pumpWidget(
      _mapPanel(
        highlightedPct: 0.0,
        onHighlight: (p) => tappedPct = p,
      ),
    );
    await tester.pump();

    final map = find.byType(FlutterMap);
    final mapBox = tester.renderObject(map) as RenderBox;
    final start = mapBox.localToGlobal(
      Offset(mapBox.size.width / 2, mapBox.size.height / 2),
    );
    final end = start + const Offset(0, 80);

    final gesture = await tester.startGesture(start);
    await gesture.moveTo(end);
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tappedPct, isNull);
  });
}
