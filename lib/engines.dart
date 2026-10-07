import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'config.dart';

enum Phase { idle, ping, download, upload, done }

class EngineEvents {
  final void Function(Phase) onPhase;
  final void Function(double) onLive;
  final void Function(String) onServer;
  final void Function(double ping, double jitter) onPing;
  final void Function(double) onDownload;
  final void Function(double) onUpload;
  const EngineEvents({
    required this.onPhase,
    required this.onLive,
    required this.onServer,
    required this.onPing,
    required this.onDownload,
    required this.onUpload,
  });
}

abstract class SpeedEngine {
  bool cancelled = false;
  /// Bytes moved by the last run (used for the data-usage display).
  int downBytes = 0;
  int upBytes = 0;
  void cancel() => cancelled = true;
  Future<void> run(EngineEvents ev);
}

double _jitter(List<double> v) {
  if (v.length < 2) return 0;
  var s = 0.0;
  for (var i = 1; i < v.length; i++) {
    s += (v[i] - v[i - 1]).abs();
  }
  return s / (v.length - 1);
}

// ---------------------------------------------------------------------------
// Engine 1: Cloudflare public speed endpoints, 4 parallel streams,
// first 2 seconds discarded (TCP warm-up).
// ---------------------------------------------------------------------------
class CloudflareEngine extends SpeedEngine {
  static const _base = 'https://speed.cloudflare.com';
  static const _streams = 4;
  static const _warmMs = 2000;
  static const _measureMs = 6000;
  static const _colos = {
    'SIN': 'Singapore', 'DAC': 'Dhaka', 'CGP': 'Chittagong', 'CCU': 'Kolkata',
    'DEL': 'Delhi', 'BOM': 'Mumbai', 'MAA': 'Chennai', 'HKG': 'Hong Kong',
    'KUL': 'Kuala Lumpur', 'BKK': 'Bangkok', 'DXB': 'Dubai', 'LHR': 'London',
    'FRA': 'Frankfurt', 'AMS': 'Amsterdam', 'IAD': 'Ashburn',
    'LAX': 'Los Angeles', 'SJC': 'San Jose', 'NRT': 'Tokyo', 'SYD': 'Sydney',
  };
  static final Uint8List _payload = Uint8List(256 * 1024);

  @override
  Future<void> run(EngineEvents ev) async {
    ev.onPhase(Phase.ping);
    await _server(ev);
    await _ping(ev);
    if (cancelled) return;
    ev.onPhase(Phase.download);
    ev.onDownload(await _measure(ev, _downloadWorker, isDown: true));
    if (cancelled) return;
    ev.onPhase(Phase.upload);
    ev.onUpload(await _measure(ev, _uploadWorker, isDown: false));
  }

  Future<void> _server(EngineEvents ev) async {
    try {
      final r = await http
          .get(Uri.parse('$_base/cdn-cgi/trace'))
          .timeout(const Duration(seconds: 5));
      final m = RegExp(r'colo=(\w+)').firstMatch(r.body);
      final code = m?.group(1);
      ev.onServer(code == null ? 'Cloudflare' : (_colos[code] ?? code));
    } catch (_) {
      ev.onServer('Cloudflare');
    }
  }

  Future<void> _ping(EngineEvents ev) async {
    final client = http.Client();
    final times = <double>[];
    try {
      await client.get(Uri.parse('$_base/__down?bytes=0'));
      for (var i = 0; i < 8 && !cancelled; i++) {
        final sw = Stopwatch()..start();
        await client.get(Uri.parse('$_base/__down?bytes=0'));
        times.add(sw.elapsedMicroseconds / 1000);
      }
    } finally {
      client.close();
    }
    if (times.length < 2) throw Exception('ping failed');
    ev.onPing(times.reduce((a, b) => a < b ? a : b), _jitter(times));
  }

  Future<void> _downloadWorker(
      void Function(int) add, bool Function() stop) async {
    final client = http.Client();
    try {
      while (!stop()) {
        final res = await client.send(
            http.Request('GET', Uri.parse('$_base/__down?bytes=25000000')));
        await for (final chunk in res.stream) {
          add(chunk.length);
          if (stop()) break;
        }
      }
    } catch (_) {
      // one stream failing is fine; others keep going
    } finally {
      client.close();
    }
  }

