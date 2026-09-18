import 'dart:convert';

/// Stable bidirectional IDs also survive restoring an older local backup.
class SharedIdMap {
  const SharedIdMap(this.localBook, this.remoteBook, [this.aliases = const {}]);
  final Map<String, String> aliases;
  final String localBook;
  final String remoteBook;
  bool get isJoinedCache => localBook.startsWith('shared:');
  String encode(String kind, String id) {
    if (kind == 'books') return remoteBook;
    if (isJoinedCache && id.startsWith('$localBook::'))
      return id.substring(localBook.length + 2);
    final saved = aliases.entries
        .where((e) => e.key.startsWith('$kind:') && e.value == id)
        .firstOrNull;
    if (saved != null) return saved.key.substring(kind.length + 1);
    final prefix = '$remoteBook~$kind~';
    return id.startsWith(prefix) ? id : '$prefix$id';
  }

  String decode(String kind, String id) {
    if (kind == 'books') return localBook;
    if (aliases.containsKey('$kind:$id')) return aliases['$kind:$id']!;
    if (isJoinedCache) return '$localBook::$id';
    final prefix = '$remoteBook~$kind~';
    return localBook != remoteBook && id.startsWith(prefix)
        ? id.substring(prefix.length)
        : id;
  }

  Map<String, dynamic> row(
    String kind,
    Map<String, dynamic> value, {
    required bool upload,
  }) {
    final data = Map<String, dynamic>.of(value);
    String convert(String target, String id) =>
        upload ? encode(target, id) : decode(target, id);
    data['id'] = convert(kind, data['id'] as String);
    if (data.containsKey('book_id'))
      data['book_id'] = upload ? remoteBook : localBook;
    const refs = {
      'account_id': 'accounts',
      'destination_account_id': 'accounts',
      'category_id': 'categories',
      'subcategory_id': 'categories',
      'parent_id': 'categories',
      'goal_id': 'goals',
      'source_transaction_id': 'transactions',
      'original_transaction_id': 'transactions',
      'related_transaction_id': 'transactions',
      'credit_account_id': 'accounts',
      'repayment_account_id': 'accounts',
    };
    for (final entry in refs.entries) {
      if (data[entry.key] != null)
        data[entry.key] = convert(entry.value, data[entry.key] as String);
    }
    final jsonField = kind == 'transactions'
        ? 'metadata_json'
        : kind == 'recurring_bills'
        ? 'schedule_json'
        : null;
    if (jsonField != null && data[jsonField] is String) {
      final payload = jsonDecode(data[jsonField] as String);
      if (payload is Map<String, dynamic>) {
        final refField = kind == 'transactions'
            ? 'recurring_bill_id'
            : 'subcategory_id';
        if (payload[refField] is String) {
          payload[refField] = convert(
            kind == 'transactions' ? 'recurring_bills' : 'categories',
            payload[refField] as String,
          );
        }
        data[jsonField] = jsonEncode(payload);
      }
    }
    if (kind == 'books') data['family_id'] = remoteBook;
    return data;
  }
}
