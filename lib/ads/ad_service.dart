/// AdMob wiring. Ships with Google's official TEST ids — swap to real ids
/// before production via:
///   --dart-define=BANNER_AD_ID=... --dart-define=INTERSTITIAL_AD_ID=...
///   --dart-define=REWARDED_AD_ID=... --dart-define=APP_OPEN_AD_ID=...
/// (The manifest/Info.plist App ID still needs a manual edit for release.)
///
/// All show-methods no-op safely when [init] was never called (unit tests).
library;

import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static final AdService instance = AdService._();
  AdService._();

  static const bannerId = String.fromEnvironment(
    'BANNER_AD_ID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );
  static const interstitialId = String.fromEnvironment(
    'INTERSTITIAL_AD_ID',
    defaultValue: 'ca-app-pub-3940256099942544/1033173712',
  );
  static const rewardedId = String.fromEnvironment(
    'REWARDED_AD_ID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917',
  );
  static const appOpenId = String.fromEnvironment(
    'APP_OPEN_AD_ID',
    defaultValue: 'ca-app-pub-3940256099942544/9257395921',
  );

  /// Minimum gap between interstitials.
  static const interstitialCooldown = Duration(minutes: 4);

  bool _initialized = false;
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  AppOpenAd? _appOpen;
  DateTime? _lastInterstitialAt;
  bool _showingAppOpen = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await MobileAds.instance.initialize();
    _loadInterstitial();
    _loadRewarded();
    _loadAppOpen();
  }

  // -- banner ------------------------------------------------------------

  BannerAd makeBanner({void Function()? onLoaded}) {
    return BannerAd(
      size: AdSize.banner,
      adUnitId: bannerId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded?.call(),
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    )..load();
  }

  // -- interstitial ------------------------------------------------------

  void _loadInterstitial() {
    if (!_initialized) return;
    InterstitialAd.load(
      adUnitId: interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) {},
      ),
    );
  }

  /// Shows an interstitial unless one was shown recently.
  void maybeShowInterstitial() {
    if (!_initialized) return;
    final last = _lastInterstitialAt;
    if (last != null &&
        DateTime.now().difference(last) < interstitialCooldown) {
      return;
    }
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    _interstitial = null;
    _lastInterstitialAt = DateTime.now();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        _loadInterstitial();
      },
    );
    ad.show();
  }

  // -- rewarded ----------------------------------------------------------

  void _loadRewarded() {
    if (!_initialized) return;
    RewardedAd.load(
      adUnitId: rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (_) {},
      ),
    );
  }

  /// Shows a rewarded ad. Completes with true when the user earned it.
  /// False when no ad was ready (caller should not grant the reward).
  Future<bool> showRewarded() async {
    if (!_initialized) return false;
    final ad = _rewarded;
    if (ad == null) {
      _loadRewarded();
      return false;
    }
    _rewarded = null;
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        _loadRewarded();
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    return earned;
  }

  // -- app open ----------------------------------------------------------

  void _loadAppOpen() {
    if (!_initialized) return;
    AppOpenAd.load(
      adUnitId: appOpenId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) => _appOpen = ad,
        onAdFailedToLoad: (_) {},
      ),
    );
  }

  /// Call on app resume. Shows at most one at a time.
  void showAppOpenIfReady() {
    if (!_initialized || _showingAppOpen) return;
    final ad = _appOpen;
    if (ad == null) {
      _loadAppOpen();
      return;
    }
    _appOpen = null;
    _showingAppOpen = true;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _showingAppOpen = false;
        _loadAppOpen();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        _showingAppOpen = false;
        _loadAppOpen();
      },
    );
    ad.show();
  }
}
