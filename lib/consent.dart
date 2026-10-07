import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config.dart';
import 'theme.dart';

/// Ad privacy choice (GDPR consent + CCPA "do not sell/share").
///
/// One choice for everyone, so no location detection is needed:
///   Allow      -> setConsent(true),  do_not_sell = false
///   Don't allow-> setConsent(false), do_not_sell = true
///
/// NOTE: these are the LevelPlay Flutter plugin 9.3.x APIs (marked deprecated
/// by LevelPlay). If you upgrade the plugin to 9.4+/9.5+, switch to
/// LevelPlayPrivacySettings (setGDPRConsent / setCCPA) in [apply] only.
class ConsentService {
  ConsentService._();
  static final ConsentService instance = ConsentService._();
  static const _key = 'ads_consent'; // 'granted' | 'denied'

  /// true = allowed, false = declined, null = not asked yet.
  Future<bool?> load() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString(_key);
    if (v == 'granted') return true;
    if (v == 'denied') return false;
    return null;
  }

  Future<void> save(bool granted) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, granted ? 'granted' : 'denied');
    await apply(granted);
  }

  /// Passes the choice to LevelPlay. Must also run before LevelPlay.init on
  /// every app start (AdsService does this).
  Future<void> apply(bool granted) async {
    await Future<void>.sync(() => LevelPlay.setConsent(granted))
        .catchError((Object _) {});
    await Future<void>.sync(() => LevelPlay.setMetaData({
          'do_not_sell': [granted ? 'false' : 'true'],
        })).catchError((Object _) {});
  }

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  /// Shows the first-run choice dialog if the user has not decided yet.
  Future<void> ensureDecision(BuildContext context) async {
    final v = await load();
    if (v != null) {
      await apply(v);
      return;
    }
    if (!context.mounted) return;
    final granted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: kTile,
          title: const Text('Your privacy choices'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'We show ads to keep this app free. Our ad partners may use '
                  'your device identifiers and approximate location to show '
                  'personalised ads and measure results.\n\n'
                  "If you choose \"Don't allow\", you may still see ads, but "
                  'they will be less personalised, and we tell our ad partners '
                  'not to sell or share your personal information.\n\n'
                  'You can change this any time from Privacy settings in the app menu.',
                ),
                TextButton(
                  onPressed: () => _open(kPrivacyUrl),
                  child: const Text('Read our privacy policy'),
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Don't allow"),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: kLime, foregroundColor: Colors.black),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Allow'),
            ),
          ],
        ),
      ),
    );
    // Closing without a tap counts as "don't allow".
    await save(granted ?? false);
  }

  /// Lets the user change the choice any time.
  Future<void> showSettings(BuildContext context) async {
    final current = await load() ?? false;
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: kTile,
      builder: (ctx) {
        var value = current;
        return StatefulBuilder(
          builder: (ctx, setState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Privacy settings',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: value,
                    onChanged: (v) {
                      setState(() => value = v);
                      save(v);
                    },
                    title: const Text('Personalised ads & data sharing'),
                    subtitle: const Text(
                        'Off = we withhold consent and tell ad partners not to sell or share your data.',
                        style: TextStyle(color: kMuted)),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Privacy policy'),
                    trailing: const Icon(Icons.open_in_new, size: 18),
                    onTap: () => _open(kPrivacyUrl),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                        'Changes are fully applied the next time you open the app.',
                        style: TextStyle(color: kMuted, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
