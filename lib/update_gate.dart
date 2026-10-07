import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config.dart';
import 'theme.dart';

/// Compares "1.2.3" style versions. <0 if a<b, 0 if equal, >0 if a>b.
int compareVersions(String a, String b) {
  List<int> parse(String v) => v
      .split('+')
      .first
      .split('.')
      .map((e) => int.tryParse(e.trim()) ?? 0)
      .toList();
  final x = parse(a), y = parse(b);
  for (var i = 0; i < max(x.length, y.length); i++) {
    final xi = i < x.length ? x[i] : 0;
    final yi = i < y.length ? y[i] : 0;
    if (xi != yi) return xi.compareTo(yi);
  }
  return 0;
}

Future<void> openStore(String url) async {
  if (url.isEmpty) return;
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// Wraps the app. If the installed version is below `min_version` the app is
/// blocked until the user updates. Below `latest_version` shows a dismissible
/// dialog. Network or parse errors never block the user.
class UpdateGate extends StatefulWidget {
  final Widget child;
  const UpdateGate({super.key, required this.child});
  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  bool _force = false;
  String _message = '';
  String _storeUrl = '';

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    if (isPlaceholder(kConfigUrl)) return;
    try {
      final uri = Uri.parse(kConfigUrl).replace(queryParameters: {
        't': DateTime.now().millisecondsSinceEpoch.toString(),
      });
      final r = await http.get(uri).timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) return;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final cur = (await PackageInfo.fromPlatform()).version;
      final minV = (j['min_version'] ?? '0.0.0').toString();
      final latest = (j['latest_version'] ?? '0.0.0').toString();
      final msg = (j['update_message'] ??
              'A new version is available with bug fixes and improvements.')
          .toString();
      final url =
          (Platform.isIOS ? j['app_store_url'] : j['play_store_url'])
                  ?.toString() ??
              '';
      if (!mounted) return;
      if (compareVersions(cur, minV) < 0) {
        setState(() {
          _force = true;
          _message = msg;
          _storeUrl = url;
        });
      } else if (compareVersions(cur, latest) < 0) {
        _showOptional(msg, url);
      }
    } catch (_) {
      // fail open
    }
  }

  void _showOptional(String msg, String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kTile,
        title: const Text('Update available'),
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Later')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: kLime, foregroundColor: Colors.black),
            onPressed: () {
              Navigator.pop(ctx);
              openStore(url);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_force,
      child: Stack(
        children: [
          widget.child,
          if (_force)
            Positioned.fill(
              child: Scaffold(
                backgroundColor: kBg,
                body: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.system_update, size: 72, color: kLime),
                        const SizedBox(height: 24),
                        const Text('Update required',
                            style: TextStyle(
                                fontSize: 26, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 12),
                        Text(_message,
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(color: kMuted, fontSize: 16)),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: kLime,
                              foregroundColor: Colors.black,
                              shape: const StadiumBorder(),
                            ),
                            onPressed: () => openStore(_storeUrl),
                            child: const Text('Update now',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w500)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
