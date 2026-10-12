/// Persistent banner ad shown above the bottom nav. Collapses to nothing
/// until an ad loads (or when ads are unavailable, e.g. unit tests).
library;

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shelter/ads/ad_service.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _banner;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    try {
      _banner = AdService.instance.makeBanner(
        onLoaded: () {
          if (mounted) setState(() => _loaded = true);
        },
      );
    } catch (_) {
      _banner = null; // ads unavailable (tests) — stay collapsed
    }
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = _banner;
    if (!_loaded || b == null) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: AdWidget(ad: b),
    );
  }
}
