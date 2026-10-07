import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';
import 'ads.dart';
import 'theme.dart';

/// One small native ad slot (used in the History screen).
/// Shows nothing until LevelPlay is initialised, and collapses if no ad loads.
class NativeAdBox extends StatefulWidget {
  const NativeAdBox({super.key});
  @override
  State<NativeAdBox> createState() => _NativeAdBoxState();
}

class _NativeAdBoxState extends State<NativeAdBox>
    with LevelPlayNativeAdListener {
  LevelPlayNativeAd? _nativeAd;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    AdsService.instance.ready.addListener(_onReady);
    _create();
  }

  void _create() {
    if (_nativeAd != null || !AdsService.instance.ready.value) return;
    _nativeAd = LevelPlayNativeAd.builder().withListener(this).build();
  }

  void _onReady() {
    if (mounted) setState(_create);
  }

  @override
  void dispose() {
    AdsService.instance.ready.removeListener(_onReady);
    try {
      (_nativeAd as dynamic)?.destroyAd();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();
    if (_nativeAd == null) {
      return kDebugMode
          ? const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: DashedBox(label: 'Native ad', height: 120))
          : const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 175,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, c) => LevelPlayNativeAdView(
              height: 175,
              width: c.maxWidth,
              nativeAd: _nativeAd,
              templateType: LevelPlayTemplateType.SMALL,
              onPlatformViewCreated: () => _nativeAd?.loadAd(),
            ),
          ),
        ),
      ),
    );
  }

  // Callback parameters are `dynamic` so a renamed plugin type cannot break the build.
  void onAdLoaded(dynamic nativeAd, dynamic adInfo) {}

  void onAdLoadFailed(dynamic nativeAd, dynamic error) {
    debugPrint('Native ad load failed: $error');
    if (mounted) setState(() => _failed = true);
  }

  void onAdImpression(dynamic nativeAd, dynamic adInfo) {}
  void onAdClicked(dynamic nativeAd, dynamic adInfo) {}
}
