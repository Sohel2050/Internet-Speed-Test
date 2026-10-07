import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:unity_levelplay_mediation/unity_levelplay_mediation.dart';
import 'config.dart';

String get _interstitialId =>
    Platform.isIOS ? kInterstitialAdUnitIos : kInterstitialAdUnitAndroid;
String get _rewardedId =>
    Platform.isIOS ? kRewardedAdUnitIos : kRewardedAdUnitAndroid;

// Callback parameters are typed `dynamic` on purpose, so these classes keep
// compiling if the plugin renames its info/error/reward types.

/// Interstitial shown at a natural break: when the user taps Start on every
/// 3rd test, at most once every 3 minutes. The test starts after the ad closes.
class InterstitialManager with LevelPlayInterstitialAdListener {
  InterstitialManager._();
  static final InterstitialManager instance = InterstitialManager._();

  static const _everyNthRun = 3;
  static const _minGap = Duration(minutes: 3);

  LevelPlayInterstitialAd? _ad;
  Timer? _retry;
  Completer<void>? _closed;
  DateTime? _lastShown;
  int _runs = 0;
  int _failures = 0;

  void start() {
    if (_ad != null || isPlaceholder(_interstitialId)) return;
    final ad = LevelPlayInterstitialAd(adUnitId: _interstitialId);
    ad.setListener(this);
    _ad = ad;
    ad.loadAd();
  }

  /// Returns true if an ad was shown (and has been closed again).
  Future<bool> maybeShow() async {
    _runs++;
    final ad = _ad;
    if (ad == null || _runs % _everyNthRun != 0) return false;
    final last = _lastShown;
    if (last != null && DateTime.now().difference(last) < _minGap) {
      return false;
    }
    if (!await ad.isAdReady()) return false;
    _lastShown = DateTime.now();
    final done = Completer<void>();
    _closed = done;
    ad.showAd();
    await done.future.timeout(const Duration(minutes: 2), onTimeout: () {});
    return true;
  }

  void _finish() {
    final c = _closed;
    if (c != null && !c.isCompleted) c.complete();
    _closed = null;
    _ad?.loadAd();
  }

  void onAdLoaded(dynamic adInfo) {
    _failures = 0;
  }

  void onAdLoadFailed(dynamic error) {
    debugPrint('Interstitial load failed: $error');
    _retry?.cancel();
    _failures++;
    final secs = (15 * _failures).clamp(15, 120);
    _retry = Timer(Duration(seconds: secs), () => _ad?.loadAd());
  }

  void onAdDisplayed(dynamic adInfo) {}
  void onAdDisplayFailed(dynamic error, dynamic adInfo) => _finish();
  void onAdClicked(dynamic adInfo) {}
  void onAdClosed(dynamic adInfo) => _finish();
  void onAdInfoChanged(dynamic adInfo) {}
}

/// Rewarded ad, opt-in only (used for the CSV export in History).
class RewardedManager with LevelPlayRewardedAdListener {
  RewardedManager._();
  static final RewardedManager instance = RewardedManager._();

  LevelPlayRewardedAd? _ad;
  Timer? _retry;
  Completer<void>? _closed;
  bool _earned = false;
  int _failures = 0;

  void start() {
    if (_ad != null || isPlaceholder(_rewardedId)) return;
    final ad = LevelPlayRewardedAd(adUnitId: _rewardedId);
    ad.setListener(this);
    _ad = ad;
    ad.loadAd();
  }

  Future<bool> get isReady async {
    final ad = _ad;
    if (ad == null) return false;
    return await ad.isAdReady();
  }

  /// Shows the ad. Returns true only if the user earned the reward.
  Future<bool> show() async {
    final ad = _ad;
    if (ad == null || !await ad.isAdReady()) return false;
    _earned = false;
    final done = Completer<void>();
    _closed = done;
    ad.showAd();
    await done.future.timeout(const Duration(minutes: 3), onTimeout: () {});
    return _earned;
  }

  void _finish() {
    final c = _closed;
    if (c != null && !c.isCompleted) c.complete();
    _closed = null;
    _ad?.loadAd();
  }

  void onAdLoaded(dynamic adInfo) {
    _failures = 0;
  }

  void onAdLoadFailed(dynamic error) {
    debugPrint('Rewarded load failed: $error');
    _retry?.cancel();
    _failures++;
    final secs = (15 * _failures).clamp(15, 120);
    _retry = Timer(Duration(seconds: secs), () => _ad?.loadAd());
  }

  void onAdDisplayed(dynamic adInfo) {}
  void onAdDisplayFailed(dynamic error, dynamic adInfo) => _finish();
  void onAdClicked(dynamic adInfo) {}
  void onAdClosed(dynamic adInfo) => _finish();
  void onAdInfoChanged(dynamic adInfo) {}
  void onAdRewarded(dynamic reward, dynamic adInfo) {
    _earned = true;
  }
}
