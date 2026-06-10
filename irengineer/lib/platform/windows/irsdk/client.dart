import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../../../domain/lap/series.dart';
import 'types.dart';

const _memMapName = r'Local\IRSDKMemMapFileName';
const _fileMapRead = 0x0004;
const _statusConnected = 0x0001;

typedef _OpenFileMappingNative = IntPtr Function(
  Uint32 dwDesiredAccess,
  Int32 bInheritHandle,
  Pointer<Utf16> lpName,
);
typedef _OpenFileMappingDart = int Function(
  int dwDesiredAccess,
  int bInheritHandle,
  Pointer<Utf16> lpName,
);

typedef _MapViewOfFileNative = Pointer Function(
  IntPtr hFileMappingObject,
  Uint32 dwDesiredAccess,
  Uint32 dwFileOffsetHigh,
  Uint32 dwFileOffsetLow,
  IntPtr dwNumberOfBytesToMap,
);
typedef _MapViewOfFileDart = Pointer Function(
  int hFileMappingObject,
  int dwDesiredAccess,
  int dwFileOffsetHigh,
  int dwFileOffsetLow,
  int dwNumberOfBytesToMap,
);

typedef _UnmapViewOfFileNative = Int32 Function(Pointer lpBaseAddress);
typedef _UnmapViewOfFileDart = int Function(Pointer lpBaseAddress);

final _kernel32 = DynamicLibrary.open('kernel32.dll');
final _openFileMapping = _kernel32.lookupFunction<_OpenFileMappingNative, _OpenFileMappingDart>(
  'OpenFileMappingW',
);
final _mapViewOfFile = _kernel32.lookupFunction<_MapViewOfFileNative, _MapViewOfFileDart>(
  'MapViewOfFile',
);
final _unmapViewOfFile = _kernel32.lookupFunction<_UnmapViewOfFileNative, _UnmapViewOfFileDart>(
  'UnmapViewOfFile',
);

/// Reads iRacing shared memory on Windows (Dart port aligned with Go client_windows.go).
class IrSdkClient implements TelemetryProvider {
  IrSdkClient._();

  Pointer<Uint8>? _view;
  int _mapSize = 0;
  final Map<String, _VarInfo> _vars = {};
  String _sessionYaml = '';

  static Future<IrSdkClient?> open() async {
    if (!Platform.isWindows) {
      return null;
    }
    final client = IrSdkClient._();
    try {
      client._connect();
      return client;
    } catch (_) {
      await client.close();
      return null;
    }
  }

  void _connect() {
    final name = _memMapName.toNativeUtf16();
    try {
      final h = _openFileMapping(_fileMapRead, FALSE, name);
      if (h == 0) {
        throw StateError('iRacing shared memory not found');
      }
      try {
        final view = _mapViewOfFile(h, _fileMapRead, 0, 0, 0);
        if (view.address == 0) {
          throw StateError('MapViewOfFile failed');
        }
        _view = view.cast<Uint8>();
        _parseHeaders();
      } finally {
        CloseHandle(h);
      }
    } finally {
      calloc.free(name);
    }
  }

  void _parseHeaders() {
    final view = _view!;
    final hdr = _readHeader(view);
    // Go: unsafeSlice(view, header.BufferLength + 1024) — field at index 8.
    _mapSize = hdr.bufferLength + 1024;
    _vars.clear();

    final base = hdr.varHeaderOffset;
    for (var i = 0; i < hdr.numVars; i++) {
      final off = base + i * 144;
      final name = _cstring(view, off, 32);
      final i32 = view.cast<Int32>();
      final word = off ~/ 4;
      final type = i32[word];
      final varOffset = i32[word + 1];
      final count = i32[word + 2];
      _vars[name.toLowerCase()] = _VarInfo(
        offset: varOffset,
        count: count,
        type: type,
      );
    }
  }

  _Header _readHeader(Pointer<Uint8> view) {
    final i32 = view.cast<Int32>();
    return _Header(
      version: i32[0],
      status: i32[1],
      tickRate: i32[2],
      sessionInfoUpdate: i32[3],
      sessionInfoLen: i32[4],
      sessionInfoOffset: i32[5],
      numVars: i32[6],
      varHeaderOffset: i32[7],
      bufferLength: i32[8],
    );
  }

  Uint8List _bytes(Pointer<Uint8> view) => view.asTypedList(_mapSize);

  @override
  bool get connected {
    final view = _view;
    if (view == null) {
      return false;
    }
    return _readHeader(view).status & _statusConnected != 0;
  }