  Future<void> _uploadWorker(
      void Function(int) add, bool Function() stop) async {
    final client = http.Client();
    try {
      while (!stop()) {
        await client.post(Uri.parse('$_base/__up'), body: _payload);
        add(_payload.length);
      }
    } catch (_) {
    } finally {
      client.close();
    }
  }

  Future<double> _measure(
    EngineEvents ev,
    Future<void> Function(void Function(int), bool Function()) worker, {
    required bool isDown,
  }) async {
    final sw = Stopwatch()..start();
    var total = 0;
    var warmBytes = 0;
    var warmMs = -1;
    var lastMs = 0;
    var lastBytes = 0;
    var live = 0.0;
    bool stop() => cancelled || sw.elapsedMilliseconds >= _warmMs + _measureMs;
    final timer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      final ms = sw.elapsedMilliseconds;
      if (warmMs < 0 && ms >= _warmMs) {
        warmMs = ms;
        warmBytes = total;
      }
      final dt = ms - lastMs;
      if (dt > 0) {
        final inst = (total - lastBytes) * 8 / (dt / 1000) / 1e6;
        live = live == 0 ? inst : live * 0.6 + inst * 0.4;
        ev.onLive(live);
      }
      lastMs = ms;
      lastBytes = total;
    });
    try {
      await Future.wait(
          List.generate(_streams, (_) => worker((n) => total += n, stop)));
    } finally {
      timer.cancel();
    }
    if (isDown) {
      downBytes = total;
    } else {
      upBytes = total;
    }
    if (total == 0) throw Exception('no data');
    final endMs = sw.elapsedMilliseconds;
    if (warmMs < 0 || endMs <= warmMs) {
      return total * 8 / (endMs / 1000) / 1e6;
    }
    return (total - warmBytes) * 8 / ((endMs - warmMs) / 1000) / 1e6;
  }
}

// ---------------------------------------------------------------------------
// Engine 2: M-Lab NDT7 (WebSocket). Server chosen by the M-Lab Locate API.
// ---------------------------------------------------------------------------
class _Target {
  final String label;
  final Uri download;
  final Uri upload;
  _Target(this.label, this.download, this.upload);
}

class _DownResult {
  final double mbps;
  final double minRttMs;
  final double jitterMs;
  final int bytes;
  _DownResult(this.mbps, this.minRttMs, this.jitterMs, this.bytes);
}

class MlabEngine extends SpeedEngine {
  static const _locate = 'https://locate.measurementlab.net/v2/nearest/ndt/ndt7';
  static const _proto = 'net.measurementlab.ndt.v7';
  static const _maxSeconds = 10;

  @override
  Future<void> run(EngineEvents ev) async {
    ev.onPhase(Phase.ping); // "finding server"
    final targets = await _targets();
    if (cancelled) return;
    ev.onPhase(Phase.download);

    _Target? used;
    _DownResult? down;
    Object? lastErr;
    for (final t in targets.take(3)) {
      try {
        ev.onServer(t.label);
        down = await _download(t.download, ev);
        used = t;
        break;
      } catch (e) {
        lastErr = e;
        if (cancelled) return;
      }
    }
    if (down == null || used == null) {
      throw lastErr ?? Exception('M-Lab download failed');
    }
    downBytes = down.bytes;
    ev.onPing(down.minRttMs, down.jitterMs);
    ev.onDownload(down.mbps);
    if (cancelled) return;

    ev.onPhase(Phase.upload);
    ev.onUpload(await _upload(used.upload, ev));
  }

  Uri _tag(String url) {
    final u = Uri.parse(url);
    return u.replace(queryParameters: {
      ...u.queryParameters,
      'client_name': kClientName,
      'client_library_name': kClientName,
      'client_library_version': kClientVersion,
    });
  }

