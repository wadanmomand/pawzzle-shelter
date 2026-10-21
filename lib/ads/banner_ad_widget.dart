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
  bool _disposed = false;
  int _attempt = 0;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  void _loadBanner() {
    if (_disposed) return;
    try {
      _banner = AdService.instance.makeBanner(
        onLoaded: () {
          if (mounted) setState(() => _loaded = true);
        },
        onFailed: _scheduleRetry,
      );
    } catch (_) {
      _scheduleRetry();
    }
  }

  /// A failed load used to leave the widget collapsed forever (no retry).
  /// Retry with growing delays (5s, 10s, ... capped at 30s) while alive.
  void _scheduleRetry() {
    if (_disposed) return;
    _attempt++;
    final secs = _attempt * 5 > 30 ? 30 : _attempt * 5;
    Future.delayed(Duration(seconds: secs), () {
      if (_disposed || _loaded) return;
      _banner?.dispose();
      _banner = null;
      _loadBanner();
    });
  }

  @override
  void dispose() {
    _disposed = true;
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
