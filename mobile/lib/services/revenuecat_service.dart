import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../config/app_config.dart';

class RevenueCatService {
  bool _configured = false;
  bool get configured => _configured;

  Future<void> configure({required String appUserId}) async {
    if (kIsWeb || !(Platform.isIOS || Platform.isAndroid)) return;
    final key = AppConfig.revenueCatKeyForPlatform();
    if (key.isEmpty) return;

    await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.info);
    final configuration = PurchasesConfiguration(key)..appUserID = appUserId;
    await Purchases.configure(configuration);
    _configured = true;
  }

  Future<bool> hasPremium() async {
    if (!_configured) return false;
    final info = await Purchases.getCustomerInfo();
    return info.entitlements.all[AppConfig.revenueCatEntitlement]?.isActive ??
        false;
  }

  Future<Package?> currentPackage() async {
    if (!_configured) return null;
    final offerings = await Purchases.getOfferings();
    final current = offerings.current;
    if (current == null || current.availablePackages.isEmpty) return null;
    return current.monthly ?? current.availablePackages.first;
  }

  Future<bool> purchase(Package package) async {
    if (!_configured) return false;
    try {
      final params = PurchaseParams.package(package);
      final result = await Purchases.purchase(params);
      return result.customerInfo.entitlements
              .all[AppConfig.revenueCatEntitlement]?.isActive ??
          false;
    } on PlatformException catch (error) {
      final code = PurchasesErrorHelper.getErrorCode(error);
      if (code == PurchasesErrorCode.purchaseCancelledError) return false;
      rethrow;
    }
  }

  Future<bool> restore() async {
    if (!_configured) return false;
    final info = await Purchases.restorePurchases();
    return info.entitlements.all[AppConfig.revenueCatEntitlement]?.isActive ??
        false;
  }
}
