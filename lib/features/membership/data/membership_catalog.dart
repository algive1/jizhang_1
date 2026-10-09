import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'apple_purchase_service.dart';

import '../../sharing/data/shared_api.dart';

class MembershipProduct {
  MembershipProduct.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      title = json['title'] as String,
      months = json['months'] as int,
      priceInCents = json['priceInCents'] as int,
      description = json['description'] as String,
      recommended = json['recommended'] as bool,
      versionId = json['versionId'] as String? ?? 'pro',
      tag = json['tag'] as String? ?? '',
      currencySymbol = json['currencySymbol'] as String? ?? '¥',
      enabled = json['enabled'] as bool? ?? true,
      originalPriceInCents = json['originalPriceInCents'] as int? ?? 0,
      sortOrder = json['sortOrder'] as int? ?? 0,
      rightOverrides = (json['rightOverrides'] as List? ?? const [])
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
  final String id, title, description, versionId, tag, currencySymbol;
  final int months, priceInCents, originalPriceInCents, sortOrder;
  final bool recommended, enabled;
  final List<Map<String, dynamic>> rightOverrides;
  String? get appleProductId => switch (id) {
    'monthly' || 'quarterly' || 'yearly' => 'haohaojizhang.membership.$id',
    _ => null,
  };
  String get unit => months == 1
      ? '月'
      : months == 3
      ? '季度'
      : '年';
  static String money(num cents) =>
      (cents / 100).toStringAsFixed(cents % 100 == 0 ? 0 : 2);
}

class MembershipBenefit {
  MembershipBenefit.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      title = json['title'] as String,
      subtitle = json['subtitle'] as String,
      detail = json['detail'] as String,
      iconUrl = json['iconUrl'] as String? ?? '',
      enabled = json['enabled'] as bool? ?? true;
  final String id, title, subtitle, detail, iconUrl;
  final bool enabled;
  MembershipBenefit withValue(String value) => MembershipBenefit.fromJson({
    'id': id,
    'title': title,
    'subtitle': value,
    'detail': detail,
    'iconUrl': iconUrl,
    'enabled': enabled,
  });
}

class MembershipVersion {
  MembershipVersion.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      title = json['title'] as String,
      enabled = json['enabled'] as bool? ?? true,
      sortOrder = json['sortOrder'] as int? ?? 0,
      benefitIds = (json['benefitIds'] as List?)?.cast<String>();
  final String id, title;
  final bool enabled;
  final int sortOrder;
  final List<String>? benefitIds;
}

class MembershipFaq {
  MembershipFaq.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      question = json['question'] as String,
      answer = json['answer'] as String;
  final String id, question, answer;
}

class MembershipCatalog {
  MembershipCatalog.fromJson(Map<String, dynamic> json, {this.isRemote = false})
    : versions =
          (json['versions'] as List? ??
                  const [
                    {'id': 'pro', 'title': 'Pro 会员'},
                  ])
              .map(
                (v) => MembershipVersion.fromJson(
                  Map<String, dynamic>.from(v as Map),
                ),
              )
              .toList(),
      plans = (json['plans'] as List)
          .map(
            (v) =>
                MembershipProduct.fromJson(Map<String, dynamic>.from(v as Map)),
          )
          .toList(),
      benefits = (json['benefits'] as List)
          .map(
            (v) =>
                MembershipBenefit.fromJson(Map<String, dynamic>.from(v as Map)),
          )
          .toList(),
      faqs = (json['faqs'] as List)
          .map(
            (v) => MembershipFaq.fromJson(Map<String, dynamic>.from(v as Map)),
          )
          .toList() {
    if (plans.map((p) => p.id).toSet().length != plans.length ||
        plans.any((p) => p.priceInCents <= 0 || p.months <= 0)) {
      throw const FormatException('会员配置格式无效');
    }
  }
  final List<MembershipProduct> plans;
  final List<MembershipVersion> versions;
  final List<MembershipBenefit> benefits;
  final List<MembershipFaq> faqs;
  final bool isRemote;

