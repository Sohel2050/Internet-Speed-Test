import 'package:package_info_plus/package_info_plus.dart';

/// App name read from the platform (AndroidManifest android:label /
/// iOS CFBundleDisplayName). Single source: change it there only.
String appName = 'Speed Test';

Future<void> loadAppInfo() async {
  try {
    final n = (await PackageInfo.fromPlatform()).appName;
    if (n.isNotEmpty) appName = n;
  } catch (_) {}
}
