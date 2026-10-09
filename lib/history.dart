import 'ads.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'fullscreen_ads.dart';
import 'models.dart';
import 'native_ad.dart';
import 'theme.dart';

/// Stores the last [maxItems] results and the user's plan speed on the phone.
class HistoryStore {
  static const _key = 'history_v1';
  static const _planKey = 'plan_mbps';
  static const maxItems = 50;

  static Future<List<TestRecord>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => TestRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Newest first.
  static Future<void> add(TestRecord r) async {
    try {
      final items = await load();
      items.insert(0, r);
      if (items.length > maxItems) {
        items.removeRange(maxItems, items.length);
      }
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, jsonEncode(items.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_key);
    await p.remove(_usageTotalKey);
    for (final k in p.getKeys().where((k) => k.startsWith(_usageMonthPrefix)).toList()) {
      await p.remove(k);
    }
  }

  // ---- data usage counters (bytes moved by speed tests) ----
  static const _usageTotalKey = 'data_total';
  static const _usageMonthPrefix = 'data_m_';

  static String _monthKey(DateTime d) =>
      '$_usageMonthPrefix${d.year}${d.month.toString().padLeft(2, '0')}';

  static Future<void> addUsage(int bytes) async {
    if (bytes <= 0) return;
    try {
      final p = await SharedPreferences.getInstance();
      final mk = _monthKey(DateTime.now());
      await p.setInt(_usageTotalKey, (p.getInt(_usageTotalKey) ?? 0) + bytes);
      await p.setInt(mk, (p.getInt(mk) ?? 0) + bytes);
    } catch (_) {}
  }

  static Future<Usage> loadUsage() async {
    final p = await SharedPreferences.getInstance();
    return Usage(
      p.getInt(_usageTotalKey) ?? 0,
      p.getInt(_monthKey(DateTime.now())) ?? 0,
    );
  }

  static Future<double> loadPlan() async {
    final p = await SharedPreferences.getInstance();
    return p.getDouble(_planKey) ?? 0;
  }

  static Future<void> savePlan(double mbps) async {
    final p = await SharedPreferences.getInstance();
    if (mbps <= 0) {
      await p.remove(_planKey);
    } else {
      await p.setDouble(_planKey, mbps);
    }
  }
}

class Usage {
  final int total;
  final int month;
  const Usage(this.total, this.month);
}

String fmtTime(DateTime t) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '${months[t.month - 1]} ${t.day}, $h:$m';
}

