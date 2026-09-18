import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sharing/data/shared_api.dart';

class MembershipProduct {
  MembershipProduct.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      title = json['title'] as String,
      months = json['months'] as int,
      priceInCents = json['priceInCents'] as int,
      description = json['description'] as String,
      recommended = json['recommended'] as bool;
  final String id, title, description;
  final int months, priceInCents;
  final bool recommended;
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
      detail = json['detail'] as String;
  final String id, title, subtitle, detail;
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
    : plans = (json['plans'] as List)
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
    if (plans.length != 3 ||
        benefits.length != 8 ||
        plans.map((p) => p.id).toSet().length != 3 ||
        plans.any((p) => p.priceInCents <= 0 || p.months <= 0)) {
      throw const FormatException('会员配置格式无效');
    }
  }
  final List<MembershipProduct> plans;
  final List<MembershipBenefit> benefits;
  final List<MembershipFaq> faqs;
  final bool isRemote;
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
      return MembershipCatalog.fromJson(
        await api.request('/membership/catalog'),
        isRemote: true,
      );
    } finally {
      api.close();
    }
  }

  Future<MembershipCatalog> _loadLocalCatalog() async {
    return MembershipCatalog.fromJson(
      jsonDecode(
        await rootBundle.loadString('assets/config/membership_catalog.json'),
      ) as Map<String, dynamic>,
    );
  }
}

final membershipCatalogRepositoryProvider =
    Provider<MembershipCatalogRepository>(
      (ref) => ConfiguredMembershipCatalogRepository(),
    );
final membershipCatalogProvider = FutureProvider<MembershipCatalog>(
  (ref) => ref.watch(membershipCatalogRepositoryProvider).load(),
);