  @override
  IrSdkSnapshot readSnapshot() {
    final view = _view;
    if (view == null) {
      return const IrSdkSnapshot();
    }
    final hdr = _readHeader(view);
    final isConnected = hdr.status & _statusConnected != 0;
    if (!isConnected) {
      return const IrSdkSnapshot(connected: false);
    }

    final yaml = _sessionYamlFrom(view, hdr);
    const n = 64;
    final positions = List<int>.filled(n, 0);
    final lapTimes = List<double>.filled(n, 0);
    final f2 = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      positions[i] = _getIndexedFloat(view, 'CarIdxPosition', i).round();
      lapTimes[i] = _getIndexedFloat(view, 'CarIdxLastLapTime', i);
      f2[i] = _getIndexedFloat(view, 'CarIdxF2Time', i);
    }

    return IrSdkSnapshot(
      connected: true,
      lap: _getFloat(view, 'Lap').round(),
      lapCompleted: _getFloat(view, 'LapCompleted').round(),
      lapLastLapTime: _getFloat(view, 'LapLastLapTime'),
      sessionTimeRemain: _getFloat(view, 'SessionTimeRemain'),
      onPitRoad: _getFloat(view, 'OnPitRoad') > 0.5,
      playerCarPosition: _getFloat(view, 'PlayerCarPosition').round(),
      sessionType: _parseSessionType(yaml),
      carIdxPosition: positions,
      carIdxLastLapTime: lapTimes,
      carIdxF2Time: f2,
    );
  }

  @override
  LapSample pollSample() {
    final view = _view;
    if (view == null || !connected) {
      throw StateError('irsdk not connected');
    }
    return LapSample(
      lapDistPct: _getFloat(view, 'LapDistPct'),
      speed: _getFloat(view, 'Speed'),
      brake: _getFloat(view, 'Brake'),
      throttle: _getFloat(view, 'Throttle'),
      steer: _getFloat(view, 'SteeringWheelAngle'),
      latAccel: _getFloat(view, 'LatAccel'),
    );
  }

  @override
  Future<void> close() async {
    final view = _view;
    if (view != null) {
      _unmapViewOfFile(view.cast());
      _view = null;
    }
  }

  double _getFloat(Pointer<Uint8> view, String name) {
    final v = _vars[name.toLowerCase()];
    if (v == null) {
      return 0;
    }
    final off = v.offset;
    if (off + 4 > _mapSize) {
      return 0;
    }
    final data = _bytes(view);
    return ByteData.view(data.buffer, data.offsetInBytes + off, 4)
        .getFloat32(0, Endian.little);
  }

  double _getIndexedFloat(Pointer<Uint8> view, String name, int idx) {
    final v = _vars[name.toLowerCase()];
    if (v == null || idx >= v.count) {
      return 0;
    }
    final off = v.offset + idx * 4;
    if (off + 4 > _mapSize) {
      return 0;
    }
    final data = _bytes(view);
    return ByteData.view(data.buffer, data.offsetInBytes + off, 4)
        .getFloat32(0, Endian.little);
  }

  String _sessionYamlFrom(Pointer<Uint8> view, _Header hdr) {
    final start = hdr.sessionInfoOffset;
    final end = start + hdr.sessionInfoLen;
    if (start <= 0 || end > _mapSize) {
      return _sessionYaml;
    }
    final data = _bytes(view);
    final slice = data.sublist(start, end);
    _sessionYaml = String.fromCharCodes(slice.where((b) => b != 0));
    return _sessionYaml;
  }

  SessionType _parseSessionType(String yaml) {
    final lower = yaml.toLowerCase();
    if (lower.contains('sessiontype: race')) {
      return SessionType.race;
    }
    if (lower.contains('sessiontype: qualify')) {
      return SessionType.qualify;
    }
    if (lower.contains('sessiontype: practice')) {
      return SessionType.practice;
    }
    return SessionType.unknown;
  }

  String _cstring(Pointer<Uint8> view, int offset, int maxLen) {
    final data = _bytes(view);
    final chars = <int>[];
    for (var i = 0; i < maxLen; i++) {
      final b = data[offset + i];
      if (b == 0) {
        break;
      }
      chars.add(b);
    }
    return String.fromCharCodes(chars);
  }
}

class _Header {
  const _Header({
    required this.version,
    required this.status,
    required this.tickRate,
    required this.sessionInfoUpdate,
    required this.sessionInfoLen,
    required this.sessionInfoOffset,
    required this.numVars,
    required this.varHeaderOffset,
    required this.bufferLength,
  });

  final int version;
  final int status;
  final int tickRate;
  final int sessionInfoUpdate;
  final int sessionInfoLen;
  final int sessionInfoOffset;
  final int numVars;
  final int varHeaderOffset;
  final int bufferLength;
}

class _VarInfo {
  const _VarInfo({required this.offset, required this.count, required this.type});
  final int offset;
  final int count;
  final int type;
}
