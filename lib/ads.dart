import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';
import 'config.dart';
import 'consent.dart';
import 'fullscreen_ads.dart';
import 'theme.dart';

/// Initialises Unity LevelPlay once. Does nothing until real keys are filled
/// in lib/config.dart.
class AdsService with LevelPlayInitListener {
  AdsService._();
  static final AdsService instance = AdsService._();

  final ValueNotifier<bool> ready = ValueNotifier<bool>(false);
  bool _started = false;

  String get _appKey =>
      Platform.isIOS ? kLevelPlayAppKeyIos : kLevelPlayAppKeyAndroid;
  String get bannerUnitId =>
      Platform.isIOS ? kBannerAdUnitIos : kBannerAdUnitAndroid;
  bool get configured => !isPlaceholder(_appKey) && !isPlaceholder(bannerUnitId);

  Future<void> init() async {
    if (_started || !configured) return;
    // Ads only start after the user has made a privacy choice.
    final consent = await ConsentService.instance.load();
    if (consent == null) return;
    _started = true;
    try {
      await ConsentService.instance.apply(consent); // must be before init
      if (Platform.isIOS) {
        final s = await ATTrackingManager.getTrackingAuthorizationStatus();
        if (s == ATTStatus.NotDetermined) {
          await ATTrackingManager.requestTrackingAuthorization();
        }
      }
      final req = LevelPlayInitRequest.builder(_appKey).build();
      await LevelPlay.init(initRequest: req, initListener: this);
    } on PlatformException catch (e) {
      debugPrint('LevelPlay init error: $e');
    }
  }

  @override
  void onInitSuccess(LevelPlayConfiguration configuration) {
    ready.value = true;
    InterstitialManager.instance.start();
    RewardedManager.instance.start();
  }

  @override
  void onInitFailed(LevelPlayInitError error) {
    debugPrint('LevelPlay init failed: $error');
  }
}

/// One banner at the bottom of the screen.
class BannerAdBox extends StatefulWidget {
  const BannerAdBox({super.key});
  @override
  State<BannerAdBox> createState() => _BannerAdBoxState();
}

class _BannerAdBoxState extends State<BannerAdBox>
    with LevelPlayBannerAdViewListener {
  final GlobalKey<LevelPlayBannerAdViewState> _key =
      GlobalKey<LevelPlayBannerAdViewState>();
  final _size = LevelPlayAdSize.BANNER;

  @override
  void initState() {
    super.initState();
    AdsService.instance.ready.addListener(_onReady);
    if (AdsService.instance.ready.value) _scheduleLoad();
  }

  void _onReady() {
    if (!mounted) return;
    setState(() {});
    _scheduleLoad();
  }

  void _scheduleLoad([Duration d = const Duration(milliseconds: 600)]) {
    Future.delayed(d, () {
      if (mounted) _key.currentState?.loadAd();
    });
  }

  @override
  void dispose() {
    AdsService.instance.ready.removeListener(_onReady);
    _key.currentState?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdsService.instance.ready.value) {
      // Debug builds show a placeholder; release shows nothing.
      return kDebugMode
          ? const Padding(
              padding: EdgeInsets.all(8),
              child: DashedBox(label: 'Banner ad 320x50'))
          : const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      height: _size.height.toDouble(),
      alignment: Alignment.center,
      child: SizedBox(
        width: _size.width.toDouble(),
        height: _size.height.toDouble(),
        child: LevelPlayBannerAdView(
          key: _key,
          adUnitId: AdsService.instance.bannerUnitId,
          adSize: _size,
          listener: this,
          placementName: 'DefaultBanner',
        ),
      ),
    );
  }

  @override
  void onAdLoadFailed(LevelPlayAdError error) {
    debugPrint('Banner load failed: $error');
    _scheduleLoad(const Duration(seconds: 30));
  }

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) {}
  @override
  void onAdClicked(LevelPlayAdInfo adInfo) {}
  @override
  void onAdCollapsed(LevelPlayAdInfo adInfo) {}
  @override
  void onAdDisplayFailed(LevelPlayAdInfo adInfo, LevelPlayAdError error) {}
  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) {}
  @override
  void onAdExpanded(LevelPlayAdInfo adInfo) {}
  @override
  void onAdLeftApplication(LevelPlayAdInfo adInfo) {}
}


/// One 300x250 MREC (medium rectangle). Controlled by kEnableMrecAd.
/// Uses the banner ad unit (LevelPlay banner units serve MREC too).
/// Collapses if no ad loads.
class MrecAdBox extends StatefulWidget {
  const MrecAdBox({super.key});
  @override
  State<MrecAdBox> createState() => _MrecAdBoxState();
}

class _MrecAdBoxState extends State<MrecAdBox>
    with LevelPlayBannerAdViewListener {
  final GlobalKey<LevelPlayBannerAdViewState> _key =
      GlobalKey<LevelPlayBannerAdViewState>();
  final _size = LevelPlayAdSize.MEDIUM_RECTANGLE;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    AdsService.instance.ready.addListener(_onReady);
    if (AdsService.instance.ready.value) _scheduleLoad();
  }

  void _onReady() {
    if (!mounted) return;
    setState(() {});
    _scheduleLoad();
  }

  void _scheduleLoad([Duration d = const Duration(milliseconds: 600)]) {
    Future.delayed(d, () {
      if (mounted) _key.currentState?.loadAd();
    });
  }

  @override
  void dispose() {
    AdsService.instance.ready.removeListener(_onReady);
    _key.currentState?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kEnableMrecAd || _failed) return const SizedBox.shrink();
    if (!AdsService.instance.ready.value) {
      return kDebugMode
          ? const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: DashedBox(label: 'MREC ad 300x250', height: 250))
          : const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Center(
        child: SizedBox(
          width: _size.width.toDouble(),
          height: _size.height.toDouble(),
          child: LevelPlayBannerAdView(
            key: _key,
            adUnitId: AdsService.instance.bannerUnitId,
            adSize: _size,
            listener: this,
            placementName: 'DefaultMrec',
          ),
        ),
      ),
    );
  }

  @override
  void onAdLoadFailed(LevelPlayAdError error) {
    debugPrint('MREC load failed: $error');
    // Do not retry in a loop: collapse the slot.
    if (mounted) setState(() => _failed = true);
  }

  @override
  void onAdLoaded(LevelPlayAdInfo adInfo) {}
  @override
  void onAdClicked(LevelPlayAdInfo adInfo) {}
  @override
  void onAdCollapsed(LevelPlayAdInfo adInfo) {}
  @override
  void onAdDisplayFailed(LevelPlayAdInfo adInfo, LevelPlayAdError error) {}
  @override
  void onAdDisplayed(LevelPlayAdInfo adInfo) {}
  @override
  void onAdExpanded(LevelPlayAdInfo adInfo) {}
  @override
  void onAdLeftApplication(LevelPlayAdInfo adInfo) {}
}
