import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/transaction_record.dart';
import '../../../core/utils/entity_id.dart';
import '../../settings/data/app_settings_repository.dart';

class BookkeepingTemplate {
  const BookkeepingTemplate({
    required this.id,
    required this.bookId,
    required this.name,
    required this.type,
    required this.amount,
    required this.accountId,
    required this.categoryId,
    required this.subcategoryId,
    required this.merchant,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String bookId;
  final String name;
  final TransactionType type;
  final double? amount;
  final String? accountId;
  final String? categoryId;
  final String? subcategoryId;
  final String? merchant;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'bookId': bookId,
    'name': name,
    'type': type.name,
    if (amount != null) 'amount': amount,
    if (accountId != null) 'accountId': accountId,
    if (categoryId != null) 'categoryId': categoryId,
    if (subcategoryId != null) 'subcategoryId': subcategoryId,
    if (merchant != null) 'merchant': merchant,
    if (note != null) 'note': note,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static BookkeepingTemplate? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = raw.map((key, value) => MapEntry(key.toString(), value));
    final id = json['id'];
    final bookId = json['bookId'];
    final name = json['name'];
    final typeName = json['type'];
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    final updatedAt = DateTime.tryParse(json['updatedAt']?.toString() ?? '');
    if (id is! String ||
        bookId is! String ||
        name is! String ||
        name.trim().isEmpty ||
        typeName is! String ||
        createdAt == null ||
        updatedAt == null) {
      return null;
    }
    final type = TransactionType.values
        .where((value) => value.name == typeName)
        .firstOrNull;
    if (type == null ||
        !{
          TransactionType.expense,
          TransactionType.income,
          TransactionType.borrow,
          TransactionType.lend,
          TransactionType.repayment,
        }.contains(type)) {
      return null;
    }
    final amount = (json['amount'] as num?)?.toDouble();
    if (amount != null && (!amount.isFinite || amount <= 0)) return null;
    return BookkeepingTemplate(
      id: id,
      bookId: bookId,
      name: name.trim(),
      type: type,
      amount: amount,
      accountId: _string(json['accountId']),
      categoryId: _string(json['categoryId']),
      subcategoryId: _string(json['subcategoryId']),
      merchant: _string(json['merchant']),
      note: _string(json['note']),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static String? _string(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

abstract interface class BookkeepingTemplateRepository {
  Future<List<BookkeepingTemplate>> list(String bookId);
  Future<BookkeepingTemplate> save({
    String? id,
    required String bookId,
    required String name,
    required TransactionType type,
    double? amount,
    String? accountId,
    String? categoryId,
    String? subcategoryId,
    String? merchant,
    String? note,
  });
  Future<void> delete(String bookId, String id);
}

class SettingsBookkeepingTemplateRepository
    implements BookkeepingTemplateRepository {
  SettingsBookkeepingTemplateRepository(this._settings);

  static const _prefix = 'bookkeeping.templates.v1.';
  static const _maxTemplates = 30;

  final AppSettingsRepository _settings;

  String _key(String bookId) => '$_prefix$bookId';

  @override
  Future<List<BookkeepingTemplate>> list(String bookId) async {
    final raw = await _settings.get(_key(bookId));
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final templates = decoded
          .map(BookkeepingTemplate.fromJson)
          .whereType<BookkeepingTemplate>()
          .where((item) => item.bookId == bookId)
          .toList(growable: false)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return templates;
    } on Object {
      return const [];
    }
  }

  @override
  Future<BookkeepingTemplate> save({
    String? id,
    required String bookId,
    required String name,
    required TransactionType type,
    double? amount,
    String? accountId,
    String? categoryId,
    String? subcategoryId,
    String? merchant,
    String? note,
  }) async {
    final title = name.trim();
    if (bookId.trim().isEmpty || title.isEmpty || title.length > 40) {
      throw ArgumentError('模板名称无效');
    }
    if (amount != null && (!amount.isFinite || amount <= 0)) {
      throw ArgumentError('模板金额必须大于 0');
    }
    final now = DateTime.now();
    final values = await list(bookId);
    final existing = id == null
        ? null
        : values.where((item) => item.id == id).firstOrNull;
    final template = BookkeepingTemplate(
      id: existing?.id ?? ('template-' + newEntityId()),
      bookId: bookId,
      name: title,
      type: type,
      amount: amount,
      accountId: _clean(accountId),
      categoryId: _clean(categoryId),
      subcategoryId: _clean(subcategoryId),
      merchant: _clean(merchant),
      note: _clean(note),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    final next = [
      template,
      ...values.where((item) => item.id != template.id),
    ].take(_maxTemplates).toList(growable: false);
    await _settings.set(
      _key(bookId),
      jsonEncode(next.map((item) => item.toJson()).toList(growable: false)),
    );
    return template;
  }

  @override
  Future<void> delete(String bookId, String id) async {
    final values = await list(bookId);
    final next = values.where((item) => item.id != id).toList(growable: false);
    await _settings.set(
      _key(bookId),
      jsonEncode(next.map((item) => item.toJson()).toList(growable: false)),
    );
  }

  String? _clean(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}

final bookkeepingTemplateRepositoryProvider =
    Provider<BookkeepingTemplateRepository>((ref) {
  return SettingsBookkeepingTemplateRepository(
    ref.watch(appSettingsRepositoryProvider),
  );
});