  Future<List<_Target>> _targets() async {
    final r = await http
        .get(Uri.parse(_locate))
        .timeout(const Duration(seconds: 8));
    if (r.statusCode != 200) throw Exception('locate ${r.statusCode}');
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    final results = (body['results'] as List?) ?? const [];
    final out = <_Target>[];
    for (final e in results) {
      final urls = e['urls'] as Map<String, dynamic>?;
      final d = urls?['wss:///ndt/v7/download'] as String?;
      final u = urls?['wss:///ndt/v7/upload'] as String?;
      if (d == null || u == null) continue;
      final loc = e['location'] as Map<String, dynamic>?;
      final city = loc?['city']?.toString() ?? '';
      final country = loc?['country']?.toString() ?? '';
      final label = [city, country].where((s) => s.isNotEmpty).join(', ');
      out.add(_Target(label.isEmpty ? 'M-Lab' : label, _tag(d), _tag(u)));
    }
    if (out.isEmpty) throw Exception('no M-Lab servers');
    return out;
  }

  Future<WebSocket> _connect(Uri u) => WebSocket.connect(
        u.toString(),
        protocols: [_proto],
        compression: CompressionOptions.compressionOff,
      ).timeout(const Duration(seconds: 10));

  Future<_DownResult> _download(Uri url, EngineEvents ev) async {
    final ws = await _connect(url);
    final sw = Stopwatch()..start();
    var bytes = 0;
    var lastMs = 0;
    var lastBytes = 0;
    var live = 0.0;
    var minRtt = 0.0;
    final rtts = <double>[];
    final done = Completer<void>();
    final cap = Timer(const Duration(seconds: _maxSeconds + 4), () {
      ws.close();
    });

    ws.listen(
      (dynamic msg) {
        if (msg is String) {
          bytes += msg.length;
          try {
            final m = jsonDecode(msg) as Map<String, dynamic>;
            final t = m['TCPInfo'] as Map<String, dynamic>?;
            if (t != null) {
              final mr = t['MinRTT'];
              final r = t['RTT'];
              if (mr is num && mr > 0) minRtt = mr / 1000;
              if (r is num && r > 0) rtts.add(r / 1000);
            }
          } catch (_) {}
        } else if (msg is List<int>) {
          bytes += msg.length;
        }
        final ms = sw.elapsedMilliseconds;
        if (ms - lastMs >= 150) {
          final inst = (bytes - lastBytes) * 8 / ((ms - lastMs) / 1000) / 1e6;
          live = live == 0 ? inst : live * 0.6 + inst * 0.4;
          ev.onLive(live);
          lastMs = ms;
          lastBytes = bytes;
        }
        if (cancelled) ws.close();
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      onError: (_) {
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );

    await done.future;
    cap.cancel();
    if (bytes == 0) throw Exception('no data');
    final secs = sw.elapsedMicroseconds / 1e6;
    return _DownResult(bytes * 8 / secs / 1e6, minRtt, _jitter(rtts), bytes);
  }

  Future<double> _upload(Uri url, EngineEvents ev) async {
    final ws = await _connect(url);
    final sw = Stopwatch()..start();
    var sent = 0;
    var serverMbps = 0.0;

    // The server reports how many bytes it received and when: use that number.
    ws.listen(
      (dynamic msg) {
        if (msg is String) {
          try {
            final m = jsonDecode(msg) as Map<String, dynamic>;
            final a = m['AppInfo'] as Map<String, dynamic>?;
            final nb = a?['NumBytes'];
            final et = a?['ElapsedTime']; // microseconds
            if (nb is num && et is num && et > 0) {
              serverMbps = nb * 8 / et; // bits per microsecond == Mbit/s
              ev.onLive(serverMbps);
            }
          } catch (_) {}
        }
      },
      onError: (_) {},
      cancelOnError: false,
    );

    final chunk = Uint8List(128 * 1024);
    Stream<List<int>> gen() async* {
      while (!cancelled && sw.elapsedMilliseconds < _maxSeconds * 1000) {
        sent += chunk.length;
        yield chunk;
      }
    }

    try {
      await ws.addStream(gen());
    } catch (_) {}
    try {
      await ws.close();
    } catch (_) {}
    upBytes = sent;

    if (serverMbps > 0) return serverMbps;
    if (sent == 0) throw Exception('upload failed');
    return sent * 8 / (sw.elapsedMicroseconds / 1e6) / 1e6;
  }
}
