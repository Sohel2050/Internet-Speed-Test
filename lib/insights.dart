import 'package:flutter/material.dart';
import 'theme.dart';

String fmtMbps(double v) =>
    v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

/// Shows how the result compares with the speed the user pays for.
class PlanCard extends StatelessWidget {
  final double plan;
  final double down;
  final bool showResult;
  final VoidCallback onEdit;
  const PlanCard({
    super.key,
    required this.plan,
    required this.down,
    required this.showResult,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final pct = plan > 0 ? down / plan * 100 : 0.0;
    final color = pct >= 80 ? kLime : (pct >= 50 ? kOrange : Colors.redAccent);
    final String title;
    final String sub;
    if (plan <= 0) {
      title = 'Set your plan speed';
      sub = 'Compare every test with the speed you pay for.';
    } else if (showResult) {
      title = 'You get ${pct.round()}% of your plan';
      sub = '${down.toStringAsFixed(1)} of ${fmtMbps(plan)} Mbps';
    } else {
      title = 'Your plan: ${fmtMbps(plan)} Mbps';
      sub = 'Tap to change';
    }
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: kTile, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w500)),
              ),
              Icon(Icons.edit_outlined, size: 18, color: kMuted),
            ]),
            const SizedBox(height: 4),
            Text(sub, style: TextStyle(color: kMuted, fontSize: 14)),
            if (plan > 0 && showResult)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (pct / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    color: color,
                    backgroundColor: kTrack,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum Level { great, ok, poor }

class _UseCase {
  final String name;
  final IconData icon;
  final Level Function(double down, double up, double ping, double jitter) rate;
  const _UseCase(this.name, this.icon, this.rate);
}

// Rough rules of thumb, not guarantees.
final List<_UseCase> _cases = [
  _UseCase('Web and social media', Icons.language, (d, u, p, j) {
    if (d >= 5) return Level.great;
    if (d >= 1.5) return Level.ok;
    return Level.poor;
  }),
  _UseCase('HD video (1080p)', Icons.hd, (d, u, p, j) {
    if (d >= 8) return Level.great;
    if (d >= 5) return Level.ok;
    return Level.poor;
  }),
  _UseCase('4K video', Icons.four_k, (d, u, p, j) {
    if (d >= 25) return Level.great;
    if (d >= 15) return Level.ok;
    return Level.poor;
  }),
  _UseCase('Video calls', Icons.videocam, (d, u, p, j) {
    if (d >= 5 && u >= 3 && p <= 100) return Level.great;
    if (d >= 2 && u >= 1.5 && p <= 200) return Level.ok;
    return Level.poor;
  }),
  _UseCase('Online gaming', Icons.sports_esports, (d, u, p, j) {
    if (p <= 50 && j <= 20) return Level.great;
    if (p <= 100 && j <= 40) return Level.ok;
    return Level.poor;
  }),
];

class InsightsCard extends StatelessWidget {
  final double down, up, ping, jitter;
  const InsightsCard({
    super.key,
    required this.down,
    required this.up,
    required this.ping,
    required this.jitter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
          color: kTile, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('What will work',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('Based on this test. A rough guide only.',
              style: TextStyle(color: kMuted, fontSize: 13)),
          const SizedBox(height: 8),
          for (final c in _cases)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Icon(c.icon, size: 22, color: kMuted),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(c.name, style: const TextStyle(fontSize: 16))),
                _chip(c.rate(down, up, ping, jitter)),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _chip(Level l) {
    final Color c;
    final String t;
    switch (l) {
      case Level.great:
        c = kLime;
        t = 'Great';
        break;
      case Level.ok:
        c = kOrange;
        t = 'OK';
        break;
      case Level.poor:
        c = Colors.redAccent;
        t = 'Poor';
        break;
    }
    return Container(
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
}
