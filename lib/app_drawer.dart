import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ads.dart';
import 'config.dart';
import 'consent.dart';
import 'history.dart';
import 'theme.dart';

/// Side menu: history, privacy, store links, contact, licenses.
/// [pageContext] is the context of the main page (still valid after the
/// drawer closes), used for pushing pages and showing dialogs.
class AppDrawer extends StatelessWidget {
  final BuildContext pageContext;
  const AppDrawer({super.key, required this.pageContext});

  String get _storeUrl => Platform.isIOS ? kAppStoreUrl : kShareLink;
  String get _moreAppsUrl =>
      Platform.isIOS ? kMoreAppsUrlIos : kMoreAppsUrlAndroid;

  Future<void> _open(String url) async {
    if (isPlaceholder(url)) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _mail() => _open(
      'mailto:$kContactEmail?subject=${Uri.encodeComponent('Speed Test feedback')}');

  Widget _tile(
      BuildContext ctx, IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: kMuted),
      title: Text(title),
      onTap: () {
        Navigator.pop(ctx);
        onTap();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final showStore = !isPlaceholder(_storeUrl);
    return Drawer(
      backgroundColor: kBg,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                      color: kTile, shape: BoxShape.circle),
                  child: const Icon(Icons.speed, size: 26, color: kLime),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Speed Test',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w500)),
                    FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (c, s) => Text(
                          s.hasData ? 'Version ${s.data!.version}' : '',
                          style: const TextStyle(color: kMuted, fontSize: 13)),
                    ),
                  ],
                ),
              ]),
            ),
            const Divider(color: kLine, height: 1),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _tile(context, Icons.history, 'History', () {
                    Navigator.push(
                        pageContext,
                        MaterialPageRoute(
                            builder: (_) => const HistoryPage()));
                  }),
                  const Divider(color: kLine, height: 1),
                  if (AdsService.instance.configured)
                    _tile(context, Icons.shield_outlined, 'Privacy settings',
                        () => ConsentService.instance.showSettings(pageContext)),
                  _tile(context, Icons.privacy_tip_outlined, 'Privacy policy',
                      () => _open(kPrivacyUrl)),
                  _tile(context, Icons.public, 'M-Lab data policy',
                      () => _open(kMlabPolicyUrl)),
                  const Divider(color: kLine, height: 1),
                  if (showStore)
                    _tile(context, Icons.star_outline, 'Rate this app',
                        () => _open(_storeUrl)),
                  if (showStore)
                    _tile(context, Icons.share_outlined, 'Share this app', () {
                      Share.share(
                          'Check your internet speed with Speed Test: $_storeUrl');
                    }),
                  if (!isPlaceholder(_moreAppsUrl))
                    _tile(context, Icons.apps, 'More apps',
                        () => _open(_moreAppsUrl)),
                  if (!isPlaceholder(kContactEmail))
                    _tile(context, Icons.mail_outline, 'Contact us', _mail),
                  _tile(context, Icons.description_outlined,
                      'Open source licenses', () {
                    showLicensePage(
                        context: pageContext, applicationName: 'Speed Test');
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