  List<MembershipProduct> availablePlans({
    String? versionId,
    bool appleOnly = false,
  }) =>
      plans
          .where(
            (p) =>
                p.enabled &&
                (versionId == null || p.versionId == versionId) &&
                versions.any((v) => v.id == p.versionId && v.enabled) &&
                (!appleOnly || p.appleProductId != null),
          )
          .toList()
        ..sort((a, b) {
          final order = a.sortOrder.compareTo(b.sortOrder);
          return order == 0 ? a.months.compareTo(b.months) : order;
        });

  List<MembershipBenefit> benefitsFor(MembershipProduct product) {
    final ids = versions
        .firstWhere((v) => v.id == product.versionId)
        .benefitIds;
    return benefits
        .where((b) => b.enabled && (ids == null || ids.contains(b.id)))
        .expand((b) {
          final overrides = product.rightOverrides.where(
            (r) => r['benefitId'] == b.id,
          );
          final override = overrides.isEmpty ? null : overrides.first;
          if (override?['enabled'] == false) return <MembershipBenefit>[];
          final value = override?['value'] as String? ?? '';
          return [value.isEmpty ? b : b.withValue(value)];
        })
        .toList();
  }
}

abstract interface class MembershipCatalogRepository {
  Future<MembershipCatalog> load();
}

class ConfiguredMembershipCatalogRepository
    implements MembershipCatalogRepository {
  static Future<MembershipCatalog>? _localCatalogFuture;

  @override
  Future<MembershipCatalog> load() => _load();

  Future<MembershipCatalog> _load() async {
    const url = String.fromEnvironment('SHARED_API_BASE_URL');
    if (url.isEmpty) {
      final cached = _localCatalogFuture;
      if (cached != null) return cached;
      final future = _loadLocalCatalog();
      _localCatalogFuture = future;
      try {
        return await future;
      } catch (_) {
        if (identical(_localCatalogFuture, future)) {
          _localCatalogFuture = null;
        }
        rethrow;
      }
    }
    final api = SharedApi(baseUrl: url);
    try {
      return await _decode(
        await api.request('/membership/catalog'),
        isRemote: true,
      );
    } finally {
      api.close();
    }
  }

  Future<MembershipCatalog> _loadLocalCatalog() async {
    return await _decode(
      jsonDecode(
        await rootBundle.loadString('assets/config/membership_catalog.json'),
      ) as Map<String, dynamic>,
    );
  }

  Future<MembershipCatalog> _decode(
    Map<String, dynamic> json, {
    bool isRemote = false,
  }) async {
    if (Platform.isIOS) {
      final store = InAppPurchase.instance;
      if (!await store.isAvailable()) throw StateError('App Store 暂不可用');
      final response = await store.queryProductDetails(
        AppleMembershipPurchaseService.productIds,
      );
      if (response.error != null) throw StateError(response.error!.message);
      json = {
        ...json,
        'plans': [
          for (final raw in json['plans'] as List)
            (() {
              final plan = Map<String, dynamic>.from(raw as Map);
              final products = response.productDetails.where(
                (p) => p.id == 'haohaojizhang.membership.${plan['id']}',
              );
              if (products.isEmpty) return {...plan, 'enabled': false};
              final product = products.first;
              return {
                ...plan,
                'priceInCents': (product.rawPrice * 100).round(),
                'currencySymbol': product.currencySymbol,
                'originalPriceInCents': 0,
              };
            })(),
        ],
      };
    }
    return MembershipCatalog.fromJson(json, isRemote: isRemote);
  }
}

final membershipCatalogRepositoryProvider =
    Provider<MembershipCatalogRepository>(
      (ref) => ConfiguredMembershipCatalogRepository(),
    );
final membershipCatalogProvider = FutureProvider<MembershipCatalog>(
  (ref) => ref.watch(membershipCatalogRepositoryProvider).load(),
);
