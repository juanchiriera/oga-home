import 'package:oga/core/ads/ad_gate.dart';
import 'package:oga/core/ads/admob_config.dart';
import 'package:oga/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class InlineNativeAdCard extends StatefulWidget {
  const InlineNativeAdCard({
    required this.placement,
    this.height = 120,
    this.margin = const EdgeInsets.only(bottom: 12),
    super.key,
  });

  final InlineAdPlacement placement;
  final double height;
  final EdgeInsetsGeometry margin;

  @override
  State<InlineNativeAdCard> createState() => _InlineNativeAdCardState();
}

class _InlineNativeAdCardState extends State<InlineNativeAdCard> {
  BannerAd? _bannerAd;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bannerAd == null && shouldShowAds(context)) {
      _loadAd();
    }
  }

  Future<void> _loadAd() async {
    final ad = BannerAd(
      adUnitId: AdMobConfig.adUnitIdForPlacement(widget.placement),
      size: AdSize.mediumRectangle,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) {
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (!mounted) {
            return;
          }
          setState(() {
            _loaded = false;
            _bannerAd = null;
          });
        },
      ),
    );
    await ad.load();
    if (!mounted) {
      ad.dispose();
      return;
    }
    _bannerAd = ad;
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!shouldShowAds(context) || !_loaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: widget.margin,
      child: SizedBox(
        height: widget.height,
        child: CozyCard(
          padding: const EdgeInsets.all(8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AdWidget(ad: _bannerAd!),
          ),
        ),
      ),
    );
  }
}
