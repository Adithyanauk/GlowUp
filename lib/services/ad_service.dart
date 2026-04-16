import 'dart:developer' as developer;
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Centralized ad service — uses Google test ad unit IDs.
/// Replace these IDs with production IDs before releasing to Play Store.
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  bool _isInitialized = false;

  // ── Test Ad Unit IDs (Android) ──
  // Replace with your production IDs before release.
  static const String bannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String interstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;

  /// Initialize the Mobile Ads SDK — call once in main().
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      developer.log('AdService: MobileAds SDK initialized successfully');
      // Pre-load interstitial for a smooth first show
      loadInterstitialAd();
    } catch (e) {
      developer.log('AdService: Failed to initialize MobileAds SDK: $e');
    }
  }

  // ── Banner Ad ──

  /// Create a banner ad configured with the test unit ID.
  BannerAd createBannerAd({
    required Function() onLoaded,
    Function(String)? onFailed,
  }) {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          developer.log('AdService: Banner ad loaded successfully');
          onLoaded();
        },
        onAdFailedToLoad: (ad, error) {
          developer.log('AdService: Banner ad failed to load: ${error.message} (code: ${error.code})');
          ad.dispose();
          onFailed?.call(error.message);
        },
      ),
    );
  }

  // ── Interstitial Ad ──

  /// Pre-load an interstitial ad so it's ready to show instantly.
  void loadInterstitialAd() {
    if (_isInterstitialLoading || _interstitialAd != null) return;
    _isInterstitialLoading = true;

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          developer.log('AdService: Interstitial ad loaded successfully');
          _interstitialAd = ad;
          _isInterstitialLoading = false;
        },
        onAdFailedToLoad: (error) {
          developer.log('AdService: Interstitial ad failed to load: ${error.message} (code: ${error.code})');
          _isInterstitialLoading = false;
        },
      ),
    );
  }

  /// Show the interstitial ad if one is loaded.
  /// After showing (or dismissal), a new one is pre-loaded automatically.
  void showInterstitialAd({Function()? onAdDismissed}) {
    if (_interstitialAd == null) {
      developer.log('AdService: No interstitial ad ready, skipping');
      onAdDismissed?.call();
      loadInterstitialAd(); // try to load for next time
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        developer.log('AdService: Interstitial ad shown');
      },
      onAdDismissedFullScreenContent: (ad) {
        developer.log('AdService: Interstitial ad dismissed');
        ad.dispose();
        _interstitialAd = null;
        onAdDismissed?.call();
        loadInterstitialAd(); // pre-load the next one
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        developer.log('AdService: Interstitial ad failed to show: ${error.message}');
        ad.dispose();
        _interstitialAd = null;
        onAdDismissed?.call();
        loadInterstitialAd();
      },
    );

    _interstitialAd!.show();
  }

  /// Dispose all loaded ads (e.g. on app shutdown).
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}