IconData networkIcon(String network) {
  switch (network) {
    case 'Mobile data':
      return Icons.signal_cellular_alt;
    case 'Ethernet':
      return Icons.settings_ethernet;
    case 'No connection':
      return Icons.signal_wifi_off;
    default:
      return Icons.wifi;
  }
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<TestRecord>? items;
  Usage? usage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await HistoryStore.load();
    final u = await HistoryStore.loadUsage();
    if (mounted) {
      setState(() {
        items = l;
        usage = u;
      });
    }
  }

  String _csvField(String s) => (s.contains(',') || s.contains('"'))
      ? '"${s.replaceAll('"', '""')}"'
      : s;

  Future<void> _shareCsv(List<TestRecord> list) async {
    final b = StringBuffer(
        'time,network,engine,server,download_mbps,upload_mbps,ping_ms,jitter_ms\n');
    for (final r in list) {
      b.writeln([
        r.time.toIso8601String(),
        _csvField(r.network),
        _csvField(r.engine),
        _csvField(r.server),
        r.down.toStringAsFixed(2),
        r.up.toStringAsFixed(2),
        r.ping.toStringAsFixed(1),
        r.jitter.toStringAsFixed(1),
      ].join(','));
    }
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/speedtest_history.csv');
      await file.writeAsString(b.toString());
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        text: 'Speed test history',
      );
    } catch (_) {}
  }

  /// Export is free when no rewarded ad is available. If one is ready, the
  /// user is asked first and must watch it to the end.
  Future<void> _export() async {
    final list = items;
    if (list == null || list.isEmpty) return;
    final rewarded = RewardedManager.instance;
    if (await rewarded.isReady) {
      if (!mounted) return;
      final watch = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: kTile,
          title: const Text('Export history'),
          content: const Text(
              'Watch a short ad to export your results as a CSV file.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: kLime, foregroundColor: kOnLime),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Watch ad'),
            ),
          ],
        ),
      );
      if (watch != true) return;
      final earned = await rewarded.show();
      if (!earned) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Watch the full ad to export your history.')));
        }
        return;
      }
    }
    await _shareCsv(list);
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kTile,
        title: const Text('Clear history?'),
        content: const Text('All saved results will be deleted from this phone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: kLime, foregroundColor: kOnLime),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await HistoryStore.clear();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = items;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(children: [
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                        color: kTile, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back, size: 22),
                  ),
                ),
                const SizedBox(width: 14),
                const Text('History',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.w500)),
                const Spacer(),
                IconButton(
                  tooltip: 'Export CSV',
                  icon: Icon(Icons.file_download_outlined, color: kMuted),
                  onPressed: (list == null || list.isEmpty) ? null : _export,
                ),
                IconButton(
                  tooltip: 'Clear history',
                  icon: Icon(Icons.delete_outline, color: kMuted),
                  onPressed: (list == null || list.isEmpty) ? null : _clear,
                ),
              ]),
            ),
            Expanded(child: _body(list)),
          ],
        ),
      ),
    );
  }

  Widget _body(List<TestRecord>? list) {
    if (list == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (list.isEmpty) {
      return Center(
        child: Text('No tests yet.\nRun a test and it will show up here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: kMuted, fontSize: 16)),
      );
    }
    final recent = list.take(20).toList().reversed.toList(); // oldest -> newest
    final values = recent.map((e) => e.down).toList();
    final avg = values.reduce((a, b) => a + b) / values.length;
    final best = values.reduce((a, b) => a > b ? a : b);
    final u = usage;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      children: [
        if (u != null) _usageCard(u),
        if (u != null) const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: kTile, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Download, last ${values.length} tests (Mbps)',
                  style: TextStyle(color: kMuted, fontSize: 14)),
              const SizedBox(height: 12),
              SizedBox(
                height: 110,
                width: double.infinity,
                child: CustomPaint(painter: _SparkPainter(values)),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _stat('Latest', values.last),
                  _stat('Average', avg),
                  _stat('Best', best),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const NativeAdBox(),
        const MrecAdBox(),
        for (final r in list) _tile(r),
      ],
    );
  }

  Widget _usageCard(Usage u) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: kTile, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Icon(Icons.data_usage, color: kMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Data used by speed tests',
                    style: TextStyle(color: kMuted, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                    'This month ${fmtBytes(u.month)}  -  All time ${fmtBytes(u.total)}',
                    style: const TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ]),
      );

  Widget _stat(String t, double v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t, style: TextStyle(color: kMuted, fontSize: 13)),
          Text(v.toStringAsFixed(1),
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
        ],
      );

  Widget _tile(TestRecord r) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: kTile, borderRadius: BorderRadius.circular(16)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(networkIcon(r.network), color: kMuted, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fmtTime(r.time),
                      style: TextStyle(color: kMuted, fontSize: 13)),
                  const SizedBox(height: 4),
                  Wrap(spacing: 14, runSpacing: 4, children: [
                    _val(Icons.arrow_downward, kLime, r.down.toStringAsFixed(1)),
                    _val(Icons.arrow_upward, kOrange, r.up.toStringAsFixed(1)),
                    Text('Ping ${r.ping.round()} ms',
                        style: const TextStyle(fontSize: 16)),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                      '${r.server} - ${r.engine}${r.dataBytes > 0 ? ' - ${fmtBytes(r.dataBytes)}' : ''}',
                      style: TextStyle(color: kMuted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _val(IconData i, Color c, String v) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(i, size: 15, color: c),
          const SizedBox(width: 3),
          Text(v, style: const TextStyle(fontSize: 16)),
        ],
      );
}

class _SparkPainter extends CustomPainter {
  final List<double> v;
  _SparkPainter(this.v);

  @override
  void paint(Canvas canvas, Size size) {
    if (v.isEmpty) return;
    final maxV = v.reduce((a, b) => a > b ? a : b) * 1.15;
    if (maxV <= 0) return;
    final grid = Paint()
      ..color = kLine
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = size.height * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final line = Paint()
      ..color = kLime
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dot = Paint()..color = kLime;
    final path = Path();
    final pts = <Offset>[];
    for (var i = 0; i < v.length; i++) {
      final x = v.length == 1 ? size.width / 2 : size.width * i / (v.length - 1);
      final y = size.height - (v[i] / maxV) * size.height;
      pts.add(Offset(x, y));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, line);
    for (final p in pts) {
      canvas.drawCircle(p, 3.5, dot);
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.v != v;
}
