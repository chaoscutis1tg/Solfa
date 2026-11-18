import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

enum AdMobShowResult {
  /// User watched the real Google AdMob Rewarded Video Ad to completion.
  earnedReward,

  /// Real Google AdMob Rewarded Ad was shown, but the user closed it early before earning the reward.
  dismissedWithoutReward,

  /// AdMob SDK is not supported on current platform (e.g., Windows test runner)
  /// or AdMob returned No-Fill (e.g., new ad unit still warming up), so the caller
  /// should fall back to the built-in 15-second supporter video modal.
  unavailableFallback,
}

/// Official Google AdMob Rewarded Video Ad Service for ChaoNote (vn.solfa.app.solfa).
class AdMobService {
  AdMobService._();

  static final AdMobService instance = AdMobService._();

  /// Official Google AdMob App ID for ChaoNote Android.
  static const String kAndroidAppId =
      'ca-app-pub-9062104579352036~8837018232';

  /// Official Google AdMob Rewarded Ad Unit ID for ChaoNote (+100 Gem & +1 Battle Turn).
  static const String kProductionRewardedAdUnitId =
      'ca-app-pub-9062104579352036/9476533675';

  /// Google's official Android test Rewarded Ad Unit ID (used only in debug mode if production unit has not filled yet).
  static const String kGoogleTestRewardedAdUnitId =
      'ca-app-pub-3940256099942544/5224354917';

  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _isLoadingAd = false;
  RewardedAd? _cachedRewardedAd;

  bool get isSupportedMobilePlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  bool get hasPreloadedAd => _cachedRewardedAd != null;

  /// Initializes Google Mobile Ads SDK on Android/iOS and preloads a Rewarded Ad.
  Future<void> initialize({bool isTestMode = false}) async {
    if (isTestMode || !isSupportedMobilePlatform) return;
    if (_isInitialized || _isInitializing) return;
    _isInitializing = true;
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      unawaited(preloadRewardedAd(isTestMode: isTestMode));
    } catch (_) {
      // Safe fallback if Google Play Services is unavailable on device
    } finally {
      _isInitializing = false;
    }
  }

  /// Preloads a RewardedAd into memory so it opens instantaneously when the user taps Watch Ad.
  Future<bool> preloadRewardedAd({bool isTestMode = false}) async {
    if (isTestMode || !isSupportedMobilePlatform) return false;
    if (_cachedRewardedAd != null) return true;
    if (_isLoadingAd) return false;

    if (!_isInitialized) {
      await initialize(isTestMode: isTestMode);
    }

    _isLoadingAd = true;
    try {
      final ad = await _loadSingleUnit(kProductionRewardedAdUnitId);
      if (ad != null) {
        _cachedRewardedAd = ad;
        return true;
      }
      // In debug mode, if the newly created production ad unit is still in its 1-hour warm-up period,
      // fallback to Google's official test ad unit so developers can verify the full AdMob flow.
      if (kDebugMode) {
        final testAd = await _loadSingleUnit(kGoogleTestRewardedAdUnitId);
        if (testAd != null) {
          _cachedRewardedAd = testAd;
          return true;
        }
      }
      return false;
    } finally {
      _isLoadingAd = false;
    }
  }

  Future<RewardedAd?> _loadSingleUnit(String adUnitId) async {
    final completer = Completer<RewardedAd?>();
    try {
      await RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (RewardedAd ad) {
            if (!completer.isCompleted) {
              completer.complete(ad);
            }
          },
          onAdFailedToLoad: (LoadAdError error) {
            if (!completer.isCompleted) {
              completer.complete(null);
            }
          },
        ),
      );
    } catch (_) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }

    return completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => null,
    );
  }

  /// Shows the real Google AdMob Rewarded Video Ad if available.
  /// Returns [AdMobShowResult.earnedReward] only if `onUserEarnedReward` fires.
  Future<AdMobShowResult> showRewardedAd({bool isTestMode = false}) async {
    if (isTestMode || !isSupportedMobilePlatform) {
      return AdMobShowResult.unavailableFallback;
    }

    if (_cachedRewardedAd == null) {
      await preloadRewardedAd(isTestMode: isTestMode);
    }

    final ad = _cachedRewardedAd;
    if (ad == null) {
      return AdMobShowResult.unavailableFallback;
    }
    _cachedRewardedAd = null;

    final completer = Completer<AdMobShowResult>();
    bool rewardEarned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose();
        unawaited(preloadRewardedAd(isTestMode: isTestMode));
        if (!completer.isCompleted) {
          completer.complete(
            rewardEarned
                ? AdMobShowResult.earnedReward
                : AdMobShowResult.dismissedWithoutReward,
          );
        }
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        ad.dispose();
        unawaited(preloadRewardedAd(isTestMode: isTestMode));
        if (!completer.isCompleted) {
          completer.complete(AdMobShowResult.unavailableFallback);
        }
      },
    );

    try {
      await ad.show(
        onUserEarnedReward: (AdWithoutView adView, RewardItem reward) {
          rewardEarned = true;
        },
      );
    } catch (_) {
      ad.dispose();
      if (!completer.isCompleted) {
        completer.complete(AdMobShowResult.unavailableFallback);
      }
    }

    return completer.future;
  }
}

