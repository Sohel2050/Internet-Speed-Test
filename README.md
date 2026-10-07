# Speed Test (Flutter)

## 1. Setup
1. `flutter create --org com.albonik --project-name speed_test .`  (or copy `lib/` and `pubspec.yaml` into your project)
2. Copy `android/app/build.gradle.kts` and `android/app/proguard-rules.pro` over your own.
3. `flutter pub get`

## 2. Fill in lib/config.dart
- `kConfigUrl`   -> public URL of your force-update JSON
- `kPrivacyUrl`  -> your privacy policy page
- `kLevelPlayAppKey*`, `kBannerAdUnit*` -> from the LevelPlay dashboard
  (until filled, ads are skipped and the force-update check is off)

## 2b. Ads + privacy choice
- Android LevelPlay app key and ad units are already in `lib/config.dart`
  (only the Banner is used; Interstitial/Native/Rewarded IDs are stored for later).
- iOS needs its own LevelPlay app key + ad units.
- On first launch the user gets an Allow / Don't allow dialog (`lib/consent.dart`);
  the choice goes to LevelPlay (GDPR consent + CCPA do_not_sell) BEFORE ads start.
  Privacy settings in the side menu lets the user change it any time.
- The plugin is pinned to 9.3.x because these are the 9.3 APIs. When you upgrade to
  9.4+/9.5+, change `apply()` in consent.dart to LevelPlayPrivacySettings.
- Not a TCF/UMP CMP. For a certified CMP use Google UMP (needs an AdMob account).
- App must NOT be child-directed in Play Console (target audience 13+).
- Mention ads + M-Lab data in your privacy policy and Play Data safety form.

## 2c. Features and packages
- Share card (share_plus 10.x, path_provider), CSV export, in-app review (in_app_review).
- share_plus is pinned to 10.x because the code uses `Share.shareXFiles`.
- Interstitial: on every 3rd test start, at most once per 3 minutes, test starts after it closes.
- Rewarded: optional, used before CSV export (export is free if no rewarded ad is ready).
- Review prompt: after a good result, 5+ tests done, at most once per 90 days.
- Interstitial/rewarded code follows the LevelPlay Flutter docs; if the plugin API
  differs on your installed version, compare lib/fullscreen_ads.dart with the demo app:
  https://github.com/ironsource-mobile/Flutter-SDK/tree/master/example

## 2d. More features
- Latency to popular sites (Google, YouTube, Facebook, WhatsApp, Cloudflare): lib/sites.dart.
  Uses small HTTPS HEAD requests, shown only when the user taps Check.
- Data used: per test (main screen + History) and this month / all time (History). Cleared with History.
- Native ad: one slot in History (lib/native_ad.dart). LevelPlay's native API takes no ad unit ID in Dart;
  the Native ad unit configured in the dashboard is used.
- Light theme is NOT included yet (colors are compile-time constants in lib/theme.dart).

## 2e. Side menu (lib/app_drawer.dart)
History, Privacy settings, Privacy policy, M-Lab data policy, Rate, Share, More apps,
Contact us, Open source licenses. Fill these in lib/config.dart:
`kPrivacyUrl`, `kContactEmail`, `kAppStoreUrl`, `kMoreAppsUrlAndroid`, `kMoreAppsUrlIos`.
Rate / Share / More apps / Contact are hidden until their value is filled in.

## 2f. Ready-made project files (included in this zip)
- `android/app/src/main/AndroidManifest.xml` (permissions, app name) and
  `android/app/src/main/kotlin/com/albonik/speedtest/MainActivity.kt`.
  If your project already has a manifest with extra entries, merge instead of overwriting.
- `android/app/build.gradle.kts` applies google-services only if `google-services.json` exists.
- `ios_setup/Info.plist.additions.xml`: ATT text + where to paste the SKAdNetwork list. Set the iOS Bundle ID to com.albonik.speedtest.
- App icon + splash: generated art in `assets/logo/`. After `flutter pub get` run:
  `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create`.

## 2g. Your logo and your app name
- Logo: put your files in `assets/logo/` as `logo.png` and `logo_foreground.png` (see the comment block in pubspec.yaml), then run the two commands from section 2f.
- `name:` in pubspec.yaml is only the Dart project name. You can change it freely (lowercase letters, digits, underscores). No code imports it.
- The name users see: Android -> `android:label` in AndroidManifest.xml; iOS -> `CFBundleDisplayName` in Info.plist. Store names are set in the stores.
- The app id (`com.albonik.speedtest`) is separate: Android `namespace` + `applicationId` in build.gradle.kts, the `package` line and folder of MainActivity.kt, iOS Bundle Identifier. If you ever change it, change all of them together, and the LevelPlay and store apps must match.

## 3. android/app/src/main/AndroidManifest.xml (inside <manifest>)
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
    <uses-permission android:name="com.google.android.gms.permission.AD_ID"/>

## 4. android/key.properties
    storePassword=...
    keyPassword=...
    keyAlias=upload
    storeFile=../upload-keystore.jks
(path is relative to android/app/). Never commit key.properties or the .jks.

## 5. iOS (ios/Runner/Info.plist)
- `NSUserTrackingUsageDescription` text (needed for the ATT prompt)
- SKAdNetworkItems list from the LevelPlay docs

## 6. Build
    flutter build appbundle --release
Then test a release APK on a real phone: `flutter build apk --release`.

## Force update JSON (host anywhere public, e.g. GitHub Pages / Firebase Hosting)
    {
      "min_version": "1.0.0",
      "latest_version": "1.0.0",
      "update_message": "A new version is available with bug fixes and improvements.",
      "play_store_url": "https://play.google.com/store/apps/details?id=com.albonik.speedtest",
      "app_store_url": "https://apps.apple.com/app/id<YOUR_ID>"
    }
Installed < min_version  -> app blocked until update.
Installed < latest_version -> dismissible dialog.
# Internet-Speed-Test
