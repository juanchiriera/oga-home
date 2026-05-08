import 'package:oga/core/flavor.dart';
import 'package:flutter/foundation.dart';

enum InlineAdPlacement {
  homeAfterGreeting,
  stockBelowSearch,
  expensesBelowRecognizedMonth,
  expensesInMovements,
  recipesBelowImportUrl,
  notesAsItem,
}

class AdMobConfig {
  AdMobConfig._();

  static const _androidTestAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const _iosTestAppId = 'ca-app-pub-3940256099942544~1458002511';

  static const _androidTestBannerAdUnit =
      'ca-app-pub-3940256099942544/6300978111';
  static const _iosTestBannerAdUnit = 'ca-app-pub-3940256099942544/2934735716';

  static String get androidAppId => const String.fromEnvironment(
    'ADMOB_ANDROID_APP_ID',
    defaultValue: _androidTestAppId,
  );

  static String get iosAppId => const String.fromEnvironment(
    'ADMOB_IOS_APP_ID',
    defaultValue: _iosTestAppId,
  );

  static String adUnitIdForPlacement(InlineAdPlacement placement) {
    final flavor = AppFlavor.fromEnvironment();
    final envPrefix = '${defaultTargetPlatform.name.toUpperCase()}_${flavor.name.toUpperCase()}';
    final key = switch (placement) {
      InlineAdPlacement.homeAfterGreeting => 'HOME_INLINE',
      InlineAdPlacement.stockBelowSearch => 'STOCK_INLINE',
      InlineAdPlacement.expensesBelowRecognizedMonth => 'EXPENSES_TOP_INLINE',
      InlineAdPlacement.expensesInMovements => 'EXPENSES_LIST_INLINE',
      InlineAdPlacement.recipesBelowImportUrl => 'RECIPES_INLINE',
      InlineAdPlacement.notesAsItem => 'NOTES_INLINE',
    };
    final fromEnv = String.fromEnvironment(
      'ADMOB_${envPrefix}_${key}_AD_UNIT_ID',
      defaultValue: '',
    );
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    return defaultTargetPlatform == TargetPlatform.iOS
        ? _iosTestBannerAdUnit
        : _androidTestBannerAdUnit;
  }
}
