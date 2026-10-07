import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'theme.dart';

class _Site {
  final String name;
  final String url;
  final IconData icon;
  const _Site(this.name, this.url, this.icon);
}

const List<_Site> _sites = [
  _Site('Google', 'https://www.google.com/generate_204', Icons.search),
  _Site('YouTube', 'https://www.youtube.com/generate_204', Icons.smart_display),
  _Site('Facebook', 'https://www.facebook.com/', Icons.thumb_up_alt_outlined),
  _Site('WhatsApp', 'https://web.whatsapp.com/', Icons.chat_bubble_outline),
  _Site('Cloudflare', 'https://www.cloudflare.com/cdn-cgi/trace', Icons.cloud_outlined),
];

/// Median response time (ms) of a small HTTPS request, or null if the site
/// did not answer. The first request (DNS + TLS) is not counted.
Future<double?> _measureSite(String url) async {
  final client = http.Client();
  try {
    final uri = Uri.parse(url);
    const limit = Duration(seconds: 5);
    await client.head(uri).timeout(limit);
    final times = <double>[];
    for (var i = 0; i < 3; i++) {
      final sw = Stopwatch()..start();
      await client.head(uri).timeout(limit);
      times.add(sw.elapsedMicroseconds / 1000);
    }
    times.sort();
    return times[1];
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

class SiteLatencyCard extends StatefulWidget {
  final bool enabled;
  const SiteLatencyCard({super.key, this.enabled = true});
  @override
  State<SiteLatencyCard> createState() => _SiteLatencyCardState();
}

class _SiteLatencyCardState extends State<SiteLatencyCard> {
  final Map<String, double?> _results = {};
  final Set<String> _done = {};
  bool _running = false;
  bool _hasRun = false;

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _hasRun = true;
      _results.clear();
      _done.clear();
    });
    await Future.wait(_sites.map((s) async {
      final v = await _measureSite(s.url);
      if (mounted) {
        setState(() {
          _results[s.name] = v;
          _done.add(s.name);
        });
      }
    }));
    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
          color: kTile, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Expanded(
              child: Text('Latency to popular sites',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
            ),
            TextButton(
              onPressed: (_running || !widget.enabled) ? null : _run,
              child: Text(_hasRun ? 'Run again' : 'Check',
                  style: const TextStyle(color: kLime)),
            ),
          ]),
          const Text(
              'Response time of each site from your connection. A site that does not respond may be slow or blocked.',
              style: TextStyle(color: kMuted, fontSize: 13)),
          const SizedBox(height: 8),
          for (final s in _sites)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Icon(s.icon, size: 22, color: kMuted),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(s.name, style: const TextStyle(fontSize: 16))),
                _trailing(s),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _trailing(_Site s) {
    if (!_hasRun) {
      return const Text('--', style: TextStyle(color: kMuted));
    }
    if (!_done.contains(s.name)) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    final v = _results[s.name];
    if (v == null) {
      return _chip('No response', Colors.redAccent);
    }
    final Color c = v <= 60 ? kLime : (v <= 150 ? kOrange : Colors.redAccent);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('${v.round()} ms', style: const TextStyle(fontSize: 15)),
      const SizedBox(width: 8),
      _dot(c),
    ]);
  }

  Widget _dot(Color c) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );

  Widget _chip(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: c.withAlpha(38),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(t,
            style:
                TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w500)),
      );
}
