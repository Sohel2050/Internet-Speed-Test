class TestRecord {
  final DateTime time;
  final String network;
  final String engine;
  final String server;
  final double down;
  final double up;
  final double ping;
  final double jitter;
  final int dataBytes;

  const TestRecord({
    required this.time,
    required this.network,
    required this.engine,
    required this.server,
    required this.down,
    required this.up,
    required this.ping,
    required this.jitter,
    this.dataBytes = 0,
  });

  Map<String, dynamic> toJson() => {
        't': time.millisecondsSinceEpoch,
        'n': network,
        'e': engine,
        's': server,
        'd': down,
        'u': up,
        'p': ping,
        'j': jitter,
        'b': dataBytes,
      };

  factory TestRecord.fromJson(Map<String, dynamic> j) => TestRecord(
        time: DateTime.fromMillisecondsSinceEpoch((j['t'] as num).toInt()),
        network: (j['n'] ?? '').toString(),
        engine: (j['e'] ?? '').toString(),
        server: (j['s'] ?? '').toString(),
        down: (j['d'] as num?)?.toDouble() ?? 0,
        up: (j['u'] as num?)?.toDouble() ?? 0,
        ping: (j['p'] as num?)?.toDouble() ?? 0,
        jitter: (j['j'] as num?)?.toDouble() ?? 0,
        dataBytes: (j['b'] as num?)?.toInt() ?? 0,
      );
}

String fmtBytes(int b) {
  const kb = 1024;
  const mb = 1024 * 1024;
  const gb = 1024 * 1024 * 1024;
  if (b < mb) return '${(b / kb).round()} KB';
  if (b < gb) return '${(b / mb).toStringAsFixed(1)} MB';
  return '${(b / gb).toStringAsFixed(2)} GB';
}
