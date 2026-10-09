import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'app_info.dart';
import 'config.dart';
import 'history.dart';
import 'models.dart';
import 'theme.dart';

/// Shows a preview of the result card and shares it as an image.
class ShareCardDialog extends StatefulWidget {
  final TestRecord record;
  const ShareCardDialog({super.key, required this.record});
  @override
  State<ShareCardDialog> createState() => _ShareCardDialogState();
}

class _ShareCardDialogState extends State<ShareCardDialog> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _busy = false;

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/speed_result.png');
      await file.writeAsBytes(data.buffer.asUint8List());
      final r = widget.record;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: 'My internet speed: ${r.down.toStringAsFixed(1)} Mbps down, '
            '${r.up.toStringAsFixed(1)} Mbps up, ping ${r.ping.round()} ms. '
            'Tested with Speed Test: $kShareLink',
      );
    } catch (_) {
      // sharing cancelled or failed
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              key: _boundaryKey,
              child: _ResultCard(record: widget.record),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: const StadiumBorder()),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: kLime,
                    foregroundColor: kOnLime,
                    minimumSize: const Size.fromHeight(52),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: _busy ? null : _share,
                  icon: const Icon(Icons.share, size: 20),
                  label: const Text('Share'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final TestRecord record;
  const _ResultCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final r = record;
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration:
                  BoxDecoration(color: kTile, shape: BoxShape.circle),
              child: Icon(Icons.speed, size: 18, color: kLime),
            ),
            const SizedBox(width: 10),
            Text(appName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(fmtTime(r.time),
                style: TextStyle(color: kMuted, fontSize: 12)),
          ]),
          const SizedBox(height: 28),
          Text('DOWNLOAD',
              style: TextStyle(color: kMuted, fontSize: 12, letterSpacing: 1.5)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(r.down.toStringAsFixed(1),
                  style: TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.w400,
                      color: kLime,
                      height: 1.1)),
              const SizedBox(width: 8),
              Text('Mbps',
                  style: TextStyle(color: kMuted, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: kLine, height: 1),
          const SizedBox(height: 16),
          Row(children: [
            _col('UPLOAD', r.up.toStringAsFixed(1), 'Mbps', kOrange),
            _col('PING', '${r.ping.round()}', 'ms', kText),
            _col('JITTER', '${r.jitter.round()}', 'ms', kText),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Icon(networkIcon(r.network), size: 16, color: kMuted),
            const SizedBox(width: 6),
            Flexible(
              child: Text('${r.network} - ${r.server}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: kMuted, fontSize: 13)),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _col(String t, String v, String unit, Color c) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t,
                style: TextStyle(
                    color: kMuted, fontSize: 11, letterSpacing: 1.2)),
            const SizedBox(height: 4),
            Text(v,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w500, color: c)),
            Text(unit, style: TextStyle(color: kMuted, fontSize: 12)),
          ],
        ),
      );
}
