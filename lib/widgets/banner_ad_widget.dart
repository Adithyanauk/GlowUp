import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';

/// A self-contained banner ad widget that loads and displays a Google AdMob
/// banner. Simply drop it into any screen's widget tree.
/// Shows nothing until the ad is loaded (no blank space).
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = AdService().createBannerAd(
      onLoaded: () {
        if (mounted) setState(() => _isAdLoaded = true);
      },
      onFailed: (message) {
        developer.log('BannerAdWidget: Ad failed — $message');
        // Retry after a delay
        Future.delayed(const Duration(seconds: 30), () {
          if (mounted) _retryLoad();
        });
      },
    );
    _bannerAd!.load();
  }

  void _retryLoad() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _isAdLoaded = false;
    _loadAd();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show nothing until the ad is loaded — no blank space
    if (!_isAdLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      height: _bannerAd!.size.height.toDouble(),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
