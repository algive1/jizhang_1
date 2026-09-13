// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AccountEntriesTable extends AccountEntries
    with TableInfo<$AccountEntriesTable, AccountEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('book-personal'),
  );
  static const VerificationMeta _openingBalanceInCentsMeta =
      const VerificationMeta('openingBalanceInCents');
  @override
  late final GeneratedColumn<int> openingBalanceInCents = GeneratedColumn<int>(
    'opening_balance_in_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _balanceInCentsMeta = const VerificationMeta(
    'balanceInCents',
  );
  @override
  late final GeneratedColumn<int> balanceInCents = GeneratedColumn<int>(
    'balance_in_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('CNY'),
  );
  static const VerificationMeta _assetFormMeta = const VerificationMeta(
    'assetForm',
  );
  @override
  late final GeneratedColumn<String> assetForm = GeneratedColumn<String>(
    'asset_form',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unspecified'),
  );
  static const VerificationMeta _identifierSuffixMeta = const VerificationMeta(
    'identifierSuffix',
  );
  @override
  late final GeneratedColumn<String> identifierSuffix = GeneratedColumn<String>(
    'identifier_suffix',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    openingBalanceInCents,
    name,
    type,
    balanceInCents,
    currency,
    assetForm,
    identifierSuffix,
    icon,
    color,
    sortOrder,
    isArchived,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<AccountEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    }
    if (data.containsKey('opening_balance_in_cents')) {
      context.handle(
        _openingBalanceInCentsMeta,
        openingBalanceInCents.isAcceptableOrUnknown(
          data['opening_balance_in_cents']!,
          _openingBalanceInCentsMeta,
        ),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('balance_in_cents')) {
      context.handle(
        _balanceInCentsMeta,
        balanceInCents.isAcceptableOrUnknown(
          data['balance_in_cents']!,
          _balanceInCentsMeta,
        ),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('asset_form')) {
      context.handle(
        _assetFormMeta,
        assetForm.isAcceptableOrUnknown(data['asset_form']!, _assetFormMeta),
      );
    }
    if (data.containsKey('identifier_suffix')) {
      context.handle(
        _identifierSuffixMeta,
        identifierSuffix.isAcceptableOrUnknown(
          data['identifier_suffix']!,
          _identifierSuffixMeta,
        ),
      );
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    } else if (isInserting) {
      context.missing(_iconMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AccountEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AccountEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      openingBalanceInCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}opening_balance_in_cents'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      balanceInCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}balance_in_cents'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      assetForm: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_form'],
      )!,
      identifierSuffix: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}identifier_suffix'],
      ),
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AccountEntriesTable createAlias(String alias) {
    return $AccountEntriesTable(attachedDatabase, alias);
  }
}

class AccountEntity extends DataClass implements Insertable<AccountEntity> {
  final String id;
  final String bookId;
  final int openingBalanceInCents;
  final String name;
  final String type;
  final int balanceInCents;
  final String currency;
  final String assetForm;
  final String? identifierSuffix;
  final String icon;
  final int color;
  final int sortOrder;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  const AccountEntity({
    required this.id,
    required this.bookId,
    required this.openingBalanceInCents,
    required this.name,
    required this.type,
    required this.balanceInCents,
    required this.currency,
    required this.assetForm,
    this.identifierSuffix,
    required this.icon,
    required this.color,
    required this.sortOrder,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['opening_balance_in_cents'] = Variable<int>(openingBalanceInCents);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['balance_in_cents'] = Variable<int>(balanceInCents);
    map['currency'] = Variable<String>(currency);
    map['asset_form'] = Variable<String>(assetForm);
    if (!nullToAbsent || identifierSuffix != null) {
      map['identifier_suffix'] = Variable<String>(identifierSuffix);
    }
    map['icon'] = Variable<String>(icon);
    map['color'] = Variable<int>(color);
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_archived'] = Variable<bool>(isArchived);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AccountEntriesCompanion toCompanion(bool nullToAbsent) {
    return AccountEntriesCompanion(
      id: Value(id),
      bookId: Value(bookId),
      openingBalanceInCents: Value(openingBalanceInCents),
      name: Value(name),
      type: Value(type),
      balanceInCents: Value(balanceInCents),
      currency: Value(currency),
      assetForm: Value(assetForm),
      identifierSuffix: identifierSuffix == null && nullToAbsent
          ? const Value.absent()
          : Value(identifierSuffix),
      icon: Value(icon),
      color: Value(color),
      sortOrder: Value(sortOrder),
      isArchived: Value(isArchived),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory AccountEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AccountEntity(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      openingBalanceInCents: serializer.fromJson<int>(
        json['openingBalanceInCents'],
      ),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      balanceInCents: serializer.fromJson<int>(json['balanceInCents']),
      currency: serializer.fromJson<String>(json['currency']),
      assetForm: serializer.fromJson<String>(json['assetForm']),
      identifierSuffix: serializer.fromJson<String?>(json['identifierSuffix']),
      icon: serializer.fromJson<String>(json['icon']),
      color: serializer.fromJson<int>(json['color']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'openingBalanceInCents': serializer.toJson<int>(openingBalanceInCents),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'balanceInCents': serializer.toJson<int>(balanceInCents),
      'currency': serializer.toJson<String>(currency),
      'assetForm': serializer.toJson<String>(assetForm),
      'identifierSuffix': serializer.toJson<String?>(identifierSuffix),
      'icon': serializer.toJson<String>(icon),
      'color': serializer.toJson<int>(color),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isArchived': serializer.toJson<bool>(isArchived),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AccountEntity copyWith({
    String? id,
    String? bookId,
    int? openingBalanceInCents,
    String? name,
    String? type,
    int? balanceInCents,
    String? currency,
    String? assetForm,
    Value<String?> identifierSuffix = const Value.absent(),
    String? icon,
    int? color,
    int? sortOrder,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => AccountEntity(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    openingBalanceInCents: openingBalanceInCents ?? this.openingBalanceInCents,
    name: name ?? this.name,
    type: type ?? this.type,
    balanceInCents: balanceInCents ?? this.balanceInCents,
    currency: currency ?? this.currency,
    assetForm: assetForm ?? this.assetForm,
    identifierSuffix: identifierSuffix.present
        ? identifierSuffix.value
        : this.identifierSuffix,
    icon: icon ?? this.icon,
    color: color ?? this.color,
    sortOrder: sortOrder ?? this.sortOrder,
    isArchived: isArchived ?? this.isArchived,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AccountEntity copyWithCompanion(AccountEntriesCompanion data) {
    return AccountEntity(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      openingBalanceInCents: data.openingBalanceInCents.present
          ? data.openingBalanceInCents.value
          : this.openingBalanceInCents,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      balanceInCents: data.balanceInCents.present
          ? data.balanceInCents.value
          : this.balanceInCents,
      currency: data.currency.present ? data.currency.value : this.currency,
      assetForm: data.assetForm.present ? data.assetForm.value : this.assetForm,
      identifierSuffix: data.identifierSuffix.present
          ? data.identifierSuffix.value
          : this.identifierSuffix,
      icon: data.icon.present ? data.icon.value : this.icon,
      color: data.color.present ? data.color.value : this.color,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AccountEntity(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('openingBalanceInCents: $openingBalanceInCents, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('balanceInCents: $balanceInCents, ')
          ..write('currency: $currency, ')
          ..write('assetForm: $assetForm, ')
          ..write('identifierSuffix: $identifierSuffix, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isArchived: $isArchived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    openingBalanceInCents,
    name,
    type,
    balanceInCents,
    currency,
    assetForm,
    identifierSuffix,
    icon,
    color,
    sortOrder,
    isArchived,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccountEntity &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.openingBalanceInCents == this.openingBalanceInCents &&
          other.name == this.name &&
          other.type == this.type &&
          other.balanceInCents == this.balanceInCents &&
          other.currency == this.currency &&
          other.assetForm == this.assetForm &&
          other.identifierSuffix == this.identifierSuffix &&
          other.icon == this.icon &&
          other.color == this.color &&
          other.sortOrder == this.sortOrder &&
          other.isArchived == this.isArchived &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AccountEntriesCompanion extends UpdateCompanion<AccountEntity> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<int> openingBalanceInCents;
  final Value<String> name;
  final Value<String> type;
  final Value<int> balanceInCents;
  final Value<String> currency;
  final Value<String> assetForm;
  final Value<String?> identifierSuffix;
  final Value<String> icon;
  final Value<int> color;
  final Value<int> sortOrder;
  final Value<bool> isArchived;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AccountEntriesCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.openingBalanceInCents = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.balanceInCents = const Value.absent(),
    this.currency = const Value.absent(),
    this.assetForm = const Value.absent(),
    this.identifierSuffix = const Value.absent(),
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountEntriesCompanion.insert({
    required String id,
    this.bookId = const Value.absent(),
    this.openingBalanceInCents = const Value.absent(),
    required String name,
    required String type,
    this.balanceInCents = const Value.absent(),
    this.currency = const Value.absent(),
    this.assetForm = const Value.absent(),
    this.identifierSuffix = const Value.absent(),
    required String icon,
    required int color,
    this.sortOrder = const Value.absent(),
    this.isArchived = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       type = Value(type),
       icon = Value(icon),
       color = Value(color),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<AccountEntity> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<int>? openingBalanceInCents,
    Expression<String>? name,
    Expression<String>? type,
    Expression<int>? balanceInCents,
    Expression<String>? currency,
    Expression<String>? assetForm,
    Expression<String>? identifierSuffix,
    Expression<String>? icon,
    Expression<int>? color,
    Expression<int>? sortOrder,
    Expression<bool>? isArchived,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (openingBalanceInCents != null)
        'opening_balance_in_cents': openingBalanceInCents,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (balanceInCents != null) 'balance_in_cents': balanceInCents,
      if (currency != null) 'currency': currency,
      if (assetForm != null) 'asset_form': assetForm,
      if (identifierSuffix != null) 'identifier_suffix': identifierSuffix,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isArchived != null) 'is_archived': isArchived,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<int>? openingBalanceInCents,
    Value<String>? name,
    Value<String>? type,
    Value<int>? balanceInCents,
    Value<String>? currency,
    Value<String>? assetForm,
    Value<String?>? identifierSuffix,
    Value<String>? icon,
    Value<int>? color,
    Value<int>? sortOrder,
    Value<bool>? isArchived,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AccountEntriesCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      openingBalanceInCents:
          openingBalanceInCents ?? this.openingBalanceInCents,
      name: name ?? this.name,
      type: type ?? this.type,
      balanceInCents: balanceInCents ?? this.balanceInCents,
      currency: currency ?? this.currency,
      assetForm: assetForm ?? this.assetForm,
      identifierSuffix: identifierSuffix ?? this.identifierSuffix,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (openingBalanceInCents.present) {
      map['opening_balance_in_cents'] = Variable<int>(
        openingBalanceInCents.value,
      );
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (balanceInCents.present) {
      map['balance_in_cents'] = Variable<int>(balanceInCents.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (assetForm.present) {
      map['asset_form'] = Variable<String>(assetForm.value);
    }
    if (identifierSuffix.present) {
      map['identifier_suffix'] = Variable<String>(identifierSuffix.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountEntriesCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('openingBalanceInCents: $openingBalanceInCents, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('balanceInCents: $balanceInCents, ')
          ..write('currency: $currency, ')
          ..write('assetForm: $assetForm, ')
          ..write('identifierSuffix: $identifierSuffix, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isArchived: $isArchived, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoryEntriesTable extends CategoryEntries
    with TableInfo<$CategoryEntriesTable, CategoryEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoryEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('book-personal'),
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    parentId,
    name,
    icon,
    type,
    sortOrder,
    isDefault,
    isArchived,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoryEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    } else if (isInserting) {
      context.missing(_iconMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CategoryEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoryEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
    );
  }

  @override
  $CategoryEntriesTable createAlias(String alias) {
    return $CategoryEntriesTable(attachedDatabase, alias);
  }
}

class CategoryEntity extends DataClass implements Insertable<CategoryEntity> {
  final String id;
  final String bookId;
  final String? parentId;
  final String name;
  final String icon;
  final String type;
  final int sortOrder;
  final bool isDefault;
  final bool isArchived;
  const CategoryEntity({
    required this.id,
    required this.bookId,
    this.parentId,
    required this.name,
    required this.icon,
    required this.type,
    required this.sortOrder,
    required this.isDefault,
    required this.isArchived,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['name'] = Variable<String>(name);
    map['icon'] = Variable<String>(icon);
    map['type'] = Variable<String>(type);
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_default'] = Variable<bool>(isDefault);
    map['is_archived'] = Variable<bool>(isArchived);
    return map;
  }

  CategoryEntriesCompanion toCompanion(bool nullToAbsent) {
    return CategoryEntriesCompanion(
      id: Value(id),
      bookId: Value(bookId),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      name: Value(name),
      icon: Value(icon),
      type: Value(type),
      sortOrder: Value(sortOrder),
      isDefault: Value(isDefault),
      isArchived: Value(isArchived),
    );
  }

  factory CategoryEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoryEntity(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      name: serializer.fromJson<String>(json['name']),
      icon: serializer.fromJson<String>(json['icon']),
      type: serializer.fromJson<String>(json['type']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'parentId': serializer.toJson<String?>(parentId),
      'name': serializer.toJson<String>(name),
      'icon': serializer.toJson<String>(icon),
      'type': serializer.toJson<String>(type),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isDefault': serializer.toJson<bool>(isDefault),
      'isArchived': serializer.toJson<bool>(isArchived),
    };
  }

  CategoryEntity copyWith({
    String? id,
    String? bookId,
    Value<String?> parentId = const Value.absent(),
    String? name,
    String? icon,
    String? type,
    int? sortOrder,
    bool? isDefault,
    bool? isArchived,
  }) => CategoryEntity(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    parentId: parentId.present ? parentId.value : this.parentId,
    name: name ?? this.name,
    icon: icon ?? this.icon,
    type: type ?? this.type,
    sortOrder: sortOrder ?? this.sortOrder,
    isDefault: isDefault ?? this.isDefault,
    isArchived: isArchived ?? this.isArchived,
  );
  CategoryEntity copyWithCompanion(CategoryEntriesCompanion data) {
    return CategoryEntity(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      name: data.name.present ? data.name.value : this.name,
      icon: data.icon.present ? data.icon.value : this.icon,
      type: data.type.present ? data.type.value : this.type,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoryEntity(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('type: $type, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isDefault: $isDefault, ')
          ..write('isArchived: $isArchived')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    parentId,
    name,
    icon,
    type,
    sortOrder,
    isDefault,
    isArchived,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoryEntity &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.parentId == this.parentId &&
          other.name == this.name &&
          other.icon == this.icon &&
          other.type == this.type &&
          other.sortOrder == this.sortOrder &&
          other.isDefault == this.isDefault &&
          other.isArchived == this.isArchived);
}

class CategoryEntriesCompanion extends UpdateCompanion<CategoryEntity> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String?> parentId;
  final Value<String> name;
  final Value<String> icon;
  final Value<String> type;
  final Value<int> sortOrder;
  final Value<bool> isDefault;
  final Value<bool> isArchived;
  final Value<int> rowid;
  const CategoryEntriesCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.parentId = const Value.absent(),
    this.name = const Value.absent(),
    this.icon = const Value.absent(),
    this.type = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoryEntriesCompanion.insert({
    required String id,
    this.bookId = const Value.absent(),
    this.parentId = const Value.absent(),
    required String name,
    required String icon,
    required String type,
    this.sortOrder = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       icon = Value(icon),
       type = Value(type);
  static Insertable<CategoryEntity> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? parentId,
    Expression<String>? name,
    Expression<String>? icon,
    Expression<String>? type,
    Expression<int>? sortOrder,
    Expression<bool>? isDefault,
    Expression<bool>? isArchived,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (parentId != null) 'parent_id': parentId,
      if (name != null) 'name': name,
      if (icon != null) 'icon': icon,
      if (type != null) 'type': type,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isDefault != null) 'is_default': isDefault,
      if (isArchived != null) 'is_archived': isArchived,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoryEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String?>? parentId,
    Value<String>? name,
    Value<String>? icon,
    Value<String>? type,
    Value<int>? sortOrder,
    Value<bool>? isDefault,
    Value<bool>? isArchived,
    Value<int>? rowid,
  }) {
    return CategoryEntriesCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      type: type ?? this.type,
      sortOrder: sortOrder ?? this.sortOrder,
      isDefault: isDefault ?? this.isDefault,
      isArchived: isArchived ?? this.isArchived,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoryEntriesCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('type: $type, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isDefault: $isDefault, ')
          ..write('isArchived: $isArchived, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransactionEntriesTable extends TransactionEntries
    with TableInfo<$TransactionEntriesTable, TransactionEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountInCentsMeta = const VerificationMeta(
    'amountInCents',
  );
  @override
  late final GeneratedColumn<int> amountInCents = GeneratedColumn<int>(
    'amount_in_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('CNY'),
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _subcategoryIdMeta = const VerificationMeta(
    'subcategoryId',
  );
  @override
  late final GeneratedColumn<String> subcategoryId = GeneratedColumn<String>(
    'subcategory_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id)',
    ),
  );
  static const VerificationMeta _destinationAccountIdMeta =
      const VerificationMeta('destinationAccountId');
  @override
  late final GeneratedColumn<String> destinationAccountId =
      GeneratedColumn<String>(
        'destination_account_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES accounts (id)',
        ),
      );
  static const VerificationMeta _merchantMeta = const VerificationMeta(
    'merchant',
  );
  @override
  late final GeneratedColumn<String> merchant = GeneratedColumn<String>(
    'merchant',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isRecurringMeta = const VerificationMeta(
    'isRecurring',
  );
  @override
  late final GeneratedColumn<bool> isRecurring = GeneratedColumn<bool>(
    'is_recurring',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_recurring" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isOneTimeMeta = const VerificationMeta(
    'isOneTime',
  );
  @override
  late final GeneratedColumn<bool> isOneTime = GeneratedColumn<bool>(
    'is_one_time',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_one_time" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isLargeTransactionMeta =
      const VerificationMeta('isLargeTransaction');
  @override
  late final GeneratedColumn<bool> isLargeTransaction = GeneratedColumn<bool>(
    'is_large_transaction',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_large_transaction" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isPlannedMeta = const VerificationMeta(
    'isPlanned',
  );
  @override
  late final GeneratedColumn<bool> isPlanned = GeneratedColumn<bool>(
    'is_planned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_planned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('manual'),
  );
  static const VerificationMeta _aiConfidenceMeta = const VerificationMeta(
    'aiConfidence',
  );
  @override
  late final GeneratedColumn<double> aiConfidence = GeneratedColumn<double>(
    'ai_confidence',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userCorrectedMeta = const VerificationMeta(
    'userCorrected',
  );
  @override
  late final GeneratedColumn<bool> userCorrected = GeneratedColumn<bool>(
    'user_corrected',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("user_corrected" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('localOnly'),
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originalTransactionIdMeta =
      const VerificationMeta('originalTransactionId');
  @override
  late final GeneratedColumn<String> originalTransactionId =
      GeneratedColumn<String>(
        'original_transaction_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _relatedTransactionIdMeta =
      const VerificationMeta('relatedTransactionId');
  @override
  late final GeneratedColumn<String> relatedTransactionId =
      GeneratedColumn<String>(
        'related_transaction_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _reimbursementStatusMeta =
      const VerificationMeta('reimbursementStatus');
  @override
  late final GeneratedColumn<String> reimbursementStatus =
      GeneratedColumn<String>(
        'reimbursement_status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('none'),
      );
  static const VerificationMeta _reimbursementAmountInCentsMeta =
      const VerificationMeta('reimbursementAmountInCents');
  @override
  late final GeneratedColumn<int> reimbursementAmountInCents =
      GeneratedColumn<int>(
        'reimbursement_amount_in_cents',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _reimbursementDateMeta = const VerificationMeta(
    'reimbursementDate',
  );
  @override
  late final GeneratedColumn<DateTime> reimbursementDate =
      GeneratedColumn<DateTime>(
        'reimbursement_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _reimbursementNoteMeta = const VerificationMeta(
    'reimbursementNote',
  );
  @override
  late final GeneratedColumn<String> reimbursementNote =
      GeneratedColumn<String>(
        'reimbursement_note',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _refundStatusMeta = const VerificationMeta(
    'refundStatus',
  );
  @override
  late final GeneratedColumn<String> refundStatus = GeneratedColumn<String>(
    'refund_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('none'),
  );
  static const VerificationMeta _refundAmountInCentsMeta =
      const VerificationMeta('refundAmountInCents');
  @override
  late final GeneratedColumn<int> refundAmountInCents = GeneratedColumn<int>(
    'refund_amount_in_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metadataJsonMeta = const VerificationMeta(
    'metadataJson',
  );
  @override
  late final GeneratedColumn<String> metadataJson = GeneratedColumn<String>(
    'metadata_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _duplicateConfidenceMeta =
      const VerificationMeta('duplicateConfidence');
  @override
  late final GeneratedColumn<double> duplicateConfidence =
      GeneratedColumn<double>(
        'duplicate_confidence',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _visibilityMeta = const VerificationMeta(
    'visibility',
  );
  @override
  late final GeneratedColumn<String> visibility = GeneratedColumn<String>(
    'visibility',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('private'),
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedByMeta = const VerificationMeta(
    'updatedBy',
  );
  @override
  late final GeneratedColumn<String> updatedBy = GeneratedColumn<String>(
    'updated_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    userId,
    type,
    amountInCents,
    currency,
    categoryId,
    subcategoryId,
    accountId,
    destinationAccountId,
    merchant,
    note,
    occurredAt,
    createdAt,
    updatedAt,
    deletedAt,
    isRecurring,
    isOneTime,
    isLargeTransaction,
    isPlanned,
    source,
    aiConfidence,
    userCorrected,
    syncStatus,
    deviceId,
    originalTransactionId,
    relatedTransactionId,
    reimbursementStatus,
    reimbursementAmountInCents,
    reimbursementDate,
    reimbursementNote,
    refundStatus,
    refundAmountInCents,
    metadataJson,
    duplicateConfidence,
    visibility,
    createdBy,
    updatedBy,
    version,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<TransactionEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('amount_in_cents')) {
      context.handle(
        _amountInCentsMeta,
        amountInCents.isAcceptableOrUnknown(
          data['amount_in_cents']!,
          _amountInCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountInCentsMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('subcategory_id')) {
      context.handle(
        _subcategoryIdMeta,
        subcategoryId.isAcceptableOrUnknown(
          data['subcategory_id']!,
          _subcategoryIdMeta,
        ),
      );
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('destination_account_id')) {
      context.handle(
        _destinationAccountIdMeta,
        destinationAccountId.isAcceptableOrUnknown(
          data['destination_account_id']!,
          _destinationAccountIdMeta,
        ),
      );
    }
    if (data.containsKey('merchant')) {
      context.handle(
        _merchantMeta,
        merchant.isAcceptableOrUnknown(data['merchant']!, _merchantMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('is_recurring')) {
      context.handle(
        _isRecurringMeta,
        isRecurring.isAcceptableOrUnknown(
          data['is_recurring']!,
          _isRecurringMeta,
        ),
      );
    }
    if (data.containsKey('is_one_time')) {
      context.handle(
        _isOneTimeMeta,
        isOneTime.isAcceptableOrUnknown(data['is_one_time']!, _isOneTimeMeta),
      );
    }
    if (data.containsKey('is_large_transaction')) {
      context.handle(
        _isLargeTransactionMeta,
        isLargeTransaction.isAcceptableOrUnknown(
          data['is_large_transaction']!,
          _isLargeTransactionMeta,
        ),
      );
    }
    if (data.containsKey('is_planned')) {
      context.handle(
        _isPlannedMeta,
        isPlanned.isAcceptableOrUnknown(data['is_planned']!, _isPlannedMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('ai_confidence')) {
      context.handle(
        _aiConfidenceMeta,
        aiConfidence.isAcceptableOrUnknown(
          data['ai_confidence']!,
          _aiConfidenceMeta,
        ),
      );
    }
    if (data.containsKey('user_corrected')) {
      context.handle(
        _userCorrectedMeta,
        userCorrected.isAcceptableOrUnknown(
          data['user_corrected']!,
          _userCorrectedMeta,
        ),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    }
    if (data.containsKey('original_transaction_id')) {
      context.handle(
        _originalTransactionIdMeta,
        originalTransactionId.isAcceptableOrUnknown(
          data['original_transaction_id']!,
          _originalTransactionIdMeta,
        ),
      );
    }
    if (data.containsKey('related_transaction_id')) {
      context.handle(
        _relatedTransactionIdMeta,
        relatedTransactionId.isAcceptableOrUnknown(
          data['related_transaction_id']!,
          _relatedTransactionIdMeta,
        ),
      );
    }
    if (data.containsKey('reimbursement_status')) {
      context.handle(
        _reimbursementStatusMeta,
        reimbursementStatus.isAcceptableOrUnknown(
          data['reimbursement_status']!,
          _reimbursementStatusMeta,
        ),
      );
    }
    if (data.containsKey('reimbursement_amount_in_cents')) {
      context.handle(
        _reimbursementAmountInCentsMeta,
        reimbursementAmountInCents.isAcceptableOrUnknown(
          data['reimbursement_amount_in_cents']!,
          _reimbursementAmountInCentsMeta,
        ),
      );
    }
    if (data.containsKey('reimbursement_date')) {
      context.handle(
        _reimbursementDateMeta,
        reimbursementDate.isAcceptableOrUnknown(
          data['reimbursement_date']!,
          _reimbursementDateMeta,
        ),
      );
    }
    if (data.containsKey('reimbursement_note')) {
      context.handle(
        _reimbursementNoteMeta,
        reimbursementNote.isAcceptableOrUnknown(
          data['reimbursement_note']!,
          _reimbursementNoteMeta,
        ),
      );
    }
    if (data.containsKey('refund_status')) {
      context.handle(
        _refundStatusMeta,
        refundStatus.isAcceptableOrUnknown(
          data['refund_status']!,
          _refundStatusMeta,
        ),
      );
    }
    if (data.containsKey('refund_amount_in_cents')) {
      context.handle(
        _refundAmountInCentsMeta,
        refundAmountInCents.isAcceptableOrUnknown(
          data['refund_amount_in_cents']!,
          _refundAmountInCentsMeta,
        ),
      );
    }
    if (data.containsKey('metadata_json')) {
      context.handle(
        _metadataJsonMeta,
        metadataJson.isAcceptableOrUnknown(
          data['metadata_json']!,
          _metadataJsonMeta,
        ),
      );
    }
    if (data.containsKey('duplicate_confidence')) {
      context.handle(
        _duplicateConfidenceMeta,
        duplicateConfidence.isAcceptableOrUnknown(
          data['duplicate_confidence']!,
          _duplicateConfidenceMeta,
        ),
      );
    }
    if (data.containsKey('visibility')) {
      context.handle(
        _visibilityMeta,
        visibility.isAcceptableOrUnknown(data['visibility']!, _visibilityMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TransactionEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransactionEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      amountInCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_in_cents'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      subcategoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subcategory_id'],
      ),
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      destinationAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}destination_account_id'],
      ),
      merchant: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchant'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      isRecurring: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_recurring'],
      )!,
      isOneTime: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_one_time'],
      )!,
      isLargeTransaction: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_large_transaction'],
      )!,
      isPlanned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_planned'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      aiConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ai_confidence'],
      ),
      userCorrected: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}user_corrected'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      ),
      originalTransactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_transaction_id'],
      ),
      relatedTransactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}related_transaction_id'],
      ),
      reimbursementStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reimbursement_status'],
      )!,
      reimbursementAmountInCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reimbursement_amount_in_cents'],
      ),
      reimbursementDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}reimbursement_date'],
      ),
      reimbursementNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reimbursement_note'],
      ),
      refundStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}refund_status'],
      )!,
      refundAmountInCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}refund_amount_in_cents'],
      ),
      metadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata_json'],
      ),
      duplicateConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}duplicate_confidence'],
      ),
      visibility: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}visibility'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      ),
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_by'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $TransactionEntriesTable createAlias(String alias) {
    return $TransactionEntriesTable(attachedDatabase, alias);
  }
}

class TransactionEntity extends DataClass
    implements Insertable<TransactionEntity> {
  final String id;
  final String bookId;
  final String? userId;
  final String type;
  final int amountInCents;
  final String currency;
  final String? categoryId;
  final String? subcategoryId;
  final String accountId;
  final String? destinationAccountId;
  final String? merchant;
  final String? note;
  final DateTime occurredAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool isRecurring;
  final bool isOneTime;
  final bool isLargeTransaction;
  final bool isPlanned;
  final String source;
  final double? aiConfidence;
  final bool userCorrected;
  final String syncStatus;
  final String? deviceId;
  final String? originalTransactionId;
  final String? relatedTransactionId;
  final String reimbursementStatus;
  final int? reimbursementAmountInCents;
  final DateTime? reimbursementDate;
  final String? reimbursementNote;
  final String refundStatus;
  final int? refundAmountInCents;
  final String? metadataJson;
  final double? duplicateConfidence;
  final String visibility;
  final String? createdBy;
  final String? updatedBy;
  final int version;
  const TransactionEntity({
    required this.id,
    required this.bookId,
    this.userId,
    required this.type,
    required this.amountInCents,
    required this.currency,
    this.categoryId,
    this.subcategoryId,
    required this.accountId,
    this.destinationAccountId,
    this.merchant,
    this.note,
    required this.occurredAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.isRecurring,
    required this.isOneTime,
    required this.isLargeTransaction,
    required this.isPlanned,
    required this.source,
    this.aiConfidence,
    required this.userCorrected,
    required this.syncStatus,
    this.deviceId,
    this.originalTransactionId,
    this.relatedTransactionId,
    required this.reimbursementStatus,
    this.reimbursementAmountInCents,
    this.reimbursementDate,
    this.reimbursementNote,
    required this.refundStatus,
    this.refundAmountInCents,
    this.metadataJson,
    this.duplicateConfidence,
    required this.visibility,
    this.createdBy,
    this.updatedBy,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    map['type'] = Variable<String>(type);
    map['amount_in_cents'] = Variable<int>(amountInCents);
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || subcategoryId != null) {
      map['subcategory_id'] = Variable<String>(subcategoryId);
    }
    map['account_id'] = Variable<String>(accountId);
    if (!nullToAbsent || destinationAccountId != null) {
      map['destination_account_id'] = Variable<String>(destinationAccountId);
    }
    if (!nullToAbsent || merchant != null) {
      map['merchant'] = Variable<String>(merchant);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['is_recurring'] = Variable<bool>(isRecurring);
    map['is_one_time'] = Variable<bool>(isOneTime);
    map['is_large_transaction'] = Variable<bool>(isLargeTransaction);
    map['is_planned'] = Variable<bool>(isPlanned);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || aiConfidence != null) {
      map['ai_confidence'] = Variable<double>(aiConfidence);
    }
    map['user_corrected'] = Variable<bool>(userCorrected);
    map['sync_status'] = Variable<String>(syncStatus);
    if (!nullToAbsent || deviceId != null) {
      map['device_id'] = Variable<String>(deviceId);
    }
    if (!nullToAbsent || originalTransactionId != null) {
      map['original_transaction_id'] = Variable<String>(originalTransactionId);
    }
    if (!nullToAbsent || relatedTransactionId != null) {
      map['related_transaction_id'] = Variable<String>(relatedTransactionId);
    }
    map['reimbursement_status'] = Variable<String>(reimbursementStatus);
    if (!nullToAbsent || reimbursementAmountInCents != null) {
      map['reimbursement_amount_in_cents'] = Variable<int>(
        reimbursementAmountInCents,
      );
    }
    if (!nullToAbsent || reimbursementDate != null) {
      map['reimbursement_date'] = Variable<DateTime>(reimbursementDate);
    }
    if (!nullToAbsent || reimbursementNote != null) {
      map['reimbursement_note'] = Variable<String>(reimbursementNote);
    }
    map['refund_status'] = Variable<String>(refundStatus);
    if (!nullToAbsent || refundAmountInCents != null) {
      map['refund_amount_in_cents'] = Variable<int>(refundAmountInCents);
    }
    if (!nullToAbsent || metadataJson != null) {
      map['metadata_json'] = Variable<String>(metadataJson);
    }
    if (!nullToAbsent || duplicateConfidence != null) {
      map['duplicate_confidence'] = Variable<double>(duplicateConfidence);
    }
    map['visibility'] = Variable<String>(visibility);
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    if (!nullToAbsent || updatedBy != null) {
      map['updated_by'] = Variable<String>(updatedBy);
    }
    map['version'] = Variable<int>(version);
    return map;
  }

  TransactionEntriesCompanion toCompanion(bool nullToAbsent) {
    return TransactionEntriesCompanion(
      id: Value(id),
      bookId: Value(bookId),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      type: Value(type),
      amountInCents: Value(amountInCents),
      currency: Value(currency),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      subcategoryId: subcategoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(subcategoryId),
      accountId: Value(accountId),
      destinationAccountId: destinationAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(destinationAccountId),
      merchant: merchant == null && nullToAbsent
          ? const Value.absent()
          : Value(merchant),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      occurredAt: Value(occurredAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      isRecurring: Value(isRecurring),
      isOneTime: Value(isOneTime),
      isLargeTransaction: Value(isLargeTransaction),
      isPlanned: Value(isPlanned),
      source: Value(source),
      aiConfidence: aiConfidence == null && nullToAbsent
          ? const Value.absent()
          : Value(aiConfidence),
      userCorrected: Value(userCorrected),
      syncStatus: Value(syncStatus),
      deviceId: deviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(deviceId),
      originalTransactionId: originalTransactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(originalTransactionId),
      relatedTransactionId: relatedTransactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(relatedTransactionId),
      reimbursementStatus: Value(reimbursementStatus),
      reimbursementAmountInCents:
          reimbursementAmountInCents == null && nullToAbsent
          ? const Value.absent()
          : Value(reimbursementAmountInCents),
      reimbursementDate: reimbursementDate == null && nullToAbsent
          ? const Value.absent()
          : Value(reimbursementDate),
      reimbursementNote: reimbursementNote == null && nullToAbsent
          ? const Value.absent()
          : Value(reimbursementNote),
      refundStatus: Value(refundStatus),
      refundAmountInCents: refundAmountInCents == null && nullToAbsent
          ? const Value.absent()
          : Value(refundAmountInCents),
      metadataJson: metadataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(metadataJson),
      duplicateConfidence: duplicateConfidence == null && nullToAbsent
          ? const Value.absent()
          : Value(duplicateConfidence),
      visibility: Value(visibility),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      updatedBy: updatedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedBy),
      version: Value(version),
    );
  }

  factory TransactionEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransactionEntity(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      userId: serializer.fromJson<String?>(json['userId']),
      type: serializer.fromJson<String>(json['type']),
      amountInCents: serializer.fromJson<int>(json['amountInCents']),
      currency: serializer.fromJson<String>(json['currency']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      subcategoryId: serializer.fromJson<String?>(json['subcategoryId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      destinationAccountId: serializer.fromJson<String?>(
        json['destinationAccountId'],
      ),
      merchant: serializer.fromJson<String?>(json['merchant']),
      note: serializer.fromJson<String?>(json['note']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      isRecurring: serializer.fromJson<bool>(json['isRecurring']),
      isOneTime: serializer.fromJson<bool>(json['isOneTime']),
      isLargeTransaction: serializer.fromJson<bool>(json['isLargeTransaction']),
      isPlanned: serializer.fromJson<bool>(json['isPlanned']),
      source: serializer.fromJson<String>(json['source']),
      aiConfidence: serializer.fromJson<double?>(json['aiConfidence']),
      userCorrected: serializer.fromJson<bool>(json['userCorrected']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      deviceId: serializer.fromJson<String?>(json['deviceId']),
      originalTransactionId: serializer.fromJson<String?>(
        json['originalTransactionId'],
      ),
      relatedTransactionId: serializer.fromJson<String?>(
        json['relatedTransactionId'],
      ),
      reimbursementStatus: serializer.fromJson<String>(
        json['reimbursementStatus'],
      ),
      reimbursementAmountInCents: serializer.fromJson<int?>(
        json['reimbursementAmountInCents'],
      ),
      reimbursementDate: serializer.fromJson<DateTime?>(
        json['reimbursementDate'],
      ),
      reimbursementNote: serializer.fromJson<String?>(
        json['reimbursementNote'],
      ),
      refundStatus: serializer.fromJson<String>(json['refundStatus']),
      refundAmountInCents: serializer.fromJson<int?>(
        json['refundAmountInCents'],
      ),
      metadataJson: serializer.fromJson<String?>(json['metadataJson']),
      duplicateConfidence: serializer.fromJson<double?>(
        json['duplicateConfidence'],
      ),
      visibility: serializer.fromJson<String>(json['visibility']),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
      updatedBy: serializer.fromJson<String?>(json['updatedBy']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'userId': serializer.toJson<String?>(userId),
      'type': serializer.toJson<String>(type),
      'amountInCents': serializer.toJson<int>(amountInCents),
      'currency': serializer.toJson<String>(currency),
      'categoryId': serializer.toJson<String?>(categoryId),
      'subcategoryId': serializer.toJson<String?>(subcategoryId),
      'accountId': serializer.toJson<String>(accountId),
      'destinationAccountId': serializer.toJson<String?>(destinationAccountId),
      'merchant': serializer.toJson<String?>(merchant),
      'note': serializer.toJson<String?>(note),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'isRecurring': serializer.toJson<bool>(isRecurring),
      'isOneTime': serializer.toJson<bool>(isOneTime),
      'isLargeTransaction': serializer.toJson<bool>(isLargeTransaction),
      'isPlanned': serializer.toJson<bool>(isPlanned),
      'source': serializer.toJson<String>(source),
      'aiConfidence': serializer.toJson<double?>(aiConfidence),
      'userCorrected': serializer.toJson<bool>(userCorrected),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'deviceId': serializer.toJson<String?>(deviceId),
      'originalTransactionId': serializer.toJson<String?>(
        originalTransactionId,
      ),
      'relatedTransactionId': serializer.toJson<String?>(relatedTransactionId),
      'reimbursementStatus': serializer.toJson<String>(reimbursementStatus),
      'reimbursementAmountInCents': serializer.toJson<int?>(
        reimbursementAmountInCents,
      ),
      'reimbursementDate': serializer.toJson<DateTime?>(reimbursementDate),
      'reimbursementNote': serializer.toJson<String?>(reimbursementNote),
      'refundStatus': serializer.toJson<String>(refundStatus),
      'refundAmountInCents': serializer.toJson<int?>(refundAmountInCents),
      'metadataJson': serializer.toJson<String?>(metadataJson),
      'duplicateConfidence': serializer.toJson<double?>(duplicateConfidence),
      'visibility': serializer.toJson<String>(visibility),
      'createdBy': serializer.toJson<String?>(createdBy),
      'updatedBy': serializer.toJson<String?>(updatedBy),
      'version': serializer.toJson<int>(version),
    };
  }

  TransactionEntity copyWith({
    String? id,
    String? bookId,
    Value<String?> userId = const Value.absent(),
    String? type,
    int? amountInCents,
    String? currency,
    Value<String?> categoryId = const Value.absent(),
    Value<String?> subcategoryId = const Value.absent(),
    String? accountId,
    Value<String?> destinationAccountId = const Value.absent(),
    Value<String?> merchant = const Value.absent(),
    Value<String?> note = const Value.absent(),
    DateTime? occurredAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    bool? isRecurring,
    bool? isOneTime,
    bool? isLargeTransaction,
    bool? isPlanned,
    String? source,
    Value<double?> aiConfidence = const Value.absent(),
    bool? userCorrected,
    String? syncStatus,
    Value<String?> deviceId = const Value.absent(),
    Value<String?> originalTransactionId = const Value.absent(),
    Value<String?> relatedTransactionId = const Value.absent(),
    String? reimbursementStatus,
    Value<int?> reimbursementAmountInCents = const Value.absent(),
    Value<DateTime?> reimbursementDate = const Value.absent(),
    Value<String?> reimbursementNote = const Value.absent(),
    String? refundStatus,
    Value<int?> refundAmountInCents = const Value.absent(),
    Value<String?> metadataJson = const Value.absent(),
    Value<double?> duplicateConfidence = const Value.absent(),
    String? visibility,
    Value<String?> createdBy = const Value.absent(),
    Value<String?> updatedBy = const Value.absent(),
    int? version,
  }) => TransactionEntity(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    userId: userId.present ? userId.value : this.userId,
    type: type ?? this.type,
    amountInCents: amountInCents ?? this.amountInCents,
    currency: currency ?? this.currency,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    subcategoryId: subcategoryId.present
        ? subcategoryId.value
        : this.subcategoryId,
    accountId: accountId ?? this.accountId,
    destinationAccountId: destinationAccountId.present
        ? destinationAccountId.value
        : this.destinationAccountId,
    merchant: merchant.present ? merchant.value : this.merchant,
    note: note.present ? note.value : this.note,
    occurredAt: occurredAt ?? this.occurredAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    isRecurring: isRecurring ?? this.isRecurring,
    isOneTime: isOneTime ?? this.isOneTime,
    isLargeTransaction: isLargeTransaction ?? this.isLargeTransaction,
    isPlanned: isPlanned ?? this.isPlanned,
    source: source ?? this.source,
    aiConfidence: aiConfidence.present ? aiConfidence.value : this.aiConfidence,
    userCorrected: userCorrected ?? this.userCorrected,
    syncStatus: syncStatus ?? this.syncStatus,
    deviceId: deviceId.present ? deviceId.value : this.deviceId,
    originalTransactionId: originalTransactionId.present
        ? originalTransactionId.value
        : this.originalTransactionId,
    relatedTransactionId: relatedTransactionId.present
        ? relatedTransactionId.value
        : this.relatedTransactionId,
    reimbursementStatus: reimbursementStatus ?? this.reimbursementStatus,
    reimbursementAmountInCents: reimbursementAmountInCents.present
        ? reimbursementAmountInCents.value
        : this.reimbursementAmountInCents,
    reimbursementDate: reimbursementDate.present
        ? reimbursementDate.value
        : this.reimbursementDate,
    reimbursementNote: reimbursementNote.present
        ? reimbursementNote.value
        : this.reimbursementNote,
    refundStatus: refundStatus ?? this.refundStatus,
    refundAmountInCents: refundAmountInCents.present
        ? refundAmountInCents.value
        : this.refundAmountInCents,
    metadataJson: metadataJson.present ? metadataJson.value : this.metadataJson,
    duplicateConfidence: duplicateConfidence.present
        ? duplicateConfidence.value
        : this.duplicateConfidence,
    visibility: visibility ?? this.visibility,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    updatedBy: updatedBy.present ? updatedBy.value : this.updatedBy,
    version: version ?? this.version,
  );
  TransactionEntity copyWithCompanion(TransactionEntriesCompanion data) {
    return TransactionEntity(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      userId: data.userId.present ? data.userId.value : this.userId,
      type: data.type.present ? data.type.value : this.type,
      amountInCents: data.amountInCents.present
          ? data.amountInCents.value
          : this.amountInCents,
      currency: data.currency.present ? data.currency.value : this.currency,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      subcategoryId: data.subcategoryId.present
          ? data.subcategoryId.value
          : this.subcategoryId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      destinationAccountId: data.destinationAccountId.present
          ? data.destinationAccountId.value
          : this.destinationAccountId,
      merchant: data.merchant.present ? data.merchant.value : this.merchant,
      note: data.note.present ? data.note.value : this.note,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      isRecurring: data.isRecurring.present
          ? data.isRecurring.value
          : this.isRecurring,
      isOneTime: data.isOneTime.present ? data.isOneTime.value : this.isOneTime,
      isLargeTransaction: data.isLargeTransaction.present
          ? data.isLargeTransaction.value
          : this.isLargeTransaction,
      isPlanned: data.isPlanned.present ? data.isPlanned.value : this.isPlanned,
      source: data.source.present ? data.source.value : this.source,
      aiConfidence: data.aiConfidence.present
          ? data.aiConfidence.value
          : this.aiConfidence,
      userCorrected: data.userCorrected.present
          ? data.userCorrected.value
          : this.userCorrected,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      originalTransactionId: data.originalTransactionId.present
          ? data.originalTransactionId.value
          : this.originalTransactionId,
      relatedTransactionId: data.relatedTransactionId.present
          ? data.relatedTransactionId.value
          : this.relatedTransactionId,
      reimbursementStatus: data.reimbursementStatus.present
          ? data.reimbursementStatus.value
          : this.reimbursementStatus,
      reimbursementAmountInCents: data.reimbursementAmountInCents.present
          ? data.reimbursementAmountInCents.value
          : this.reimbursementAmountInCents,
      reimbursementDate: data.reimbursementDate.present
          ? data.reimbursementDate.value
          : this.reimbursementDate,
      reimbursementNote: data.reimbursementNote.present
          ? data.reimbursementNote.value
          : this.reimbursementNote,
      refundStatus: data.refundStatus.present
          ? data.refundStatus.value
          : this.refundStatus,
      refundAmountInCents: data.refundAmountInCents.present
          ? data.refundAmountInCents.value
          : this.refundAmountInCents,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
      duplicateConfidence: data.duplicateConfidence.present
          ? data.duplicateConfidence.value
          : this.duplicateConfidence,
      visibility: data.visibility.present
          ? data.visibility.value
          : this.visibility,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransactionEntity(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('userId: $userId, ')
          ..write('type: $type, ')
          ..write('amountInCents: $amountInCents, ')
          ..write('currency: $currency, ')
          ..write('categoryId: $categoryId, ')
          ..write('subcategoryId: $subcategoryId, ')
          ..write('accountId: $accountId, ')
          ..write('destinationAccountId: $destinationAccountId, ')
          ..write('merchant: $merchant, ')
          ..write('note: $note, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('isRecurring: $isRecurring, ')
          ..write('isOneTime: $isOneTime, ')
          ..write('isLargeTransaction: $isLargeTransaction, ')
          ..write('isPlanned: $isPlanned, ')
          ..write('source: $source, ')
          ..write('aiConfidence: $aiConfidence, ')
          ..write('userCorrected: $userCorrected, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('deviceId: $deviceId, ')
          ..write('originalTransactionId: $originalTransactionId, ')
          ..write('relatedTransactionId: $relatedTransactionId, ')
          ..write('reimbursementStatus: $reimbursementStatus, ')
          ..write('reimbursementAmountInCents: $reimbursementAmountInCents, ')
          ..write('reimbursementDate: $reimbursementDate, ')
          ..write('reimbursementNote: $reimbursementNote, ')
          ..write('refundStatus: $refundStatus, ')
          ..write('refundAmountInCents: $refundAmountInCents, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('duplicateConfidence: $duplicateConfidence, ')
          ..write('visibility: $visibility, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    bookId,
    userId,
    type,
    amountInCents,
    currency,
    categoryId,
    subcategoryId,
    accountId,
    destinationAccountId,
    merchant,
    note,
    occurredAt,
    createdAt,
    updatedAt,
    deletedAt,
    isRecurring,
    isOneTime,
    isLargeTransaction,
    isPlanned,
    source,
    aiConfidence,
    userCorrected,
    syncStatus,
    deviceId,
    originalTransactionId,
    relatedTransactionId,
    reimbursementStatus,
    reimbursementAmountInCents,
    reimbursementDate,
    reimbursementNote,
    refundStatus,
    refundAmountInCents,
    metadataJson,
    duplicateConfidence,
    visibility,
    createdBy,
    updatedBy,
    version,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransactionEntity &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.userId == this.userId &&
          other.type == this.type &&
          other.amountInCents == this.amountInCents &&
          other.currency == this.currency &&
          other.categoryId == this.categoryId &&
          other.subcategoryId == this.subcategoryId &&
          other.accountId == this.accountId &&
          other.destinationAccountId == this.destinationAccountId &&
          other.merchant == this.merchant &&
          other.note == this.note &&
          other.occurredAt == this.occurredAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.isRecurring == this.isRecurring &&
          other.isOneTime == this.isOneTime &&
          other.isLargeTransaction == this.isLargeTransaction &&
          other.isPlanned == this.isPlanned &&
          other.source == this.source &&
          other.aiConfidence == this.aiConfidence &&
          other.userCorrected == this.userCorrected &&
          other.syncStatus == this.syncStatus &&
          other.deviceId == this.deviceId &&
          other.originalTransactionId == this.originalTransactionId &&
          other.relatedTransactionId == this.relatedTransactionId &&
          other.reimbursementStatus == this.reimbursementStatus &&
          other.reimbursementAmountInCents == this.reimbursementAmountInCents &&
          other.reimbursementDate == this.reimbursementDate &&
          other.reimbursementNote == this.reimbursementNote &&
          other.refundStatus == this.refundStatus &&
          other.refundAmountInCents == this.refundAmountInCents &&
          other.metadataJson == this.metadataJson &&
          other.duplicateConfidence == this.duplicateConfidence &&
          other.visibility == this.visibility &&
          other.createdBy == this.createdBy &&
          other.updatedBy == this.updatedBy &&
          other.version == this.version);
}

class TransactionEntriesCompanion extends UpdateCompanion<TransactionEntity> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String?> userId;
  final Value<String> type;
  final Value<int> amountInCents;
  final Value<String> currency;
  final Value<String?> categoryId;
  final Value<String?> subcategoryId;
  final Value<String> accountId;
  final Value<String?> destinationAccountId;
  final Value<String?> merchant;
  final Value<String?> note;
  final Value<DateTime> occurredAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<bool> isRecurring;
  final Value<bool> isOneTime;
  final Value<bool> isLargeTransaction;
  final Value<bool> isPlanned;
  final Value<String> source;
  final Value<double?> aiConfidence;
  final Value<bool> userCorrected;
  final Value<String> syncStatus;
  final Value<String?> deviceId;
  final Value<String?> originalTransactionId;
  final Value<String?> relatedTransactionId;
  final Value<String> reimbursementStatus;
  final Value<int?> reimbursementAmountInCents;
  final Value<DateTime?> reimbursementDate;
  final Value<String?> reimbursementNote;
  final Value<String> refundStatus;
  final Value<int?> refundAmountInCents;
  final Value<String?> metadataJson;
  final Value<double?> duplicateConfidence;
  final Value<String> visibility;
  final Value<String?> createdBy;
  final Value<String?> updatedBy;
  final Value<int> version;
  final Value<int> rowid;
  const TransactionEntriesCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.userId = const Value.absent(),
    this.type = const Value.absent(),
    this.amountInCents = const Value.absent(),
    this.currency = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.subcategoryId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.destinationAccountId = const Value.absent(),
    this.merchant = const Value.absent(),
    this.note = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.isRecurring = const Value.absent(),
    this.isOneTime = const Value.absent(),
    this.isLargeTransaction = const Value.absent(),
    this.isPlanned = const Value.absent(),
    this.source = const Value.absent(),
    this.aiConfidence = const Value.absent(),
    this.userCorrected = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.originalTransactionId = const Value.absent(),
    this.relatedTransactionId = const Value.absent(),
    this.reimbursementStatus = const Value.absent(),
    this.reimbursementAmountInCents = const Value.absent(),
    this.reimbursementDate = const Value.absent(),
    this.reimbursementNote = const Value.absent(),
    this.refundStatus = const Value.absent(),
    this.refundAmountInCents = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.duplicateConfidence = const Value.absent(),
    this.visibility = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionEntriesCompanion.insert({
    required String id,
    required String bookId,
    this.userId = const Value.absent(),
    required String type,
    required int amountInCents,
    this.currency = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.subcategoryId = const Value.absent(),
    required String accountId,
    this.destinationAccountId = const Value.absent(),
    this.merchant = const Value.absent(),
    this.note = const Value.absent(),
    required DateTime occurredAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.isRecurring = const Value.absent(),
    this.isOneTime = const Value.absent(),
    this.isLargeTransaction = const Value.absent(),
    this.isPlanned = const Value.absent(),
    this.source = const Value.absent(),
    this.aiConfidence = const Value.absent(),
    this.userCorrected = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.originalTransactionId = const Value.absent(),
    this.relatedTransactionId = const Value.absent(),
    this.reimbursementStatus = const Value.absent(),
    this.reimbursementAmountInCents = const Value.absent(),
    this.reimbursementDate = const Value.absent(),
    this.reimbursementNote = const Value.absent(),
    this.refundStatus = const Value.absent(),
    this.refundAmountInCents = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.duplicateConfidence = const Value.absent(),
    this.visibility = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       type = Value(type),
       amountInCents = Value(amountInCents),
       accountId = Value(accountId),
       occurredAt = Value(occurredAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TransactionEntity> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? userId,
    Expression<String>? type,
    Expression<int>? amountInCents,
    Expression<String>? currency,
    Expression<String>? categoryId,
    Expression<String>? subcategoryId,
    Expression<String>? accountId,
    Expression<String>? destinationAccountId,
    Expression<String>? merchant,
    Expression<String>? note,
    Expression<DateTime>? occurredAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<bool>? isRecurring,
    Expression<bool>? isOneTime,
    Expression<bool>? isLargeTransaction,
    Expression<bool>? isPlanned,
    Expression<String>? source,
    Expression<double>? aiConfidence,
    Expression<bool>? userCorrected,
    Expression<String>? syncStatus,
    Expression<String>? deviceId,
    Expression<String>? originalTransactionId,
    Expression<String>? relatedTransactionId,
    Expression<String>? reimbursementStatus,
    Expression<int>? reimbursementAmountInCents,
    Expression<DateTime>? reimbursementDate,
    Expression<String>? reimbursementNote,
    Expression<String>? refundStatus,
    Expression<int>? refundAmountInCents,
    Expression<String>? metadataJson,
    Expression<double>? duplicateConfidence,
    Expression<String>? visibility,
    Expression<String>? createdBy,
    Expression<String>? updatedBy,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (userId != null) 'user_id': userId,
      if (type != null) 'type': type,
      if (amountInCents != null) 'amount_in_cents': amountInCents,
      if (currency != null) 'currency': currency,
      if (categoryId != null) 'category_id': categoryId,
      if (subcategoryId != null) 'subcategory_id': subcategoryId,
      if (accountId != null) 'account_id': accountId,
      if (destinationAccountId != null)
        'destination_account_id': destinationAccountId,
      if (merchant != null) 'merchant': merchant,
      if (note != null) 'note': note,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (isRecurring != null) 'is_recurring': isRecurring,
      if (isOneTime != null) 'is_one_time': isOneTime,
      if (isLargeTransaction != null)
        'is_large_transaction': isLargeTransaction,
      if (isPlanned != null) 'is_planned': isPlanned,
      if (source != null) 'source': source,
      if (aiConfidence != null) 'ai_confidence': aiConfidence,
      if (userCorrected != null) 'user_corrected': userCorrected,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (deviceId != null) 'device_id': deviceId,
      if (originalTransactionId != null)
        'original_transaction_id': originalTransactionId,
      if (relatedTransactionId != null)
        'related_transaction_id': relatedTransactionId,
      if (reimbursementStatus != null)
        'reimbursement_status': reimbursementStatus,
      if (reimbursementAmountInCents != null)
        'reimbursement_amount_in_cents': reimbursementAmountInCents,
      if (reimbursementDate != null) 'reimbursement_date': reimbursementDate,
      if (reimbursementNote != null) 'reimbursement_note': reimbursementNote,
      if (refundStatus != null) 'refund_status': refundStatus,
      if (refundAmountInCents != null)
        'refund_amount_in_cents': refundAmountInCents,
      if (metadataJson != null) 'metadata_json': metadataJson,
      if (duplicateConfidence != null)
        'duplicate_confidence': duplicateConfidence,
      if (visibility != null) 'visibility': visibility,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String?>? userId,
    Value<String>? type,
    Value<int>? amountInCents,
    Value<String>? currency,
    Value<String?>? categoryId,
    Value<String?>? subcategoryId,
    Value<String>? accountId,
    Value<String?>? destinationAccountId,
    Value<String?>? merchant,
    Value<String?>? note,
    Value<DateTime>? occurredAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<bool>? isRecurring,
    Value<bool>? isOneTime,
    Value<bool>? isLargeTransaction,
    Value<bool>? isPlanned,
    Value<String>? source,
    Value<double?>? aiConfidence,
    Value<bool>? userCorrected,
    Value<String>? syncStatus,
    Value<String?>? deviceId,
    Value<String?>? originalTransactionId,
    Value<String?>? relatedTransactionId,
    Value<String>? reimbursementStatus,
    Value<int?>? reimbursementAmountInCents,
    Value<DateTime?>? reimbursementDate,
    Value<String?>? reimbursementNote,
    Value<String>? refundStatus,
    Value<int?>? refundAmountInCents,
    Value<String?>? metadataJson,
    Value<double?>? duplicateConfidence,
    Value<String>? visibility,
    Value<String?>? createdBy,
    Value<String?>? updatedBy,
    Value<int>? version,
    Value<int>? rowid,
  }) {
    return TransactionEntriesCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      amountInCents: amountInCents ?? this.amountInCents,
      currency: currency ?? this.currency,
      categoryId: categoryId ?? this.categoryId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      accountId: accountId ?? this.accountId,
      destinationAccountId: destinationAccountId ?? this.destinationAccountId,
      merchant: merchant ?? this.merchant,
      note: note ?? this.note,
      occurredAt: occurredAt ?? this.occurredAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      isRecurring: isRecurring ?? this.isRecurring,
      isOneTime: isOneTime ?? this.isOneTime,
      isLargeTransaction: isLargeTransaction ?? this.isLargeTransaction,
      isPlanned: isPlanned ?? this.isPlanned,
      source: source ?? this.source,
      aiConfidence: aiConfidence ?? this.aiConfidence,
      userCorrected: userCorrected ?? this.userCorrected,
      syncStatus: syncStatus ?? this.syncStatus,
      deviceId: deviceId ?? this.deviceId,
      originalTransactionId:
          originalTransactionId ?? this.originalTransactionId,
      relatedTransactionId: relatedTransactionId ?? this.relatedTransactionId,
      reimbursementStatus: reimbursementStatus ?? this.reimbursementStatus,
      reimbursementAmountInCents:
          reimbursementAmountInCents ?? this.reimbursementAmountInCents,
      reimbursementDate: reimbursementDate ?? this.reimbursementDate,
      reimbursementNote: reimbursementNote ?? this.reimbursementNote,
      refundStatus: refundStatus ?? this.refundStatus,
      refundAmountInCents: refundAmountInCents ?? this.refundAmountInCents,
      metadataJson: metadataJson ?? this.metadataJson,
      duplicateConfidence: duplicateConfidence ?? this.duplicateConfidence,
      visibility: visibility ?? this.visibility,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      version: version ?? this.version,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (amountInCents.present) {
      map['amount_in_cents'] = Variable<int>(amountInCents.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (subcategoryId.present) {
      map['subcategory_id'] = Variable<String>(subcategoryId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (destinationAccountId.present) {
      map['destination_account_id'] = Variable<String>(
        destinationAccountId.value,
      );
    }
    if (merchant.present) {
      map['merchant'] = Variable<String>(merchant.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (isRecurring.present) {
      map['is_recurring'] = Variable<bool>(isRecurring.value);
    }
    if (isOneTime.present) {
      map['is_one_time'] = Variable<bool>(isOneTime.value);
    }
    if (isLargeTransaction.present) {
      map['is_large_transaction'] = Variable<bool>(isLargeTransaction.value);
    }
    if (isPlanned.present) {
      map['is_planned'] = Variable<bool>(isPlanned.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (aiConfidence.present) {
      map['ai_confidence'] = Variable<double>(aiConfidence.value);
    }
    if (userCorrected.present) {
      map['user_corrected'] = Variable<bool>(userCorrected.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (originalTransactionId.present) {
      map['original_transaction_id'] = Variable<String>(
        originalTransactionId.value,
      );
    }
    if (relatedTransactionId.present) {
      map['related_transaction_id'] = Variable<String>(
        relatedTransactionId.value,
      );
    }
    if (reimbursementStatus.present) {
      map['reimbursement_status'] = Variable<String>(reimbursementStatus.value);
    }
    if (reimbursementAmountInCents.present) {
      map['reimbursement_amount_in_cents'] = Variable<int>(
        reimbursementAmountInCents.value,
      );
    }
    if (reimbursementDate.present) {
      map['reimbursement_date'] = Variable<DateTime>(reimbursementDate.value);
    }
    if (reimbursementNote.present) {
      map['reimbursement_note'] = Variable<String>(reimbursementNote.value);
    }
    if (refundStatus.present) {
      map['refund_status'] = Variable<String>(refundStatus.value);
    }
    if (refundAmountInCents.present) {
      map['refund_amount_in_cents'] = Variable<int>(refundAmountInCents.value);
    }
    if (metadataJson.present) {
      map['metadata_json'] = Variable<String>(metadataJson.value);
    }
    if (duplicateConfidence.present) {
      map['duplicate_confidence'] = Variable<double>(duplicateConfidence.value);
    }
    if (visibility.present) {
      map['visibility'] = Variable<String>(visibility.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<String>(updatedBy.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionEntriesCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('userId: $userId, ')
          ..write('type: $type, ')
          ..write('amountInCents: $amountInCents, ')
          ..write('currency: $currency, ')
          ..write('categoryId: $categoryId, ')
          ..write('subcategoryId: $subcategoryId, ')
          ..write('accountId: $accountId, ')
          ..write('destinationAccountId: $destinationAccountId, ')
          ..write('merchant: $merchant, ')
          ..write('note: $note, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('isRecurring: $isRecurring, ')
          ..write('isOneTime: $isOneTime, ')
          ..write('isLargeTransaction: $isLargeTransaction, ')
          ..write('isPlanned: $isPlanned, ')
          ..write('source: $source, ')
          ..write('aiConfidence: $aiConfidence, ')
          ..write('userCorrected: $userCorrected, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('deviceId: $deviceId, ')
          ..write('originalTransactionId: $originalTransactionId, ')
          ..write('relatedTransactionId: $relatedTransactionId, ')
          ..write('reimbursementStatus: $reimbursementStatus, ')
          ..write('reimbursementAmountInCents: $reimbursementAmountInCents, ')
          ..write('reimbursementDate: $reimbursementDate, ')
          ..write('reimbursementNote: $reimbursementNote, ')
          ..write('refundStatus: $refundStatus, ')
          ..write('refundAmountInCents: $refundAmountInCents, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('duplicateConfidence: $duplicateConfidence, ')
          ..write('visibility: $visibility, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GoalEntriesTable extends GoalEntries
    with TableInfo<$GoalEntriesTable, GoalEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GoalEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _goalTypeMeta = const VerificationMeta(
    'goalType',
  );
  @override
  late final GeneratedColumn<String> goalType = GeneratedColumn<String>(
    'goal_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('custom'),
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetAmountInCentsMeta =
      const VerificationMeta('targetAmountInCents');
  @override
  late final GeneratedColumn<int> targetAmountInCents = GeneratedColumn<int>(
    'target_amount_in_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentAmountInCentsMeta =
      const VerificationMeta('currentAmountInCents');
  @override
  late final GeneratedColumn<int> currentAmountInCents = GeneratedColumn<int>(
    'current_amount_in_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _targetDateMeta = const VerificationMeta(
    'targetDate',
  );
  @override
  late final GeneratedColumn<DateTime> targetDate = GeneratedColumn<DateTime>(
    'target_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverPathMeta = const VerificationMeta(
    'coverPath',
  );
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
    'cover_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _completionCelebrationShownMeta =
      const VerificationMeta('completionCelebrationShown');
  @override
  late final GeneratedColumn<bool> completionCelebrationShown =
      GeneratedColumn<bool>(
        'completion_celebration_shown',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("completion_celebration_shown" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('book-personal'),
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedByMeta = const VerificationMeta(
    'updatedBy',
  );
  @override
  late final GeneratedColumn<String> updatedBy = GeneratedColumn<String>(
    'updated_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _monthlyReservationInCentsMeta =
      const VerificationMeta('monthlyReservationInCents');
  @override
  late final GeneratedColumn<int> monthlyReservationInCents =
      GeneratedColumn<int>(
        'monthly_reservation_in_cents',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    goalType,
    icon,
    targetAmountInCents,
    currentAmountInCents,
    targetDate,
    status,
    createdAt,
    updatedAt,
    description,
    coverPath,
    completionCelebrationShown,
    bookId,
    createdBy,
    updatedBy,
    version,
    sortOrder,
    monthlyReservationInCents,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'goals';
  @override
  VerificationContext validateIntegrity(
    Insertable<GoalEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('goal_type')) {
      context.handle(
        _goalTypeMeta,
        goalType.isAcceptableOrUnknown(data['goal_type']!, _goalTypeMeta),
      );
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    } else if (isInserting) {
      context.missing(_iconMeta);
    }
    if (data.containsKey('target_amount_in_cents')) {
      context.handle(
        _targetAmountInCentsMeta,
        targetAmountInCents.isAcceptableOrUnknown(
          data['target_amount_in_cents']!,
          _targetAmountInCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetAmountInCentsMeta);
    }
    if (data.containsKey('current_amount_in_cents')) {
      context.handle(
        _currentAmountInCentsMeta,
        currentAmountInCents.isAcceptableOrUnknown(
          data['current_amount_in_cents']!,
          _currentAmountInCentsMeta,
        ),
      );
    }
    if (data.containsKey('target_date')) {
      context.handle(
        _targetDateMeta,
        targetDate.isAcceptableOrUnknown(data['target_date']!, _targetDateMeta),
      );
    } else if (isInserting) {
      context.missing(_targetDateMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('completion_celebration_shown')) {
      context.handle(
        _completionCelebrationShownMeta,
        completionCelebrationShown.isAcceptableOrUnknown(
          data['completion_celebration_shown']!,
          _completionCelebrationShownMeta,
        ),
      );
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('monthly_reservation_in_cents')) {
      context.handle(
        _monthlyReservationInCentsMeta,
        monthlyReservationInCents.isAcceptableOrUnknown(
          data['monthly_reservation_in_cents']!,
          _monthlyReservationInCentsMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GoalEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GoalEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      goalType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goal_type'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      targetAmountInCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_amount_in_cents'],
      )!,
      currentAmountInCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_amount_in_cents'],
      )!,
      targetDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}target_date'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      completionCelebrationShown: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completion_celebration_shown'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      ),
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_by'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      monthlyReservationInCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}monthly_reservation_in_cents'],
      )!,
    );
  }

  @override
  $GoalEntriesTable createAlias(String alias) {
    return $GoalEntriesTable(attachedDatabase, alias);
  }
}

class GoalEntity extends DataClass implements Insertable<GoalEntity> {
  final String id;
  final String name;
  final String goalType;
  final String icon;
  final int targetAmountInCents;
  final int currentAmountInCents;
  final DateTime targetDate;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? description;
  final String? coverPath;
  final bool completionCelebrationShown;
  final String bookId;
  final String? createdBy;
  final String? updatedBy;
  final int version;
  final int sortOrder;
  final int monthlyReservationInCents;
  const GoalEntity({
    required this.id,
    required this.name,
    required this.goalType,
    required this.icon,
    required this.targetAmountInCents,
    required this.currentAmountInCents,
    required this.targetDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.coverPath,
    required this.completionCelebrationShown,
    required this.bookId,
    this.createdBy,
    this.updatedBy,
    required this.version,
    required this.sortOrder,
    required this.monthlyReservationInCents,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['goal_type'] = Variable<String>(goalType);
    map['icon'] = Variable<String>(icon);
    map['target_amount_in_cents'] = Variable<int>(targetAmountInCents);
    map['current_amount_in_cents'] = Variable<int>(currentAmountInCents);
    map['target_date'] = Variable<DateTime>(targetDate);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    map['completion_celebration_shown'] = Variable<bool>(
      completionCelebrationShown,
    );
    map['book_id'] = Variable<String>(bookId);
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    if (!nullToAbsent || updatedBy != null) {
      map['updated_by'] = Variable<String>(updatedBy);
    }
    map['version'] = Variable<int>(version);
    map['sort_order'] = Variable<int>(sortOrder);
    map['monthly_reservation_in_cents'] = Variable<int>(
      monthlyReservationInCents,
    );
    return map;
  }

  GoalEntriesCompanion toCompanion(bool nullToAbsent) {
    return GoalEntriesCompanion(
      id: Value(id),
      name: Value(name),
      goalType: Value(goalType),
      icon: Value(icon),
      targetAmountInCents: Value(targetAmountInCents),
      currentAmountInCents: Value(currentAmountInCents),
      targetDate: Value(targetDate),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      coverPath: coverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverPath),
      completionCelebrationShown: Value(completionCelebrationShown),
      bookId: Value(bookId),
      createdBy: createdBy == null && nullToAbsent
          ? const Value.absent()
          : Value(createdBy),
      updatedBy: updatedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedBy),
      version: Value(version),
      sortOrder: Value(sortOrder),
      monthlyReservationInCents: Value(monthlyReservationInCents),
    );
  }

  factory GoalEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GoalEntity(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      goalType: serializer.fromJson<String>(json['goalType']),
      icon: serializer.fromJson<String>(json['icon']),
      targetAmountInCents: serializer.fromJson<int>(
        json['targetAmountInCents'],
      ),
      currentAmountInCents: serializer.fromJson<int>(
        json['currentAmountInCents'],
      ),
      targetDate: serializer.fromJson<DateTime>(json['targetDate']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      description: serializer.fromJson<String?>(json['description']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      completionCelebrationShown: serializer.fromJson<bool>(
        json['completionCelebrationShown'],
      ),
      bookId: serializer.fromJson<String>(json['bookId']),
      createdBy: serializer.fromJson<String?>(json['createdBy']),
      updatedBy: serializer.fromJson<String?>(json['updatedBy']),
      version: serializer.fromJson<int>(json['version']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      monthlyReservationInCents: serializer.fromJson<int>(
        json['monthlyReservationInCents'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'goalType': serializer.toJson<String>(goalType),
      'icon': serializer.toJson<String>(icon),
      'targetAmountInCents': serializer.toJson<int>(targetAmountInCents),
      'currentAmountInCents': serializer.toJson<int>(currentAmountInCents),
      'targetDate': serializer.toJson<DateTime>(targetDate),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'description': serializer.toJson<String?>(description),
      'coverPath': serializer.toJson<String?>(coverPath),
      'completionCelebrationShown': serializer.toJson<bool>(
        completionCelebrationShown,
      ),
      'bookId': serializer.toJson<String>(bookId),
      'createdBy': serializer.toJson<String?>(createdBy),
      'updatedBy': serializer.toJson<String?>(updatedBy),
      'version': serializer.toJson<int>(version),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'monthlyReservationInCents': serializer.toJson<int>(
        monthlyReservationInCents,
      ),
    };
  }

  GoalEntity copyWith({
    String? id,
    String? name,
    String? goalType,
    String? icon,
    int? targetAmountInCents,
    int? currentAmountInCents,
    DateTime? targetDate,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<String?> description = const Value.absent(),
    Value<String?> coverPath = const Value.absent(),
    bool? completionCelebrationShown,
    String? bookId,
    Value<String?> createdBy = const Value.absent(),
    Value<String?> updatedBy = const Value.absent(),
    int? version,
    int? sortOrder,
    int? monthlyReservationInCents,
  }) => GoalEntity(
    id: id ?? this.id,
    name: name ?? this.name,
    goalType: goalType ?? this.goalType,
    icon: icon ?? this.icon,
    targetAmountInCents: targetAmountInCents ?? this.targetAmountInCents,
    currentAmountInCents: currentAmountInCents ?? this.currentAmountInCents,
    targetDate: targetDate ?? this.targetDate,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    description: description.present ? description.value : this.description,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    completionCelebrationShown:
        completionCelebrationShown ?? this.completionCelebrationShown,
    bookId: bookId ?? this.bookId,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    updatedBy: updatedBy.present ? updatedBy.value : this.updatedBy,
    version: version ?? this.version,
    sortOrder: sortOrder ?? this.sortOrder,
    monthlyReservationInCents:
        monthlyReservationInCents ?? this.monthlyReservationInCents,
  );
  GoalEntity copyWithCompanion(GoalEntriesCompanion data) {
    return GoalEntity(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      goalType: data.goalType.present ? data.goalType.value : this.goalType,
      icon: data.icon.present ? data.icon.value : this.icon,
      targetAmountInCents: data.targetAmountInCents.present
          ? data.targetAmountInCents.value
          : this.targetAmountInCents,
      currentAmountInCents: data.currentAmountInCents.present
          ? data.currentAmountInCents.value
          : this.currentAmountInCents,
      targetDate: data.targetDate.present
          ? data.targetDate.value
          : this.targetDate,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      description: data.description.present
          ? data.description.value
          : this.description,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      completionCelebrationShown: data.completionCelebrationShown.present
          ? data.completionCelebrationShown.value
          : this.completionCelebrationShown,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      version: data.version.present ? data.version.value : this.version,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      monthlyReservationInCents: data.monthlyReservationInCents.present
          ? data.monthlyReservationInCents.value
          : this.monthlyReservationInCents,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GoalEntity(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('goalType: $goalType, ')
          ..write('icon: $icon, ')
          ..write('targetAmountInCents: $targetAmountInCents, ')
          ..write('currentAmountInCents: $currentAmountInCents, ')
          ..write('targetDate: $targetDate, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('description: $description, ')
          ..write('coverPath: $coverPath, ')
          ..write('completionCelebrationShown: $completionCelebrationShown, ')
          ..write('bookId: $bookId, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('version: $version, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('monthlyReservationInCents: $monthlyReservationInCents')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    goalType,
    icon,
    targetAmountInCents,
    currentAmountInCents,
    targetDate,
    status,
    createdAt,
    updatedAt,
    description,
    coverPath,
    completionCelebrationShown,
    bookId,
    createdBy,
    updatedBy,
    version,
    sortOrder,
    monthlyReservationInCents,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GoalEntity &&
          other.id == this.id &&
          other.name == this.name &&
          other.goalType == this.goalType &&
          other.icon == this.icon &&
          other.targetAmountInCents == this.targetAmountInCents &&
          other.currentAmountInCents == this.currentAmountInCents &&
          other.targetDate == this.targetDate &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.description == this.description &&
          other.coverPath == this.coverPath &&
          other.completionCelebrationShown == this.completionCelebrationShown &&
          other.bookId == this.bookId &&
          other.createdBy == this.createdBy &&
          other.updatedBy == this.updatedBy &&
          other.version == this.version &&
          other.sortOrder == this.sortOrder &&
          other.monthlyReservationInCents == this.monthlyReservationInCents);
}

class GoalEntriesCompanion extends UpdateCompanion<GoalEntity> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> goalType;
  final Value<String> icon;
  final Value<int> targetAmountInCents;
  final Value<int> currentAmountInCents;
  final Value<DateTime> targetDate;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<String?> description;
  final Value<String?> coverPath;
  final Value<bool> completionCelebrationShown;
  final Value<String> bookId;
  final Value<String?> createdBy;
  final Value<String?> updatedBy;
  final Value<int> version;
  final Value<int> sortOrder;
  final Value<int> monthlyReservationInCents;
  final Value<int> rowid;
  const GoalEntriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.goalType = const Value.absent(),
    this.icon = const Value.absent(),
    this.targetAmountInCents = const Value.absent(),
    this.currentAmountInCents = const Value.absent(),
    this.targetDate = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.description = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.completionCelebrationShown = const Value.absent(),
    this.bookId = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.version = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.monthlyReservationInCents = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GoalEntriesCompanion.insert({
    required String id,
    required String name,
    this.goalType = const Value.absent(),
    required String icon,
    required int targetAmountInCents,
    this.currentAmountInCents = const Value.absent(),
    required DateTime targetDate,
    this.status = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.description = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.completionCelebrationShown = const Value.absent(),
    this.bookId = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.version = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.monthlyReservationInCents = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       icon = Value(icon),
       targetAmountInCents = Value(targetAmountInCents),
       targetDate = Value(targetDate),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<GoalEntity> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? goalType,
    Expression<String>? icon,
    Expression<int>? targetAmountInCents,
    Expression<int>? currentAmountInCents,
    Expression<DateTime>? targetDate,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? description,
    Expression<String>? coverPath,
    Expression<bool>? completionCelebrationShown,
    Expression<String>? bookId,
    Expression<String>? createdBy,
    Expression<String>? updatedBy,
    Expression<int>? version,
    Expression<int>? sortOrder,
    Expression<int>? monthlyReservationInCents,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (goalType != null) 'goal_type': goalType,
      if (icon != null) 'icon': icon,
      if (targetAmountInCents != null)
        'target_amount_in_cents': targetAmountInCents,
      if (currentAmountInCents != null)
        'current_amount_in_cents': currentAmountInCents,
      if (targetDate != null) 'target_date': targetDate,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (description != null) 'description': description,
      if (coverPath != null) 'cover_path': coverPath,
      if (completionCelebrationShown != null)
        'completion_celebration_shown': completionCelebrationShown,
      if (bookId != null) 'book_id': bookId,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (version != null) 'version': version,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (monthlyReservationInCents != null)
        'monthly_reservation_in_cents': monthlyReservationInCents,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GoalEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? goalType,
    Value<String>? icon,
    Value<int>? targetAmountInCents,
    Value<int>? currentAmountInCents,
    Value<DateTime>? targetDate,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<String?>? description,
    Value<String?>? coverPath,
    Value<bool>? completionCelebrationShown,
    Value<String>? bookId,
    Value<String?>? createdBy,
    Value<String?>? updatedBy,
    Value<int>? version,
    Value<int>? sortOrder,
    Value<int>? monthlyReservationInCents,
    Value<int>? rowid,
  }) {
    return GoalEntriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      goalType: goalType ?? this.goalType,
      icon: icon ?? this.icon,
      targetAmountInCents: targetAmountInCents ?? this.targetAmountInCents,
      currentAmountInCents: currentAmountInCents ?? this.currentAmountInCents,
      targetDate: targetDate ?? this.targetDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      description: description ?? this.description,
      coverPath: coverPath ?? this.coverPath,
      completionCelebrationShown:
          completionCelebrationShown ?? this.completionCelebrationShown,
      bookId: bookId ?? this.bookId,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      version: version ?? this.version,
      sortOrder: sortOrder ?? this.sortOrder,
      monthlyReservationInCents:
          monthlyReservationInCents ?? this.monthlyReservationInCents,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (goalType.present) {
      map['goal_type'] = Variable<String>(goalType.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (targetAmountInCents.present) {
      map['target_amount_in_cents'] = Variable<int>(targetAmountInCents.value);
    }
    if (currentAmountInCents.present) {
      map['current_amount_in_cents'] = Variable<int>(
        currentAmountInCents.value,
      );
    }
    if (targetDate.present) {
      map['target_date'] = Variable<DateTime>(targetDate.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (completionCelebrationShown.present) {
      map['completion_celebration_shown'] = Variable<bool>(
        completionCelebrationShown.value,
      );
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<String>(updatedBy.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (monthlyReservationInCents.present) {
      map['monthly_reservation_in_cents'] = Variable<int>(
        monthlyReservationInCents.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GoalEntriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('goalType: $goalType, ')
          ..write('icon: $icon, ')
          ..write('targetAmountInCents: $targetAmountInCents, ')
          ..write('currentAmountInCents: $currentAmountInCents, ')
          ..write('targetDate: $targetDate, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('description: $description, ')
          ..write('coverPath: $coverPath, ')
          ..write('completionCelebrationShown: $completionCelebrationShown, ')
          ..write('bookId: $bookId, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('version: $version, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('monthlyReservationInCents: $monthlyReservationInCents, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GoalMilestoneEntriesTable extends GoalMilestoneEntries
    with TableInfo<$GoalMilestoneEntriesTable, GoalMilestoneEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GoalMilestoneEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _goalIdMeta = const VerificationMeta('goalId');
  @override
  late final GeneratedColumn<String> goalId = GeneratedColumn<String>(
    'goal_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES goals (id)',
    ),
  );
  static const VerificationMeta _amountInCentsMeta = const VerificationMeta(
    'amountInCents',
  );
  @override
  late final GeneratedColumn<int> amountInCents = GeneratedColumn<int>(
    'amount_in_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _celebrationShownMeta = const VerificationMeta(
    'celebrationShown',
  );
  @override
  late final GeneratedColumn<bool> celebrationShown = GeneratedColumn<bool>(
    'celebration_shown',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("celebration_shown" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    goalId,
    amountInCents,
    title,
    sortOrder,
    completedAt,
    celebrationShown,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'goal_milestones';
  @override
  VerificationContext validateIntegrity(
    Insertable<GoalMilestoneEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('goal_id')) {
      context.handle(
        _goalIdMeta,
        goalId.isAcceptableOrUnknown(data['goal_id']!, _goalIdMeta),
      );
    } else if (isInserting) {
      context.missing(_goalIdMeta);
    }
    if (data.containsKey('amount_in_cents')) {
      context.handle(
        _amountInCentsMeta,
        amountInCents.isAcceptableOrUnknown(
          data['amount_in_cents']!,
          _amountInCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountInCentsMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('celebration_shown')) {
      context.handle(
        _celebrationShownMeta,
        celebrationShown.isAcceptableOrUnknown(
          data['celebration_shown']!,
          _celebrationShownMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GoalMilestoneEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GoalMilestoneEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      goalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goal_id'],
      )!,
      amountInCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_in_cents'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      celebrationShown: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}celebration_shown'],
      )!,
    );
  }

  @override
  $GoalMilestoneEntriesTable createAlias(String alias) {
    return $GoalMilestoneEntriesTable(attachedDatabase, alias);
  }
}

class GoalMilestoneEntity extends DataClass
    implements Insertable<GoalMilestoneEntity> {
  final String id;
  final String goalId;
  final int amountInCents;
  final String title;
  final int sortOrder;
  final DateTime? completedAt;
  final bool celebrationShown;
  const GoalMilestoneEntity({
    required this.id,
    required this.goalId,
    required this.amountInCents,
    required this.title,
    required this.sortOrder,
    this.completedAt,
    required this.celebrationShown,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['goal_id'] = Variable<String>(goalId);
    map['amount_in_cents'] = Variable<int>(amountInCents);
    map['title'] = Variable<String>(title);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['celebration_shown'] = Variable<bool>(celebrationShown);
    return map;
  }

  GoalMilestoneEntriesCompanion toCompanion(bool nullToAbsent) {
    return GoalMilestoneEntriesCompanion(
      id: Value(id),
      goalId: Value(goalId),
      amountInCents: Value(amountInCents),
      title: Value(title),
      sortOrder: Value(sortOrder),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      celebrationShown: Value(celebrationShown),
    );
  }

  factory GoalMilestoneEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GoalMilestoneEntity(
      id: serializer.fromJson<String>(json['id']),
      goalId: serializer.fromJson<String>(json['goalId']),
      amountInCents: serializer.fromJson<int>(json['amountInCents']),
      title: serializer.fromJson<String>(json['title']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      celebrationShown: serializer.fromJson<bool>(json['celebrationShown']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'goalId': serializer.toJson<String>(goalId),
      'amountInCents': serializer.toJson<int>(amountInCents),
      'title': serializer.toJson<String>(title),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'celebrationShown': serializer.toJson<bool>(celebrationShown),
    };
  }

  GoalMilestoneEntity copyWith({
    String? id,
    String? goalId,
    int? amountInCents,
    String? title,
    int? sortOrder,
    Value<DateTime?> completedAt = const Value.absent(),
    bool? celebrationShown,
  }) => GoalMilestoneEntity(
    id: id ?? this.id,
    goalId: goalId ?? this.goalId,
    amountInCents: amountInCents ?? this.amountInCents,
    title: title ?? this.title,
    sortOrder: sortOrder ?? this.sortOrder,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    celebrationShown: celebrationShown ?? this.celebrationShown,
  );
  GoalMilestoneEntity copyWithCompanion(GoalMilestoneEntriesCompanion data) {
    return GoalMilestoneEntity(
      id: data.id.present ? data.id.value : this.id,
      goalId: data.goalId.present ? data.goalId.value : this.goalId,
      amountInCents: data.amountInCents.present
          ? data.amountInCents.value
          : this.amountInCents,
      title: data.title.present ? data.title.value : this.title,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      celebrationShown: data.celebrationShown.present
          ? data.celebrationShown.value
          : this.celebrationShown,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GoalMilestoneEntity(')
          ..write('id: $id, ')
          ..write('goalId: $goalId, ')
          ..write('amountInCents: $amountInCents, ')
          ..write('title: $title, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('completedAt: $completedAt, ')
          ..write('celebrationShown: $celebrationShown')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    goalId,
    amountInCents,
    title,
    sortOrder,
    completedAt,
    celebrationShown,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GoalMilestoneEntity &&
          other.id == this.id &&
          other.goalId == this.goalId &&
          other.amountInCents == this.amountInCents &&
          other.title == this.title &&
          other.sortOrder == this.sortOrder &&
          other.completedAt == this.completedAt &&
          other.celebrationShown == this.celebrationShown);
}

class GoalMilestoneEntriesCompanion
    extends UpdateCompanion<GoalMilestoneEntity> {
  final Value<String> id;
  final Value<String> goalId;
  final Value<int> amountInCents;
  final Value<String> title;
  final Value<int> sortOrder;
  final Value<DateTime?> completedAt;
  final Value<bool> celebrationShown;
  final Value<int> rowid;
  const GoalMilestoneEntriesCompanion({
    this.id = const Value.absent(),
    this.goalId = const Value.absent(),
    this.amountInCents = const Value.absent(),
    this.title = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.celebrationShown = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GoalMilestoneEntriesCompanion.insert({
    required String id,
    required String goalId,
    required int amountInCents,
    required String title,
    required int sortOrder,
    this.completedAt = const Value.absent(),
    this.celebrationShown = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       goalId = Value(goalId),
       amountInCents = Value(amountInCents),
       title = Value(title),
       sortOrder = Value(sortOrder);
  static Insertable<GoalMilestoneEntity> custom({
    Expression<String>? id,
    Expression<String>? goalId,
    Expression<int>? amountInCents,
    Expression<String>? title,
    Expression<int>? sortOrder,
    Expression<DateTime>? completedAt,
    Expression<bool>? celebrationShown,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (goalId != null) 'goal_id': goalId,
      if (amountInCents != null) 'amount_in_cents': amountInCents,
      if (title != null) 'title': title,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (completedAt != null) 'completed_at': completedAt,
      if (celebrationShown != null) 'celebration_shown': celebrationShown,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GoalMilestoneEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? goalId,
    Value<int>? amountInCents,
    Value<String>? title,
    Value<int>? sortOrder,
    Value<DateTime?>? completedAt,
    Value<bool>? celebrationShown,
    Value<int>? rowid,
  }) {
    return GoalMilestoneEntriesCompanion(
      id: id ?? this.id,
      goalId: goalId ?? this.goalId,
      amountInCents: amountInCents ?? this.amountInCents,
      title: title ?? this.title,
      sortOrder: sortOrder ?? this.sortOrder,
      completedAt: completedAt ?? this.completedAt,
      celebrationShown: celebrationShown ?? this.celebrationShown,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (goalId.present) {
      map['goal_id'] = Variable<String>(goalId.value);
    }
    if (amountInCents.present) {
      map['amount_in_cents'] = Variable<int>(amountInCents.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (celebrationShown.present) {
      map['celebration_shown'] = Variable<bool>(celebrationShown.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GoalMilestoneEntriesCompanion(')
          ..write('id: $id, ')
          ..write('goalId: $goalId, ')
          ..write('amountInCents: $amountInCents, ')
          ..write('title: $title, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('completedAt: $completedAt, ')
          ..write('celebrationShown: $celebrationShown, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GoalContributionEntriesTable extends GoalContributionEntries
    with TableInfo<$GoalContributionEntriesTable, GoalContributionEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GoalContributionEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _goalIdMeta = const VerificationMeta('goalId');
  @override
  late final GeneratedColumn<String> goalId = GeneratedColumn<String>(
    'goal_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES goals (id)',
    ),
  );
  static const VerificationMeta _amountInCentsMeta = const VerificationMeta(
    'amountInCents',
  );
  @override
  late final GeneratedColumn<int> amountInCents = GeneratedColumn<int>(
    'amount_in_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceTransactionIdMeta =
      const VerificationMeta('sourceTransactionId');
  @override
  late final GeneratedColumn<String> sourceTransactionId =
      GeneratedColumn<String>(
        'source_transaction_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contributorUserIdMeta = const VerificationMeta(
    'contributorUserId',
  );
  @override
  late final GeneratedColumn<String> contributorUserId =
      GeneratedColumn<String>(
        'contributor_user_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    goalId,
    amountInCents,
    type,
    sourceTransactionId,
    createdAt,
    note,
    contributorUserId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'goal_contributions';
  @override
  VerificationContext validateIntegrity(
    Insertable<GoalContributionEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('goal_id')) {
      context.handle(
        _goalIdMeta,
        goalId.isAcceptableOrUnknown(data['goal_id']!, _goalIdMeta),
      );
    } else if (isInserting) {
      context.missing(_goalIdMeta);
    }
    if (data.containsKey('amount_in_cents')) {
      context.handle(
        _amountInCentsMeta,
        amountInCents.isAcceptableOrUnknown(
          data['amount_in_cents']!,
          _amountInCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountInCentsMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('source_transaction_id')) {
      context.handle(
        _sourceTransactionIdMeta,
        sourceTransactionId.isAcceptableOrUnknown(
          data['source_transaction_id']!,
          _sourceTransactionIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('contributor_user_id')) {
      context.handle(
        _contributorUserIdMeta,
        contributorUserId.isAcceptableOrUnknown(
          data['contributor_user_id']!,
          _contributorUserIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GoalContributionEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GoalContributionEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      goalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goal_id'],
      )!,
      amountInCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_in_cents'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      sourceTransactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_transaction_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      contributorUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contributor_user_id'],
      ),
    );
  }

  @override
  $GoalContributionEntriesTable createAlias(String alias) {
    return $GoalContributionEntriesTable(attachedDatabase, alias);
  }
}

class GoalContributionEntity extends DataClass
    implements Insertable<GoalContributionEntity> {
  final String id;
  final String goalId;
  final int amountInCents;
  final String type;
  final String? sourceTransactionId;
  final DateTime createdAt;
  final String? note;
  final String? contributorUserId;
  const GoalContributionEntity({
    required this.id,
    required this.goalId,
    required this.amountInCents,
    required this.type,
    this.sourceTransactionId,
    required this.createdAt,
    this.note,
    this.contributorUserId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['goal_id'] = Variable<String>(goalId);
    map['amount_in_cents'] = Variable<int>(amountInCents);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || sourceTransactionId != null) {
      map['source_transaction_id'] = Variable<String>(sourceTransactionId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || contributorUserId != null) {
      map['contributor_user_id'] = Variable<String>(contributorUserId);
    }
    return map;
  }

  GoalContributionEntriesCompanion toCompanion(bool nullToAbsent) {
    return GoalContributionEntriesCompanion(
      id: Value(id),
      goalId: Value(goalId),
      amountInCents: Value(amountInCents),
      type: Value(type),
      sourceTransactionId: sourceTransactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceTransactionId),
      createdAt: Value(createdAt),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      contributorUserId: contributorUserId == null && nullToAbsent
          ? const Value.absent()
          : Value(contributorUserId),
    );
  }

  factory GoalContributionEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GoalContributionEntity(
      id: serializer.fromJson<String>(json['id']),
      goalId: serializer.fromJson<String>(json['goalId']),
      amountInCents: serializer.fromJson<int>(json['amountInCents']),
      type: serializer.fromJson<String>(json['type']),
      sourceTransactionId: serializer.fromJson<String?>(
        json['sourceTransactionId'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      note: serializer.fromJson<String?>(json['note']),
      contributorUserId: serializer.fromJson<String?>(
        json['contributorUserId'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'goalId': serializer.toJson<String>(goalId),
      'amountInCents': serializer.toJson<int>(amountInCents),
      'type': serializer.toJson<String>(type),
      'sourceTransactionId': serializer.toJson<String?>(sourceTransactionId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'note': serializer.toJson<String?>(note),
      'contributorUserId': serializer.toJson<String?>(contributorUserId),
    };
  }

  GoalContributionEntity copyWith({
    String? id,
    String? goalId,
    int? amountInCents,
    String? type,
    Value<String?> sourceTransactionId = const Value.absent(),
    DateTime? createdAt,
    Value<String?> note = const Value.absent(),
    Value<String?> contributorUserId = const Value.absent(),
  }) => GoalContributionEntity(
    id: id ?? this.id,
    goalId: goalId ?? this.goalId,
    amountInCents: amountInCents ?? this.amountInCents,
    type: type ?? this.type,
    sourceTransactionId: sourceTransactionId.present
        ? sourceTransactionId.value
        : this.sourceTransactionId,
    createdAt: createdAt ?? this.createdAt,
    note: note.present ? note.value : this.note,
    contributorUserId: contributorUserId.present
        ? contributorUserId.value
        : this.contributorUserId,
  );
  GoalContributionEntity copyWithCompanion(
    GoalContributionEntriesCompanion data,
  ) {
    return GoalContributionEntity(
      id: data.id.present ? data.id.value : this.id,
      goalId: data.goalId.present ? data.goalId.value : this.goalId,
      amountInCents: data.amountInCents.present
          ? data.amountInCents.value
          : this.amountInCents,
      type: data.type.present ? data.type.value : this.type,
      sourceTransactionId: data.sourceTransactionId.present
          ? data.sourceTransactionId.value
          : this.sourceTransactionId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      note: data.note.present ? data.note.value : this.note,
      contributorUserId: data.contributorUserId.present
          ? data.contributorUserId.value
          : this.contributorUserId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GoalContributionEntity(')
          ..write('id: $id, ')
          ..write('goalId: $goalId, ')
          ..write('amountInCents: $amountInCents, ')
          ..write('type: $type, ')
          ..write('sourceTransactionId: $sourceTransactionId, ')
          ..write('createdAt: $createdAt, ')
          ..write('note: $note, ')
          ..write('contributorUserId: $contributorUserId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    goalId,
    amountInCents,
    type,
    sourceTransactionId,
    createdAt,
    note,
    contributorUserId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GoalContributionEntity &&
          other.id == this.id &&
          other.goalId == this.goalId &&
          other.amountInCents == this.amountInCents &&
          other.type == this.type &&
          other.sourceTransactionId == this.sourceTransactionId &&
          other.createdAt == this.createdAt &&
          other.note == this.note &&
          other.contributorUserId == this.contributorUserId);
}

class GoalContributionEntriesCompanion
    extends UpdateCompanion<GoalContributionEntity> {
  final Value<String> id;
  final Value<String> goalId;
  final Value<int> amountInCents;
  final Value<String> type;
  final Value<String?> sourceTransactionId;
  final Value<DateTime> createdAt;
  final Value<String?> note;
  final Value<String?> contributorUserId;
  final Value<int> rowid;
  const GoalContributionEntriesCompanion({
    this.id = const Value.absent(),
    this.goalId = const Value.absent(),
    this.amountInCents = const Value.absent(),
    this.type = const Value.absent(),
    this.sourceTransactionId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.note = const Value.absent(),
    this.contributorUserId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GoalContributionEntriesCompanion.insert({
    required String id,
    required String goalId,
    required int amountInCents,
    required String type,
    this.sourceTransactionId = const Value.absent(),
    required DateTime createdAt,
    this.note = const Value.absent(),
    this.contributorUserId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       goalId = Value(goalId),
       amountInCents = Value(amountInCents),
       type = Value(type),
       createdAt = Value(createdAt);
  static Insertable<GoalContributionEntity> custom({
    Expression<String>? id,
    Expression<String>? goalId,
    Expression<int>? amountInCents,
    Expression<String>? type,
    Expression<String>? sourceTransactionId,
    Expression<DateTime>? createdAt,
    Expression<String>? note,
    Expression<String>? contributorUserId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (goalId != null) 'goal_id': goalId,
      if (amountInCents != null) 'amount_in_cents': amountInCents,
      if (type != null) 'type': type,
      if (sourceTransactionId != null)
        'source_transaction_id': sourceTransactionId,
      if (createdAt != null) 'created_at': createdAt,
      if (note != null) 'note': note,
      if (contributorUserId != null) 'contributor_user_id': contributorUserId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GoalContributionEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? goalId,
    Value<int>? amountInCents,
    Value<String>? type,
    Value<String?>? sourceTransactionId,
    Value<DateTime>? createdAt,
    Value<String?>? note,
    Value<String?>? contributorUserId,
    Value<int>? rowid,
  }) {
    return GoalContributionEntriesCompanion(
      id: id ?? this.id,
      goalId: goalId ?? this.goalId,
      amountInCents: amountInCents ?? this.amountInCents,
      type: type ?? this.type,
      sourceTransactionId: sourceTransactionId ?? this.sourceTransactionId,
      createdAt: createdAt ?? this.createdAt,
      note: note ?? this.note,
      contributorUserId: contributorUserId ?? this.contributorUserId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (goalId.present) {
      map['goal_id'] = Variable<String>(goalId.value);
    }
    if (amountInCents.present) {
      map['amount_in_cents'] = Variable<int>(amountInCents.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (sourceTransactionId.present) {
      map['source_transaction_id'] = Variable<String>(
        sourceTransactionId.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (contributorUserId.present) {
      map['contributor_user_id'] = Variable<String>(contributorUserId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GoalContributionEntriesCompanion(')
          ..write('id: $id, ')
          ..write('goalId: $goalId, ')
          ..write('amountInCents: $amountInCents, ')
          ..write('type: $type, ')
          ..write('sourceTransactionId: $sourceTransactionId, ')
          ..write('createdAt: $createdAt, ')
          ..write('note: $note, ')
          ..write('contributorUserId: $contributorUserId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingEntriesTable extends AppSettingEntries
    with TableInfo<$AppSettingEntriesTable, AppSettingEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSettingEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSettingEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingEntity(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AppSettingEntriesTable createAlias(String alias) {
    return $AppSettingEntriesTable(attachedDatabase, alias);
  }
}

class AppSettingEntity extends DataClass
    implements Insertable<AppSettingEntity> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const AppSettingEntity({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AppSettingEntriesCompanion toCompanion(bool nullToAbsent) {
    return AppSettingEntriesCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppSettingEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingEntity(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AppSettingEntity copyWith({
    String? key,
    String? value,
    DateTime? updatedAt,
  }) => AppSettingEntity(
    key: key ?? this.key,
    value: value ?? this.value,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  AppSettingEntity copyWithCompanion(AppSettingEntriesCompanion data) {
    return AppSettingEntity(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingEntity(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingEntity &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class AppSettingEntriesCompanion extends UpdateCompanion<AppSettingEntity> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AppSettingEntriesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingEntriesCompanion.insert({
    required String key,
    required String value,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<AppSettingEntity> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingEntriesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AppSettingEntriesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingEntriesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BudgetEntriesTable extends BudgetEntries
    with TableInfo<$BudgetEntriesTable, BudgetEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BudgetEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('book-personal'),
  );
  static const VerificationMeta _monthKeyMeta = const VerificationMeta(
    'monthKey',
  );
  @override
  late final GeneratedColumn<String> monthKey = GeneratedColumn<String>(
    'month_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _amountInCentsMeta = const VerificationMeta(
    'amountInCents',
  );
  @override
  late final GeneratedColumn<int> amountInCents = GeneratedColumn<int>(
    'amount_in_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    monthKey,
    categoryId,
    amountInCents,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'budgets';
  @override
  VerificationContext validateIntegrity(
    Insertable<BudgetEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    }
    if (data.containsKey('month_key')) {
      context.handle(
        _monthKeyMeta,
        monthKey.isAcceptableOrUnknown(data['month_key']!, _monthKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_monthKeyMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('amount_in_cents')) {
      context.handle(
        _amountInCentsMeta,
        amountInCents.isAcceptableOrUnknown(
          data['amount_in_cents']!,
          _amountInCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountInCentsMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {bookId, monthKey, categoryId},
  ];
  @override
  BudgetEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BudgetEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      monthKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}month_key'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      amountInCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_in_cents'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $BudgetEntriesTable createAlias(String alias) {
    return $BudgetEntriesTable(attachedDatabase, alias);
  }
}

class BudgetEntity extends DataClass implements Insertable<BudgetEntity> {
  final String id;
  final String bookId;
  final String monthKey;
  final String? categoryId;
  final int amountInCents;
  final DateTime createdAt;
  final DateTime updatedAt;
  const BudgetEntity({
    required this.id,
    required this.bookId,
    required this.monthKey,
    this.categoryId,
    required this.amountInCents,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['month_key'] = Variable<String>(monthKey);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    map['amount_in_cents'] = Variable<int>(amountInCents);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BudgetEntriesCompanion toCompanion(bool nullToAbsent) {
    return BudgetEntriesCompanion(
      id: Value(id),
      bookId: Value(bookId),
      monthKey: Value(monthKey),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      amountInCents: Value(amountInCents),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory BudgetEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BudgetEntity(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      monthKey: serializer.fromJson<String>(json['monthKey']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      amountInCents: serializer.fromJson<int>(json['amountInCents']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'monthKey': serializer.toJson<String>(monthKey),
      'categoryId': serializer.toJson<String?>(categoryId),
      'amountInCents': serializer.toJson<int>(amountInCents),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  BudgetEntity copyWith({
    String? id,
    String? bookId,
    String? monthKey,
    Value<String?> categoryId = const Value.absent(),
    int? amountInCents,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => BudgetEntity(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    monthKey: monthKey ?? this.monthKey,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    amountInCents: amountInCents ?? this.amountInCents,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  BudgetEntity copyWithCompanion(BudgetEntriesCompanion data) {
    return BudgetEntity(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      monthKey: data.monthKey.present ? data.monthKey.value : this.monthKey,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      amountInCents: data.amountInCents.present
          ? data.amountInCents.value
          : this.amountInCents,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BudgetEntity(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('monthKey: $monthKey, ')
          ..write('categoryId: $categoryId, ')
          ..write('amountInCents: $amountInCents, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    monthKey,
    categoryId,
    amountInCents,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BudgetEntity &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.monthKey == this.monthKey &&
          other.categoryId == this.categoryId &&
          other.amountInCents == this.amountInCents &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BudgetEntriesCompanion extends UpdateCompanion<BudgetEntity> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> monthKey;
  final Value<String?> categoryId;
  final Value<int> amountInCents;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const BudgetEntriesCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.monthKey = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.amountInCents = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BudgetEntriesCompanion.insert({
    required String id,
    this.bookId = const Value.absent(),
    required String monthKey,
    this.categoryId = const Value.absent(),
    required int amountInCents,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       monthKey = Value(monthKey),
       amountInCents = Value(amountInCents),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<BudgetEntity> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? monthKey,
    Expression<String>? categoryId,
    Expression<int>? amountInCents,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (monthKey != null) 'month_key': monthKey,
      if (categoryId != null) 'category_id': categoryId,
      if (amountInCents != null) 'amount_in_cents': amountInCents,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BudgetEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String>? monthKey,
    Value<String?>? categoryId,
    Value<int>? amountInCents,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return BudgetEntriesCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      monthKey: monthKey ?? this.monthKey,
      categoryId: categoryId ?? this.categoryId,
      amountInCents: amountInCents ?? this.amountInCents,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (monthKey.present) {
      map['month_key'] = Variable<String>(monthKey.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (amountInCents.present) {
      map['amount_in_cents'] = Variable<int>(amountInCents.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BudgetEntriesCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('monthKey: $monthKey, ')
          ..write('categoryId: $categoryId, ')
          ..write('amountInCents: $amountInCents, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecurringBillEntriesTable extends RecurringBillEntries
    with TableInfo<$RecurringBillEntriesTable, RecurringBillEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecurringBillEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountInCentsMeta = const VerificationMeta(
    'amountInCents',
  );
  @override
  late final GeneratedColumn<int> amountInCents = GeneratedColumn<int>(
    'amount_in_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cycleMeta = const VerificationMeta('cycle');
  @override
  late final GeneratedColumn<String> cycle = GeneratedColumn<String>(
    'cycle',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextDateMeta = const VerificationMeta(
    'nextDate',
  );
  @override
  late final GeneratedColumn<DateTime> nextDate = GeneratedColumn<DateTime>(
    'next_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customIntervalDaysMeta =
      const VerificationMeta('customIntervalDays');
  @override
  late final GeneratedColumn<int> customIntervalDays = GeneratedColumn<int>(
    'custom_interval_days',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _autoRecordMeta = const VerificationMeta(
    'autoRecord',
  );
  @override
  late final GeneratedColumn<bool> autoRecord = GeneratedColumn<bool>(
    'auto_record',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_record" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _reminderMeta = const VerificationMeta(
    'reminder',
  );
  @override
  late final GeneratedColumn<bool> reminder = GeneratedColumn<bool>(
    'reminder',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("reminder" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    name,
    type,
    amountInCents,
    cycle,
    startDate,
    endDate,
    nextDate,
    accountId,
    categoryId,
    customIntervalDays,
    autoRecord,
    reminder,
    status,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recurring_bills';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecurringBillEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('amount_in_cents')) {
      context.handle(
        _amountInCentsMeta,
        amountInCents.isAcceptableOrUnknown(
          data['amount_in_cents']!,
          _amountInCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountInCentsMeta);
    }
    if (data.containsKey('cycle')) {
      context.handle(
        _cycleMeta,
        cycle.isAcceptableOrUnknown(data['cycle']!, _cycleMeta),
      );
    } else if (isInserting) {
      context.missing(_cycleMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    }
    if (data.containsKey('next_date')) {
      context.handle(
        _nextDateMeta,
        nextDate.isAcceptableOrUnknown(data['next_date']!, _nextDateMeta),
      );
    } else if (isInserting) {
      context.missing(_nextDateMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('custom_interval_days')) {
      context.handle(
        _customIntervalDaysMeta,
        customIntervalDays.isAcceptableOrUnknown(
          data['custom_interval_days']!,
          _customIntervalDaysMeta,
        ),
      );
    }
    if (data.containsKey('auto_record')) {
      context.handle(
        _autoRecordMeta,
        autoRecord.isAcceptableOrUnknown(data['auto_record']!, _autoRecordMeta),
      );
    }
    if (data.containsKey('reminder')) {
      context.handle(
        _reminderMeta,
        reminder.isAcceptableOrUnknown(data['reminder']!, _reminderMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecurringBillEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecurringBillEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      amountInCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_in_cents'],
      )!,
      cycle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cycle'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      ),
      nextDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_date'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      customIntervalDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}custom_interval_days'],
      ),
      autoRecord: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_record'],
      )!,
      reminder: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}reminder'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $RecurringBillEntriesTable createAlias(String alias) {
    return $RecurringBillEntriesTable(attachedDatabase, alias);
  }
}

class RecurringBillEntity extends DataClass
    implements Insertable<RecurringBillEntity> {
  final String id;
  final String bookId;
  final String name;
  final String type;
  final int amountInCents;
  final String cycle;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime nextDate;
  final String? accountId;
  final String? categoryId;
  final int? customIntervalDays;
  final bool autoRecord;
  final bool reminder;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  const RecurringBillEntity({
    required this.id,
    required this.bookId,
    required this.name,
    required this.type,
    required this.amountInCents,
    required this.cycle,
    required this.startDate,
    this.endDate,
    required this.nextDate,
    this.accountId,
    this.categoryId,
    this.customIntervalDays,
    required this.autoRecord,
    required this.reminder,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['amount_in_cents'] = Variable<int>(amountInCents);
    map['cycle'] = Variable<String>(cycle);
    map['start_date'] = Variable<DateTime>(startDate);
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<DateTime>(endDate);
    }
    map['next_date'] = Variable<DateTime>(nextDate);
    if (!nullToAbsent || accountId != null) {
      map['account_id'] = Variable<String>(accountId);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || customIntervalDays != null) {
      map['custom_interval_days'] = Variable<int>(customIntervalDays);
    }
    map['auto_record'] = Variable<bool>(autoRecord);
    map['reminder'] = Variable<bool>(reminder);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  RecurringBillEntriesCompanion toCompanion(bool nullToAbsent) {
    return RecurringBillEntriesCompanion(
      id: Value(id),
      bookId: Value(bookId),
      name: Value(name),
      type: Value(type),
      amountInCents: Value(amountInCents),
      cycle: Value(cycle),
      startDate: Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      nextDate: Value(nextDate),
      accountId: accountId == null && nullToAbsent
          ? const Value.absent()
          : Value(accountId),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      customIntervalDays: customIntervalDays == null && nullToAbsent
          ? const Value.absent()
          : Value(customIntervalDays),
      autoRecord: Value(autoRecord),
      reminder: Value(reminder),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory RecurringBillEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecurringBillEntity(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      amountInCents: serializer.fromJson<int>(json['amountInCents']),
      cycle: serializer.fromJson<String>(json['cycle']),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      endDate: serializer.fromJson<DateTime?>(json['endDate']),
      nextDate: serializer.fromJson<DateTime>(json['nextDate']),
      accountId: serializer.fromJson<String?>(json['accountId']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      customIntervalDays: serializer.fromJson<int?>(json['customIntervalDays']),
      autoRecord: serializer.fromJson<bool>(json['autoRecord']),
      reminder: serializer.fromJson<bool>(json['reminder']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'amountInCents': serializer.toJson<int>(amountInCents),
      'cycle': serializer.toJson<String>(cycle),
      'startDate': serializer.toJson<DateTime>(startDate),
      'endDate': serializer.toJson<DateTime?>(endDate),
      'nextDate': serializer.toJson<DateTime>(nextDate),
      'accountId': serializer.toJson<String?>(accountId),
      'categoryId': serializer.toJson<String?>(categoryId),
      'customIntervalDays': serializer.toJson<int?>(customIntervalDays),
      'autoRecord': serializer.toJson<bool>(autoRecord),
      'reminder': serializer.toJson<bool>(reminder),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  RecurringBillEntity copyWith({
    String? id,
    String? bookId,
    String? name,
    String? type,
    int? amountInCents,
    String? cycle,
    DateTime? startDate,
    Value<DateTime?> endDate = const Value.absent(),
    DateTime? nextDate,
    Value<String?> accountId = const Value.absent(),
    Value<String?> categoryId = const Value.absent(),
    Value<int?> customIntervalDays = const Value.absent(),
    bool? autoRecord,
    bool? reminder,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => RecurringBillEntity(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    name: name ?? this.name,
    type: type ?? this.type,
    amountInCents: amountInCents ?? this.amountInCents,
    cycle: cycle ?? this.cycle,
    startDate: startDate ?? this.startDate,
    endDate: endDate.present ? endDate.value : this.endDate,
    nextDate: nextDate ?? this.nextDate,
    accountId: accountId.present ? accountId.value : this.accountId,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    customIntervalDays: customIntervalDays.present
        ? customIntervalDays.value
        : this.customIntervalDays,
    autoRecord: autoRecord ?? this.autoRecord,
    reminder: reminder ?? this.reminder,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  RecurringBillEntity copyWithCompanion(RecurringBillEntriesCompanion data) {
    return RecurringBillEntity(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      amountInCents: data.amountInCents.present
          ? data.amountInCents.value
          : this.amountInCents,
      cycle: data.cycle.present ? data.cycle.value : this.cycle,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      nextDate: data.nextDate.present ? data.nextDate.value : this.nextDate,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      customIntervalDays: data.customIntervalDays.present
          ? data.customIntervalDays.value
          : this.customIntervalDays,
      autoRecord: data.autoRecord.present
          ? data.autoRecord.value
          : this.autoRecord,
      reminder: data.reminder.present ? data.reminder.value : this.reminder,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecurringBillEntity(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('amountInCents: $amountInCents, ')
          ..write('cycle: $cycle, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('nextDate: $nextDate, ')
          ..write('accountId: $accountId, ')
          ..write('categoryId: $categoryId, ')
          ..write('customIntervalDays: $customIntervalDays, ')
          ..write('autoRecord: $autoRecord, ')
          ..write('reminder: $reminder, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    name,
    type,
    amountInCents,
    cycle,
    startDate,
    endDate,
    nextDate,
    accountId,
    categoryId,
    customIntervalDays,
    autoRecord,
    reminder,
    status,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecurringBillEntity &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.name == this.name &&
          other.type == this.type &&
          other.amountInCents == this.amountInCents &&
          other.cycle == this.cycle &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.nextDate == this.nextDate &&
          other.accountId == this.accountId &&
          other.categoryId == this.categoryId &&
          other.customIntervalDays == this.customIntervalDays &&
          other.autoRecord == this.autoRecord &&
          other.reminder == this.reminder &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class RecurringBillEntriesCompanion
    extends UpdateCompanion<RecurringBillEntity> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> name;
  final Value<String> type;
  final Value<int> amountInCents;
  final Value<String> cycle;
  final Value<DateTime> startDate;
  final Value<DateTime?> endDate;
  final Value<DateTime> nextDate;
  final Value<String?> accountId;
  final Value<String?> categoryId;
  final Value<int?> customIntervalDays;
  final Value<bool> autoRecord;
  final Value<bool> reminder;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const RecurringBillEntriesCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.amountInCents = const Value.absent(),
    this.cycle = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.nextDate = const Value.absent(),
    this.accountId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.customIntervalDays = const Value.absent(),
    this.autoRecord = const Value.absent(),
    this.reminder = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecurringBillEntriesCompanion.insert({
    required String id,
    required String bookId,
    required String name,
    required String type,
    required int amountInCents,
    required String cycle,
    required DateTime startDate,
    this.endDate = const Value.absent(),
    required DateTime nextDate,
    this.accountId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.customIntervalDays = const Value.absent(),
    this.autoRecord = const Value.absent(),
    this.reminder = const Value.absent(),
    this.status = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       name = Value(name),
       type = Value(type),
       amountInCents = Value(amountInCents),
       cycle = Value(cycle),
       startDate = Value(startDate),
       nextDate = Value(nextDate),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<RecurringBillEntity> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? name,
    Expression<String>? type,
    Expression<int>? amountInCents,
    Expression<String>? cycle,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<DateTime>? nextDate,
    Expression<String>? accountId,
    Expression<String>? categoryId,
    Expression<int>? customIntervalDays,
    Expression<bool>? autoRecord,
    Expression<bool>? reminder,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (amountInCents != null) 'amount_in_cents': amountInCents,
      if (cycle != null) 'cycle': cycle,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (nextDate != null) 'next_date': nextDate,
      if (accountId != null) 'account_id': accountId,
      if (categoryId != null) 'category_id': categoryId,
      if (customIntervalDays != null)
        'custom_interval_days': customIntervalDays,
      if (autoRecord != null) 'auto_record': autoRecord,
      if (reminder != null) 'reminder': reminder,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecurringBillEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String>? name,
    Value<String>? type,
    Value<int>? amountInCents,
    Value<String>? cycle,
    Value<DateTime>? startDate,
    Value<DateTime?>? endDate,
    Value<DateTime>? nextDate,
    Value<String?>? accountId,
    Value<String?>? categoryId,
    Value<int?>? customIntervalDays,
    Value<bool>? autoRecord,
    Value<bool>? reminder,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return RecurringBillEntriesCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      name: name ?? this.name,
      type: type ?? this.type,
      amountInCents: amountInCents ?? this.amountInCents,
      cycle: cycle ?? this.cycle,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      nextDate: nextDate ?? this.nextDate,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      customIntervalDays: customIntervalDays ?? this.customIntervalDays,
      autoRecord: autoRecord ?? this.autoRecord,
      reminder: reminder ?? this.reminder,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (amountInCents.present) {
      map['amount_in_cents'] = Variable<int>(amountInCents.value);
    }
    if (cycle.present) {
      map['cycle'] = Variable<String>(cycle.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (nextDate.present) {
      map['next_date'] = Variable<DateTime>(nextDate.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (customIntervalDays.present) {
      map['custom_interval_days'] = Variable<int>(customIntervalDays.value);
    }
    if (autoRecord.present) {
      map['auto_record'] = Variable<bool>(autoRecord.value);
    }
    if (reminder.present) {
      map['reminder'] = Variable<bool>(reminder.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecurringBillEntriesCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('amountInCents: $amountInCents, ')
          ..write('cycle: $cycle, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('nextDate: $nextDate, ')
          ..write('accountId: $accountId, ')
          ..write('categoryId: $categoryId, ')
          ..write('customIntervalDays: $customIntervalDays, ')
          ..write('autoRecord: $autoRecord, ')
          ..write('reminder: $reminder, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InstallmentPlanEntriesTable extends InstallmentPlanEntries
    with TableInfo<$InstallmentPlanEntriesTable, InstallmentPlanEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InstallmentPlanEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalTransactionIdMeta =
      const VerificationMeta('originalTransactionId');
  @override
  late final GeneratedColumn<String> originalTransactionId =
      GeneratedColumn<String>(
        'original_transaction_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _totalAmountInCentsMeta =
      const VerificationMeta('totalAmountInCents');
  @override
  late final GeneratedColumn<int> totalAmountInCents = GeneratedColumn<int>(
    'total_amount_in_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalPeriodsMeta = const VerificationMeta(
    'totalPeriods',
  );
  @override
  late final GeneratedColumn<int> totalPeriods = GeneratedColumn<int>(
    'total_periods',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentPeriodMeta = const VerificationMeta(
    'currentPeriod',
  );
  @override
  late final GeneratedColumn<int> currentPeriod = GeneratedColumn<int>(
    'current_period',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _principalPerPeriodInCentsMeta =
      const VerificationMeta('principalPerPeriodInCents');
  @override
  late final GeneratedColumn<int> principalPerPeriodInCents =
      GeneratedColumn<int>(
        'principal_per_period_in_cents',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _feePerPeriodInCentsMeta =
      const VerificationMeta('feePerPeriodInCents');
  @override
  late final GeneratedColumn<int> feePerPeriodInCents = GeneratedColumn<int>(
    'fee_per_period_in_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueDayMeta = const VerificationMeta('dueDay');
  @override
  late final GeneratedColumn<int> dueDay = GeneratedColumn<int>(
    'due_day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _creditAccountIdMeta = const VerificationMeta(
    'creditAccountId',
  );
  @override
  late final GeneratedColumn<String> creditAccountId = GeneratedColumn<String>(
    'credit_account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repaymentAccountIdMeta =
      const VerificationMeta('repaymentAccountId');
  @override
  late final GeneratedColumn<String> repaymentAccountId =
      GeneratedColumn<String>(
        'repayment_account_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _remainingPrincipalInCentsMeta =
      const VerificationMeta('remainingPrincipalInCents');
  @override
  late final GeneratedColumn<int> remainingPrincipalInCents =
      GeneratedColumn<int>(
        'remaining_principal_in_cents',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    name,
    originalTransactionId,
    totalAmountInCents,
    totalPeriods,
    currentPeriod,
    principalPerPeriodInCents,
    feePerPeriodInCents,
    startDate,
    dueDay,
    creditAccountId,
    repaymentAccountId,
    remainingPrincipalInCents,
    status,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'installment_plans';
  @override
  VerificationContext validateIntegrity(
    Insertable<InstallmentPlanEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('original_transaction_id')) {
      context.handle(
        _originalTransactionIdMeta,
        originalTransactionId.isAcceptableOrUnknown(
          data['original_transaction_id']!,
          _originalTransactionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originalTransactionIdMeta);
    }
    if (data.containsKey('total_amount_in_cents')) {
      context.handle(
        _totalAmountInCentsMeta,
        totalAmountInCents.isAcceptableOrUnknown(
          data['total_amount_in_cents']!,
          _totalAmountInCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalAmountInCentsMeta);
    }
    if (data.containsKey('total_periods')) {
      context.handle(
        _totalPeriodsMeta,
        totalPeriods.isAcceptableOrUnknown(
          data['total_periods']!,
          _totalPeriodsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalPeriodsMeta);
    }
    if (data.containsKey('current_period')) {
      context.handle(
        _currentPeriodMeta,
        currentPeriod.isAcceptableOrUnknown(
          data['current_period']!,
          _currentPeriodMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currentPeriodMeta);
    }
    if (data.containsKey('principal_per_period_in_cents')) {
      context.handle(
        _principalPerPeriodInCentsMeta,
        principalPerPeriodInCents.isAcceptableOrUnknown(
          data['principal_per_period_in_cents']!,
          _principalPerPeriodInCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_principalPerPeriodInCentsMeta);
    }
    if (data.containsKey('fee_per_period_in_cents')) {
      context.handle(
        _feePerPeriodInCentsMeta,
        feePerPeriodInCents.isAcceptableOrUnknown(
          data['fee_per_period_in_cents']!,
          _feePerPeriodInCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_feePerPeriodInCentsMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('due_day')) {
      context.handle(
        _dueDayMeta,
        dueDay.isAcceptableOrUnknown(data['due_day']!, _dueDayMeta),
      );
    } else if (isInserting) {
      context.missing(_dueDayMeta);
    }
    if (data.containsKey('credit_account_id')) {
      context.handle(
        _creditAccountIdMeta,
        creditAccountId.isAcceptableOrUnknown(
          data['credit_account_id']!,
          _creditAccountIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_creditAccountIdMeta);
    }
    if (data.containsKey('repayment_account_id')) {
      context.handle(
        _repaymentAccountIdMeta,
        repaymentAccountId.isAcceptableOrUnknown(
          data['repayment_account_id']!,
          _repaymentAccountIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_repaymentAccountIdMeta);
    }
    if (data.containsKey('remaining_principal_in_cents')) {
      context.handle(
        _remainingPrincipalInCentsMeta,
        remainingPrincipalInCents.isAcceptableOrUnknown(
          data['remaining_principal_in_cents']!,
          _remainingPrincipalInCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_remainingPrincipalInCentsMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InstallmentPlanEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InstallmentPlanEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      originalTransactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_transaction_id'],
      )!,
      totalAmountInCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_amount_in_cents'],
      )!,
      totalPeriods: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_periods'],
      )!,
      currentPeriod: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_period'],
      )!,
      principalPerPeriodInCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}principal_per_period_in_cents'],
      )!,
      feePerPeriodInCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fee_per_period_in_cents'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      )!,
      dueDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_day'],
      )!,
      creditAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}credit_account_id'],
      )!,
      repaymentAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repayment_account_id'],
      )!,
      remainingPrincipalInCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remaining_principal_in_cents'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $InstallmentPlanEntriesTable createAlias(String alias) {
    return $InstallmentPlanEntriesTable(attachedDatabase, alias);
  }
}

class InstallmentPlanEntity extends DataClass
    implements Insertable<InstallmentPlanEntity> {
  final String id;
  final String bookId;
  final String name;
  final String originalTransactionId;
  final int totalAmountInCents;
  final int totalPeriods;
  final int currentPeriod;
  final int principalPerPeriodInCents;
  final int feePerPeriodInCents;
  final DateTime startDate;
  final int dueDay;
  final String creditAccountId;
  final String repaymentAccountId;
  final int remainingPrincipalInCents;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  const InstallmentPlanEntity({
    required this.id,
    required this.bookId,
    required this.name,
    required this.originalTransactionId,
    required this.totalAmountInCents,
    required this.totalPeriods,
    required this.currentPeriod,
    required this.principalPerPeriodInCents,
    required this.feePerPeriodInCents,
    required this.startDate,
    required this.dueDay,
    required this.creditAccountId,
    required this.repaymentAccountId,
    required this.remainingPrincipalInCents,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['name'] = Variable<String>(name);
    map['original_transaction_id'] = Variable<String>(originalTransactionId);
    map['total_amount_in_cents'] = Variable<int>(totalAmountInCents);
    map['total_periods'] = Variable<int>(totalPeriods);
    map['current_period'] = Variable<int>(currentPeriod);
    map['principal_per_period_in_cents'] = Variable<int>(
      principalPerPeriodInCents,
    );
    map['fee_per_period_in_cents'] = Variable<int>(feePerPeriodInCents);
    map['start_date'] = Variable<DateTime>(startDate);
    map['due_day'] = Variable<int>(dueDay);
    map['credit_account_id'] = Variable<String>(creditAccountId);
    map['repayment_account_id'] = Variable<String>(repaymentAccountId);
    map['remaining_principal_in_cents'] = Variable<int>(
      remainingPrincipalInCents,
    );
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  InstallmentPlanEntriesCompanion toCompanion(bool nullToAbsent) {
    return InstallmentPlanEntriesCompanion(
      id: Value(id),
      bookId: Value(bookId),
      name: Value(name),
      originalTransactionId: Value(originalTransactionId),
      totalAmountInCents: Value(totalAmountInCents),
      totalPeriods: Value(totalPeriods),
      currentPeriod: Value(currentPeriod),
      principalPerPeriodInCents: Value(principalPerPeriodInCents),
      feePerPeriodInCents: Value(feePerPeriodInCents),
      startDate: Value(startDate),
      dueDay: Value(dueDay),
      creditAccountId: Value(creditAccountId),
      repaymentAccountId: Value(repaymentAccountId),
      remainingPrincipalInCents: Value(remainingPrincipalInCents),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory InstallmentPlanEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InstallmentPlanEntity(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      name: serializer.fromJson<String>(json['name']),
      originalTransactionId: serializer.fromJson<String>(
        json['originalTransactionId'],
      ),
      totalAmountInCents: serializer.fromJson<int>(json['totalAmountInCents']),
      totalPeriods: serializer.fromJson<int>(json['totalPeriods']),
      currentPeriod: serializer.fromJson<int>(json['currentPeriod']),
      principalPerPeriodInCents: serializer.fromJson<int>(
        json['principalPerPeriodInCents'],
      ),
      feePerPeriodInCents: serializer.fromJson<int>(
        json['feePerPeriodInCents'],
      ),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      dueDay: serializer.fromJson<int>(json['dueDay']),
      creditAccountId: serializer.fromJson<String>(json['creditAccountId']),
      repaymentAccountId: serializer.fromJson<String>(
        json['repaymentAccountId'],
      ),
      remainingPrincipalInCents: serializer.fromJson<int>(
        json['remainingPrincipalInCents'],
      ),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'name': serializer.toJson<String>(name),
      'originalTransactionId': serializer.toJson<String>(originalTransactionId),
      'totalAmountInCents': serializer.toJson<int>(totalAmountInCents),
      'totalPeriods': serializer.toJson<int>(totalPeriods),
      'currentPeriod': serializer.toJson<int>(currentPeriod),
      'principalPerPeriodInCents': serializer.toJson<int>(
        principalPerPeriodInCents,
      ),
      'feePerPeriodInCents': serializer.toJson<int>(feePerPeriodInCents),
      'startDate': serializer.toJson<DateTime>(startDate),
      'dueDay': serializer.toJson<int>(dueDay),
      'creditAccountId': serializer.toJson<String>(creditAccountId),
      'repaymentAccountId': serializer.toJson<String>(repaymentAccountId),
      'remainingPrincipalInCents': serializer.toJson<int>(
        remainingPrincipalInCents,
      ),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  InstallmentPlanEntity copyWith({
    String? id,
    String? bookId,
    String? name,
    String? originalTransactionId,
    int? totalAmountInCents,
    int? totalPeriods,
    int? currentPeriod,
    int? principalPerPeriodInCents,
    int? feePerPeriodInCents,
    DateTime? startDate,
    int? dueDay,
    String? creditAccountId,
    String? repaymentAccountId,
    int? remainingPrincipalInCents,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => InstallmentPlanEntity(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    name: name ?? this.name,
    originalTransactionId: originalTransactionId ?? this.originalTransactionId,
    totalAmountInCents: totalAmountInCents ?? this.totalAmountInCents,
    totalPeriods: totalPeriods ?? this.totalPeriods,
    currentPeriod: currentPeriod ?? this.currentPeriod,
    principalPerPeriodInCents:
        principalPerPeriodInCents ?? this.principalPerPeriodInCents,
    feePerPeriodInCents: feePerPeriodInCents ?? this.feePerPeriodInCents,
    startDate: startDate ?? this.startDate,
    dueDay: dueDay ?? this.dueDay,
    creditAccountId: creditAccountId ?? this.creditAccountId,
    repaymentAccountId: repaymentAccountId ?? this.repaymentAccountId,
    remainingPrincipalInCents:
        remainingPrincipalInCents ?? this.remainingPrincipalInCents,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  InstallmentPlanEntity copyWithCompanion(
    InstallmentPlanEntriesCompanion data,
  ) {
    return InstallmentPlanEntity(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      name: data.name.present ? data.name.value : this.name,
      originalTransactionId: data.originalTransactionId.present
          ? data.originalTransactionId.value
          : this.originalTransactionId,
      totalAmountInCents: data.totalAmountInCents.present
          ? data.totalAmountInCents.value
          : this.totalAmountInCents,
      totalPeriods: data.totalPeriods.present
          ? data.totalPeriods.value
          : this.totalPeriods,
      currentPeriod: data.currentPeriod.present
          ? data.currentPeriod.value
          : this.currentPeriod,
      principalPerPeriodInCents: data.principalPerPeriodInCents.present
          ? data.principalPerPeriodInCents.value
          : this.principalPerPeriodInCents,
      feePerPeriodInCents: data.feePerPeriodInCents.present
          ? data.feePerPeriodInCents.value
          : this.feePerPeriodInCents,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      dueDay: data.dueDay.present ? data.dueDay.value : this.dueDay,
      creditAccountId: data.creditAccountId.present
          ? data.creditAccountId.value
          : this.creditAccountId,
      repaymentAccountId: data.repaymentAccountId.present
          ? data.repaymentAccountId.value
          : this.repaymentAccountId,
      remainingPrincipalInCents: data.remainingPrincipalInCents.present
          ? data.remainingPrincipalInCents.value
          : this.remainingPrincipalInCents,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InstallmentPlanEntity(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('name: $name, ')
          ..write('originalTransactionId: $originalTransactionId, ')
          ..write('totalAmountInCents: $totalAmountInCents, ')
          ..write('totalPeriods: $totalPeriods, ')
          ..write('currentPeriod: $currentPeriod, ')
          ..write('principalPerPeriodInCents: $principalPerPeriodInCents, ')
          ..write('feePerPeriodInCents: $feePerPeriodInCents, ')
          ..write('startDate: $startDate, ')
          ..write('dueDay: $dueDay, ')
          ..write('creditAccountId: $creditAccountId, ')
          ..write('repaymentAccountId: $repaymentAccountId, ')
          ..write('remainingPrincipalInCents: $remainingPrincipalInCents, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    name,
    originalTransactionId,
    totalAmountInCents,
    totalPeriods,
    currentPeriod,
    principalPerPeriodInCents,
    feePerPeriodInCents,
    startDate,
    dueDay,
    creditAccountId,
    repaymentAccountId,
    remainingPrincipalInCents,
    status,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InstallmentPlanEntity &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.name == this.name &&
          other.originalTransactionId == this.originalTransactionId &&
          other.totalAmountInCents == this.totalAmountInCents &&
          other.totalPeriods == this.totalPeriods &&
          other.currentPeriod == this.currentPeriod &&
          other.principalPerPeriodInCents == this.principalPerPeriodInCents &&
          other.feePerPeriodInCents == this.feePerPeriodInCents &&
          other.startDate == this.startDate &&
          other.dueDay == this.dueDay &&
          other.creditAccountId == this.creditAccountId &&
          other.repaymentAccountId == this.repaymentAccountId &&
          other.remainingPrincipalInCents == this.remainingPrincipalInCents &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class InstallmentPlanEntriesCompanion
    extends UpdateCompanion<InstallmentPlanEntity> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> name;
  final Value<String> originalTransactionId;
  final Value<int> totalAmountInCents;
  final Value<int> totalPeriods;
  final Value<int> currentPeriod;
  final Value<int> principalPerPeriodInCents;
  final Value<int> feePerPeriodInCents;
  final Value<DateTime> startDate;
  final Value<int> dueDay;
  final Value<String> creditAccountId;
  final Value<String> repaymentAccountId;
  final Value<int> remainingPrincipalInCents;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const InstallmentPlanEntriesCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.name = const Value.absent(),
    this.originalTransactionId = const Value.absent(),
    this.totalAmountInCents = const Value.absent(),
    this.totalPeriods = const Value.absent(),
    this.currentPeriod = const Value.absent(),
    this.principalPerPeriodInCents = const Value.absent(),
    this.feePerPeriodInCents = const Value.absent(),
    this.startDate = const Value.absent(),
    this.dueDay = const Value.absent(),
    this.creditAccountId = const Value.absent(),
    this.repaymentAccountId = const Value.absent(),
    this.remainingPrincipalInCents = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InstallmentPlanEntriesCompanion.insert({
    required String id,
    required String bookId,
    required String name,
    required String originalTransactionId,
    required int totalAmountInCents,
    required int totalPeriods,
    required int currentPeriod,
    required int principalPerPeriodInCents,
    required int feePerPeriodInCents,
    required DateTime startDate,
    required int dueDay,
    required String creditAccountId,
    required String repaymentAccountId,
    required int remainingPrincipalInCents,
    this.status = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       name = Value(name),
       originalTransactionId = Value(originalTransactionId),
       totalAmountInCents = Value(totalAmountInCents),
       totalPeriods = Value(totalPeriods),
       currentPeriod = Value(currentPeriod),
       principalPerPeriodInCents = Value(principalPerPeriodInCents),
       feePerPeriodInCents = Value(feePerPeriodInCents),
       startDate = Value(startDate),
       dueDay = Value(dueDay),
       creditAccountId = Value(creditAccountId),
       repaymentAccountId = Value(repaymentAccountId),
       remainingPrincipalInCents = Value(remainingPrincipalInCents),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<InstallmentPlanEntity> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? name,
    Expression<String>? originalTransactionId,
    Expression<int>? totalAmountInCents,
    Expression<int>? totalPeriods,
    Expression<int>? currentPeriod,
    Expression<int>? principalPerPeriodInCents,
    Expression<int>? feePerPeriodInCents,
    Expression<DateTime>? startDate,
    Expression<int>? dueDay,
    Expression<String>? creditAccountId,
    Expression<String>? repaymentAccountId,
    Expression<int>? remainingPrincipalInCents,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (name != null) 'name': name,
      if (originalTransactionId != null)
        'original_transaction_id': originalTransactionId,
      if (totalAmountInCents != null)
        'total_amount_in_cents': totalAmountInCents,
      if (totalPeriods != null) 'total_periods': totalPeriods,
      if (currentPeriod != null) 'current_period': currentPeriod,
      if (principalPerPeriodInCents != null)
        'principal_per_period_in_cents': principalPerPeriodInCents,
      if (feePerPeriodInCents != null)
        'fee_per_period_in_cents': feePerPeriodInCents,
      if (startDate != null) 'start_date': startDate,
      if (dueDay != null) 'due_day': dueDay,
      if (creditAccountId != null) 'credit_account_id': creditAccountId,
      if (repaymentAccountId != null)
        'repayment_account_id': repaymentAccountId,
      if (remainingPrincipalInCents != null)
        'remaining_principal_in_cents': remainingPrincipalInCents,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InstallmentPlanEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String>? name,
    Value<String>? originalTransactionId,
    Value<int>? totalAmountInCents,
    Value<int>? totalPeriods,
    Value<int>? currentPeriod,
    Value<int>? principalPerPeriodInCents,
    Value<int>? feePerPeriodInCents,
    Value<DateTime>? startDate,
    Value<int>? dueDay,
    Value<String>? creditAccountId,
    Value<String>? repaymentAccountId,
    Value<int>? remainingPrincipalInCents,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return InstallmentPlanEntriesCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      name: name ?? this.name,
      originalTransactionId:
          originalTransactionId ?? this.originalTransactionId,
      totalAmountInCents: totalAmountInCents ?? this.totalAmountInCents,
      totalPeriods: totalPeriods ?? this.totalPeriods,
      currentPeriod: currentPeriod ?? this.currentPeriod,
      principalPerPeriodInCents:
          principalPerPeriodInCents ?? this.principalPerPeriodInCents,
      feePerPeriodInCents: feePerPeriodInCents ?? this.feePerPeriodInCents,
      startDate: startDate ?? this.startDate,
      dueDay: dueDay ?? this.dueDay,
      creditAccountId: creditAccountId ?? this.creditAccountId,
      repaymentAccountId: repaymentAccountId ?? this.repaymentAccountId,
      remainingPrincipalInCents:
          remainingPrincipalInCents ?? this.remainingPrincipalInCents,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (originalTransactionId.present) {
      map['original_transaction_id'] = Variable<String>(
        originalTransactionId.value,
      );
    }
    if (totalAmountInCents.present) {
      map['total_amount_in_cents'] = Variable<int>(totalAmountInCents.value);
    }
    if (totalPeriods.present) {
      map['total_periods'] = Variable<int>(totalPeriods.value);
    }
    if (currentPeriod.present) {
      map['current_period'] = Variable<int>(currentPeriod.value);
    }
    if (principalPerPeriodInCents.present) {
      map['principal_per_period_in_cents'] = Variable<int>(
        principalPerPeriodInCents.value,
      );
    }
    if (feePerPeriodInCents.present) {
      map['fee_per_period_in_cents'] = Variable<int>(feePerPeriodInCents.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (dueDay.present) {
      map['due_day'] = Variable<int>(dueDay.value);
    }
    if (creditAccountId.present) {
      map['credit_account_id'] = Variable<String>(creditAccountId.value);
    }
    if (repaymentAccountId.present) {
      map['repayment_account_id'] = Variable<String>(repaymentAccountId.value);
    }
    if (remainingPrincipalInCents.present) {
      map['remaining_principal_in_cents'] = Variable<int>(
        remainingPrincipalInCents.value,
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InstallmentPlanEntriesCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('name: $name, ')
          ..write('originalTransactionId: $originalTransactionId, ')
          ..write('totalAmountInCents: $totalAmountInCents, ')
          ..write('totalPeriods: $totalPeriods, ')
          ..write('currentPeriod: $currentPeriod, ')
          ..write('principalPerPeriodInCents: $principalPerPeriodInCents, ')
          ..write('feePerPeriodInCents: $feePerPeriodInCents, ')
          ..write('startDate: $startDate, ')
          ..write('dueDay: $dueDay, ')
          ..write('creditAccountId: $creditAccountId, ')
          ..write('repaymentAccountId: $repaymentAccountId, ')
          ..write('remainingPrincipalInCents: $remainingPrincipalInCents, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MerchantRuleEntriesTable extends MerchantRuleEntries
    with TableInfo<$MerchantRuleEntriesTable, MerchantRuleEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MerchantRuleEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('book-personal'),
  );
  static const VerificationMeta _merchantPatternMeta = const VerificationMeta(
    'merchantPattern',
  );
  @override
  late final GeneratedColumn<String> merchantPattern = GeneratedColumn<String>(
    'merchant_pattern',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedPatternMeta = const VerificationMeta(
    'normalizedPattern',
  );
  @override
  late final GeneratedColumn<String> normalizedPattern =
      GeneratedColumn<String>(
        'normalized_pattern',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _matchTypeMeta = const VerificationMeta(
    'matchType',
  );
  @override
  late final GeneratedColumn<String> matchType = GeneratedColumn<String>(
    'match_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _subcategoryIdMeta = const VerificationMeta(
    'subcategoryId',
  );
  @override
  late final GeneratedColumn<String> subcategoryId = GeneratedColumn<String>(
    'subcategory_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    merchantPattern,
    normalizedPattern,
    matchType,
    categoryId,
    subcategoryId,
    userId,
    confidence,
    source,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'merchant_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<MerchantRuleEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    }
    if (data.containsKey('merchant_pattern')) {
      context.handle(
        _merchantPatternMeta,
        merchantPattern.isAcceptableOrUnknown(
          data['merchant_pattern']!,
          _merchantPatternMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_merchantPatternMeta);
    }
    if (data.containsKey('normalized_pattern')) {
      context.handle(
        _normalizedPatternMeta,
        normalizedPattern.isAcceptableOrUnknown(
          data['normalized_pattern']!,
          _normalizedPatternMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedPatternMeta);
    }
    if (data.containsKey('match_type')) {
      context.handle(
        _matchTypeMeta,
        matchType.isAcceptableOrUnknown(data['match_type']!, _matchTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_matchTypeMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('subcategory_id')) {
      context.handle(
        _subcategoryIdMeta,
        subcategoryId.isAcceptableOrUnknown(
          data['subcategory_id']!,
          _subcategoryIdMeta,
        ),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    } else if (isInserting) {
      context.missing(_confidenceMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {bookId, userId, normalizedPattern, matchType},
  ];
  @override
  MerchantRuleEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MerchantRuleEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      merchantPattern: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchant_pattern'],
      )!,
      normalizedPattern: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_pattern'],
      )!,
      matchType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}match_type'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      subcategoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subcategory_id'],
      ),
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MerchantRuleEntriesTable createAlias(String alias) {
    return $MerchantRuleEntriesTable(attachedDatabase, alias);
  }
}

class MerchantRuleEntity extends DataClass
    implements Insertable<MerchantRuleEntity> {
  final String id;
  final String bookId;
  final String merchantPattern;
  final String normalizedPattern;
  final String matchType;
  final String categoryId;
  final String? subcategoryId;
  final String? userId;
  final double confidence;
  final String source;
  final DateTime createdAt;
  final DateTime updatedAt;
  const MerchantRuleEntity({
    required this.id,
    required this.bookId,
    required this.merchantPattern,
    required this.normalizedPattern,
    required this.matchType,
    required this.categoryId,
    this.subcategoryId,
    this.userId,
    required this.confidence,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['merchant_pattern'] = Variable<String>(merchantPattern);
    map['normalized_pattern'] = Variable<String>(normalizedPattern);
    map['match_type'] = Variable<String>(matchType);
    map['category_id'] = Variable<String>(categoryId);
    if (!nullToAbsent || subcategoryId != null) {
      map['subcategory_id'] = Variable<String>(subcategoryId);
    }
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    map['confidence'] = Variable<double>(confidence);
    map['source'] = Variable<String>(source);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MerchantRuleEntriesCompanion toCompanion(bool nullToAbsent) {
    return MerchantRuleEntriesCompanion(
      id: Value(id),
      bookId: Value(bookId),
      merchantPattern: Value(merchantPattern),
      normalizedPattern: Value(normalizedPattern),
      matchType: Value(matchType),
      categoryId: Value(categoryId),
      subcategoryId: subcategoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(subcategoryId),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
      confidence: Value(confidence),
      source: Value(source),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MerchantRuleEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MerchantRuleEntity(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      merchantPattern: serializer.fromJson<String>(json['merchantPattern']),
      normalizedPattern: serializer.fromJson<String>(json['normalizedPattern']),
      matchType: serializer.fromJson<String>(json['matchType']),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      subcategoryId: serializer.fromJson<String?>(json['subcategoryId']),
      userId: serializer.fromJson<String?>(json['userId']),
      confidence: serializer.fromJson<double>(json['confidence']),
      source: serializer.fromJson<String>(json['source']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'merchantPattern': serializer.toJson<String>(merchantPattern),
      'normalizedPattern': serializer.toJson<String>(normalizedPattern),
      'matchType': serializer.toJson<String>(matchType),
      'categoryId': serializer.toJson<String>(categoryId),
      'subcategoryId': serializer.toJson<String?>(subcategoryId),
      'userId': serializer.toJson<String?>(userId),
      'confidence': serializer.toJson<double>(confidence),
      'source': serializer.toJson<String>(source),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MerchantRuleEntity copyWith({
    String? id,
    String? bookId,
    String? merchantPattern,
    String? normalizedPattern,
    String? matchType,
    String? categoryId,
    Value<String?> subcategoryId = const Value.absent(),
    Value<String?> userId = const Value.absent(),
    double? confidence,
    String? source,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => MerchantRuleEntity(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    merchantPattern: merchantPattern ?? this.merchantPattern,
    normalizedPattern: normalizedPattern ?? this.normalizedPattern,
    matchType: matchType ?? this.matchType,
    categoryId: categoryId ?? this.categoryId,
    subcategoryId: subcategoryId.present
        ? subcategoryId.value
        : this.subcategoryId,
    userId: userId.present ? userId.value : this.userId,
    confidence: confidence ?? this.confidence,
    source: source ?? this.source,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MerchantRuleEntity copyWithCompanion(MerchantRuleEntriesCompanion data) {
    return MerchantRuleEntity(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      merchantPattern: data.merchantPattern.present
          ? data.merchantPattern.value
          : this.merchantPattern,
      normalizedPattern: data.normalizedPattern.present
          ? data.normalizedPattern.value
          : this.normalizedPattern,
      matchType: data.matchType.present ? data.matchType.value : this.matchType,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      subcategoryId: data.subcategoryId.present
          ? data.subcategoryId.value
          : this.subcategoryId,
      userId: data.userId.present ? data.userId.value : this.userId,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      source: data.source.present ? data.source.value : this.source,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MerchantRuleEntity(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('merchantPattern: $merchantPattern, ')
          ..write('normalizedPattern: $normalizedPattern, ')
          ..write('matchType: $matchType, ')
          ..write('categoryId: $categoryId, ')
          ..write('subcategoryId: $subcategoryId, ')
          ..write('userId: $userId, ')
          ..write('confidence: $confidence, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    merchantPattern,
    normalizedPattern,
    matchType,
    categoryId,
    subcategoryId,
    userId,
    confidence,
    source,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MerchantRuleEntity &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.merchantPattern == this.merchantPattern &&
          other.normalizedPattern == this.normalizedPattern &&
          other.matchType == this.matchType &&
          other.categoryId == this.categoryId &&
          other.subcategoryId == this.subcategoryId &&
          other.userId == this.userId &&
          other.confidence == this.confidence &&
          other.source == this.source &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MerchantRuleEntriesCompanion extends UpdateCompanion<MerchantRuleEntity> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> merchantPattern;
  final Value<String> normalizedPattern;
  final Value<String> matchType;
  final Value<String> categoryId;
  final Value<String?> subcategoryId;
  final Value<String?> userId;
  final Value<double> confidence;
  final Value<String> source;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MerchantRuleEntriesCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.merchantPattern = const Value.absent(),
    this.normalizedPattern = const Value.absent(),
    this.matchType = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.subcategoryId = const Value.absent(),
    this.userId = const Value.absent(),
    this.confidence = const Value.absent(),
    this.source = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MerchantRuleEntriesCompanion.insert({
    required String id,
    this.bookId = const Value.absent(),
    required String merchantPattern,
    required String normalizedPattern,
    required String matchType,
    required String categoryId,
    this.subcategoryId = const Value.absent(),
    this.userId = const Value.absent(),
    required double confidence,
    required String source,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       merchantPattern = Value(merchantPattern),
       normalizedPattern = Value(normalizedPattern),
       matchType = Value(matchType),
       categoryId = Value(categoryId),
       confidence = Value(confidence),
       source = Value(source),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<MerchantRuleEntity> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? merchantPattern,
    Expression<String>? normalizedPattern,
    Expression<String>? matchType,
    Expression<String>? categoryId,
    Expression<String>? subcategoryId,
    Expression<String>? userId,
    Expression<double>? confidence,
    Expression<String>? source,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (merchantPattern != null) 'merchant_pattern': merchantPattern,
      if (normalizedPattern != null) 'normalized_pattern': normalizedPattern,
      if (matchType != null) 'match_type': matchType,
      if (categoryId != null) 'category_id': categoryId,
      if (subcategoryId != null) 'subcategory_id': subcategoryId,
      if (userId != null) 'user_id': userId,
      if (confidence != null) 'confidence': confidence,
      if (source != null) 'source': source,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MerchantRuleEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String>? merchantPattern,
    Value<String>? normalizedPattern,
    Value<String>? matchType,
    Value<String>? categoryId,
    Value<String?>? subcategoryId,
    Value<String?>? userId,
    Value<double>? confidence,
    Value<String>? source,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return MerchantRuleEntriesCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      merchantPattern: merchantPattern ?? this.merchantPattern,
      normalizedPattern: normalizedPattern ?? this.normalizedPattern,
      matchType: matchType ?? this.matchType,
      categoryId: categoryId ?? this.categoryId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      userId: userId ?? this.userId,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (merchantPattern.present) {
      map['merchant_pattern'] = Variable<String>(merchantPattern.value);
    }
    if (normalizedPattern.present) {
      map['normalized_pattern'] = Variable<String>(normalizedPattern.value);
    }
    if (matchType.present) {
      map['match_type'] = Variable<String>(matchType.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (subcategoryId.present) {
      map['subcategory_id'] = Variable<String>(subcategoryId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MerchantRuleEntriesCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('merchantPattern: $merchantPattern, ')
          ..write('normalizedPattern: $normalizedPattern, ')
          ..write('matchType: $matchType, ')
          ..write('categoryId: $categoryId, ')
          ..write('subcategoryId: $subcategoryId, ')
          ..write('userId: $userId, ')
          ..write('confidence: $confidence, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EconomicEventEntriesTable extends EconomicEventEntries
    with TableInfo<$EconomicEventEntriesTable, EconomicEventEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EconomicEventEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountInCentsMeta = const VerificationMeta(
    'amountInCents',
  );
  @override
  late final GeneratedColumn<int> amountInCents = GeneratedColumn<int>(
    'amount_in_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('CNY'),
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('candidate'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    amountInCents,
    currency,
    occurredAt,
    status,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'economic_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<EconomicEventEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('amount_in_cents')) {
      context.handle(
        _amountInCentsMeta,
        amountInCents.isAcceptableOrUnknown(
          data['amount_in_cents']!,
          _amountInCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountInCentsMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EconomicEventEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EconomicEventEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      amountInCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_in_cents'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $EconomicEventEntriesTable createAlias(String alias) {
    return $EconomicEventEntriesTable(attachedDatabase, alias);
  }
}

class EconomicEventEntity extends DataClass
    implements Insertable<EconomicEventEntity> {
  final String id;
  final String bookId;
  final int amountInCents;
  final String currency;
  final DateTime occurredAt;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  const EconomicEventEntity({
    required this.id,
    required this.bookId,
    required this.amountInCents,
    required this.currency,
    required this.occurredAt,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['amount_in_cents'] = Variable<int>(amountInCents);
    map['currency'] = Variable<String>(currency);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  EconomicEventEntriesCompanion toCompanion(bool nullToAbsent) {
    return EconomicEventEntriesCompanion(
      id: Value(id),
      bookId: Value(bookId),
      amountInCents: Value(amountInCents),
      currency: Value(currency),
      occurredAt: Value(occurredAt),
      status: Value(status),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory EconomicEventEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EconomicEventEntity(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      amountInCents: serializer.fromJson<int>(json['amountInCents']),
      currency: serializer.fromJson<String>(json['currency']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'amountInCents': serializer.toJson<int>(amountInCents),
      'currency': serializer.toJson<String>(currency),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  EconomicEventEntity copyWith({
    String? id,
    String? bookId,
    int? amountInCents,
    String? currency,
    DateTime? occurredAt,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => EconomicEventEntity(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    amountInCents: amountInCents ?? this.amountInCents,
    currency: currency ?? this.currency,
    occurredAt: occurredAt ?? this.occurredAt,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  EconomicEventEntity copyWithCompanion(EconomicEventEntriesCompanion data) {
    return EconomicEventEntity(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      amountInCents: data.amountInCents.present
          ? data.amountInCents.value
          : this.amountInCents,
      currency: data.currency.present ? data.currency.value : this.currency,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EconomicEventEntity(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('amountInCents: $amountInCents, ')
          ..write('currency: $currency, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    amountInCents,
    currency,
    occurredAt,
    status,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EconomicEventEntity &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.amountInCents == this.amountInCents &&
          other.currency == this.currency &&
          other.occurredAt == this.occurredAt &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class EconomicEventEntriesCompanion
    extends UpdateCompanion<EconomicEventEntity> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<int> amountInCents;
  final Value<String> currency;
  final Value<DateTime> occurredAt;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const EconomicEventEntriesCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.amountInCents = const Value.absent(),
    this.currency = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EconomicEventEntriesCompanion.insert({
    required String id,
    required String bookId,
    required int amountInCents,
    this.currency = const Value.absent(),
    required DateTime occurredAt,
    this.status = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       amountInCents = Value(amountInCents),
       occurredAt = Value(occurredAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<EconomicEventEntity> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<int>? amountInCents,
    Expression<String>? currency,
    Expression<DateTime>? occurredAt,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (amountInCents != null) 'amount_in_cents': amountInCents,
      if (currency != null) 'currency': currency,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EconomicEventEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<int>? amountInCents,
    Value<String>? currency,
    Value<DateTime>? occurredAt,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return EconomicEventEntriesCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      amountInCents: amountInCents ?? this.amountInCents,
      currency: currency ?? this.currency,
      occurredAt: occurredAt ?? this.occurredAt,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (amountInCents.present) {
      map['amount_in_cents'] = Variable<int>(amountInCents.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EconomicEventEntriesCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('amountInCents: $amountInCents, ')
          ..write('currency: $currency, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EconomicEventRecordEntriesTable extends EconomicEventRecordEntries
    with
        TableInfo<$EconomicEventRecordEntriesTable, EconomicEventRecordEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EconomicEventRecordEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES economic_events (id)',
    ),
  );
  static const VerificationMeta _transactionIdMeta = const VerificationMeta(
    'transactionId',
  );
  @override
  late final GeneratedColumn<String> transactionId = GeneratedColumn<String>(
    'transaction_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES transactions (id)',
    ),
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('source'),
  );
  static const VerificationMeta _fingerprintMeta = const VerificationMeta(
    'fingerprint',
  );
  @override
  late final GeneratedColumn<String> fingerprint = GeneratedColumn<String>(
    'fingerprint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    eventId,
    transactionId,
    role,
    fingerprint,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'economic_event_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<EconomicEventRecordEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
        _transactionIdMeta,
        transactionId.isAcceptableOrUnknown(
          data['transaction_id']!,
          _transactionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    }
    if (data.containsKey('fingerprint')) {
      context.handle(
        _fingerprintMeta,
        fingerprint.isAcceptableOrUnknown(
          data['fingerprint']!,
          _fingerprintMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fingerprintMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {eventId, transactionId},
  ];
  @override
  EconomicEventRecordEntity map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EconomicEventRecordEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      transactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transaction_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      fingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fingerprint'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $EconomicEventRecordEntriesTable createAlias(String alias) {
    return $EconomicEventRecordEntriesTable(attachedDatabase, alias);
  }
}

class EconomicEventRecordEntity extends DataClass
    implements Insertable<EconomicEventRecordEntity> {
  final String id;
  final String eventId;
  final String transactionId;
  final String role;
  final String fingerprint;
  final DateTime createdAt;
  const EconomicEventRecordEntity({
    required this.id,
    required this.eventId,
    required this.transactionId,
    required this.role,
    required this.fingerprint,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['event_id'] = Variable<String>(eventId);
    map['transaction_id'] = Variable<String>(transactionId);
    map['role'] = Variable<String>(role);
    map['fingerprint'] = Variable<String>(fingerprint);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  EconomicEventRecordEntriesCompanion toCompanion(bool nullToAbsent) {
    return EconomicEventRecordEntriesCompanion(
      id: Value(id),
      eventId: Value(eventId),
      transactionId: Value(transactionId),
      role: Value(role),
      fingerprint: Value(fingerprint),
      createdAt: Value(createdAt),
    );
  }

  factory EconomicEventRecordEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EconomicEventRecordEntity(
      id: serializer.fromJson<String>(json['id']),
      eventId: serializer.fromJson<String>(json['eventId']),
      transactionId: serializer.fromJson<String>(json['transactionId']),
      role: serializer.fromJson<String>(json['role']),
      fingerprint: serializer.fromJson<String>(json['fingerprint']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'eventId': serializer.toJson<String>(eventId),
      'transactionId': serializer.toJson<String>(transactionId),
      'role': serializer.toJson<String>(role),
      'fingerprint': serializer.toJson<String>(fingerprint),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  EconomicEventRecordEntity copyWith({
    String? id,
    String? eventId,
    String? transactionId,
    String? role,
    String? fingerprint,
    DateTime? createdAt,
  }) => EconomicEventRecordEntity(
    id: id ?? this.id,
    eventId: eventId ?? this.eventId,
    transactionId: transactionId ?? this.transactionId,
    role: role ?? this.role,
    fingerprint: fingerprint ?? this.fingerprint,
    createdAt: createdAt ?? this.createdAt,
  );
  EconomicEventRecordEntity copyWithCompanion(
    EconomicEventRecordEntriesCompanion data,
  ) {
    return EconomicEventRecordEntity(
      id: data.id.present ? data.id.value : this.id,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      role: data.role.present ? data.role.value : this.role,
      fingerprint: data.fingerprint.present
          ? data.fingerprint.value
          : this.fingerprint,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EconomicEventRecordEntity(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('transactionId: $transactionId, ')
          ..write('role: $role, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, eventId, transactionId, role, fingerprint, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EconomicEventRecordEntity &&
          other.id == this.id &&
          other.eventId == this.eventId &&
          other.transactionId == this.transactionId &&
          other.role == this.role &&
          other.fingerprint == this.fingerprint &&
          other.createdAt == this.createdAt);
}

class EconomicEventRecordEntriesCompanion
    extends UpdateCompanion<EconomicEventRecordEntity> {
  final Value<String> id;
  final Value<String> eventId;
  final Value<String> transactionId;
  final Value<String> role;
  final Value<String> fingerprint;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const EconomicEventRecordEntriesCompanion({
    this.id = const Value.absent(),
    this.eventId = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.role = const Value.absent(),
    this.fingerprint = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EconomicEventRecordEntriesCompanion.insert({
    required String id,
    required String eventId,
    required String transactionId,
    this.role = const Value.absent(),
    required String fingerprint,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       eventId = Value(eventId),
       transactionId = Value(transactionId),
       fingerprint = Value(fingerprint),
       createdAt = Value(createdAt);
  static Insertable<EconomicEventRecordEntity> custom({
    Expression<String>? id,
    Expression<String>? eventId,
    Expression<String>? transactionId,
    Expression<String>? role,
    Expression<String>? fingerprint,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventId != null) 'event_id': eventId,
      if (transactionId != null) 'transaction_id': transactionId,
      if (role != null) 'role': role,
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EconomicEventRecordEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? eventId,
    Value<String>? transactionId,
    Value<String>? role,
    Value<String>? fingerprint,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return EconomicEventRecordEntriesCompanion(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      transactionId: transactionId ?? this.transactionId,
      role: role ?? this.role,
      fingerprint: fingerprint ?? this.fingerprint,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<String>(transactionId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (fingerprint.present) {
      map['fingerprint'] = Variable<String>(fingerprint.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EconomicEventRecordEntriesCompanion(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('transactionId: $transactionId, ')
          ..write('role: $role, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InboxItemEntriesTable extends InboxItemEntries
    with TableInfo<$InboxItemEntriesTable, InboxItemEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InboxItemEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('book-personal'),
  );
  static const VerificationMeta _transactionIdMeta = const VerificationMeta(
    'transactionId',
  );
  @override
  late final GeneratedColumn<String> transactionId = GeneratedColumn<String>(
    'transaction_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES transactions (id)',
    ),
  );
  static const VerificationMeta _candidateTransactionIdMeta =
      const VerificationMeta('candidateTransactionId');
  @override
  late final GeneratedColumn<String> candidateTransactionId =
      GeneratedColumn<String>(
        'candidate_transaction_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES transactions (id)',
        ),
      );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _duplicateConfidenceMeta =
      const VerificationMeta('duplicateConfidence');
  @override
  late final GeneratedColumn<double> duplicateConfidence =
      GeneratedColumn<double>(
        'duplicate_confidence',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resolvedAtMeta = const VerificationMeta(
    'resolvedAt',
  );
  @override
  late final GeneratedColumn<DateTime> resolvedAt = GeneratedColumn<DateTime>(
    'resolved_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    transactionId,
    candidateTransactionId,
    reason,
    status,
    duplicateConfidence,
    payloadJson,
    createdAt,
    resolvedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inbox_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<InboxItemEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
        _transactionIdMeta,
        transactionId.isAcceptableOrUnknown(
          data['transaction_id']!,
          _transactionIdMeta,
        ),
      );
    }
    if (data.containsKey('candidate_transaction_id')) {
      context.handle(
        _candidateTransactionIdMeta,
        candidateTransactionId.isAcceptableOrUnknown(
          data['candidate_transaction_id']!,
          _candidateTransactionIdMeta,
        ),
      );
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('duplicate_confidence')) {
      context.handle(
        _duplicateConfidenceMeta,
        duplicateConfidence.isAcceptableOrUnknown(
          data['duplicate_confidence']!,
          _duplicateConfidenceMeta,
        ),
      );
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
        _resolvedAtMeta,
        resolvedAt.isAcceptableOrUnknown(data['resolved_at']!, _resolvedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InboxItemEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InboxItemEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      transactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transaction_id'],
      ),
      candidateTransactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}candidate_transaction_id'],
      ),
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      duplicateConfidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}duplicate_confidence'],
      ),
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      resolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}resolved_at'],
      ),
    );
  }

  @override
  $InboxItemEntriesTable createAlias(String alias) {
    return $InboxItemEntriesTable(attachedDatabase, alias);
  }
}

class InboxItemEntity extends DataClass implements Insertable<InboxItemEntity> {
  final String id;
  final String bookId;
  final String? transactionId;
  final String? candidateTransactionId;
  final String reason;
  final String status;
  final double? duplicateConfidence;
  final String? payloadJson;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  const InboxItemEntity({
    required this.id,
    required this.bookId,
    this.transactionId,
    this.candidateTransactionId,
    required this.reason,
    required this.status,
    this.duplicateConfidence,
    this.payloadJson,
    required this.createdAt,
    this.resolvedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    if (!nullToAbsent || transactionId != null) {
      map['transaction_id'] = Variable<String>(transactionId);
    }
    if (!nullToAbsent || candidateTransactionId != null) {
      map['candidate_transaction_id'] = Variable<String>(
        candidateTransactionId,
      );
    }
    map['reason'] = Variable<String>(reason);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || duplicateConfidence != null) {
      map['duplicate_confidence'] = Variable<double>(duplicateConfidence);
    }
    if (!nullToAbsent || payloadJson != null) {
      map['payload_json'] = Variable<String>(payloadJson);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt);
    }
    return map;
  }

  InboxItemEntriesCompanion toCompanion(bool nullToAbsent) {
    return InboxItemEntriesCompanion(
      id: Value(id),
      bookId: Value(bookId),
      transactionId: transactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(transactionId),
      candidateTransactionId: candidateTransactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(candidateTransactionId),
      reason: Value(reason),
      status: Value(status),
      duplicateConfidence: duplicateConfidence == null && nullToAbsent
          ? const Value.absent()
          : Value(duplicateConfidence),
      payloadJson: payloadJson == null && nullToAbsent
          ? const Value.absent()
          : Value(payloadJson),
      createdAt: Value(createdAt),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
    );
  }

  factory InboxItemEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InboxItemEntity(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      transactionId: serializer.fromJson<String?>(json['transactionId']),
      candidateTransactionId: serializer.fromJson<String?>(
        json['candidateTransactionId'],
      ),
      reason: serializer.fromJson<String>(json['reason']),
      status: serializer.fromJson<String>(json['status']),
      duplicateConfidence: serializer.fromJson<double?>(
        json['duplicateConfidence'],
      ),
      payloadJson: serializer.fromJson<String?>(json['payloadJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      resolvedAt: serializer.fromJson<DateTime?>(json['resolvedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'transactionId': serializer.toJson<String?>(transactionId),
      'candidateTransactionId': serializer.toJson<String?>(
        candidateTransactionId,
      ),
      'reason': serializer.toJson<String>(reason),
      'status': serializer.toJson<String>(status),
      'duplicateConfidence': serializer.toJson<double?>(duplicateConfidence),
      'payloadJson': serializer.toJson<String?>(payloadJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'resolvedAt': serializer.toJson<DateTime?>(resolvedAt),
    };
  }

  InboxItemEntity copyWith({
    String? id,
    String? bookId,
    Value<String?> transactionId = const Value.absent(),
    Value<String?> candidateTransactionId = const Value.absent(),
    String? reason,
    String? status,
    Value<double?> duplicateConfidence = const Value.absent(),
    Value<String?> payloadJson = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> resolvedAt = const Value.absent(),
  }) => InboxItemEntity(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    transactionId: transactionId.present
        ? transactionId.value
        : this.transactionId,
    candidateTransactionId: candidateTransactionId.present
        ? candidateTransactionId.value
        : this.candidateTransactionId,
    reason: reason ?? this.reason,
    status: status ?? this.status,
    duplicateConfidence: duplicateConfidence.present
        ? duplicateConfidence.value
        : this.duplicateConfidence,
    payloadJson: payloadJson.present ? payloadJson.value : this.payloadJson,
    createdAt: createdAt ?? this.createdAt,
    resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
  );
  InboxItemEntity copyWithCompanion(InboxItemEntriesCompanion data) {
    return InboxItemEntity(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      candidateTransactionId: data.candidateTransactionId.present
          ? data.candidateTransactionId.value
          : this.candidateTransactionId,
      reason: data.reason.present ? data.reason.value : this.reason,
      status: data.status.present ? data.status.value : this.status,
      duplicateConfidence: data.duplicateConfidence.present
          ? data.duplicateConfidence.value
          : this.duplicateConfidence,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      resolvedAt: data.resolvedAt.present
          ? data.resolvedAt.value
          : this.resolvedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InboxItemEntity(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('transactionId: $transactionId, ')
          ..write('candidateTransactionId: $candidateTransactionId, ')
          ..write('reason: $reason, ')
          ..write('status: $status, ')
          ..write('duplicateConfidence: $duplicateConfidence, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolvedAt: $resolvedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    transactionId,
    candidateTransactionId,
    reason,
    status,
    duplicateConfidence,
    payloadJson,
    createdAt,
    resolvedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InboxItemEntity &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.transactionId == this.transactionId &&
          other.candidateTransactionId == this.candidateTransactionId &&
          other.reason == this.reason &&
          other.status == this.status &&
          other.duplicateConfidence == this.duplicateConfidence &&
          other.payloadJson == this.payloadJson &&
          other.createdAt == this.createdAt &&
          other.resolvedAt == this.resolvedAt);
}

class InboxItemEntriesCompanion extends UpdateCompanion<InboxItemEntity> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String?> transactionId;
  final Value<String?> candidateTransactionId;
  final Value<String> reason;
  final Value<String> status;
  final Value<double?> duplicateConfidence;
  final Value<String?> payloadJson;
  final Value<DateTime> createdAt;
  final Value<DateTime?> resolvedAt;
  final Value<int> rowid;
  const InboxItemEntriesCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.candidateTransactionId = const Value.absent(),
    this.reason = const Value.absent(),
    this.status = const Value.absent(),
    this.duplicateConfidence = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InboxItemEntriesCompanion.insert({
    required String id,
    this.bookId = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.candidateTransactionId = const Value.absent(),
    required String reason,
    this.status = const Value.absent(),
    this.duplicateConfidence = const Value.absent(),
    this.payloadJson = const Value.absent(),
    required DateTime createdAt,
    this.resolvedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       reason = Value(reason),
       createdAt = Value(createdAt);
  static Insertable<InboxItemEntity> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? transactionId,
    Expression<String>? candidateTransactionId,
    Expression<String>? reason,
    Expression<String>? status,
    Expression<double>? duplicateConfidence,
    Expression<String>? payloadJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? resolvedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (transactionId != null) 'transaction_id': transactionId,
      if (candidateTransactionId != null)
        'candidate_transaction_id': candidateTransactionId,
      if (reason != null) 'reason': reason,
      if (status != null) 'status': status,
      if (duplicateConfidence != null)
        'duplicate_confidence': duplicateConfidence,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (createdAt != null) 'created_at': createdAt,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InboxItemEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String?>? transactionId,
    Value<String?>? candidateTransactionId,
    Value<String>? reason,
    Value<String>? status,
    Value<double?>? duplicateConfidence,
    Value<String?>? payloadJson,
    Value<DateTime>? createdAt,
    Value<DateTime?>? resolvedAt,
    Value<int>? rowid,
  }) {
    return InboxItemEntriesCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      transactionId: transactionId ?? this.transactionId,
      candidateTransactionId:
          candidateTransactionId ?? this.candidateTransactionId,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      duplicateConfidence: duplicateConfidence ?? this.duplicateConfidence,
      payloadJson: payloadJson ?? this.payloadJson,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<String>(transactionId.value);
    }
    if (candidateTransactionId.present) {
      map['candidate_transaction_id'] = Variable<String>(
        candidateTransactionId.value,
      );
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (duplicateConfidence.present) {
      map['duplicate_confidence'] = Variable<double>(duplicateConfidence.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InboxItemEntriesCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('transactionId: $transactionId, ')
          ..write('candidateTransactionId: $candidateTransactionId, ')
          ..write('reason: $reason, ')
          ..write('status: $status, ')
          ..write('duplicateConfidence: $duplicateConfidence, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FamilyEntriesTable extends FamilyEntries
    with TableInfo<$FamilyEntriesTable, FamilyEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FamilyEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerUserIdMeta = const VerificationMeta(
    'ownerUserId',
  );
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
    'owner_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    ownerUserId,
    createdAt,
    updatedAt,
    version,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'families';
  @override
  VerificationContext validateIntegrity(
    Insertable<FamilyEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('owner_user_id')) {
      context.handle(
        _ownerUserIdMeta,
        ownerUserId.isAcceptableOrUnknown(
          data['owner_user_id']!,
          _ownerUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerUserIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FamilyEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FamilyEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      ownerUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_user_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $FamilyEntriesTable createAlias(String alias) {
    return $FamilyEntriesTable(attachedDatabase, alias);
  }
}

class FamilyEntity extends DataClass implements Insertable<FamilyEntity> {
  final String id;
  final String name;
  final String ownerUserId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  const FamilyEntity({
    required this.id,
    required this.name,
    required this.ownerUserId,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['owner_user_id'] = Variable<String>(ownerUserId);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['version'] = Variable<int>(version);
    return map;
  }

  FamilyEntriesCompanion toCompanion(bool nullToAbsent) {
    return FamilyEntriesCompanion(
      id: Value(id),
      name: Value(name),
      ownerUserId: Value(ownerUserId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      version: Value(version),
    );
  }

  factory FamilyEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FamilyEntity(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      ownerUserId: serializer.fromJson<String>(json['ownerUserId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'ownerUserId': serializer.toJson<String>(ownerUserId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'version': serializer.toJson<int>(version),
    };
  }

  FamilyEntity copyWith({
    String? id,
    String? name,
    String? ownerUserId,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
  }) => FamilyEntity(
    id: id ?? this.id,
    name: name ?? this.name,
    ownerUserId: ownerUserId ?? this.ownerUserId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
  );
  FamilyEntity copyWithCompanion(FamilyEntriesCompanion data) {
    return FamilyEntity(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      ownerUserId: data.ownerUserId.present
          ? data.ownerUserId.value
          : this.ownerUserId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FamilyEntity(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, ownerUserId, createdAt, updatedAt, version);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FamilyEntity &&
          other.id == this.id &&
          other.name == this.name &&
          other.ownerUserId == this.ownerUserId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.version == this.version);
}

class FamilyEntriesCompanion extends UpdateCompanion<FamilyEntity> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> ownerUserId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> version;
  final Value<int> rowid;
  const FamilyEntriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.ownerUserId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FamilyEntriesCompanion.insert({
    required String id,
    required String name,
    required String ownerUserId,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       ownerUserId = Value(ownerUserId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<FamilyEntity> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? ownerUserId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FamilyEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? ownerUserId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? version,
    Value<int>? rowid,
  }) {
    return FamilyEntriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FamilyEntriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookEntriesTable extends BookEntries
    with TableInfo<$BookEntriesTable, BookEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerUserIdMeta = const VerificationMeta(
    'ownerUserId',
  );
  @override
  late final GeneratedColumn<String> ownerUserId = GeneratedColumn<String>(
    'owner_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _familyIdMeta = const VerificationMeta(
    'familyId',
  );
  @override
  late final GeneratedColumn<String> familyId = GeneratedColumn<String>(
    'family_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES families (id)',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isArchivedMeta = const VerificationMeta(
    'isArchived',
  );
  @override
  late final GeneratedColumn<bool> isArchived = GeneratedColumn<bool>(
    'is_archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _assetSourceBookIdMeta = const VerificationMeta(
    'assetSourceBookId',
  );
  @override
  late final GeneratedColumn<String> assetSourceBookId =
      GeneratedColumn<String>(
        'asset_source_book_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    ownerUserId,
    familyId,
    createdAt,
    updatedAt,
    isArchived,
    assetSourceBookId,
    version,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'books';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('owner_user_id')) {
      context.handle(
        _ownerUserIdMeta,
        ownerUserId.isAcceptableOrUnknown(
          data['owner_user_id']!,
          _ownerUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ownerUserIdMeta);
    }
    if (data.containsKey('family_id')) {
      context.handle(
        _familyIdMeta,
        familyId.isAcceptableOrUnknown(data['family_id']!, _familyIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('is_archived')) {
      context.handle(
        _isArchivedMeta,
        isArchived.isAcceptableOrUnknown(data['is_archived']!, _isArchivedMeta),
      );
    }
    if (data.containsKey('asset_source_book_id')) {
      context.handle(
        _assetSourceBookIdMeta,
        assetSourceBookId.isAcceptableOrUnknown(
          data['asset_source_book_id']!,
          _assetSourceBookIdMeta,
        ),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BookEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      ownerUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner_user_id'],
      )!,
      familyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      isArchived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_archived'],
      )!,
      assetSourceBookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_source_book_id'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $BookEntriesTable createAlias(String alias) {
    return $BookEntriesTable(attachedDatabase, alias);
  }
}

class BookEntity extends DataClass implements Insertable<BookEntity> {
  final String id;
  final String name;
  final String type;
  final String ownerUserId;
  final String? familyId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;
  final String? assetSourceBookId;
  final int version;
  const BookEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.ownerUserId,
    this.familyId,
    required this.createdAt,
    required this.updatedAt,
    required this.isArchived,
    this.assetSourceBookId,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['owner_user_id'] = Variable<String>(ownerUserId);
    if (!nullToAbsent || familyId != null) {
      map['family_id'] = Variable<String>(familyId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_archived'] = Variable<bool>(isArchived);
    if (!nullToAbsent || assetSourceBookId != null) {
      map['asset_source_book_id'] = Variable<String>(assetSourceBookId);
    }
    map['version'] = Variable<int>(version);
    return map;
  }

  BookEntriesCompanion toCompanion(bool nullToAbsent) {
    return BookEntriesCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      ownerUserId: Value(ownerUserId),
      familyId: familyId == null && nullToAbsent
          ? const Value.absent()
          : Value(familyId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isArchived: Value(isArchived),
      assetSourceBookId: assetSourceBookId == null && nullToAbsent
          ? const Value.absent()
          : Value(assetSourceBookId),
      version: Value(version),
    );
  }

  factory BookEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookEntity(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      ownerUserId: serializer.fromJson<String>(json['ownerUserId']),
      familyId: serializer.fromJson<String?>(json['familyId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isArchived: serializer.fromJson<bool>(json['isArchived']),
      assetSourceBookId: serializer.fromJson<String?>(
        json['assetSourceBookId'],
      ),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'ownerUserId': serializer.toJson<String>(ownerUserId),
      'familyId': serializer.toJson<String?>(familyId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isArchived': serializer.toJson<bool>(isArchived),
      'assetSourceBookId': serializer.toJson<String?>(assetSourceBookId),
      'version': serializer.toJson<int>(version),
    };
  }

  BookEntity copyWith({
    String? id,
    String? name,
    String? type,
    String? ownerUserId,
    Value<String?> familyId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isArchived,
    Value<String?> assetSourceBookId = const Value.absent(),
    int? version,
  }) => BookEntity(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    ownerUserId: ownerUserId ?? this.ownerUserId,
    familyId: familyId.present ? familyId.value : this.familyId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isArchived: isArchived ?? this.isArchived,
    assetSourceBookId: assetSourceBookId.present
        ? assetSourceBookId.value
        : this.assetSourceBookId,
    version: version ?? this.version,
  );
  BookEntity copyWithCompanion(BookEntriesCompanion data) {
    return BookEntity(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      ownerUserId: data.ownerUserId.present
          ? data.ownerUserId.value
          : this.ownerUserId,
      familyId: data.familyId.present ? data.familyId.value : this.familyId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isArchived: data.isArchived.present
          ? data.isArchived.value
          : this.isArchived,
      assetSourceBookId: data.assetSourceBookId.present
          ? data.assetSourceBookId.value
          : this.assetSourceBookId,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookEntity(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('familyId: $familyId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isArchived: $isArchived, ')
          ..write('assetSourceBookId: $assetSourceBookId, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    ownerUserId,
    familyId,
    createdAt,
    updatedAt,
    isArchived,
    assetSourceBookId,
    version,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookEntity &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.ownerUserId == this.ownerUserId &&
          other.familyId == this.familyId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isArchived == this.isArchived &&
          other.assetSourceBookId == this.assetSourceBookId &&
          other.version == this.version);
}

class BookEntriesCompanion extends UpdateCompanion<BookEntity> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> type;
  final Value<String> ownerUserId;
  final Value<String?> familyId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> isArchived;
  final Value<String?> assetSourceBookId;
  final Value<int> version;
  final Value<int> rowid;
  const BookEntriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.ownerUserId = const Value.absent(),
    this.familyId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isArchived = const Value.absent(),
    this.assetSourceBookId = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookEntriesCompanion.insert({
    required String id,
    required String name,
    required String type,
    required String ownerUserId,
    this.familyId = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.isArchived = const Value.absent(),
    this.assetSourceBookId = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       type = Value(type),
       ownerUserId = Value(ownerUserId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<BookEntity> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? ownerUserId,
    Expression<String>? familyId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isArchived,
    Expression<String>? assetSourceBookId,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (ownerUserId != null) 'owner_user_id': ownerUserId,
      if (familyId != null) 'family_id': familyId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isArchived != null) 'is_archived': isArchived,
      if (assetSourceBookId != null) 'asset_source_book_id': assetSourceBookId,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? type,
    Value<String>? ownerUserId,
    Value<String?>? familyId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? isArchived,
    Value<String?>? assetSourceBookId,
    Value<int>? version,
    Value<int>? rowid,
  }) {
    return BookEntriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      familyId: familyId ?? this.familyId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
      assetSourceBookId: assetSourceBookId ?? this.assetSourceBookId,
      version: version ?? this.version,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (ownerUserId.present) {
      map['owner_user_id'] = Variable<String>(ownerUserId.value);
    }
    if (familyId.present) {
      map['family_id'] = Variable<String>(familyId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isArchived.present) {
      map['is_archived'] = Variable<bool>(isArchived.value);
    }
    if (assetSourceBookId.present) {
      map['asset_source_book_id'] = Variable<String>(assetSourceBookId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookEntriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('ownerUserId: $ownerUserId, ')
          ..write('familyId: $familyId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isArchived: $isArchived, ')
          ..write('assetSourceBookId: $assetSourceBookId, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FamilyMemberEntriesTable extends FamilyMemberEntries
    with TableInfo<$FamilyMemberEntriesTable, FamilyMemberEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FamilyMemberEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _familyIdMeta = const VerificationMeta(
    'familyId',
  );
  @override
  late final GeneratedColumn<String> familyId = GeneratedColumn<String>(
    'family_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES families (id)',
    ),
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _joinedAtMeta = const VerificationMeta(
    'joinedAt',
  );
  @override
  late final GeneratedColumn<DateTime> joinedAt = GeneratedColumn<DateTime>(
    'joined_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, familyId, userId, role, joinedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'family_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<FamilyMemberEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('family_id')) {
      context.handle(
        _familyIdMeta,
        familyId.isAcceptableOrUnknown(data['family_id']!, _familyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_familyIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('joined_at')) {
      context.handle(
        _joinedAtMeta,
        joinedAt.isAcceptableOrUnknown(data['joined_at']!, _joinedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_joinedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {familyId, userId},
  ];
  @override
  FamilyMemberEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FamilyMemberEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      familyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      joinedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}joined_at'],
      )!,
    );
  }

  @override
  $FamilyMemberEntriesTable createAlias(String alias) {
    return $FamilyMemberEntriesTable(attachedDatabase, alias);
  }
}

class FamilyMemberEntity extends DataClass
    implements Insertable<FamilyMemberEntity> {
  final String id;
  final String familyId;
  final String userId;
  final String role;
  final DateTime joinedAt;
  const FamilyMemberEntity({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.role,
    required this.joinedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['family_id'] = Variable<String>(familyId);
    map['user_id'] = Variable<String>(userId);
    map['role'] = Variable<String>(role);
    map['joined_at'] = Variable<DateTime>(joinedAt);
    return map;
  }

  FamilyMemberEntriesCompanion toCompanion(bool nullToAbsent) {
    return FamilyMemberEntriesCompanion(
      id: Value(id),
      familyId: Value(familyId),
      userId: Value(userId),
      role: Value(role),
      joinedAt: Value(joinedAt),
    );
  }

  factory FamilyMemberEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FamilyMemberEntity(
      id: serializer.fromJson<String>(json['id']),
      familyId: serializer.fromJson<String>(json['familyId']),
      userId: serializer.fromJson<String>(json['userId']),
      role: serializer.fromJson<String>(json['role']),
      joinedAt: serializer.fromJson<DateTime>(json['joinedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'familyId': serializer.toJson<String>(familyId),
      'userId': serializer.toJson<String>(userId),
      'role': serializer.toJson<String>(role),
      'joinedAt': serializer.toJson<DateTime>(joinedAt),
    };
  }

  FamilyMemberEntity copyWith({
    String? id,
    String? familyId,
    String? userId,
    String? role,
    DateTime? joinedAt,
  }) => FamilyMemberEntity(
    id: id ?? this.id,
    familyId: familyId ?? this.familyId,
    userId: userId ?? this.userId,
    role: role ?? this.role,
    joinedAt: joinedAt ?? this.joinedAt,
  );
  FamilyMemberEntity copyWithCompanion(FamilyMemberEntriesCompanion data) {
    return FamilyMemberEntity(
      id: data.id.present ? data.id.value : this.id,
      familyId: data.familyId.present ? data.familyId.value : this.familyId,
      userId: data.userId.present ? data.userId.value : this.userId,
      role: data.role.present ? data.role.value : this.role,
      joinedAt: data.joinedAt.present ? data.joinedAt.value : this.joinedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FamilyMemberEntity(')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('userId: $userId, ')
          ..write('role: $role, ')
          ..write('joinedAt: $joinedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, familyId, userId, role, joinedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FamilyMemberEntity &&
          other.id == this.id &&
          other.familyId == this.familyId &&
          other.userId == this.userId &&
          other.role == this.role &&
          other.joinedAt == this.joinedAt);
}

class FamilyMemberEntriesCompanion extends UpdateCompanion<FamilyMemberEntity> {
  final Value<String> id;
  final Value<String> familyId;
  final Value<String> userId;
  final Value<String> role;
  final Value<DateTime> joinedAt;
  final Value<int> rowid;
  const FamilyMemberEntriesCompanion({
    this.id = const Value.absent(),
    this.familyId = const Value.absent(),
    this.userId = const Value.absent(),
    this.role = const Value.absent(),
    this.joinedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FamilyMemberEntriesCompanion.insert({
    required String id,
    required String familyId,
    required String userId,
    required String role,
    required DateTime joinedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       familyId = Value(familyId),
       userId = Value(userId),
       role = Value(role),
       joinedAt = Value(joinedAt);
  static Insertable<FamilyMemberEntity> custom({
    Expression<String>? id,
    Expression<String>? familyId,
    Expression<String>? userId,
    Expression<String>? role,
    Expression<DateTime>? joinedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (familyId != null) 'family_id': familyId,
      if (userId != null) 'user_id': userId,
      if (role != null) 'role': role,
      if (joinedAt != null) 'joined_at': joinedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FamilyMemberEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? familyId,
    Value<String>? userId,
    Value<String>? role,
    Value<DateTime>? joinedAt,
    Value<int>? rowid,
  }) {
    return FamilyMemberEntriesCompanion(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (familyId.present) {
      map['family_id'] = Variable<String>(familyId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (joinedAt.present) {
      map['joined_at'] = Variable<DateTime>(joinedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FamilyMemberEntriesCompanion(')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('userId: $userId, ')
          ..write('role: $role, ')
          ..write('joinedAt: $joinedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FamilyInvitationEntriesTable extends FamilyInvitationEntries
    with TableInfo<$FamilyInvitationEntriesTable, FamilyInvitationEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FamilyInvitationEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _familyIdMeta = const VerificationMeta(
    'familyId',
  );
  @override
  late final GeneratedColumn<String> familyId = GeneratedColumn<String>(
    'family_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES families (id)',
    ),
  );
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _invitedByMeta = const VerificationMeta(
    'invitedBy',
  );
  @override
  late final GeneratedColumn<String> invitedBy = GeneratedColumn<String>(
    'invited_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resolvedAtMeta = const VerificationMeta(
    'resolvedAt',
  );
  @override
  late final GeneratedColumn<DateTime> resolvedAt = GeneratedColumn<DateTime>(
    'resolved_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    familyId,
    code,
    invitedBy,
    status,
    expiresAt,
    createdAt,
    resolvedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'family_invitations';
  @override
  VerificationContext validateIntegrity(
    Insertable<FamilyInvitationEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('family_id')) {
      context.handle(
        _familyIdMeta,
        familyId.isAcceptableOrUnknown(data['family_id']!, _familyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_familyIdMeta);
    }
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('invited_by')) {
      context.handle(
        _invitedByMeta,
        invitedBy.isAcceptableOrUnknown(data['invited_by']!, _invitedByMeta),
      );
    } else if (isInserting) {
      context.missing(_invitedByMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
        _resolvedAtMeta,
        resolvedAt.isAcceptableOrUnknown(data['resolved_at']!, _resolvedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FamilyInvitationEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FamilyInvitationEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      familyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family_id'],
      )!,
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      invitedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}invited_by'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      resolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}resolved_at'],
      ),
    );
  }

  @override
  $FamilyInvitationEntriesTable createAlias(String alias) {
    return $FamilyInvitationEntriesTable(attachedDatabase, alias);
  }
}

class FamilyInvitationEntity extends DataClass
    implements Insertable<FamilyInvitationEntity> {
  final String id;
  final String familyId;
  final String code;
  final String invitedBy;
  final String status;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  const FamilyInvitationEntity({
    required this.id,
    required this.familyId,
    required this.code,
    required this.invitedBy,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    this.resolvedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['family_id'] = Variable<String>(familyId);
    map['code'] = Variable<String>(code);
    map['invited_by'] = Variable<String>(invitedBy);
    map['status'] = Variable<String>(status);
    map['expires_at'] = Variable<DateTime>(expiresAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt);
    }
    return map;
  }

  FamilyInvitationEntriesCompanion toCompanion(bool nullToAbsent) {
    return FamilyInvitationEntriesCompanion(
      id: Value(id),
      familyId: Value(familyId),
      code: Value(code),
      invitedBy: Value(invitedBy),
      status: Value(status),
      expiresAt: Value(expiresAt),
      createdAt: Value(createdAt),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
    );
  }

  factory FamilyInvitationEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FamilyInvitationEntity(
      id: serializer.fromJson<String>(json['id']),
      familyId: serializer.fromJson<String>(json['familyId']),
      code: serializer.fromJson<String>(json['code']),
      invitedBy: serializer.fromJson<String>(json['invitedBy']),
      status: serializer.fromJson<String>(json['status']),
      expiresAt: serializer.fromJson<DateTime>(json['expiresAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      resolvedAt: serializer.fromJson<DateTime?>(json['resolvedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'familyId': serializer.toJson<String>(familyId),
      'code': serializer.toJson<String>(code),
      'invitedBy': serializer.toJson<String>(invitedBy),
      'status': serializer.toJson<String>(status),
      'expiresAt': serializer.toJson<DateTime>(expiresAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'resolvedAt': serializer.toJson<DateTime?>(resolvedAt),
    };
  }

  FamilyInvitationEntity copyWith({
    String? id,
    String? familyId,
    String? code,
    String? invitedBy,
    String? status,
    DateTime? expiresAt,
    DateTime? createdAt,
    Value<DateTime?> resolvedAt = const Value.absent(),
  }) => FamilyInvitationEntity(
    id: id ?? this.id,
    familyId: familyId ?? this.familyId,
    code: code ?? this.code,
    invitedBy: invitedBy ?? this.invitedBy,
    status: status ?? this.status,
    expiresAt: expiresAt ?? this.expiresAt,
    createdAt: createdAt ?? this.createdAt,
    resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
  );
  FamilyInvitationEntity copyWithCompanion(
    FamilyInvitationEntriesCompanion data,
  ) {
    return FamilyInvitationEntity(
      id: data.id.present ? data.id.value : this.id,
      familyId: data.familyId.present ? data.familyId.value : this.familyId,
      code: data.code.present ? data.code.value : this.code,
      invitedBy: data.invitedBy.present ? data.invitedBy.value : this.invitedBy,
      status: data.status.present ? data.status.value : this.status,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      resolvedAt: data.resolvedAt.present
          ? data.resolvedAt.value
          : this.resolvedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FamilyInvitationEntity(')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('code: $code, ')
          ..write('invitedBy: $invitedBy, ')
          ..write('status: $status, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolvedAt: $resolvedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    familyId,
    code,
    invitedBy,
    status,
    expiresAt,
    createdAt,
    resolvedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FamilyInvitationEntity &&
          other.id == this.id &&
          other.familyId == this.familyId &&
          other.code == this.code &&
          other.invitedBy == this.invitedBy &&
          other.status == this.status &&
          other.expiresAt == this.expiresAt &&
          other.createdAt == this.createdAt &&
          other.resolvedAt == this.resolvedAt);
}

class FamilyInvitationEntriesCompanion
    extends UpdateCompanion<FamilyInvitationEntity> {
  final Value<String> id;
  final Value<String> familyId;
  final Value<String> code;
  final Value<String> invitedBy;
  final Value<String> status;
  final Value<DateTime> expiresAt;
  final Value<DateTime> createdAt;
  final Value<DateTime?> resolvedAt;
  final Value<int> rowid;
  const FamilyInvitationEntriesCompanion({
    this.id = const Value.absent(),
    this.familyId = const Value.absent(),
    this.code = const Value.absent(),
    this.invitedBy = const Value.absent(),
    this.status = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FamilyInvitationEntriesCompanion.insert({
    required String id,
    required String familyId,
    required String code,
    required String invitedBy,
    this.status = const Value.absent(),
    required DateTime expiresAt,
    required DateTime createdAt,
    this.resolvedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       familyId = Value(familyId),
       code = Value(code),
       invitedBy = Value(invitedBy),
       expiresAt = Value(expiresAt),
       createdAt = Value(createdAt);
  static Insertable<FamilyInvitationEntity> custom({
    Expression<String>? id,
    Expression<String>? familyId,
    Expression<String>? code,
    Expression<String>? invitedBy,
    Expression<String>? status,
    Expression<DateTime>? expiresAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? resolvedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (familyId != null) 'family_id': familyId,
      if (code != null) 'code': code,
      if (invitedBy != null) 'invited_by': invitedBy,
      if (status != null) 'status': status,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (createdAt != null) 'created_at': createdAt,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FamilyInvitationEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? familyId,
    Value<String>? code,
    Value<String>? invitedBy,
    Value<String>? status,
    Value<DateTime>? expiresAt,
    Value<DateTime>? createdAt,
    Value<DateTime?>? resolvedAt,
    Value<int>? rowid,
  }) {
    return FamilyInvitationEntriesCompanion(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      code: code ?? this.code,
      invitedBy: invitedBy ?? this.invitedBy,
      status: status ?? this.status,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (familyId.present) {
      map['family_id'] = Variable<String>(familyId.value);
    }
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (invitedBy.present) {
      map['invited_by'] = Variable<String>(invitedBy.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FamilyInvitationEntriesCompanion(')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('code: $code, ')
          ..write('invitedBy: $invitedBy, ')
          ..write('status: $status, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FamilyOperationLogEntriesTable extends FamilyOperationLogEntries
    with TableInfo<$FamilyOperationLogEntriesTable, FamilyOperationLogEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FamilyOperationLogEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _familyIdMeta = const VerificationMeta(
    'familyId',
  );
  @override
  late final GeneratedColumn<String> familyId = GeneratedColumn<String>(
    'family_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES families (id)',
    ),
  );
  static const VerificationMeta _actorUserIdMeta = const VerificationMeta(
    'actorUserId',
  );
  @override
  late final GeneratedColumn<String> actorUserId = GeneratedColumn<String>(
    'actor_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actionMeta = const VerificationMeta('action');
  @override
  late final GeneratedColumn<String> action = GeneratedColumn<String>(
    'action',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    familyId,
    actorUserId,
    entityType,
    entityId,
    action,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'family_operation_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<FamilyOperationLogEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('family_id')) {
      context.handle(
        _familyIdMeta,
        familyId.isAcceptableOrUnknown(data['family_id']!, _familyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_familyIdMeta);
    }
    if (data.containsKey('actor_user_id')) {
      context.handle(
        _actorUserIdMeta,
        actorUserId.isAcceptableOrUnknown(
          data['actor_user_id']!,
          _actorUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_actorUserIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('action')) {
      context.handle(
        _actionMeta,
        action.isAcceptableOrUnknown(data['action']!, _actionMeta),
      );
    } else if (isInserting) {
      context.missing(_actionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FamilyOperationLogEntity map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FamilyOperationLogEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      familyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family_id'],
      )!,
      actorUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_user_id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      action: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FamilyOperationLogEntriesTable createAlias(String alias) {
    return $FamilyOperationLogEntriesTable(attachedDatabase, alias);
  }
}

class FamilyOperationLogEntity extends DataClass
    implements Insertable<FamilyOperationLogEntity> {
  final String id;
  final String familyId;
  final String actorUserId;
  final String entityType;
  final String entityId;
  final String action;
  final DateTime createdAt;
  const FamilyOperationLogEntity({
    required this.id,
    required this.familyId,
    required this.actorUserId,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['family_id'] = Variable<String>(familyId);
    map['actor_user_id'] = Variable<String>(actorUserId);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['action'] = Variable<String>(action);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  FamilyOperationLogEntriesCompanion toCompanion(bool nullToAbsent) {
    return FamilyOperationLogEntriesCompanion(
      id: Value(id),
      familyId: Value(familyId),
      actorUserId: Value(actorUserId),
      entityType: Value(entityType),
      entityId: Value(entityId),
      action: Value(action),
      createdAt: Value(createdAt),
    );
  }

  factory FamilyOperationLogEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FamilyOperationLogEntity(
      id: serializer.fromJson<String>(json['id']),
      familyId: serializer.fromJson<String>(json['familyId']),
      actorUserId: serializer.fromJson<String>(json['actorUserId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      action: serializer.fromJson<String>(json['action']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'familyId': serializer.toJson<String>(familyId),
      'actorUserId': serializer.toJson<String>(actorUserId),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'action': serializer.toJson<String>(action),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  FamilyOperationLogEntity copyWith({
    String? id,
    String? familyId,
    String? actorUserId,
    String? entityType,
    String? entityId,
    String? action,
    DateTime? createdAt,
  }) => FamilyOperationLogEntity(
    id: id ?? this.id,
    familyId: familyId ?? this.familyId,
    actorUserId: actorUserId ?? this.actorUserId,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    action: action ?? this.action,
    createdAt: createdAt ?? this.createdAt,
  );
  FamilyOperationLogEntity copyWithCompanion(
    FamilyOperationLogEntriesCompanion data,
  ) {
    return FamilyOperationLogEntity(
      id: data.id.present ? data.id.value : this.id,
      familyId: data.familyId.present ? data.familyId.value : this.familyId,
      actorUserId: data.actorUserId.present
          ? data.actorUserId.value
          : this.actorUserId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      action: data.action.present ? data.action.value : this.action,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FamilyOperationLogEntity(')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('actorUserId: $actorUserId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('action: $action, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    familyId,
    actorUserId,
    entityType,
    entityId,
    action,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FamilyOperationLogEntity &&
          other.id == this.id &&
          other.familyId == this.familyId &&
          other.actorUserId == this.actorUserId &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.action == this.action &&
          other.createdAt == this.createdAt);
}

class FamilyOperationLogEntriesCompanion
    extends UpdateCompanion<FamilyOperationLogEntity> {
  final Value<String> id;
  final Value<String> familyId;
  final Value<String> actorUserId;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> action;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const FamilyOperationLogEntriesCompanion({
    this.id = const Value.absent(),
    this.familyId = const Value.absent(),
    this.actorUserId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.action = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FamilyOperationLogEntriesCompanion.insert({
    required String id,
    required String familyId,
    required String actorUserId,
    required String entityType,
    required String entityId,
    required String action,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       familyId = Value(familyId),
       actorUserId = Value(actorUserId),
       entityType = Value(entityType),
       entityId = Value(entityId),
       action = Value(action),
       createdAt = Value(createdAt);
  static Insertable<FamilyOperationLogEntity> custom({
    Expression<String>? id,
    Expression<String>? familyId,
    Expression<String>? actorUserId,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? action,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (familyId != null) 'family_id': familyId,
      if (actorUserId != null) 'actor_user_id': actorUserId,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (action != null) 'action': action,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FamilyOperationLogEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? familyId,
    Value<String>? actorUserId,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? action,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return FamilyOperationLogEntriesCompanion(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      actorUserId: actorUserId ?? this.actorUserId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      action: action ?? this.action,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (familyId.present) {
      map['family_id'] = Variable<String>(familyId.value);
    }
    if (actorUserId.present) {
      map['actor_user_id'] = Variable<String>(actorUserId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (action.present) {
      map['action'] = Variable<String>(action.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FamilyOperationLogEntriesCompanion(')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('actorUserId: $actorUserId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('action: $action, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FamilyBudgetEntriesTable extends FamilyBudgetEntries
    with TableInfo<$FamilyBudgetEntriesTable, FamilyBudgetEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FamilyBudgetEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES books (id)',
    ),
  );
  static const VerificationMeta _monthKeyMeta = const VerificationMeta(
    'monthKey',
  );
  @override
  late final GeneratedColumn<String> monthKey = GeneratedColumn<String>(
    'month_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id)',
    ),
  );
  static const VerificationMeta _amountInCentsMeta = const VerificationMeta(
    'amountInCents',
  );
  @override
  late final GeneratedColumn<int> amountInCents = GeneratedColumn<int>(
    'amount_in_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _visibilityMeta = const VerificationMeta(
    'visibility',
  );
  @override
  late final GeneratedColumn<String> visibility = GeneratedColumn<String>(
    'visibility',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('shared'),
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta(
    'createdBy',
  );
  @override
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedByMeta = const VerificationMeta(
    'updatedBy',
  );
  @override
  late final GeneratedColumn<String> updatedBy = GeneratedColumn<String>(
    'updated_by',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    monthKey,
    categoryId,
    amountInCents,
    visibility,
    createdBy,
    updatedBy,
    version,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'family_budgets';
  @override
  VerificationContext validateIntegrity(
    Insertable<FamilyBudgetEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('month_key')) {
      context.handle(
        _monthKeyMeta,
        monthKey.isAcceptableOrUnknown(data['month_key']!, _monthKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_monthKeyMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('amount_in_cents')) {
      context.handle(
        _amountInCentsMeta,
        amountInCents.isAcceptableOrUnknown(
          data['amount_in_cents']!,
          _amountInCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountInCentsMeta);
    }
    if (data.containsKey('visibility')) {
      context.handle(
        _visibilityMeta,
        visibility.isAcceptableOrUnknown(data['visibility']!, _visibilityMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    } else if (isInserting) {
      context.missing(_createdByMeta);
    }
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedByMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {bookId, monthKey, categoryId},
  ];
  @override
  FamilyBudgetEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FamilyBudgetEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      monthKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}month_key'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      amountInCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_in_cents'],
      )!,
      visibility: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}visibility'],
      )!,
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      )!,
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_by'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $FamilyBudgetEntriesTable createAlias(String alias) {
    return $FamilyBudgetEntriesTable(attachedDatabase, alias);
  }
}

class FamilyBudgetEntity extends DataClass
    implements Insertable<FamilyBudgetEntity> {
  final String id;
  final String bookId;
  final String monthKey;
  final String? categoryId;
  final int amountInCents;
  final String visibility;
  final String createdBy;
  final String updatedBy;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  const FamilyBudgetEntity({
    required this.id,
    required this.bookId,
    required this.monthKey,
    this.categoryId,
    required this.amountInCents,
    required this.visibility,
    required this.createdBy,
    required this.updatedBy,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['month_key'] = Variable<String>(monthKey);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    map['amount_in_cents'] = Variable<int>(amountInCents);
    map['visibility'] = Variable<String>(visibility);
    map['created_by'] = Variable<String>(createdBy);
    map['updated_by'] = Variable<String>(updatedBy);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  FamilyBudgetEntriesCompanion toCompanion(bool nullToAbsent) {
    return FamilyBudgetEntriesCompanion(
      id: Value(id),
      bookId: Value(bookId),
      monthKey: Value(monthKey),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      amountInCents: Value(amountInCents),
      visibility: Value(visibility),
      createdBy: Value(createdBy),
      updatedBy: Value(updatedBy),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory FamilyBudgetEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FamilyBudgetEntity(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      monthKey: serializer.fromJson<String>(json['monthKey']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      amountInCents: serializer.fromJson<int>(json['amountInCents']),
      visibility: serializer.fromJson<String>(json['visibility']),
      createdBy: serializer.fromJson<String>(json['createdBy']),
      updatedBy: serializer.fromJson<String>(json['updatedBy']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'monthKey': serializer.toJson<String>(monthKey),
      'categoryId': serializer.toJson<String?>(categoryId),
      'amountInCents': serializer.toJson<int>(amountInCents),
      'visibility': serializer.toJson<String>(visibility),
      'createdBy': serializer.toJson<String>(createdBy),
      'updatedBy': serializer.toJson<String>(updatedBy),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  FamilyBudgetEntity copyWith({
    String? id,
    String? bookId,
    String? monthKey,
    Value<String?> categoryId = const Value.absent(),
    int? amountInCents,
    String? visibility,
    String? createdBy,
    String? updatedBy,
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => FamilyBudgetEntity(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    monthKey: monthKey ?? this.monthKey,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    amountInCents: amountInCents ?? this.amountInCents,
    visibility: visibility ?? this.visibility,
    createdBy: createdBy ?? this.createdBy,
    updatedBy: updatedBy ?? this.updatedBy,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  FamilyBudgetEntity copyWithCompanion(FamilyBudgetEntriesCompanion data) {
    return FamilyBudgetEntity(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      monthKey: data.monthKey.present ? data.monthKey.value : this.monthKey,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      amountInCents: data.amountInCents.present
          ? data.amountInCents.value
          : this.amountInCents,
      visibility: data.visibility.present
          ? data.visibility.value
          : this.visibility,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FamilyBudgetEntity(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('monthKey: $monthKey, ')
          ..write('categoryId: $categoryId, ')
          ..write('amountInCents: $amountInCents, ')
          ..write('visibility: $visibility, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    monthKey,
    categoryId,
    amountInCents,
    visibility,
    createdBy,
    updatedBy,
    version,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FamilyBudgetEntity &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.monthKey == this.monthKey &&
          other.categoryId == this.categoryId &&
          other.amountInCents == this.amountInCents &&
          other.visibility == this.visibility &&
          other.createdBy == this.createdBy &&
          other.updatedBy == this.updatedBy &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class FamilyBudgetEntriesCompanion extends UpdateCompanion<FamilyBudgetEntity> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> monthKey;
  final Value<String?> categoryId;
  final Value<int> amountInCents;
  final Value<String> visibility;
  final Value<String> createdBy;
  final Value<String> updatedBy;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const FamilyBudgetEntriesCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.monthKey = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.amountInCents = const Value.absent(),
    this.visibility = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FamilyBudgetEntriesCompanion.insert({
    required String id,
    required String bookId,
    required String monthKey,
    this.categoryId = const Value.absent(),
    required int amountInCents,
    this.visibility = const Value.absent(),
    required String createdBy,
    required String updatedBy,
    this.version = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       monthKey = Value(monthKey),
       amountInCents = Value(amountInCents),
       createdBy = Value(createdBy),
       updatedBy = Value(updatedBy),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<FamilyBudgetEntity> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? monthKey,
    Expression<String>? categoryId,
    Expression<int>? amountInCents,
    Expression<String>? visibility,
    Expression<String>? createdBy,
    Expression<String>? updatedBy,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (monthKey != null) 'month_key': monthKey,
      if (categoryId != null) 'category_id': categoryId,
      if (amountInCents != null) 'amount_in_cents': amountInCents,
      if (visibility != null) 'visibility': visibility,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FamilyBudgetEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String>? monthKey,
    Value<String?>? categoryId,
    Value<int>? amountInCents,
    Value<String>? visibility,
    Value<String>? createdBy,
    Value<String>? updatedBy,
    Value<int>? version,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return FamilyBudgetEntriesCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      monthKey: monthKey ?? this.monthKey,
      categoryId: categoryId ?? this.categoryId,
      amountInCents: amountInCents ?? this.amountInCents,
      visibility: visibility ?? this.visibility,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (monthKey.present) {
      map['month_key'] = Variable<String>(monthKey.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (amountInCents.present) {
      map['amount_in_cents'] = Variable<int>(amountInCents.value);
    }
    if (visibility.present) {
      map['visibility'] = Variable<String>(visibility.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<String>(updatedBy.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FamilyBudgetEntriesCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('monthKey: $monthKey, ')
          ..write('categoryId: $categoryId, ')
          ..write('amountInCents: $amountInCents, ')
          ..write('visibility: $visibility, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AdEventEntriesTable extends AdEventEntries
    with TableInfo<$AdEventEntriesTable, AdEventEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AdEventEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _placementIdMeta = const VerificationMeta(
    'placementId',
  );
  @override
  late final GeneratedColumn<String> placementId = GeneratedColumn<String>(
    'placement_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
    'event_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerMeta = const VerificationMeta(
    'provider',
  );
  @override
  late final GeneratedColumn<String> provider = GeneratedColumn<String>(
    'provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _metadataJsonMeta = const VerificationMeta(
    'metadataJson',
  );
  @override
  late final GeneratedColumn<String> metadataJson = GeneratedColumn<String>(
    'metadata_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    placementId,
    eventType,
    provider,
    sessionId,
    occurredAt,
    metadataJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ad_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<AdEventEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('placement_id')) {
      context.handle(
        _placementIdMeta,
        placementId.isAcceptableOrUnknown(
          data['placement_id']!,
          _placementIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_placementIdMeta);
    }
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('provider')) {
      context.handle(
        _providerMeta,
        provider.isAcceptableOrUnknown(data['provider']!, _providerMeta),
      );
    } else if (isInserting) {
      context.missing(_providerMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('metadata_json')) {
      context.handle(
        _metadataJsonMeta,
        metadataJson.isAcceptableOrUnknown(
          data['metadata_json']!,
          _metadataJsonMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AdEventEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AdEventEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      placementId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}placement_id'],
      )!,
      eventType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_type'],
      )!,
      provider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      metadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata_json'],
      ),
    );
  }

  @override
  $AdEventEntriesTable createAlias(String alias) {
    return $AdEventEntriesTable(attachedDatabase, alias);
  }
}

class AdEventEntity extends DataClass implements Insertable<AdEventEntity> {
  final String id;
  final String placementId;
  final String eventType;
  final String provider;
  final String? sessionId;
  final DateTime occurredAt;
  final String? metadataJson;
  const AdEventEntity({
    required this.id,
    required this.placementId,
    required this.eventType,
    required this.provider,
    this.sessionId,
    required this.occurredAt,
    this.metadataJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['placement_id'] = Variable<String>(placementId);
    map['event_type'] = Variable<String>(eventType);
    map['provider'] = Variable<String>(provider);
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<String>(sessionId);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    if (!nullToAbsent || metadataJson != null) {
      map['metadata_json'] = Variable<String>(metadataJson);
    }
    return map;
  }

  AdEventEntriesCompanion toCompanion(bool nullToAbsent) {
    return AdEventEntriesCompanion(
      id: Value(id),
      placementId: Value(placementId),
      eventType: Value(eventType),
      provider: Value(provider),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      occurredAt: Value(occurredAt),
      metadataJson: metadataJson == null && nullToAbsent
          ? const Value.absent()
          : Value(metadataJson),
    );
  }

  factory AdEventEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AdEventEntity(
      id: serializer.fromJson<String>(json['id']),
      placementId: serializer.fromJson<String>(json['placementId']),
      eventType: serializer.fromJson<String>(json['eventType']),
      provider: serializer.fromJson<String>(json['provider']),
      sessionId: serializer.fromJson<String?>(json['sessionId']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      metadataJson: serializer.fromJson<String?>(json['metadataJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'placementId': serializer.toJson<String>(placementId),
      'eventType': serializer.toJson<String>(eventType),
      'provider': serializer.toJson<String>(provider),
      'sessionId': serializer.toJson<String?>(sessionId),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'metadataJson': serializer.toJson<String?>(metadataJson),
    };
  }

  AdEventEntity copyWith({
    String? id,
    String? placementId,
    String? eventType,
    String? provider,
    Value<String?> sessionId = const Value.absent(),
    DateTime? occurredAt,
    Value<String?> metadataJson = const Value.absent(),
  }) => AdEventEntity(
    id: id ?? this.id,
    placementId: placementId ?? this.placementId,
    eventType: eventType ?? this.eventType,
    provider: provider ?? this.provider,
    sessionId: sessionId.present ? sessionId.value : this.sessionId,
    occurredAt: occurredAt ?? this.occurredAt,
    metadataJson: metadataJson.present ? metadataJson.value : this.metadataJson,
  );
  AdEventEntity copyWithCompanion(AdEventEntriesCompanion data) {
    return AdEventEntity(
      id: data.id.present ? data.id.value : this.id,
      placementId: data.placementId.present
          ? data.placementId.value
          : this.placementId,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      provider: data.provider.present ? data.provider.value : this.provider,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AdEventEntity(')
          ..write('id: $id, ')
          ..write('placementId: $placementId, ')
          ..write('eventType: $eventType, ')
          ..write('provider: $provider, ')
          ..write('sessionId: $sessionId, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('metadataJson: $metadataJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    placementId,
    eventType,
    provider,
    sessionId,
    occurredAt,
    metadataJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AdEventEntity &&
          other.id == this.id &&
          other.placementId == this.placementId &&
          other.eventType == this.eventType &&
          other.provider == this.provider &&
          other.sessionId == this.sessionId &&
          other.occurredAt == this.occurredAt &&
          other.metadataJson == this.metadataJson);
}

class AdEventEntriesCompanion extends UpdateCompanion<AdEventEntity> {
  final Value<String> id;
  final Value<String> placementId;
  final Value<String> eventType;
  final Value<String> provider;
  final Value<String?> sessionId;
  final Value<DateTime> occurredAt;
  final Value<String?> metadataJson;
  final Value<int> rowid;
  const AdEventEntriesCompanion({
    this.id = const Value.absent(),
    this.placementId = const Value.absent(),
    this.eventType = const Value.absent(),
    this.provider = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.metadataJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AdEventEntriesCompanion.insert({
    required String id,
    required String placementId,
    required String eventType,
    required String provider,
    this.sessionId = const Value.absent(),
    required DateTime occurredAt,
    this.metadataJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       placementId = Value(placementId),
       eventType = Value(eventType),
       provider = Value(provider),
       occurredAt = Value(occurredAt);
  static Insertable<AdEventEntity> custom({
    Expression<String>? id,
    Expression<String>? placementId,
    Expression<String>? eventType,
    Expression<String>? provider,
    Expression<String>? sessionId,
    Expression<DateTime>? occurredAt,
    Expression<String>? metadataJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (placementId != null) 'placement_id': placementId,
      if (eventType != null) 'event_type': eventType,
      if (provider != null) 'provider': provider,
      if (sessionId != null) 'session_id': sessionId,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (metadataJson != null) 'metadata_json': metadataJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AdEventEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? placementId,
    Value<String>? eventType,
    Value<String>? provider,
    Value<String?>? sessionId,
    Value<DateTime>? occurredAt,
    Value<String?>? metadataJson,
    Value<int>? rowid,
  }) {
    return AdEventEntriesCompanion(
      id: id ?? this.id,
      placementId: placementId ?? this.placementId,
      eventType: eventType ?? this.eventType,
      provider: provider ?? this.provider,
      sessionId: sessionId ?? this.sessionId,
      occurredAt: occurredAt ?? this.occurredAt,
      metadataJson: metadataJson ?? this.metadataJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (placementId.present) {
      map['placement_id'] = Variable<String>(placementId.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (provider.present) {
      map['provider'] = Variable<String>(provider.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (metadataJson.present) {
      map['metadata_json'] = Variable<String>(metadataJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AdEventEntriesCompanion(')
          ..write('id: $id, ')
          ..write('placementId: $placementId, ')
          ..write('eventType: $eventType, ')
          ..write('provider: $provider, ')
          ..write('sessionId: $sessionId, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('metadataJson: $metadataJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransactionAttachmentEntriesTable extends TransactionAttachmentEntries
    with
        TableInfo<
          $TransactionAttachmentEntriesTable,
          TransactionAttachmentEntity
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionAttachmentEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bookIdMeta = const VerificationMeta('bookId');
  @override
  late final GeneratedColumn<String> bookId = GeneratedColumn<String>(
    'book_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transactionIdMeta = const VerificationMeta(
    'transactionId',
  );
  @override
  late final GeneratedColumn<String> transactionId = GeneratedColumn<String>(
    'transaction_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES transactions (id)',
    ),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('application/octet-stream'),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sizeInBytesMeta = const VerificationMeta(
    'sizeInBytes',
  );
  @override
  late final GeneratedColumn<int> sizeInBytes = GeneratedColumn<int>(
    'size_in_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _checksumMeta = const VerificationMeta(
    'checksum',
  );
  @override
  late final GeneratedColumn<String> checksum = GeneratedColumn<String>(
    'checksum',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    bookId,
    transactionId,
    path,
    name,
    mimeType,
    sortOrder,
    sizeInBytes,
    checksum,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transaction_attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<TransactionAttachmentEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('book_id')) {
      context.handle(
        _bookIdMeta,
        bookId.isAcceptableOrUnknown(data['book_id']!, _bookIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bookIdMeta);
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
        _transactionIdMeta,
        transactionId.isAcceptableOrUnknown(
          data['transaction_id']!,
          _transactionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionIdMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('size_in_bytes')) {
      context.handle(
        _sizeInBytesMeta,
        sizeInBytes.isAcceptableOrUnknown(
          data['size_in_bytes']!,
          _sizeInBytesMeta,
        ),
      );
    }
    if (data.containsKey('checksum')) {
      context.handle(
        _checksumMeta,
        checksum.isAcceptableOrUnknown(data['checksum']!, _checksumMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TransactionAttachmentEntity map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransactionAttachmentEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      bookId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}book_id'],
      )!,
      transactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transaction_id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      sizeInBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_in_bytes'],
      ),
      checksum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checksum'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $TransactionAttachmentEntriesTable createAlias(String alias) {
    return $TransactionAttachmentEntriesTable(attachedDatabase, alias);
  }
}

class TransactionAttachmentEntity extends DataClass
    implements Insertable<TransactionAttachmentEntity> {
  final String id;
  final String bookId;
  final String transactionId;
  final String path;
  final String name;
  final String mimeType;
  final int sortOrder;
  final int? sizeInBytes;
  final String? checksum;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const TransactionAttachmentEntity({
    required this.id,
    required this.bookId,
    required this.transactionId,
    required this.path,
    required this.name,
    required this.mimeType,
    required this.sortOrder,
    this.sizeInBytes,
    this.checksum,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['book_id'] = Variable<String>(bookId);
    map['transaction_id'] = Variable<String>(transactionId);
    map['path'] = Variable<String>(path);
    map['name'] = Variable<String>(name);
    map['mime_type'] = Variable<String>(mimeType);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || sizeInBytes != null) {
      map['size_in_bytes'] = Variable<int>(sizeInBytes);
    }
    if (!nullToAbsent || checksum != null) {
      map['checksum'] = Variable<String>(checksum);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  TransactionAttachmentEntriesCompanion toCompanion(bool nullToAbsent) {
    return TransactionAttachmentEntriesCompanion(
      id: Value(id),
      bookId: Value(bookId),
      transactionId: Value(transactionId),
      path: Value(path),
      name: Value(name),
      mimeType: Value(mimeType),
      sortOrder: Value(sortOrder),
      sizeInBytes: sizeInBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeInBytes),
      checksum: checksum == null && nullToAbsent
          ? const Value.absent()
          : Value(checksum),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory TransactionAttachmentEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransactionAttachmentEntity(
      id: serializer.fromJson<String>(json['id']),
      bookId: serializer.fromJson<String>(json['bookId']),
      transactionId: serializer.fromJson<String>(json['transactionId']),
      path: serializer.fromJson<String>(json['path']),
      name: serializer.fromJson<String>(json['name']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      sizeInBytes: serializer.fromJson<int?>(json['sizeInBytes']),
      checksum: serializer.fromJson<String?>(json['checksum']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bookId': serializer.toJson<String>(bookId),
      'transactionId': serializer.toJson<String>(transactionId),
      'path': serializer.toJson<String>(path),
      'name': serializer.toJson<String>(name),
      'mimeType': serializer.toJson<String>(mimeType),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'sizeInBytes': serializer.toJson<int?>(sizeInBytes),
      'checksum': serializer.toJson<String?>(checksum),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  TransactionAttachmentEntity copyWith({
    String? id,
    String? bookId,
    String? transactionId,
    String? path,
    String? name,
    String? mimeType,
    int? sortOrder,
    Value<int?> sizeInBytes = const Value.absent(),
    Value<String?> checksum = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => TransactionAttachmentEntity(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    transactionId: transactionId ?? this.transactionId,
    path: path ?? this.path,
    name: name ?? this.name,
    mimeType: mimeType ?? this.mimeType,
    sortOrder: sortOrder ?? this.sortOrder,
    sizeInBytes: sizeInBytes.present ? sizeInBytes.value : this.sizeInBytes,
    checksum: checksum.present ? checksum.value : this.checksum,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  TransactionAttachmentEntity copyWithCompanion(
    TransactionAttachmentEntriesCompanion data,
  ) {
    return TransactionAttachmentEntity(
      id: data.id.present ? data.id.value : this.id,
      bookId: data.bookId.present ? data.bookId.value : this.bookId,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      path: data.path.present ? data.path.value : this.path,
      name: data.name.present ? data.name.value : this.name,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      sizeInBytes: data.sizeInBytes.present
          ? data.sizeInBytes.value
          : this.sizeInBytes,
      checksum: data.checksum.present ? data.checksum.value : this.checksum,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransactionAttachmentEntity(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('transactionId: $transactionId, ')
          ..write('path: $path, ')
          ..write('name: $name, ')
          ..write('mimeType: $mimeType, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('sizeInBytes: $sizeInBytes, ')
          ..write('checksum: $checksum, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    bookId,
    transactionId,
    path,
    name,
    mimeType,
    sortOrder,
    sizeInBytes,
    checksum,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransactionAttachmentEntity &&
          other.id == this.id &&
          other.bookId == this.bookId &&
          other.transactionId == this.transactionId &&
          other.path == this.path &&
          other.name == this.name &&
          other.mimeType == this.mimeType &&
          other.sortOrder == this.sortOrder &&
          other.sizeInBytes == this.sizeInBytes &&
          other.checksum == this.checksum &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class TransactionAttachmentEntriesCompanion
    extends UpdateCompanion<TransactionAttachmentEntity> {
  final Value<String> id;
  final Value<String> bookId;
  final Value<String> transactionId;
  final Value<String> path;
  final Value<String> name;
  final Value<String> mimeType;
  final Value<int> sortOrder;
  final Value<int?> sizeInBytes;
  final Value<String?> checksum;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const TransactionAttachmentEntriesCompanion({
    this.id = const Value.absent(),
    this.bookId = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.path = const Value.absent(),
    this.name = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.sizeInBytes = const Value.absent(),
    this.checksum = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionAttachmentEntriesCompanion.insert({
    required String id,
    required String bookId,
    required String transactionId,
    required String path,
    required String name,
    this.mimeType = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.sizeInBytes = const Value.absent(),
    this.checksum = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bookId = Value(bookId),
       transactionId = Value(transactionId),
       path = Value(path),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TransactionAttachmentEntity> custom({
    Expression<String>? id,
    Expression<String>? bookId,
    Expression<String>? transactionId,
    Expression<String>? path,
    Expression<String>? name,
    Expression<String>? mimeType,
    Expression<int>? sortOrder,
    Expression<int>? sizeInBytes,
    Expression<String>? checksum,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bookId != null) 'book_id': bookId,
      if (transactionId != null) 'transaction_id': transactionId,
      if (path != null) 'path': path,
      if (name != null) 'name': name,
      if (mimeType != null) 'mime_type': mimeType,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (sizeInBytes != null) 'size_in_bytes': sizeInBytes,
      if (checksum != null) 'checksum': checksum,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionAttachmentEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? bookId,
    Value<String>? transactionId,
    Value<String>? path,
    Value<String>? name,
    Value<String>? mimeType,
    Value<int>? sortOrder,
    Value<int?>? sizeInBytes,
    Value<String?>? checksum,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return TransactionAttachmentEntriesCompanion(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      transactionId: transactionId ?? this.transactionId,
      path: path ?? this.path,
      name: name ?? this.name,
      mimeType: mimeType ?? this.mimeType,
      sortOrder: sortOrder ?? this.sortOrder,
      sizeInBytes: sizeInBytes ?? this.sizeInBytes,
      checksum: checksum ?? this.checksum,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bookId.present) {
      map['book_id'] = Variable<String>(bookId.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<String>(transactionId.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (sizeInBytes.present) {
      map['size_in_bytes'] = Variable<int>(sizeInBytes.value);
    }
    if (checksum.present) {
      map['checksum'] = Variable<String>(checksum.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionAttachmentEntriesCompanion(')
          ..write('id: $id, ')
          ..write('bookId: $bookId, ')
          ..write('transactionId: $transactionId, ')
          ..write('path: $path, ')
          ..write('name: $name, ')
          ..write('mimeType: $mimeType, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('sizeInBytes: $sizeInBytes, ')
          ..write('checksum: $checksum, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AccountEntriesTable accountEntries = $AccountEntriesTable(this);
  late final $CategoryEntriesTable categoryEntries = $CategoryEntriesTable(
    this,
  );
  late final $TransactionEntriesTable transactionEntries =
      $TransactionEntriesTable(this);
  late final $GoalEntriesTable goalEntries = $GoalEntriesTable(this);
  late final $GoalMilestoneEntriesTable goalMilestoneEntries =
      $GoalMilestoneEntriesTable(this);
  late final $GoalContributionEntriesTable goalContributionEntries =
      $GoalContributionEntriesTable(this);
  late final $AppSettingEntriesTable appSettingEntries =
      $AppSettingEntriesTable(this);
  late final $BudgetEntriesTable budgetEntries = $BudgetEntriesTable(this);
  late final $RecurringBillEntriesTable recurringBillEntries =
      $RecurringBillEntriesTable(this);
  late final $InstallmentPlanEntriesTable installmentPlanEntries =
      $InstallmentPlanEntriesTable(this);
  late final $MerchantRuleEntriesTable merchantRuleEntries =
      $MerchantRuleEntriesTable(this);
  late final $EconomicEventEntriesTable economicEventEntries =
      $EconomicEventEntriesTable(this);
  late final $EconomicEventRecordEntriesTable economicEventRecordEntries =
      $EconomicEventRecordEntriesTable(this);
  late final $InboxItemEntriesTable inboxItemEntries = $InboxItemEntriesTable(
    this,
  );
  late final $FamilyEntriesTable familyEntries = $FamilyEntriesTable(this);
  late final $BookEntriesTable bookEntries = $BookEntriesTable(this);
  late final $FamilyMemberEntriesTable familyMemberEntries =
      $FamilyMemberEntriesTable(this);
  late final $FamilyInvitationEntriesTable familyInvitationEntries =
      $FamilyInvitationEntriesTable(this);
  late final $FamilyOperationLogEntriesTable familyOperationLogEntries =
      $FamilyOperationLogEntriesTable(this);
  late final $FamilyBudgetEntriesTable familyBudgetEntries =
      $FamilyBudgetEntriesTable(this);
  late final $AdEventEntriesTable adEventEntries = $AdEventEntriesTable(this);
  late final $TransactionAttachmentEntriesTable transactionAttachmentEntries =
      $TransactionAttachmentEntriesTable(this);
  late final AccountDao accountDao = AccountDao(this as AppDatabase);
  late final CategoryDao categoryDao = CategoryDao(this as AppDatabase);
  late final TransactionDao transactionDao = TransactionDao(
    this as AppDatabase,
  );
  late final GoalDao goalDao = GoalDao(this as AppDatabase);
  late final AppSettingsDao appSettingsDao = AppSettingsDao(
    this as AppDatabase,
  );
  late final BudgetDao budgetDao = BudgetDao(this as AppDatabase);
  late final RecurringBillDao recurringBillDao = RecurringBillDao(
    this as AppDatabase,
  );
  late final InstallmentPlanDao installmentPlanDao = InstallmentPlanDao(
    this as AppDatabase,
  );
  late final IntelligenceDao intelligenceDao = IntelligenceDao(
    this as AppDatabase,
  );
  late final FamilyDao familyDao = FamilyDao(this as AppDatabase);
  late final AdEventDao adEventDao = AdEventDao(this as AppDatabase);
  late final TransactionAttachmentDao transactionAttachmentDao =
      TransactionAttachmentDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    accountEntries,
    categoryEntries,
    transactionEntries,
    goalEntries,
    goalMilestoneEntries,
    goalContributionEntries,
    appSettingEntries,
    budgetEntries,
    recurringBillEntries,
    installmentPlanEntries,
    merchantRuleEntries,
    economicEventEntries,
    economicEventRecordEntries,
    inboxItemEntries,
    familyEntries,
    bookEntries,
    familyMemberEntries,
    familyInvitationEntries,
    familyOperationLogEntries,
    familyBudgetEntries,
    adEventEntries,
    transactionAttachmentEntries,
  ];
}

typedef $$AccountEntriesTableCreateCompanionBuilder =
    AccountEntriesCompanion Function({
      required String id,
      Value<String> bookId,
      Value<int> openingBalanceInCents,
      required String name,
      required String type,
      Value<int> balanceInCents,
      Value<String> currency,
      Value<String> assetForm,
      Value<String?> identifierSuffix,
      required String icon,
      required int color,
      Value<int> sortOrder,
      Value<bool> isArchived,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$AccountEntriesTableUpdateCompanionBuilder =
    AccountEntriesCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<int> openingBalanceInCents,
      Value<String> name,
      Value<String> type,
      Value<int> balanceInCents,
      Value<String> currency,
      Value<String> assetForm,
      Value<String?> identifierSuffix,
      Value<String> icon,
      Value<int> color,
      Value<int> sortOrder,
      Value<bool> isArchived,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$AccountEntriesTableReferences
    extends BaseReferences<_$AppDatabase, $AccountEntriesTable, AccountEntity> {
  $$AccountEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$TransactionEntriesTable, List<TransactionEntity>>
  _sourceTransactionsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactionEntries,
    aliasName: 'accounts__id__transactions__account_id',
  );

  $$TransactionEntriesTableProcessedTableManager get sourceTransactions {
    final manager = $$TransactionEntriesTableTableManager(
      $_db,
      $_db.transactionEntries,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_sourceTransactionsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TransactionEntriesTable, List<TransactionEntity>>
  _destinationTransactionsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.transactionEntries,
        aliasName: 'accounts__id__transactions__destination_account_id',
      );

  $$TransactionEntriesTableProcessedTableManager get destinationTransactions {
    final manager =
        $$TransactionEntriesTableTableManager(
          $_db,
          $_db.transactionEntries,
        ).filter(
          (f) =>
              f.destinationAccountId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _destinationTransactionsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AccountEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $AccountEntriesTable> {
  $$AccountEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get openingBalanceInCents => $composableBuilder(
    column: $table.openingBalanceInCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get balanceInCents => $composableBuilder(
    column: $table.balanceInCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetForm => $composableBuilder(
    column: $table.assetForm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get identifierSuffix => $composableBuilder(
    column: $table.identifierSuffix,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> sourceTransactions(
    Expression<bool> Function($$TransactionEntriesTableFilterComposer f) f,
  ) {
    final $$TransactionEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactionEntries,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionEntriesTableFilterComposer(
            $db: $db,
            $table: $db.transactionEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> destinationTransactions(
    Expression<bool> Function($$TransactionEntriesTableFilterComposer f) f,
  ) {
    final $$TransactionEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactionEntries,
      getReferencedColumn: (t) => t.destinationAccountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionEntriesTableFilterComposer(
            $db: $db,
            $table: $db.transactionEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountEntriesTable> {
  $$AccountEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get openingBalanceInCents => $composableBuilder(
    column: $table.openingBalanceInCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get balanceInCents => $composableBuilder(
    column: $table.balanceInCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetForm => $composableBuilder(
    column: $table.assetForm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get identifierSuffix => $composableBuilder(
    column: $table.identifierSuffix,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountEntriesTable> {
  $$AccountEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get openingBalanceInCents => $composableBuilder(
    column: $table.openingBalanceInCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get balanceInCents => $composableBuilder(
    column: $table.balanceInCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get assetForm =>
      $composableBuilder(column: $table.assetForm, builder: (column) => column);

  GeneratedColumn<String> get identifierSuffix => $composableBuilder(
    column: $table.identifierSuffix,
    builder: (column) => column,
  );

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> sourceTransactions<T extends Object>(
    Expression<T> Function($$TransactionEntriesTableAnnotationComposer a) f,
  ) {
    final $$TransactionEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.transactionEntries,
          getReferencedColumn: (t) => t.accountId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TransactionEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.transactionEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> destinationTransactions<T extends Object>(
    Expression<T> Function($$TransactionEntriesTableAnnotationComposer a) f,
  ) {
    final $$TransactionEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.transactionEntries,
          getReferencedColumn: (t) => t.destinationAccountId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TransactionEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.transactionEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$AccountEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AccountEntriesTable,
          AccountEntity,
          $$AccountEntriesTableFilterComposer,
          $$AccountEntriesTableOrderingComposer,
          $$AccountEntriesTableAnnotationComposer,
          $$AccountEntriesTableCreateCompanionBuilder,
          $$AccountEntriesTableUpdateCompanionBuilder,
          (AccountEntity, $$AccountEntriesTableReferences),
          AccountEntity,
          PrefetchHooks Function({
            bool sourceTransactions,
            bool destinationTransactions,
          })
        > {
  $$AccountEntriesTableTableManager(
    _$AppDatabase db,
    $AccountEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<int> openingBalanceInCents = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> balanceInCents = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> assetForm = const Value.absent(),
                Value<String?> identifierSuffix = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<int> color = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountEntriesCompanion(
                id: id,
                bookId: bookId,
                openingBalanceInCents: openingBalanceInCents,
                name: name,
                type: type,
                balanceInCents: balanceInCents,
                currency: currency,
                assetForm: assetForm,
                identifierSuffix: identifierSuffix,
                icon: icon,
                color: color,
                sortOrder: sortOrder,
                isArchived: isArchived,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> bookId = const Value.absent(),
                Value<int> openingBalanceInCents = const Value.absent(),
                required String name,
                required String type,
                Value<int> balanceInCents = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> assetForm = const Value.absent(),
                Value<String?> identifierSuffix = const Value.absent(),
                required String icon,
                required int color,
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AccountEntriesCompanion.insert(
                id: id,
                bookId: bookId,
                openingBalanceInCents: openingBalanceInCents,
                name: name,
                type: type,
                balanceInCents: balanceInCents,
                currency: currency,
                assetForm: assetForm,
                identifierSuffix: identifierSuffix,
                icon: icon,
                color: color,
                sortOrder: sortOrder,
                isArchived: isArchived,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$AccountEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({sourceTransactions = false, destinationTransactions = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (sourceTransactions) db.transactionEntries,
                    if (destinationTransactions) db.transactionEntries,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (sourceTransactions)
                        await $_getPrefetchedData<
                          AccountEntity,
                          $AccountEntriesTable,
                          TransactionEntity
                        >(
                          currentTable: table,
                          referencedTable: $$AccountEntriesTableReferences
                              ._sourceTransactionsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).sourceTransactions,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (destinationTransactions)
                        await $_getPrefetchedData<
                          AccountEntity,
                          $AccountEntriesTable,
                          TransactionEntity
                        >(
                          currentTable: table,
                          referencedTable: $$AccountEntriesTableReferences
                              ._destinationTransactionsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).destinationTransactions,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.destinationAccountId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$AccountEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AccountEntriesTable,
      AccountEntity,
      $$AccountEntriesTableFilterComposer,
      $$AccountEntriesTableOrderingComposer,
      $$AccountEntriesTableAnnotationComposer,
      $$AccountEntriesTableCreateCompanionBuilder,
      $$AccountEntriesTableUpdateCompanionBuilder,
      (AccountEntity, $$AccountEntriesTableReferences),
      AccountEntity,
      PrefetchHooks Function({
        bool sourceTransactions,
        bool destinationTransactions,
      })
    >;
typedef $$CategoryEntriesTableCreateCompanionBuilder =
    CategoryEntriesCompanion Function({
      required String id,
      Value<String> bookId,
      Value<String?> parentId,
      required String name,
      required String icon,
      required String type,
      Value<int> sortOrder,
      Value<bool> isDefault,
      Value<bool> isArchived,
      Value<int> rowid,
    });
typedef $$CategoryEntriesTableUpdateCompanionBuilder =
    CategoryEntriesCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String?> parentId,
      Value<String> name,
      Value<String> icon,
      Value<String> type,
      Value<int> sortOrder,
      Value<bool> isDefault,
      Value<bool> isArchived,
      Value<int> rowid,
    });

final class $$CategoryEntriesTableReferences
    extends
        BaseReferences<_$AppDatabase, $CategoryEntriesTable, CategoryEntity> {
  $$CategoryEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CategoryEntriesTable _parentIdTable(_$AppDatabase db) =>
      db.categoryEntries.createAlias('categories__parent_id__categories__id');

  $$CategoryEntriesTableProcessedTableManager? get parentId {
    final $_column = $_itemColumn<String>('parent_id');
    if ($_column == null) return null;
    final manager = $$CategoryEntriesTableTableManager(
      $_db,
      $_db.categoryEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TransactionEntriesTable, List<TransactionEntity>>
  _categoryTransactionsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactionEntries,
    aliasName: 'categories__id__transactions__category_id',
  );

  $$TransactionEntriesTableProcessedTableManager get categoryTransactions {
    final manager = $$TransactionEntriesTableTableManager(
      $_db,
      $_db.transactionEntries,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _categoryTransactionsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TransactionEntriesTable, List<TransactionEntity>>
  _subcategoryTransactionsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.transactionEntries,
        aliasName: 'categories__id__transactions__subcategory_id',
      );

  $$TransactionEntriesTableProcessedTableManager get subcategoryTransactions {
    final manager = $$TransactionEntriesTableTableManager(
      $_db,
      $_db.transactionEntries,
    ).filter((f) => f.subcategoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _subcategoryTransactionsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BudgetEntriesTable, List<BudgetEntity>>
  _budgetEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.budgetEntries,
    aliasName: 'categories__id__budgets__category_id',
  );

  $$BudgetEntriesTableProcessedTableManager get budgetEntriesRefs {
    final manager = $$BudgetEntriesTableTableManager(
      $_db,
      $_db.budgetEntries,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_budgetEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $MerchantRuleEntriesTable,
    List<MerchantRuleEntity>
  >
  _merchantRuleCategoryTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.merchantRuleEntries,
    aliasName: 'categories__id__merchant_rules__category_id',
  );

  $$MerchantRuleEntriesTableProcessedTableManager get merchantRuleCategory {
    final manager = $$MerchantRuleEntriesTableTableManager(
      $_db,
      $_db.merchantRuleEntries,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _merchantRuleCategoryTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $MerchantRuleEntriesTable,
    List<MerchantRuleEntity>
  >
  _merchantRuleSubcategoryTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.merchantRuleEntries,
        aliasName: 'categories__id__merchant_rules__subcategory_id',
      );

  $$MerchantRuleEntriesTableProcessedTableManager get merchantRuleSubcategory {
    final manager = $$MerchantRuleEntriesTableTableManager(
      $_db,
      $_db.merchantRuleEntries,
    ).filter((f) => f.subcategoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _merchantRuleSubcategoryTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $FamilyBudgetEntriesTable,
    List<FamilyBudgetEntity>
  >
  _familyBudgetEntriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.familyBudgetEntries,
        aliasName: 'categories__id__family_budgets__category_id',
      );

  $$FamilyBudgetEntriesTableProcessedTableManager get familyBudgetEntriesRefs {
    final manager = $$FamilyBudgetEntriesTableTableManager(
      $_db,
      $_db.familyBudgetEntries,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _familyBudgetEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CategoryEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoryEntriesTable> {
  $$CategoryEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoryEntriesTableFilterComposer get parentId {
    final $$CategoryEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.categoryEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryEntriesTableFilterComposer(
            $db: $db,
            $table: $db.categoryEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> categoryTransactions(
    Expression<bool> Function($$TransactionEntriesTableFilterComposer f) f,
  ) {
    final $$TransactionEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactionEntries,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionEntriesTableFilterComposer(
            $db: $db,
            $table: $db.transactionEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> subcategoryTransactions(
    Expression<bool> Function($$TransactionEntriesTableFilterComposer f) f,
  ) {
    final $$TransactionEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactionEntries,
      getReferencedColumn: (t) => t.subcategoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionEntriesTableFilterComposer(
            $db: $db,
            $table: $db.transactionEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> budgetEntriesRefs(
    Expression<bool> Function($$BudgetEntriesTableFilterComposer f) f,
  ) {
    final $$BudgetEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.budgetEntries,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BudgetEntriesTableFilterComposer(
            $db: $db,
            $table: $db.budgetEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> merchantRuleCategory(
    Expression<bool> Function($$MerchantRuleEntriesTableFilterComposer f) f,
  ) {
    final $$MerchantRuleEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.merchantRuleEntries,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MerchantRuleEntriesTableFilterComposer(
            $db: $db,
            $table: $db.merchantRuleEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> merchantRuleSubcategory(
    Expression<bool> Function($$MerchantRuleEntriesTableFilterComposer f) f,
  ) {
    final $$MerchantRuleEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.merchantRuleEntries,
      getReferencedColumn: (t) => t.subcategoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MerchantRuleEntriesTableFilterComposer(
            $db: $db,
            $table: $db.merchantRuleEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> familyBudgetEntriesRefs(
    Expression<bool> Function($$FamilyBudgetEntriesTableFilterComposer f) f,
  ) {
    final $$FamilyBudgetEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.familyBudgetEntries,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamilyBudgetEntriesTableFilterComposer(
            $db: $db,
            $table: $db.familyBudgetEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoryEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoryEntriesTable> {
  $$CategoryEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoryEntriesTableOrderingComposer get parentId {
    final $$CategoryEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.categoryEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.categoryEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CategoryEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoryEntriesTable> {
  $$CategoryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  $$CategoryEntriesTableAnnotationComposer get parentId {
    final $$CategoryEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentId,
      referencedTable: $db.categoryEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categoryEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> categoryTransactions<T extends Object>(
    Expression<T> Function($$TransactionEntriesTableAnnotationComposer a) f,
  ) {
    final $$TransactionEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.transactionEntries,
          getReferencedColumn: (t) => t.categoryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TransactionEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.transactionEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> subcategoryTransactions<T extends Object>(
    Expression<T> Function($$TransactionEntriesTableAnnotationComposer a) f,
  ) {
    final $$TransactionEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.transactionEntries,
          getReferencedColumn: (t) => t.subcategoryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TransactionEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.transactionEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> budgetEntriesRefs<T extends Object>(
    Expression<T> Function($$BudgetEntriesTableAnnotationComposer a) f,
  ) {
    final $$BudgetEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.budgetEntries,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BudgetEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.budgetEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> merchantRuleCategory<T extends Object>(
    Expression<T> Function($$MerchantRuleEntriesTableAnnotationComposer a) f,
  ) {
    final $$MerchantRuleEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.merchantRuleEntries,
          getReferencedColumn: (t) => t.categoryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MerchantRuleEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.merchantRuleEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> merchantRuleSubcategory<T extends Object>(
    Expression<T> Function($$MerchantRuleEntriesTableAnnotationComposer a) f,
  ) {
    final $$MerchantRuleEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.merchantRuleEntries,
          getReferencedColumn: (t) => t.subcategoryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$MerchantRuleEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.merchantRuleEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> familyBudgetEntriesRefs<T extends Object>(
    Expression<T> Function($$FamilyBudgetEntriesTableAnnotationComposer a) f,
  ) {
    final $$FamilyBudgetEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.familyBudgetEntries,
          getReferencedColumn: (t) => t.categoryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FamilyBudgetEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.familyBudgetEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CategoryEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoryEntriesTable,
          CategoryEntity,
          $$CategoryEntriesTableFilterComposer,
          $$CategoryEntriesTableOrderingComposer,
          $$CategoryEntriesTableAnnotationComposer,
          $$CategoryEntriesTableCreateCompanionBuilder,
          $$CategoryEntriesTableUpdateCompanionBuilder,
          (CategoryEntity, $$CategoryEntriesTableReferences),
          CategoryEntity,
          PrefetchHooks Function({
            bool parentId,
            bool categoryTransactions,
            bool subcategoryTransactions,
            bool budgetEntriesRefs,
            bool merchantRuleCategory,
            bool merchantRuleSubcategory,
            bool familyBudgetEntriesRefs,
          })
        > {
  $$CategoryEntriesTableTableManager(
    _$AppDatabase db,
    $CategoryEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoryEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoryEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoryEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoryEntriesCompanion(
                id: id,
                bookId: bookId,
                parentId: parentId,
                name: name,
                icon: icon,
                type: type,
                sortOrder: sortOrder,
                isDefault: isDefault,
                isArchived: isArchived,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> bookId = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                required String name,
                required String icon,
                required String type,
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoryEntriesCompanion.insert(
                id: id,
                bookId: bookId,
                parentId: parentId,
                name: name,
                icon: icon,
                type: type,
                sortOrder: sortOrder,
                isDefault: isDefault,
                isArchived: isArchived,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CategoryEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                parentId = false,
                categoryTransactions = false,
                subcategoryTransactions = false,
                budgetEntriesRefs = false,
                merchantRuleCategory = false,
                merchantRuleSubcategory = false,
                familyBudgetEntriesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (categoryTransactions) db.transactionEntries,
                    if (subcategoryTransactions) db.transactionEntries,
                    if (budgetEntriesRefs) db.budgetEntries,
                    if (merchantRuleCategory) db.merchantRuleEntries,
                    if (merchantRuleSubcategory) db.merchantRuleEntries,
                    if (familyBudgetEntriesRefs) db.familyBudgetEntries,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (parentId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.parentId,
                            referencedTable: $$CategoryEntriesTableReferences
                                ._parentIdTable(db),
                            referencedColumn: $$CategoryEntriesTableReferences
                                ._parentIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (categoryTransactions)
                        await $_getPrefetchedData<
                          CategoryEntity,
                          $CategoryEntriesTable,
                          TransactionEntity
                        >(
                          currentTable: table,
                          referencedTable: $$CategoryEntriesTableReferences
                              ._categoryTransactionsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoryEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).categoryTransactions,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (subcategoryTransactions)
                        await $_getPrefetchedData<
                          CategoryEntity,
                          $CategoryEntriesTable,
                          TransactionEntity
                        >(
                          currentTable: table,
                          referencedTable: $$CategoryEntriesTableReferences
                              ._subcategoryTransactionsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoryEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).subcategoryTransactions,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.subcategoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (budgetEntriesRefs)
                        await $_getPrefetchedData<
                          CategoryEntity,
                          $CategoryEntriesTable,
                          BudgetEntity
                        >(
                          currentTable: table,
                          referencedTable: $$CategoryEntriesTableReferences
                              ._budgetEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoryEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).budgetEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (merchantRuleCategory)
                        await $_getPrefetchedData<
                          CategoryEntity,
                          $CategoryEntriesTable,
                          MerchantRuleEntity
                        >(
                          currentTable: table,
                          referencedTable: $$CategoryEntriesTableReferences
                              ._merchantRuleCategoryTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoryEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).merchantRuleCategory,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (merchantRuleSubcategory)
                        await $_getPrefetchedData<
                          CategoryEntity,
                          $CategoryEntriesTable,
                          MerchantRuleEntity
                        >(
                          currentTable: table,
                          referencedTable: $$CategoryEntriesTableReferences
                              ._merchantRuleSubcategoryTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoryEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).merchantRuleSubcategory,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.subcategoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (familyBudgetEntriesRefs)
                        await $_getPrefetchedData<
                          CategoryEntity,
                          $CategoryEntriesTable,
                          FamilyBudgetEntity
                        >(
                          currentTable: table,
                          referencedTable: $$CategoryEntriesTableReferences
                              ._familyBudgetEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CategoryEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).familyBudgetEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.categoryId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CategoryEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoryEntriesTable,
      CategoryEntity,
      $$CategoryEntriesTableFilterComposer,
      $$CategoryEntriesTableOrderingComposer,
      $$CategoryEntriesTableAnnotationComposer,
      $$CategoryEntriesTableCreateCompanionBuilder,
      $$CategoryEntriesTableUpdateCompanionBuilder,
      (CategoryEntity, $$CategoryEntriesTableReferences),
      CategoryEntity,
      PrefetchHooks Function({
        bool parentId,
        bool categoryTransactions,
        bool subcategoryTransactions,
        bool budgetEntriesRefs,
        bool merchantRuleCategory,
        bool merchantRuleSubcategory,
        bool familyBudgetEntriesRefs,
      })
    >;
typedef $$TransactionEntriesTableCreateCompanionBuilder =
    TransactionEntriesCompanion Function({
      required String id,
      required String bookId,
      Value<String?> userId,
      required String type,
      required int amountInCents,
      Value<String> currency,
      Value<String?> categoryId,
      Value<String?> subcategoryId,
      required String accountId,
      Value<String?> destinationAccountId,
      Value<String?> merchant,
      Value<String?> note,
      required DateTime occurredAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<bool> isRecurring,
      Value<bool> isOneTime,
      Value<bool> isLargeTransaction,
      Value<bool> isPlanned,
      Value<String> source,
      Value<double?> aiConfidence,
      Value<bool> userCorrected,
      Value<String> syncStatus,
      Value<String?> deviceId,
      Value<String?> originalTransactionId,
      Value<String?> relatedTransactionId,
      Value<String> reimbursementStatus,
      Value<int?> reimbursementAmountInCents,
      Value<DateTime?> reimbursementDate,
      Value<String?> reimbursementNote,
      Value<String> refundStatus,
      Value<int?> refundAmountInCents,
      Value<String?> metadataJson,
      Value<double?> duplicateConfidence,
      Value<String> visibility,
      Value<String?> createdBy,
      Value<String?> updatedBy,
      Value<int> version,
      Value<int> rowid,
    });
typedef $$TransactionEntriesTableUpdateCompanionBuilder =
    TransactionEntriesCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String?> userId,
      Value<String> type,
      Value<int> amountInCents,
      Value<String> currency,
      Value<String?> categoryId,
      Value<String?> subcategoryId,
      Value<String> accountId,
      Value<String?> destinationAccountId,
      Value<String?> merchant,
      Value<String?> note,
      Value<DateTime> occurredAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<bool> isRecurring,
      Value<bool> isOneTime,
      Value<bool> isLargeTransaction,
      Value<bool> isPlanned,
      Value<String> source,
      Value<double?> aiConfidence,
      Value<bool> userCorrected,
      Value<String> syncStatus,
      Value<String?> deviceId,
      Value<String?> originalTransactionId,
      Value<String?> relatedTransactionId,
      Value<String> reimbursementStatus,
      Value<int?> reimbursementAmountInCents,
      Value<DateTime?> reimbursementDate,
      Value<String?> reimbursementNote,
      Value<String> refundStatus,
      Value<int?> refundAmountInCents,
      Value<String?> metadataJson,
      Value<double?> duplicateConfidence,
      Value<String> visibility,
      Value<String?> createdBy,
      Value<String?> updatedBy,
      Value<int> version,
      Value<int> rowid,
    });

final class $$TransactionEntriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $TransactionEntriesTable,
          TransactionEntity
        > {
  $$TransactionEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CategoryEntriesTable _categoryIdTable(_$AppDatabase db) => db
      .categoryEntries
      .createAlias('transactions__category_id__categories__id');

  $$CategoryEntriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<String>('category_id');
    if ($_column == null) return null;
    final manager = $$CategoryEntriesTableTableManager(
      $_db,
      $_db.categoryEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CategoryEntriesTable _subcategoryIdTable(_$AppDatabase db) => db
      .categoryEntries
      .createAlias('transactions__subcategory_id__categories__id');

  $$CategoryEntriesTableProcessedTableManager? get subcategoryId {
    final $_column = $_itemColumn<String>('subcategory_id');
    if ($_column == null) return null;
    final manager = $$CategoryEntriesTableTableManager(
      $_db,
      $_db.categoryEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_subcategoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AccountEntriesTable _accountIdTable(_$AppDatabase db) =>
      db.accountEntries.createAlias('transactions__account_id__accounts__id');

  $$AccountEntriesTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('account_id')!;

    final manager = $$AccountEntriesTableTableManager(
      $_db,
      $_db.accountEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $AccountEntriesTable _destinationAccountIdTable(_$AppDatabase db) => db
      .accountEntries
      .createAlias('transactions__destination_account_id__accounts__id');

  $$AccountEntriesTableProcessedTableManager? get destinationAccountId {
    final $_column = $_itemColumn<String>('destination_account_id');
    if ($_column == null) return null;
    final manager = $$AccountEntriesTableTableManager(
      $_db,
      $_db.accountEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(
      _destinationAccountIdTable($_db),
    );
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $EconomicEventRecordEntriesTable,
    List<EconomicEventRecordEntity>
  >
  _economicEventRecordEntriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.economicEventRecordEntries,
        aliasName: 'transactions__id__economic_event_records__transaction_id',
      );

  $$EconomicEventRecordEntriesTableProcessedTableManager
  get economicEventRecordEntriesRefs {
    final manager = $$EconomicEventRecordEntriesTableTableManager(
      $_db,
      $_db.economicEventRecordEntries,
    ).filter((f) => f.transactionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _economicEventRecordEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$InboxItemEntriesTable, List<InboxItemEntity>>
  _inboxTransactionTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.inboxItemEntries,
    aliasName: 'transactions__id__inbox_items__transaction_id',
  );

  $$InboxItemEntriesTableProcessedTableManager get inboxTransaction {
    final manager = $$InboxItemEntriesTableTableManager(
      $_db,
      $_db.inboxItemEntries,
    ).filter((f) => f.transactionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_inboxTransactionTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$InboxItemEntriesTable, List<InboxItemEntity>>
  _inboxCandidateTransactionTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.inboxItemEntries,
        aliasName: 'transactions__id__inbox_items__candidate_transaction_id',
      );

  $$InboxItemEntriesTableProcessedTableManager get inboxCandidateTransaction {
    final manager =
        $$InboxItemEntriesTableTableManager($_db, $_db.inboxItemEntries).filter(
          (f) => f.candidateTransactionId.id.sqlEquals(
            $_itemColumn<String>('id')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(
      _inboxCandidateTransactionTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $TransactionAttachmentEntriesTable,
    List<TransactionAttachmentEntity>
  >
  _transactionAttachmentEntriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.transactionAttachmentEntries,
        aliasName: 'transactions__id__transaction_attachments__transaction_id',
      );

  $$TransactionAttachmentEntriesTableProcessedTableManager
  get transactionAttachmentEntriesRefs {
    final manager = $$TransactionAttachmentEntriesTableTableManager(
      $_db,
      $_db.transactionAttachmentEntries,
    ).filter((f) => f.transactionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _transactionAttachmentEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TransactionEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionEntriesTable> {
  $$TransactionEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountInCents => $composableBuilder(
    column: $table.amountInCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get merchant => $composableBuilder(
    column: $table.merchant,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isRecurring => $composableBuilder(
    column: $table.isRecurring,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isOneTime => $composableBuilder(
    column: $table.isOneTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isLargeTransaction => $composableBuilder(
    column: $table.isLargeTransaction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPlanned => $composableBuilder(
    column: $table.isPlanned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get aiConfidence => $composableBuilder(
    column: $table.aiConfidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get userCorrected => $composableBuilder(
    column: $table.userCorrected,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalTransactionId => $composableBuilder(
    column: $table.originalTransactionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relatedTransactionId => $composableBuilder(
    column: $table.relatedTransactionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reimbursementStatus => $composableBuilder(
    column: $table.reimbursementStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reimbursementAmountInCents => $composableBuilder(
    column: $table.reimbursementAmountInCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get reimbursementDate => $composableBuilder(
    column: $table.reimbursementDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reimbursementNote => $composableBuilder(
    column: $table.reimbursementNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get refundStatus => $composableBuilder(
    column: $table.refundStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get refundAmountInCents => $composableBuilder(
    column: $table.refundAmountInCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get duplicateConfidence => $composableBuilder(
    column: $table.duplicateConfidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoryEntriesTableFilterComposer get categoryId {
    final $$CategoryEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categoryEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryEntriesTableFilterComposer(
            $db: $db,
            $table: $db.categoryEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoryEntriesTableFilterComposer get subcategoryId {
    final $$CategoryEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subcategoryId,
      referencedTable: $db.categoryEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryEntriesTableFilterComposer(
            $db: $db,
            $table: $db.categoryEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountEntriesTableFilterComposer get accountId {
    final $$AccountEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accountEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountEntriesTableFilterComposer(
            $db: $db,
            $table: $db.accountEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountEntriesTableFilterComposer get destinationAccountId {
    final $$AccountEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.destinationAccountId,
      referencedTable: $db.accountEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountEntriesTableFilterComposer(
            $db: $db,
            $table: $db.accountEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> economicEventRecordEntriesRefs(
    Expression<bool> Function($$EconomicEventRecordEntriesTableFilterComposer f)
    f,
  ) {
    final $$EconomicEventRecordEntriesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.economicEventRecordEntries,
          getReferencedColumn: (t) => t.transactionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$EconomicEventRecordEntriesTableFilterComposer(
                $db: $db,
                $table: $db.economicEventRecordEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> inboxTransaction(
    Expression<bool> Function($$InboxItemEntriesTableFilterComposer f) f,
  ) {
    final $$InboxItemEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.inboxItemEntries,
      getReferencedColumn: (t) => t.transactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InboxItemEntriesTableFilterComposer(
            $db: $db,
            $table: $db.inboxItemEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> inboxCandidateTransaction(
    Expression<bool> Function($$InboxItemEntriesTableFilterComposer f) f,
  ) {
    final $$InboxItemEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.inboxItemEntries,
      getReferencedColumn: (t) => t.candidateTransactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InboxItemEntriesTableFilterComposer(
            $db: $db,
            $table: $db.inboxItemEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> transactionAttachmentEntriesRefs(
    Expression<bool> Function(
      $$TransactionAttachmentEntriesTableFilterComposer f,
    )
    f,
  ) {
    final $$TransactionAttachmentEntriesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.transactionAttachmentEntries,
          getReferencedColumn: (t) => t.transactionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TransactionAttachmentEntriesTableFilterComposer(
                $db: $db,
                $table: $db.transactionAttachmentEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$TransactionEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionEntriesTable> {
  $$TransactionEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountInCents => $composableBuilder(
    column: $table.amountInCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get merchant => $composableBuilder(
    column: $table.merchant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isRecurring => $composableBuilder(
    column: $table.isRecurring,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isOneTime => $composableBuilder(
    column: $table.isOneTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isLargeTransaction => $composableBuilder(
    column: $table.isLargeTransaction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPlanned => $composableBuilder(
    column: $table.isPlanned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get aiConfidence => $composableBuilder(
    column: $table.aiConfidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get userCorrected => $composableBuilder(
    column: $table.userCorrected,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalTransactionId => $composableBuilder(
    column: $table.originalTransactionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relatedTransactionId => $composableBuilder(
    column: $table.relatedTransactionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reimbursementStatus => $composableBuilder(
    column: $table.reimbursementStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reimbursementAmountInCents => $composableBuilder(
    column: $table.reimbursementAmountInCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get reimbursementDate => $composableBuilder(
    column: $table.reimbursementDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reimbursementNote => $composableBuilder(
    column: $table.reimbursementNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get refundStatus => $composableBuilder(
    column: $table.refundStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get refundAmountInCents => $composableBuilder(
    column: $table.refundAmountInCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get duplicateConfidence => $composableBuilder(
    column: $table.duplicateConfidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoryEntriesTableOrderingComposer get categoryId {
    final $$CategoryEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categoryEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.categoryEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoryEntriesTableOrderingComposer get subcategoryId {
    final $$CategoryEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subcategoryId,
      referencedTable: $db.categoryEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.categoryEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountEntriesTableOrderingComposer get accountId {
    final $$AccountEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accountEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.accountEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountEntriesTableOrderingComposer get destinationAccountId {
    final $$AccountEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.destinationAccountId,
      referencedTable: $db.accountEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.accountEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionEntriesTable> {
  $$TransactionEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get amountInCents => $composableBuilder(
    column: $table.amountInCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get merchant =>
      $composableBuilder(column: $table.merchant, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<bool> get isRecurring => $composableBuilder(
    column: $table.isRecurring,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isOneTime =>
      $composableBuilder(column: $table.isOneTime, builder: (column) => column);

  GeneratedColumn<bool> get isLargeTransaction => $composableBuilder(
    column: $table.isLargeTransaction,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isPlanned =>
      $composableBuilder(column: $table.isPlanned, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<double> get aiConfidence => $composableBuilder(
    column: $table.aiConfidence,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get userCorrected => $composableBuilder(
    column: $table.userCorrected,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get originalTransactionId => $composableBuilder(
    column: $table.originalTransactionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get relatedTransactionId => $composableBuilder(
    column: $table.relatedTransactionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reimbursementStatus => $composableBuilder(
    column: $table.reimbursementStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reimbursementAmountInCents => $composableBuilder(
    column: $table.reimbursementAmountInCents,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get reimbursementDate => $composableBuilder(
    column: $table.reimbursementDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reimbursementNote => $composableBuilder(
    column: $table.reimbursementNote,
    builder: (column) => column,
  );

  GeneratedColumn<String> get refundStatus => $composableBuilder(
    column: $table.refundStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get refundAmountInCents => $composableBuilder(
    column: $table.refundAmountInCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => column,
  );

  GeneratedColumn<double> get duplicateConfidence => $composableBuilder(
    column: $table.duplicateConfidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  $$CategoryEntriesTableAnnotationComposer get categoryId {
    final $$CategoryEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categoryEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categoryEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoryEntriesTableAnnotationComposer get subcategoryId {
    final $$CategoryEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subcategoryId,
      referencedTable: $db.categoryEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categoryEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountEntriesTableAnnotationComposer get accountId {
    final $$AccountEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accountEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.accountEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$AccountEntriesTableAnnotationComposer get destinationAccountId {
    final $$AccountEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.destinationAccountId,
      referencedTable: $db.accountEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.accountEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> economicEventRecordEntriesRefs<T extends Object>(
    Expression<T> Function(
      $$EconomicEventRecordEntriesTableAnnotationComposer a,
    )
    f,
  ) {
    final $$EconomicEventRecordEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.economicEventRecordEntries,
          getReferencedColumn: (t) => t.transactionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$EconomicEventRecordEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.economicEventRecordEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> inboxTransaction<T extends Object>(
    Expression<T> Function($$InboxItemEntriesTableAnnotationComposer a) f,
  ) {
    final $$InboxItemEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.inboxItemEntries,
      getReferencedColumn: (t) => t.transactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InboxItemEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.inboxItemEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> inboxCandidateTransaction<T extends Object>(
    Expression<T> Function($$InboxItemEntriesTableAnnotationComposer a) f,
  ) {
    final $$InboxItemEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.inboxItemEntries,
      getReferencedColumn: (t) => t.candidateTransactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InboxItemEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.inboxItemEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> transactionAttachmentEntriesRefs<T extends Object>(
    Expression<T> Function(
      $$TransactionAttachmentEntriesTableAnnotationComposer a,
    )
    f,
  ) {
    final $$TransactionAttachmentEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.transactionAttachmentEntries,
          getReferencedColumn: (t) => t.transactionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TransactionAttachmentEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.transactionAttachmentEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$TransactionEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionEntriesTable,
          TransactionEntity,
          $$TransactionEntriesTableFilterComposer,
          $$TransactionEntriesTableOrderingComposer,
          $$TransactionEntriesTableAnnotationComposer,
          $$TransactionEntriesTableCreateCompanionBuilder,
          $$TransactionEntriesTableUpdateCompanionBuilder,
          (TransactionEntity, $$TransactionEntriesTableReferences),
          TransactionEntity,
          PrefetchHooks Function({
            bool categoryId,
            bool subcategoryId,
            bool accountId,
            bool destinationAccountId,
            bool economicEventRecordEntriesRefs,
            bool inboxTransaction,
            bool inboxCandidateTransaction,
            bool transactionAttachmentEntriesRefs,
          })
        > {
  $$TransactionEntriesTableTableManager(
    _$AppDatabase db,
    $TransactionEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> amountInCents = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> subcategoryId = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String?> destinationAccountId = const Value.absent(),
                Value<String?> merchant = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> isRecurring = const Value.absent(),
                Value<bool> isOneTime = const Value.absent(),
                Value<bool> isLargeTransaction = const Value.absent(),
                Value<bool> isPlanned = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<double?> aiConfidence = const Value.absent(),
                Value<bool> userCorrected = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<String?> originalTransactionId = const Value.absent(),
                Value<String?> relatedTransactionId = const Value.absent(),
                Value<String> reimbursementStatus = const Value.absent(),
                Value<int?> reimbursementAmountInCents = const Value.absent(),
                Value<DateTime?> reimbursementDate = const Value.absent(),
                Value<String?> reimbursementNote = const Value.absent(),
                Value<String> refundStatus = const Value.absent(),
                Value<int?> refundAmountInCents = const Value.absent(),
                Value<String?> metadataJson = const Value.absent(),
                Value<double?> duplicateConfidence = const Value.absent(),
                Value<String> visibility = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> updatedBy = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionEntriesCompanion(
                id: id,
                bookId: bookId,
                userId: userId,
                type: type,
                amountInCents: amountInCents,
                currency: currency,
                categoryId: categoryId,
                subcategoryId: subcategoryId,
                accountId: accountId,
                destinationAccountId: destinationAccountId,
                merchant: merchant,
                note: note,
                occurredAt: occurredAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                isRecurring: isRecurring,
                isOneTime: isOneTime,
                isLargeTransaction: isLargeTransaction,
                isPlanned: isPlanned,
                source: source,
                aiConfidence: aiConfidence,
                userCorrected: userCorrected,
                syncStatus: syncStatus,
                deviceId: deviceId,
                originalTransactionId: originalTransactionId,
                relatedTransactionId: relatedTransactionId,
                reimbursementStatus: reimbursementStatus,
                reimbursementAmountInCents: reimbursementAmountInCents,
                reimbursementDate: reimbursementDate,
                reimbursementNote: reimbursementNote,
                refundStatus: refundStatus,
                refundAmountInCents: refundAmountInCents,
                metadataJson: metadataJson,
                duplicateConfidence: duplicateConfidence,
                visibility: visibility,
                createdBy: createdBy,
                updatedBy: updatedBy,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                Value<String?> userId = const Value.absent(),
                required String type,
                required int amountInCents,
                Value<String> currency = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> subcategoryId = const Value.absent(),
                required String accountId,
                Value<String?> destinationAccountId = const Value.absent(),
                Value<String?> merchant = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required DateTime occurredAt,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<bool> isRecurring = const Value.absent(),
                Value<bool> isOneTime = const Value.absent(),
                Value<bool> isLargeTransaction = const Value.absent(),
                Value<bool> isPlanned = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<double?> aiConfidence = const Value.absent(),
                Value<bool> userCorrected = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<String?> deviceId = const Value.absent(),
                Value<String?> originalTransactionId = const Value.absent(),
                Value<String?> relatedTransactionId = const Value.absent(),
                Value<String> reimbursementStatus = const Value.absent(),
                Value<int?> reimbursementAmountInCents = const Value.absent(),
                Value<DateTime?> reimbursementDate = const Value.absent(),
                Value<String?> reimbursementNote = const Value.absent(),
                Value<String> refundStatus = const Value.absent(),
                Value<int?> refundAmountInCents = const Value.absent(),
                Value<String?> metadataJson = const Value.absent(),
                Value<double?> duplicateConfidence = const Value.absent(),
                Value<String> visibility = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> updatedBy = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionEntriesCompanion.insert(
                id: id,
                bookId: bookId,
                userId: userId,
                type: type,
                amountInCents: amountInCents,
                currency: currency,
                categoryId: categoryId,
                subcategoryId: subcategoryId,
                accountId: accountId,
                destinationAccountId: destinationAccountId,
                merchant: merchant,
                note: note,
                occurredAt: occurredAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                isRecurring: isRecurring,
                isOneTime: isOneTime,
                isLargeTransaction: isLargeTransaction,
                isPlanned: isPlanned,
                source: source,
                aiConfidence: aiConfidence,
                userCorrected: userCorrected,
                syncStatus: syncStatus,
                deviceId: deviceId,
                originalTransactionId: originalTransactionId,
                relatedTransactionId: relatedTransactionId,
                reimbursementStatus: reimbursementStatus,
                reimbursementAmountInCents: reimbursementAmountInCents,
                reimbursementDate: reimbursementDate,
                reimbursementNote: reimbursementNote,
                refundStatus: refundStatus,
                refundAmountInCents: refundAmountInCents,
                metadataJson: metadataJson,
                duplicateConfidence: duplicateConfidence,
                visibility: visibility,
                createdBy: createdBy,
                updatedBy: updatedBy,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TransactionEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                categoryId = false,
                subcategoryId = false,
                accountId = false,
                destinationAccountId = false,
                economicEventRecordEntriesRefs = false,
                inboxTransaction = false,
                inboxCandidateTransaction = false,
                transactionAttachmentEntriesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (economicEventRecordEntriesRefs)
                      db.economicEventRecordEntries,
                    if (inboxTransaction) db.inboxItemEntries,
                    if (inboxCandidateTransaction) db.inboxItemEntries,
                    if (transactionAttachmentEntriesRefs)
                      db.transactionAttachmentEntries,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (categoryId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.categoryId,
                            referencedTable: $$TransactionEntriesTableReferences
                                ._categoryIdTable(db),
                            referencedColumn:
                                $$TransactionEntriesTableReferences
                                    ._categoryIdTable(db)
                                    .id,
                          ) as T;
                        }
                        if (subcategoryId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.subcategoryId,
                            referencedTable: $$TransactionEntriesTableReferences
                                ._subcategoryIdTable(db),
                            referencedColumn:
                                $$TransactionEntriesTableReferences
                                    ._subcategoryIdTable(db)
                                    .id,
                          ) as T;
                        }
                        if (accountId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.accountId,
                            referencedTable: $$TransactionEntriesTableReferences
                                ._accountIdTable(db),
                            referencedColumn:
                                $$TransactionEntriesTableReferences
                                    ._accountIdTable(db)
                                    .id,
                          ) as T;
                        }
                        if (destinationAccountId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.destinationAccountId,
                            referencedTable: $$TransactionEntriesTableReferences
                                ._destinationAccountIdTable(db),
                            referencedColumn:
                                $$TransactionEntriesTableReferences
                                    ._destinationAccountIdTable(db)
                                    .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (economicEventRecordEntriesRefs)
                        await $_getPrefetchedData<
                          TransactionEntity,
                          $TransactionEntriesTable,
                          EconomicEventRecordEntity
                        >(
                          currentTable: table,
                          referencedTable: $$TransactionEntriesTableReferences
                              ._economicEventRecordEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TransactionEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).economicEventRecordEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.transactionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (inboxTransaction)
                        await $_getPrefetchedData<
                          TransactionEntity,
                          $TransactionEntriesTable,
                          InboxItemEntity
                        >(
                          currentTable: table,
                          referencedTable: $$TransactionEntriesTableReferences
                              ._inboxTransactionTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TransactionEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).inboxTransaction,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.transactionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (inboxCandidateTransaction)
                        await $_getPrefetchedData<
                          TransactionEntity,
                          $TransactionEntriesTable,
                          InboxItemEntity
                        >(
                          currentTable: table,
                          referencedTable: $$TransactionEntriesTableReferences
                              ._inboxCandidateTransactionTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TransactionEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).inboxCandidateTransaction,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.candidateTransactionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (transactionAttachmentEntriesRefs)
                        await $_getPrefetchedData<
                          TransactionEntity,
                          $TransactionEntriesTable,
                          TransactionAttachmentEntity
                        >(
                          currentTable: table,
                          referencedTable: $$TransactionEntriesTableReferences
                              ._transactionAttachmentEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TransactionEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).transactionAttachmentEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.transactionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TransactionEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionEntriesTable,
      TransactionEntity,
      $$TransactionEntriesTableFilterComposer,
      $$TransactionEntriesTableOrderingComposer,
      $$TransactionEntriesTableAnnotationComposer,
      $$TransactionEntriesTableCreateCompanionBuilder,
      $$TransactionEntriesTableUpdateCompanionBuilder,
      (TransactionEntity, $$TransactionEntriesTableReferences),
      TransactionEntity,
      PrefetchHooks Function({
        bool categoryId,
        bool subcategoryId,
        bool accountId,
        bool destinationAccountId,
        bool economicEventRecordEntriesRefs,
        bool inboxTransaction,
        bool inboxCandidateTransaction,
        bool transactionAttachmentEntriesRefs,
      })
    >;
typedef $$GoalEntriesTableCreateCompanionBuilder =
    GoalEntriesCompanion Function({
      required String id,
      required String name,
      Value<String> goalType,
      required String icon,
      required int targetAmountInCents,
      Value<int> currentAmountInCents,
      required DateTime targetDate,
      Value<String> status,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<String?> description,
      Value<String?> coverPath,
      Value<bool> completionCelebrationShown,
      Value<String> bookId,
      Value<String?> createdBy,
      Value<String?> updatedBy,
      Value<int> version,
      Value<int> sortOrder,
      Value<int> monthlyReservationInCents,
      Value<int> rowid,
    });
typedef $$GoalEntriesTableUpdateCompanionBuilder =
    GoalEntriesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> goalType,
      Value<String> icon,
      Value<int> targetAmountInCents,
      Value<int> currentAmountInCents,
      Value<DateTime> targetDate,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<String?> description,
      Value<String?> coverPath,
      Value<bool> completionCelebrationShown,
      Value<String> bookId,
      Value<String?> createdBy,
      Value<String?> updatedBy,
      Value<int> version,
      Value<int> sortOrder,
      Value<int> monthlyReservationInCents,
      Value<int> rowid,
    });

final class $$GoalEntriesTableReferences
    extends BaseReferences<_$AppDatabase, $GoalEntriesTable, GoalEntity> {
  $$GoalEntriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $GoalMilestoneEntriesTable,
    List<GoalMilestoneEntity>
  >
  _goalMilestoneEntriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.goalMilestoneEntries,
        aliasName: 'goals__id__goal_milestones__goal_id',
      );

  $$GoalMilestoneEntriesTableProcessedTableManager
  get goalMilestoneEntriesRefs {
    final manager = $$GoalMilestoneEntriesTableTableManager(
      $_db,
      $_db.goalMilestoneEntries,
    ).filter((f) => f.goalId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _goalMilestoneEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $GoalContributionEntriesTable,
    List<GoalContributionEntity>
  >
  _goalContributionEntriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.goalContributionEntries,
        aliasName: 'goals__id__goal_contributions__goal_id',
      );

  $$GoalContributionEntriesTableProcessedTableManager
  get goalContributionEntriesRefs {
    final manager = $$GoalContributionEntriesTableTableManager(
      $_db,
      $_db.goalContributionEntries,
    ).filter((f) => f.goalId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _goalContributionEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$GoalEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $GoalEntriesTable> {
  $$GoalEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get goalType => $composableBuilder(
    column: $table.goalType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetAmountInCents => $composableBuilder(
    column: $table.targetAmountInCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentAmountInCents => $composableBuilder(
    column: $table.currentAmountInCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completionCelebrationShown => $composableBuilder(
    column: $table.completionCelebrationShown,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get monthlyReservationInCents => $composableBuilder(
    column: $table.monthlyReservationInCents,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> goalMilestoneEntriesRefs(
    Expression<bool> Function($$GoalMilestoneEntriesTableFilterComposer f) f,
  ) {
    final $$GoalMilestoneEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.goalMilestoneEntries,
      getReferencedColumn: (t) => t.goalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalMilestoneEntriesTableFilterComposer(
            $db: $db,
            $table: $db.goalMilestoneEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> goalContributionEntriesRefs(
    Expression<bool> Function($$GoalContributionEntriesTableFilterComposer f) f,
  ) {
    final $$GoalContributionEntriesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.goalContributionEntries,
          getReferencedColumn: (t) => t.goalId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$GoalContributionEntriesTableFilterComposer(
                $db: $db,
                $table: $db.goalContributionEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$GoalEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $GoalEntriesTable> {
  $$GoalEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get goalType => $composableBuilder(
    column: $table.goalType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetAmountInCents => $composableBuilder(
    column: $table.targetAmountInCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentAmountInCents => $composableBuilder(
    column: $table.currentAmountInCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completionCelebrationShown => $composableBuilder(
    column: $table.completionCelebrationShown,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get monthlyReservationInCents => $composableBuilder(
    column: $table.monthlyReservationInCents,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GoalEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GoalEntriesTable> {
  $$GoalEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get goalType =>
      $composableBuilder(column: $table.goalType, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<int> get targetAmountInCents => $composableBuilder(
    column: $table.targetAmountInCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentAmountInCents => $composableBuilder(
    column: $table.currentAmountInCents,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<bool> get completionCelebrationShown => $composableBuilder(
    column: $table.completionCelebrationShown,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get monthlyReservationInCents => $composableBuilder(
    column: $table.monthlyReservationInCents,
    builder: (column) => column,
  );

  Expression<T> goalMilestoneEntriesRefs<T extends Object>(
    Expression<T> Function($$GoalMilestoneEntriesTableAnnotationComposer a) f,
  ) {
    final $$GoalMilestoneEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.goalMilestoneEntries,
          getReferencedColumn: (t) => t.goalId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$GoalMilestoneEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.goalMilestoneEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> goalContributionEntriesRefs<T extends Object>(
    Expression<T> Function($$GoalContributionEntriesTableAnnotationComposer a)
    f,
  ) {
    final $$GoalContributionEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.goalContributionEntries,
          getReferencedColumn: (t) => t.goalId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$GoalContributionEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.goalContributionEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$GoalEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GoalEntriesTable,
          GoalEntity,
          $$GoalEntriesTableFilterComposer,
          $$GoalEntriesTableOrderingComposer,
          $$GoalEntriesTableAnnotationComposer,
          $$GoalEntriesTableCreateCompanionBuilder,
          $$GoalEntriesTableUpdateCompanionBuilder,
          (GoalEntity, $$GoalEntriesTableReferences),
          GoalEntity,
          PrefetchHooks Function({
            bool goalMilestoneEntriesRefs,
            bool goalContributionEntriesRefs,
          })
        > {
  $$GoalEntriesTableTableManager(_$AppDatabase db, $GoalEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GoalEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GoalEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GoalEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> goalType = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<int> targetAmountInCents = const Value.absent(),
                Value<int> currentAmountInCents = const Value.absent(),
                Value<DateTime> targetDate = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<bool> completionCelebrationShown = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> updatedBy = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> monthlyReservationInCents = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GoalEntriesCompanion(
                id: id,
                name: name,
                goalType: goalType,
                icon: icon,
                targetAmountInCents: targetAmountInCents,
                currentAmountInCents: currentAmountInCents,
                targetDate: targetDate,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                description: description,
                coverPath: coverPath,
                completionCelebrationShown: completionCelebrationShown,
                bookId: bookId,
                createdBy: createdBy,
                updatedBy: updatedBy,
                version: version,
                sortOrder: sortOrder,
                monthlyReservationInCents: monthlyReservationInCents,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> goalType = const Value.absent(),
                required String icon,
                required int targetAmountInCents,
                Value<int> currentAmountInCents = const Value.absent(),
                required DateTime targetDate,
                Value<String> status = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<String?> description = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<bool> completionCelebrationShown = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> updatedBy = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> monthlyReservationInCents = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GoalEntriesCompanion.insert(
                id: id,
                name: name,
                goalType: goalType,
                icon: icon,
                targetAmountInCents: targetAmountInCents,
                currentAmountInCents: currentAmountInCents,
                targetDate: targetDate,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                description: description,
                coverPath: coverPath,
                completionCelebrationShown: completionCelebrationShown,
                bookId: bookId,
                createdBy: createdBy,
                updatedBy: updatedBy,
                version: version,
                sortOrder: sortOrder,
                monthlyReservationInCents: monthlyReservationInCents,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$GoalEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                goalMilestoneEntriesRefs = false,
                goalContributionEntriesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (goalMilestoneEntriesRefs) db.goalMilestoneEntries,
                    if (goalContributionEntriesRefs) db.goalContributionEntries,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (goalMilestoneEntriesRefs)
                        await $_getPrefetchedData<
                          GoalEntity,
                          $GoalEntriesTable,
                          GoalMilestoneEntity
                        >(
                          currentTable: table,
                          referencedTable: $$GoalEntriesTableReferences
                              ._goalMilestoneEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GoalEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).goalMilestoneEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.goalId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (goalContributionEntriesRefs)
                        await $_getPrefetchedData<
                          GoalEntity,
                          $GoalEntriesTable,
                          GoalContributionEntity
                        >(
                          currentTable: table,
                          referencedTable: $$GoalEntriesTableReferences
                              ._goalContributionEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GoalEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).goalContributionEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.goalId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$GoalEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GoalEntriesTable,
      GoalEntity,
      $$GoalEntriesTableFilterComposer,
      $$GoalEntriesTableOrderingComposer,
      $$GoalEntriesTableAnnotationComposer,
      $$GoalEntriesTableCreateCompanionBuilder,
      $$GoalEntriesTableUpdateCompanionBuilder,
      (GoalEntity, $$GoalEntriesTableReferences),
      GoalEntity,
      PrefetchHooks Function({
        bool goalMilestoneEntriesRefs,
        bool goalContributionEntriesRefs,
      })
    >;
typedef $$GoalMilestoneEntriesTableCreateCompanionBuilder =
    GoalMilestoneEntriesCompanion Function({
      required String id,
      required String goalId,
      required int amountInCents,
      required String title,
      required int sortOrder,
      Value<DateTime?> completedAt,
      Value<bool> celebrationShown,
      Value<int> rowid,
    });
typedef $$GoalMilestoneEntriesTableUpdateCompanionBuilder =
    GoalMilestoneEntriesCompanion Function({
      Value<String> id,
      Value<String> goalId,
      Value<int> amountInCents,
      Value<String> title,
      Value<int> sortOrder,
      Value<DateTime?> completedAt,
      Value<bool> celebrationShown,
      Value<int> rowid,
    });

final class $$GoalMilestoneEntriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $GoalMilestoneEntriesTable,
          GoalMilestoneEntity
        > {
  $$GoalMilestoneEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $GoalEntriesTable _goalIdTable(_$AppDatabase db) =>
      db.goalEntries.createAlias('goal_milestones__goal_id__goals__id');

  $$GoalEntriesTableProcessedTableManager get goalId {
    final $_column = $_itemColumn<String>('goal_id')!;

    final manager = $$GoalEntriesTableTableManager(
      $_db,
      $_db.goalEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_goalIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$GoalMilestoneEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $GoalMilestoneEntriesTable> {
  $$GoalMilestoneEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountInCents => $composableBuilder(
    column: $table.amountInCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get celebrationShown => $composableBuilder(
    column: $table.celebrationShown,
    builder: (column) => ColumnFilters(column),
  );

  $$GoalEntriesTableFilterComposer get goalId {
    final $$GoalEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goalEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalEntriesTableFilterComposer(
            $db: $db,
            $table: $db.goalEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GoalMilestoneEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $GoalMilestoneEntriesTable> {
  $$GoalMilestoneEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountInCents => $composableBuilder(
    column: $table.amountInCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get celebrationShown => $composableBuilder(
    column: $table.celebrationShown,
    builder: (column) => ColumnOrderings(column),
  );

  $$GoalEntriesTableOrderingComposer get goalId {
    final $$GoalEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goalEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.goalEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GoalMilestoneEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GoalMilestoneEntriesTable> {
  $$GoalMilestoneEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get amountInCents => $composableBuilder(
    column: $table.amountInCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get celebrationShown => $composableBuilder(
    column: $table.celebrationShown,
    builder: (column) => column,
  );

  $$GoalEntriesTableAnnotationComposer get goalId {
    final $$GoalEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goalEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.goalEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GoalMilestoneEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GoalMilestoneEntriesTable,
          GoalMilestoneEntity,
          $$GoalMilestoneEntriesTableFilterComposer,
          $$GoalMilestoneEntriesTableOrderingComposer,
          $$GoalMilestoneEntriesTableAnnotationComposer,
          $$GoalMilestoneEntriesTableCreateCompanionBuilder,
          $$GoalMilestoneEntriesTableUpdateCompanionBuilder,
          (GoalMilestoneEntity, $$GoalMilestoneEntriesTableReferences),
          GoalMilestoneEntity,
          PrefetchHooks Function({bool goalId})
        > {
  $$GoalMilestoneEntriesTableTableManager(
    _$AppDatabase db,
    $GoalMilestoneEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GoalMilestoneEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GoalMilestoneEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$GoalMilestoneEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> goalId = const Value.absent(),
                Value<int> amountInCents = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<bool> celebrationShown = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GoalMilestoneEntriesCompanion(
                id: id,
                goalId: goalId,
                amountInCents: amountInCents,
                title: title,
                sortOrder: sortOrder,
                completedAt: completedAt,
                celebrationShown: celebrationShown,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String goalId,
                required int amountInCents,
                required String title,
                required int sortOrder,
                Value<DateTime?> completedAt = const Value.absent(),
                Value<bool> celebrationShown = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GoalMilestoneEntriesCompanion.insert(
                id: id,
                goalId: goalId,
                amountInCents: amountInCents,
                title: title,
                sortOrder: sortOrder,
                completedAt: completedAt,
                celebrationShown: celebrationShown,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$GoalMilestoneEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({goalId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (goalId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.goalId,
                        referencedTable: $$GoalMilestoneEntriesTableReferences
                            ._goalIdTable(db),
                        referencedColumn: $$GoalMilestoneEntriesTableReferences
                            ._goalIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$GoalMilestoneEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GoalMilestoneEntriesTable,
      GoalMilestoneEntity,
      $$GoalMilestoneEntriesTableFilterComposer,
      $$GoalMilestoneEntriesTableOrderingComposer,
      $$GoalMilestoneEntriesTableAnnotationComposer,
      $$GoalMilestoneEntriesTableCreateCompanionBuilder,
      $$GoalMilestoneEntriesTableUpdateCompanionBuilder,
      (GoalMilestoneEntity, $$GoalMilestoneEntriesTableReferences),
      GoalMilestoneEntity,
      PrefetchHooks Function({bool goalId})
    >;
typedef $$GoalContributionEntriesTableCreateCompanionBuilder =
    GoalContributionEntriesCompanion Function({
      required String id,
      required String goalId,
      required int amountInCents,
      required String type,
      Value<String?> sourceTransactionId,
      required DateTime createdAt,
      Value<String?> note,
      Value<String?> contributorUserId,
      Value<int> rowid,
    });
typedef $$GoalContributionEntriesTableUpdateCompanionBuilder =
    GoalContributionEntriesCompanion Function({
      Value<String> id,
      Value<String> goalId,
      Value<int> amountInCents,
      Value<String> type,
      Value<String?> sourceTransactionId,
      Value<DateTime> createdAt,
      Value<String?> note,
      Value<String?> contributorUserId,
      Value<int> rowid,
    });

final class $$GoalContributionEntriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $GoalContributionEntriesTable,
          GoalContributionEntity
        > {
  $$GoalContributionEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $GoalEntriesTable _goalIdTable(_$AppDatabase db) =>
      db.goalEntries.createAlias('goal_contributions__goal_id__goals__id');

  $$GoalEntriesTableProcessedTableManager get goalId {
    final $_column = $_itemColumn<String>('goal_id')!;

    final manager = $$GoalEntriesTableTableManager(
      $_db,
      $_db.goalEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_goalIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$GoalContributionEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $GoalContributionEntriesTable> {
  $$GoalContributionEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountInCents => $composableBuilder(
    column: $table.amountInCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceTransactionId => $composableBuilder(
    column: $table.sourceTransactionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contributorUserId => $composableBuilder(
    column: $table.contributorUserId,
    builder: (column) => ColumnFilters(column),
  );

  $$GoalEntriesTableFilterComposer get goalId {
    final $$GoalEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goalEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalEntriesTableFilterComposer(
            $db: $db,
            $table: $db.goalEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GoalContributionEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $GoalContributionEntriesTable> {
  $$GoalContributionEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountInCents => $composableBuilder(
    column: $table.amountInCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceTransactionId => $composableBuilder(
    column: $table.sourceTransactionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contributorUserId => $composableBuilder(
    column: $table.contributorUserId,
    builder: (column) => ColumnOrderings(column),
  );

  $$GoalEntriesTableOrderingComposer get goalId {
    final $$GoalEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goalEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.goalEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GoalContributionEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GoalContributionEntriesTable> {
  $$GoalContributionEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get amountInCents => $composableBuilder(
    column: $table.amountInCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get sourceTransactionId => $composableBuilder(
    column: $table.sourceTransactionId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get contributorUserId => $composableBuilder(
    column: $table.contributorUserId,
    builder: (column) => column,
  );

  $$GoalEntriesTableAnnotationComposer get goalId {
    final $$GoalEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goalEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.goalEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GoalContributionEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GoalContributionEntriesTable,
          GoalContributionEntity,
          $$GoalContributionEntriesTableFilterComposer,
          $$GoalContributionEntriesTableOrderingComposer,
          $$GoalContributionEntriesTableAnnotationComposer,
          $$GoalContributionEntriesTableCreateCompanionBuilder,
          $$GoalContributionEntriesTableUpdateCompanionBuilder,
          (GoalContributionEntity, $$GoalContributionEntriesTableReferences),
          GoalContributionEntity,
          PrefetchHooks Function({bool goalId})
        > {
  $$GoalContributionEntriesTableTableManager(
    _$AppDatabase db,
    $GoalContributionEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GoalContributionEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$GoalContributionEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$GoalContributionEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> goalId = const Value.absent(),
                Value<int> amountInCents = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> sourceTransactionId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> contributorUserId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GoalContributionEntriesCompanion(
                id: id,
                goalId: goalId,
                amountInCents: amountInCents,
                type: type,
                sourceTransactionId: sourceTransactionId,
                createdAt: createdAt,
                note: note,
                contributorUserId: contributorUserId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String goalId,
                required int amountInCents,
                required String type,
                Value<String?> sourceTransactionId = const Value.absent(),
                required DateTime createdAt,
                Value<String?> note = const Value.absent(),
                Value<String?> contributorUserId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GoalContributionEntriesCompanion.insert(
                id: id,
                goalId: goalId,
                amountInCents: amountInCents,
                type: type,
                sourceTransactionId: sourceTransactionId,
                createdAt: createdAt,
                note: note,
                contributorUserId: contributorUserId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$GoalContributionEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({goalId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (goalId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.goalId,
                        referencedTable:
                            $$GoalContributionEntriesTableReferences
                                ._goalIdTable(db),
                        referencedColumn:
                            $$GoalContributionEntriesTableReferences
                                ._goalIdTable(db)
                                .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$GoalContributionEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GoalContributionEntriesTable,
      GoalContributionEntity,
      $$GoalContributionEntriesTableFilterComposer,
      $$GoalContributionEntriesTableOrderingComposer,
      $$GoalContributionEntriesTableAnnotationComposer,
      $$GoalContributionEntriesTableCreateCompanionBuilder,
      $$GoalContributionEntriesTableUpdateCompanionBuilder,
      (GoalContributionEntity, $$GoalContributionEntriesTableReferences),
      GoalContributionEntity,
      PrefetchHooks Function({bool goalId})
    >;
typedef $$AppSettingEntriesTableCreateCompanionBuilder =
    AppSettingEntriesCompanion Function({
      required String key,
      required String value,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$AppSettingEntriesTableUpdateCompanionBuilder =
    AppSettingEntriesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$AppSettingEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingEntriesTable> {
  $$AppSettingEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingEntriesTable> {
  $$AppSettingEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingEntriesTable> {
  $$AppSettingEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppSettingEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingEntriesTable,
          AppSettingEntity,
          $$AppSettingEntriesTableFilterComposer,
          $$AppSettingEntriesTableOrderingComposer,
          $$AppSettingEntriesTableAnnotationComposer,
          $$AppSettingEntriesTableCreateCompanionBuilder,
          $$AppSettingEntriesTableUpdateCompanionBuilder,
          (
            AppSettingEntity,
            BaseReferences<
              _$AppDatabase,
              $AppSettingEntriesTable,
              AppSettingEntity
            >,
          ),
          AppSettingEntity,
          PrefetchHooks Function()
        > {
  $$AppSettingEntriesTableTableManager(
    _$AppDatabase db,
    $AppSettingEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingEntriesCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingEntriesCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingEntriesTable,
      AppSettingEntity,
      $$AppSettingEntriesTableFilterComposer,
      $$AppSettingEntriesTableOrderingComposer,
      $$AppSettingEntriesTableAnnotationComposer,
      $$AppSettingEntriesTableCreateCompanionBuilder,
      $$AppSettingEntriesTableUpdateCompanionBuilder,
      (
        AppSettingEntity,
        BaseReferences<
          _$AppDatabase,
          $AppSettingEntriesTable,
          AppSettingEntity
        >,
      ),
      AppSettingEntity,
      PrefetchHooks Function()
    >;
typedef $$BudgetEntriesTableCreateCompanionBuilder =
    BudgetEntriesCompanion Function({
      required String id,
      Value<String> bookId,
      required String monthKey,
      Value<String?> categoryId,
      required int amountInCents,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$BudgetEntriesTableUpdateCompanionBuilder =
    BudgetEntriesCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String> monthKey,
      Value<String?> categoryId,
      Value<int> amountInCents,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$BudgetEntriesTableReferences
    extends BaseReferences<_$AppDatabase, $BudgetEntriesTable, BudgetEntity> {
  $$BudgetEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CategoryEntriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categoryEntries.createAlias('budgets__category_id__categories__id');

  $$CategoryEntriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<String>('category_id');
    if ($_column == null) return null;
    final manager = $$CategoryEntriesTableTableManager(
      $_db,
      $_db.categoryEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BudgetEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $BudgetEntriesTable> {
  $$BudgetEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get monthKey => $composableBuilder(
    column: $table.monthKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountInCents => $composableBuilder(
    column: $table.amountInCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoryEntriesTableFilterComposer get categoryId {
    final $$CategoryEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categoryEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryEntriesTableFilterComposer(
            $db: $db,
            $table: $db.categoryEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BudgetEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $BudgetEntriesTable> {
  $$BudgetEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get monthKey => $composableBuilder(
    column: $table.monthKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountInCents => $composableBuilder(
    column: $table.amountInCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoryEntriesTableOrderingComposer get categoryId {
    final $$CategoryEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categoryEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.categoryEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BudgetEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BudgetEntriesTable> {
  $$BudgetEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get monthKey =>
      $composableBuilder(column: $table.monthKey, builder: (column) => column);

  GeneratedColumn<int> get amountInCents => $composableBuilder(
    column: $table.amountInCents,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$CategoryEntriesTableAnnotationComposer get categoryId {
    final $$CategoryEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categoryEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categoryEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BudgetEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BudgetEntriesTable,
          BudgetEntity,
          $$BudgetEntriesTableFilterComposer,
          $$BudgetEntriesTableOrderingComposer,
          $$BudgetEntriesTableAnnotationComposer,
          $$BudgetEntriesTableCreateCompanionBuilder,
          $$BudgetEntriesTableUpdateCompanionBuilder,
          (BudgetEntity, $$BudgetEntriesTableReferences),
          BudgetEntity,
          PrefetchHooks Function({bool categoryId})
        > {
  $$BudgetEntriesTableTableManager(_$AppDatabase db, $BudgetEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BudgetEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BudgetEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BudgetEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> monthKey = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<int> amountInCents = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BudgetEntriesCompanion(
                id: id,
                bookId: bookId,
                monthKey: monthKey,
                categoryId: categoryId,
                amountInCents: amountInCents,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> bookId = const Value.absent(),
                required String monthKey,
                Value<String?> categoryId = const Value.absent(),
                required int amountInCents,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => BudgetEntriesCompanion.insert(
                id: id,
                bookId: bookId,
                monthKey: monthKey,
                categoryId: categoryId,
                amountInCents: amountInCents,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BudgetEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (categoryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.categoryId,
                        referencedTable: $$BudgetEntriesTableReferences
                            ._categoryIdTable(db),
                        referencedColumn: $$BudgetEntriesTableReferences
                            ._categoryIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BudgetEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BudgetEntriesTable,
      BudgetEntity,
      $$BudgetEntriesTableFilterComposer,
      $$BudgetEntriesTableOrderingComposer,
      $$BudgetEntriesTableAnnotationComposer,
      $$BudgetEntriesTableCreateCompanionBuilder,
      $$BudgetEntriesTableUpdateCompanionBuilder,
      (BudgetEntity, $$BudgetEntriesTableReferences),
      BudgetEntity,
      PrefetchHooks Function({bool categoryId})
    >;
typedef $$RecurringBillEntriesTableCreateCompanionBuilder =
    RecurringBillEntriesCompanion Function({
      required String id,
      required String bookId,
      required String name,
      required String type,
      required int amountInCents,
      required String cycle,
      required DateTime startDate,
      Value<DateTime?> endDate,
      required DateTime nextDate,
      Value<String?> accountId,
      Value<String?> categoryId,
      Value<int?> customIntervalDays,
      Value<bool> autoRecord,
      Value<bool> reminder,
      Value<String> status,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$RecurringBillEntriesTableUpdateCompanionBuilder =
    RecurringBillEntriesCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String> name,
      Value<String> type,
      Value<int> amountInCents,
      Value<String> cycle,
      Value<DateTime> startDate,
      Value<DateTime?> endDate,
      Value<DateTime> nextDate,
      Value<String?> accountId,
      Value<String?> categoryId,
      Value<int?> customIntervalDays,
      Value<bool> autoRecord,
      Value<bool> reminder,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$RecurringBillEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $RecurringBillEntriesTable> {
  $$RecurringBillEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountInCents => $composableBuilder(
    column: $table.amountInCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cycle => $composableBuilder(
    column: $table.cycle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextDate => $composableBuilder(
    column: $table.nextDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get customIntervalDays => $composableBuilder(
    column: $table.customIntervalDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoRecord => $composableBuilder(
    column: $table.autoRecord,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get reminder => $composableBuilder(
    column: $table.reminder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecurringBillEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $RecurringBillEntriesTable> {
  $$RecurringBillEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountInCents => $composableBuilder(
    column: $table.amountInCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cycle => $composableBuilder(
    column: $table.cycle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextDate => $composableBuilder(
    column: $table.nextDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get customIntervalDays => $composableBuilder(
    column: $table.customIntervalDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoRecord => $composableBuilder(
    column: $table.autoRecord,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get reminder => $composableBuilder(
    column: $table.reminder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecurringBillEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecurringBillEntriesTable> {
  $$RecurringBillEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get amountInCents => $composableBuilder(
    column: $table.amountInCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cycle =>
      $composableBuilder(column: $table.cycle, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<DateTime> get nextDate =>
      $composableBuilder(column: $table.nextDate, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get customIntervalDays => $composableBuilder(
    column: $table.customIntervalDays,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get autoRecord => $composableBuilder(
    column: $table.autoRecord,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get reminder =>
      $composableBuilder(column: $table.reminder, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$RecurringBillEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecurringBillEntriesTable,
          RecurringBillEntity,
          $$RecurringBillEntriesTableFilterComposer,
          $$RecurringBillEntriesTableOrderingComposer,
          $$RecurringBillEntriesTableAnnotationComposer,
          $$RecurringBillEntriesTableCreateCompanionBuilder,
          $$RecurringBillEntriesTableUpdateCompanionBuilder,
          (
            RecurringBillEntity,
            BaseReferences<
              _$AppDatabase,
              $RecurringBillEntriesTable,
              RecurringBillEntity
            >,
          ),
          RecurringBillEntity,
          PrefetchHooks Function()
        > {
  $$RecurringBillEntriesTableTableManager(
    _$AppDatabase db,
    $RecurringBillEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecurringBillEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecurringBillEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$RecurringBillEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> amountInCents = const Value.absent(),
                Value<String> cycle = const Value.absent(),
                Value<DateTime> startDate = const Value.absent(),
                Value<DateTime?> endDate = const Value.absent(),
                Value<DateTime> nextDate = const Value.absent(),
                Value<String?> accountId = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<int?> customIntervalDays = const Value.absent(),
                Value<bool> autoRecord = const Value.absent(),
                Value<bool> reminder = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecurringBillEntriesCompanion(
                id: id,
                bookId: bookId,
                name: name,
                type: type,
                amountInCents: amountInCents,
                cycle: cycle,
                startDate: startDate,
                endDate: endDate,
                nextDate: nextDate,
                accountId: accountId,
                categoryId: categoryId,
                customIntervalDays: customIntervalDays,
                autoRecord: autoRecord,
                reminder: reminder,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required String name,
                required String type,
                required int amountInCents,
                required String cycle,
                required DateTime startDate,
                Value<DateTime?> endDate = const Value.absent(),
                required DateTime nextDate,
                Value<String?> accountId = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<int?> customIntervalDays = const Value.absent(),
                Value<bool> autoRecord = const Value.absent(),
                Value<bool> reminder = const Value.absent(),
                Value<String> status = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => RecurringBillEntriesCompanion.insert(
                id: id,
                bookId: bookId,
                name: name,
                type: type,
                amountInCents: amountInCents,
                cycle: cycle,
                startDate: startDate,
                endDate: endDate,
                nextDate: nextDate,
                accountId: accountId,
                categoryId: categoryId,
                customIntervalDays: customIntervalDays,
                autoRecord: autoRecord,
                reminder: reminder,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecurringBillEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecurringBillEntriesTable,
      RecurringBillEntity,
      $$RecurringBillEntriesTableFilterComposer,
      $$RecurringBillEntriesTableOrderingComposer,
      $$RecurringBillEntriesTableAnnotationComposer,
      $$RecurringBillEntriesTableCreateCompanionBuilder,
      $$RecurringBillEntriesTableUpdateCompanionBuilder,
      (
        RecurringBillEntity,
        BaseReferences<
          _$AppDatabase,
          $RecurringBillEntriesTable,
          RecurringBillEntity
        >,
      ),
      RecurringBillEntity,
      PrefetchHooks Function()
    >;
typedef $$InstallmentPlanEntriesTableCreateCompanionBuilder =
    InstallmentPlanEntriesCompanion Function({
      required String id,
      required String bookId,
      required String name,
      required String originalTransactionId,
      required int totalAmountInCents,
      required int totalPeriods,
      required int currentPeriod,
      required int principalPerPeriodInCents,
      required int feePerPeriodInCents,
      required DateTime startDate,
      required int dueDay,
      required String creditAccountId,
      required String repaymentAccountId,
      required int remainingPrincipalInCents,
      Value<String> status,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$InstallmentPlanEntriesTableUpdateCompanionBuilder =
    InstallmentPlanEntriesCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String> name,
      Value<String> originalTransactionId,
      Value<int> totalAmountInCents,
      Value<int> totalPeriods,
      Value<int> currentPeriod,
      Value<int> principalPerPeriodInCents,
      Value<int> feePerPeriodInCents,
      Value<DateTime> startDate,
      Value<int> dueDay,
      Value<String> creditAccountId,
      Value<String> repaymentAccountId,
      Value<int> remainingPrincipalInCents,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$InstallmentPlanEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $InstallmentPlanEntriesTable> {
  $$InstallmentPlanEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalTransactionId => $composableBuilder(
    column: $table.originalTransactionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalAmountInCents => $composableBuilder(
    column: $table.totalAmountInCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalPeriods => $composableBuilder(
    column: $table.totalPeriods,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentPeriod => $composableBuilder(
    column: $table.currentPeriod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get principalPerPeriodInCents => $composableBuilder(
    column: $table.principalPerPeriodInCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get feePerPeriodInCents => $composableBuilder(
    column: $table.feePerPeriodInCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueDay => $composableBuilder(
    column: $table.dueDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get creditAccountId => $composableBuilder(
    column: $table.creditAccountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repaymentAccountId => $composableBuilder(
    column: $table.repaymentAccountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remainingPrincipalInCents => $composableBuilder(
    column: $table.remainingPrincipalInCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InstallmentPlanEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $InstallmentPlanEntriesTable> {
  $$InstallmentPlanEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalTransactionId => $composableBuilder(
    column: $table.originalTransactionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalAmountInCents => $composableBuilder(
    column: $table.totalAmountInCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalPeriods => $composableBuilder(
    column: $table.totalPeriods,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentPeriod => $composableBuilder(
    column: $table.currentPeriod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get principalPerPeriodInCents => $composableBuilder(
    column: $table.principalPerPeriodInCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get feePerPeriodInCents => $composableBuilder(
    column: $table.feePerPeriodInCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueDay => $composableBuilder(
    column: $table.dueDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get creditAccountId => $composableBuilder(
    column: $table.creditAccountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repaymentAccountId => $composableBuilder(
    column: $table.repaymentAccountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remainingPrincipalInCents => $composableBuilder(
    column: $table.remainingPrincipalInCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InstallmentPlanEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $InstallmentPlanEntriesTable> {
  $$InstallmentPlanEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get originalTransactionId => $composableBuilder(
    column: $table.originalTransactionId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalAmountInCents => $composableBuilder(
    column: $table.totalAmountInCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalPeriods => $composableBuilder(
    column: $table.totalPeriods,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentPeriod => $composableBuilder(
    column: $table.currentPeriod,
    builder: (column) => column,
  );

  GeneratedColumn<int> get principalPerPeriodInCents => $composableBuilder(
    column: $table.principalPerPeriodInCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get feePerPeriodInCents => $composableBuilder(
    column: $table.feePerPeriodInCents,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<int> get dueDay =>
      $composableBuilder(column: $table.dueDay, builder: (column) => column);

  GeneratedColumn<String> get creditAccountId => $composableBuilder(
    column: $table.creditAccountId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get repaymentAccountId => $composableBuilder(
    column: $table.repaymentAccountId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get remainingPrincipalInCents => $composableBuilder(
    column: $table.remainingPrincipalInCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$InstallmentPlanEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InstallmentPlanEntriesTable,
          InstallmentPlanEntity,
          $$InstallmentPlanEntriesTableFilterComposer,
          $$InstallmentPlanEntriesTableOrderingComposer,
          $$InstallmentPlanEntriesTableAnnotationComposer,
          $$InstallmentPlanEntriesTableCreateCompanionBuilder,
          $$InstallmentPlanEntriesTableUpdateCompanionBuilder,
          (
            InstallmentPlanEntity,
            BaseReferences<
              _$AppDatabase,
              $InstallmentPlanEntriesTable,
              InstallmentPlanEntity
            >,
          ),
          InstallmentPlanEntity,
          PrefetchHooks Function()
        > {
  $$InstallmentPlanEntriesTableTableManager(
    _$AppDatabase db,
    $InstallmentPlanEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InstallmentPlanEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$InstallmentPlanEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$InstallmentPlanEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> originalTransactionId = const Value.absent(),
                Value<int> totalAmountInCents = const Value.absent(),
                Value<int> totalPeriods = const Value.absent(),
                Value<int> currentPeriod = const Value.absent(),
                Value<int> principalPerPeriodInCents = const Value.absent(),
                Value<int> feePerPeriodInCents = const Value.absent(),
                Value<DateTime> startDate = const Value.absent(),
                Value<int> dueDay = const Value.absent(),
                Value<String> creditAccountId = const Value.absent(),
                Value<String> repaymentAccountId = const Value.absent(),
                Value<int> remainingPrincipalInCents = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InstallmentPlanEntriesCompanion(
                id: id,
                bookId: bookId,
                name: name,
                originalTransactionId: originalTransactionId,
                totalAmountInCents: totalAmountInCents,
                totalPeriods: totalPeriods,
                currentPeriod: currentPeriod,
                principalPerPeriodInCents: principalPerPeriodInCents,
                feePerPeriodInCents: feePerPeriodInCents,
                startDate: startDate,
                dueDay: dueDay,
                creditAccountId: creditAccountId,
                repaymentAccountId: repaymentAccountId,
                remainingPrincipalInCents: remainingPrincipalInCents,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required String name,
                required String originalTransactionId,
                required int totalAmountInCents,
                required int totalPeriods,
                required int currentPeriod,
                required int principalPerPeriodInCents,
                required int feePerPeriodInCents,
                required DateTime startDate,
                required int dueDay,
                required String creditAccountId,
                required String repaymentAccountId,
                required int remainingPrincipalInCents,
                Value<String> status = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => InstallmentPlanEntriesCompanion.insert(
                id: id,
                bookId: bookId,
                name: name,
                originalTransactionId: originalTransactionId,
                totalAmountInCents: totalAmountInCents,
                totalPeriods: totalPeriods,
                currentPeriod: currentPeriod,
                principalPerPeriodInCents: principalPerPeriodInCents,
                feePerPeriodInCents: feePerPeriodInCents,
                startDate: startDate,
                dueDay: dueDay,
                creditAccountId: creditAccountId,
                repaymentAccountId: repaymentAccountId,
                remainingPrincipalInCents: remainingPrincipalInCents,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InstallmentPlanEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InstallmentPlanEntriesTable,
      InstallmentPlanEntity,
      $$InstallmentPlanEntriesTableFilterComposer,
      $$InstallmentPlanEntriesTableOrderingComposer,
      $$InstallmentPlanEntriesTableAnnotationComposer,
      $$InstallmentPlanEntriesTableCreateCompanionBuilder,
      $$InstallmentPlanEntriesTableUpdateCompanionBuilder,
      (
        InstallmentPlanEntity,
        BaseReferences<
          _$AppDatabase,
          $InstallmentPlanEntriesTable,
          InstallmentPlanEntity
        >,
      ),
      InstallmentPlanEntity,
      PrefetchHooks Function()
    >;
typedef $$MerchantRuleEntriesTableCreateCompanionBuilder =
    MerchantRuleEntriesCompanion Function({
      required String id,
      Value<String> bookId,
      required String merchantPattern,
      required String normalizedPattern,
      required String matchType,
      required String categoryId,
      Value<String?> subcategoryId,
      Value<String?> userId,
      required double confidence,
      required String source,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$MerchantRuleEntriesTableUpdateCompanionBuilder =
    MerchantRuleEntriesCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String> merchantPattern,
      Value<String> normalizedPattern,
      Value<String> matchType,
      Value<String> categoryId,
      Value<String?> subcategoryId,
      Value<String?> userId,
      Value<double> confidence,
      Value<String> source,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$MerchantRuleEntriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $MerchantRuleEntriesTable,
          MerchantRuleEntity
        > {
  $$MerchantRuleEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CategoryEntriesTable _categoryIdTable(_$AppDatabase db) => db
      .categoryEntries
      .createAlias('merchant_rules__category_id__categories__id');

  $$CategoryEntriesTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<String>('category_id')!;

    final manager = $$CategoryEntriesTableTableManager(
      $_db,
      $_db.categoryEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CategoryEntriesTable _subcategoryIdTable(_$AppDatabase db) => db
      .categoryEntries
      .createAlias('merchant_rules__subcategory_id__categories__id');

  $$CategoryEntriesTableProcessedTableManager? get subcategoryId {
    final $_column = $_itemColumn<String>('subcategory_id');
    if ($_column == null) return null;
    final manager = $$CategoryEntriesTableTableManager(
      $_db,
      $_db.categoryEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_subcategoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MerchantRuleEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $MerchantRuleEntriesTable> {
  $$MerchantRuleEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get merchantPattern => $composableBuilder(
    column: $table.merchantPattern,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedPattern => $composableBuilder(
    column: $table.normalizedPattern,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get matchType => $composableBuilder(
    column: $table.matchType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CategoryEntriesTableFilterComposer get categoryId {
    final $$CategoryEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categoryEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryEntriesTableFilterComposer(
            $db: $db,
            $table: $db.categoryEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoryEntriesTableFilterComposer get subcategoryId {
    final $$CategoryEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subcategoryId,
      referencedTable: $db.categoryEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryEntriesTableFilterComposer(
            $db: $db,
            $table: $db.categoryEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MerchantRuleEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $MerchantRuleEntriesTable> {
  $$MerchantRuleEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get merchantPattern => $composableBuilder(
    column: $table.merchantPattern,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedPattern => $composableBuilder(
    column: $table.normalizedPattern,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get matchType => $composableBuilder(
    column: $table.matchType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CategoryEntriesTableOrderingComposer get categoryId {
    final $$CategoryEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categoryEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.categoryEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoryEntriesTableOrderingComposer get subcategoryId {
    final $$CategoryEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subcategoryId,
      referencedTable: $db.categoryEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.categoryEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MerchantRuleEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MerchantRuleEntriesTable> {
  $$MerchantRuleEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get merchantPattern => $composableBuilder(
    column: $table.merchantPattern,
    builder: (column) => column,
  );

  GeneratedColumn<String> get normalizedPattern => $composableBuilder(
    column: $table.normalizedPattern,
    builder: (column) => column,
  );

  GeneratedColumn<String> get matchType =>
      $composableBuilder(column: $table.matchType, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$CategoryEntriesTableAnnotationComposer get categoryId {
    final $$CategoryEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categoryEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categoryEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoryEntriesTableAnnotationComposer get subcategoryId {
    final $$CategoryEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.subcategoryId,
      referencedTable: $db.categoryEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categoryEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MerchantRuleEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MerchantRuleEntriesTable,
          MerchantRuleEntity,
          $$MerchantRuleEntriesTableFilterComposer,
          $$MerchantRuleEntriesTableOrderingComposer,
          $$MerchantRuleEntriesTableAnnotationComposer,
          $$MerchantRuleEntriesTableCreateCompanionBuilder,
          $$MerchantRuleEntriesTableUpdateCompanionBuilder,
          (MerchantRuleEntity, $$MerchantRuleEntriesTableReferences),
          MerchantRuleEntity,
          PrefetchHooks Function({bool categoryId, bool subcategoryId})
        > {
  $$MerchantRuleEntriesTableTableManager(
    _$AppDatabase db,
    $MerchantRuleEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MerchantRuleEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MerchantRuleEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MerchantRuleEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> merchantPattern = const Value.absent(),
                Value<String> normalizedPattern = const Value.absent(),
                Value<String> matchType = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<String?> subcategoryId = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MerchantRuleEntriesCompanion(
                id: id,
                bookId: bookId,
                merchantPattern: merchantPattern,
                normalizedPattern: normalizedPattern,
                matchType: matchType,
                categoryId: categoryId,
                subcategoryId: subcategoryId,
                userId: userId,
                confidence: confidence,
                source: source,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> bookId = const Value.absent(),
                required String merchantPattern,
                required String normalizedPattern,
                required String matchType,
                required String categoryId,
                Value<String?> subcategoryId = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                required double confidence,
                required String source,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MerchantRuleEntriesCompanion.insert(
                id: id,
                bookId: bookId,
                merchantPattern: merchantPattern,
                normalizedPattern: normalizedPattern,
                matchType: matchType,
                categoryId: categoryId,
                subcategoryId: subcategoryId,
                userId: userId,
                confidence: confidence,
                source: source,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MerchantRuleEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false, subcategoryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (categoryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.categoryId,
                        referencedTable: $$MerchantRuleEntriesTableReferences
                            ._categoryIdTable(db),
                        referencedColumn: $$MerchantRuleEntriesTableReferences
                            ._categoryIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (subcategoryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.subcategoryId,
                        referencedTable: $$MerchantRuleEntriesTableReferences
                            ._subcategoryIdTable(db),
                        referencedColumn: $$MerchantRuleEntriesTableReferences
                            ._subcategoryIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MerchantRuleEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MerchantRuleEntriesTable,
      MerchantRuleEntity,
      $$MerchantRuleEntriesTableFilterComposer,
      $$MerchantRuleEntriesTableOrderingComposer,
      $$MerchantRuleEntriesTableAnnotationComposer,
      $$MerchantRuleEntriesTableCreateCompanionBuilder,
      $$MerchantRuleEntriesTableUpdateCompanionBuilder,
      (MerchantRuleEntity, $$MerchantRuleEntriesTableReferences),
      MerchantRuleEntity,
      PrefetchHooks Function({bool categoryId, bool subcategoryId})
    >;
typedef $$EconomicEventEntriesTableCreateCompanionBuilder =
    EconomicEventEntriesCompanion Function({
      required String id,
      required String bookId,
      required int amountInCents,
      Value<String> currency,
      required DateTime occurredAt,
      Value<String> status,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$EconomicEventEntriesTableUpdateCompanionBuilder =
    EconomicEventEntriesCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<int> amountInCents,
      Value<String> currency,
      Value<DateTime> occurredAt,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$EconomicEventEntriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $EconomicEventEntriesTable,
          EconomicEventEntity
        > {
  $$EconomicEventEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $EconomicEventRecordEntriesTable,
    List<EconomicEventRecordEntity>
  >
  _economicEventRecordEntriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.economicEventRecordEntries,
        aliasName: 'economic_events__id__economic_event_records__event_id',
      );

  $$EconomicEventRecordEntriesTableProcessedTableManager
  get economicEventRecordEntriesRefs {
    final manager = $$EconomicEventRecordEntriesTableTableManager(
      $_db,
      $_db.economicEventRecordEntries,
    ).filter((f) => f.eventId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _economicEventRecordEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$EconomicEventEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $EconomicEventEntriesTable> {
  $$EconomicEventEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountInCents => $composableBuilder(
    column: $table.amountInCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> economicEventRecordEntriesRefs(
    Expression<bool> Function($$EconomicEventRecordEntriesTableFilterComposer f)
    f,
  ) {
    final $$EconomicEventRecordEntriesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.economicEventRecordEntries,
          getReferencedColumn: (t) => t.eventId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$EconomicEventRecordEntriesTableFilterComposer(
                $db: $db,
                $table: $db.economicEventRecordEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$EconomicEventEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $EconomicEventEntriesTable> {
  $$EconomicEventEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountInCents => $composableBuilder(
    column: $table.amountInCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EconomicEventEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EconomicEventEntriesTable> {
  $$EconomicEventEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<int> get amountInCents => $composableBuilder(
    column: $table.amountInCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> economicEventRecordEntriesRefs<T extends Object>(
    Expression<T> Function(
      $$EconomicEventRecordEntriesTableAnnotationComposer a,
    )
    f,
  ) {
    final $$EconomicEventRecordEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.economicEventRecordEntries,
          getReferencedColumn: (t) => t.eventId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$EconomicEventRecordEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.economicEventRecordEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$EconomicEventEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EconomicEventEntriesTable,
          EconomicEventEntity,
          $$EconomicEventEntriesTableFilterComposer,
          $$EconomicEventEntriesTableOrderingComposer,
          $$EconomicEventEntriesTableAnnotationComposer,
          $$EconomicEventEntriesTableCreateCompanionBuilder,
          $$EconomicEventEntriesTableUpdateCompanionBuilder,
          (EconomicEventEntity, $$EconomicEventEntriesTableReferences),
          EconomicEventEntity,
          PrefetchHooks Function({bool economicEventRecordEntriesRefs})
        > {
  $$EconomicEventEntriesTableTableManager(
    _$AppDatabase db,
    $EconomicEventEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EconomicEventEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EconomicEventEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$EconomicEventEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<int> amountInCents = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EconomicEventEntriesCompanion(
                id: id,
                bookId: bookId,
                amountInCents: amountInCents,
                currency: currency,
                occurredAt: occurredAt,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required int amountInCents,
                Value<String> currency = const Value.absent(),
                required DateTime occurredAt,
                Value<String> status = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => EconomicEventEntriesCompanion.insert(
                id: id,
                bookId: bookId,
                amountInCents: amountInCents,
                currency: currency,
                occurredAt: occurredAt,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EconomicEventEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({economicEventRecordEntriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (economicEventRecordEntriesRefs)
                  db.economicEventRecordEntries,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (economicEventRecordEntriesRefs)
                    await $_getPrefetchedData<
                      EconomicEventEntity,
                      $EconomicEventEntriesTable,
                      EconomicEventRecordEntity
                    >(
                      currentTable: table,
                      referencedTable: $$EconomicEventEntriesTableReferences
                          ._economicEventRecordEntriesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$EconomicEventEntriesTableReferences(
                            db,
                            table,
                            p0,
                          ).economicEventRecordEntriesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.eventId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$EconomicEventEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EconomicEventEntriesTable,
      EconomicEventEntity,
      $$EconomicEventEntriesTableFilterComposer,
      $$EconomicEventEntriesTableOrderingComposer,
      $$EconomicEventEntriesTableAnnotationComposer,
      $$EconomicEventEntriesTableCreateCompanionBuilder,
      $$EconomicEventEntriesTableUpdateCompanionBuilder,
      (EconomicEventEntity, $$EconomicEventEntriesTableReferences),
      EconomicEventEntity,
      PrefetchHooks Function({bool economicEventRecordEntriesRefs})
    >;
typedef $$EconomicEventRecordEntriesTableCreateCompanionBuilder =
    EconomicEventRecordEntriesCompanion Function({
      required String id,
      required String eventId,
      required String transactionId,
      Value<String> role,
      required String fingerprint,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$EconomicEventRecordEntriesTableUpdateCompanionBuilder =
    EconomicEventRecordEntriesCompanion Function({
      Value<String> id,
      Value<String> eventId,
      Value<String> transactionId,
      Value<String> role,
      Value<String> fingerprint,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$EconomicEventRecordEntriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $EconomicEventRecordEntriesTable,
          EconomicEventRecordEntity
        > {
  $$EconomicEventRecordEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $EconomicEventEntriesTable _eventIdTable(_$AppDatabase db) => db
      .economicEventEntries
      .createAlias('economic_event_records__event_id__economic_events__id');

  $$EconomicEventEntriesTableProcessedTableManager get eventId {
    final $_column = $_itemColumn<String>('event_id')!;

    final manager = $$EconomicEventEntriesTableTableManager(
      $_db,
      $_db.economicEventEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_eventIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TransactionEntriesTable _transactionIdTable(_$AppDatabase db) => db
      .transactionEntries
      .createAlias('economic_event_records__transaction_id__transactions__id');

  $$TransactionEntriesTableProcessedTableManager get transactionId {
    final $_column = $_itemColumn<String>('transaction_id')!;

    final manager = $$TransactionEntriesTableTableManager(
      $_db,
      $_db.transactionEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_transactionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EconomicEventRecordEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $EconomicEventRecordEntriesTable> {
  $$EconomicEventRecordEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$EconomicEventEntriesTableFilterComposer get eventId {
    final $$EconomicEventEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.economicEventEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EconomicEventEntriesTableFilterComposer(
            $db: $db,
            $table: $db.economicEventEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransactionEntriesTableFilterComposer get transactionId {
    final $$TransactionEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactionEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionEntriesTableFilterComposer(
            $db: $db,
            $table: $db.transactionEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EconomicEventRecordEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $EconomicEventRecordEntriesTable> {
  $$EconomicEventRecordEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$EconomicEventEntriesTableOrderingComposer get eventId {
    final $$EconomicEventEntriesTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.eventId,
          referencedTable: $db.economicEventEntries,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$EconomicEventEntriesTableOrderingComposer(
                $db: $db,
                $table: $db.economicEventEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$TransactionEntriesTableOrderingComposer get transactionId {
    final $$TransactionEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactionEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.transactionEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EconomicEventRecordEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EconomicEventRecordEntriesTable> {
  $$EconomicEventRecordEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$EconomicEventEntriesTableAnnotationComposer get eventId {
    final $$EconomicEventEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.eventId,
          referencedTable: $db.economicEventEntries,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$EconomicEventEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.economicEventEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$TransactionEntriesTableAnnotationComposer get transactionId {
    final $$TransactionEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.transactionId,
          referencedTable: $db.transactionEntries,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TransactionEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.transactionEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$EconomicEventRecordEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EconomicEventRecordEntriesTable,
          EconomicEventRecordEntity,
          $$EconomicEventRecordEntriesTableFilterComposer,
          $$EconomicEventRecordEntriesTableOrderingComposer,
          $$EconomicEventRecordEntriesTableAnnotationComposer,
          $$EconomicEventRecordEntriesTableCreateCompanionBuilder,
          $$EconomicEventRecordEntriesTableUpdateCompanionBuilder,
          (
            EconomicEventRecordEntity,
            $$EconomicEventRecordEntriesTableReferences,
          ),
          EconomicEventRecordEntity,
          PrefetchHooks Function({bool eventId, bool transactionId})
        > {
  $$EconomicEventRecordEntriesTableTableManager(
    _$AppDatabase db,
    $EconomicEventRecordEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EconomicEventRecordEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$EconomicEventRecordEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$EconomicEventRecordEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> eventId = const Value.absent(),
                Value<String> transactionId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> fingerprint = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EconomicEventRecordEntriesCompanion(
                id: id,
                eventId: eventId,
                transactionId: transactionId,
                role: role,
                fingerprint: fingerprint,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String eventId,
                required String transactionId,
                Value<String> role = const Value.absent(),
                required String fingerprint,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => EconomicEventRecordEntriesCompanion.insert(
                id: id,
                eventId: eventId,
                transactionId: transactionId,
                role: role,
                fingerprint: fingerprint,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EconomicEventRecordEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({eventId = false, transactionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (eventId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.eventId,
                        referencedTable:
                            $$EconomicEventRecordEntriesTableReferences
                                ._eventIdTable(db),
                        referencedColumn:
                            $$EconomicEventRecordEntriesTableReferences
                                ._eventIdTable(db)
                                .id,
                      ) as T;
                    }
                    if (transactionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.transactionId,
                        referencedTable:
                            $$EconomicEventRecordEntriesTableReferences
                                ._transactionIdTable(db),
                        referencedColumn:
                            $$EconomicEventRecordEntriesTableReferences
                                ._transactionIdTable(db)
                                .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EconomicEventRecordEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EconomicEventRecordEntriesTable,
      EconomicEventRecordEntity,
      $$EconomicEventRecordEntriesTableFilterComposer,
      $$EconomicEventRecordEntriesTableOrderingComposer,
      $$EconomicEventRecordEntriesTableAnnotationComposer,
      $$EconomicEventRecordEntriesTableCreateCompanionBuilder,
      $$EconomicEventRecordEntriesTableUpdateCompanionBuilder,
      (EconomicEventRecordEntity, $$EconomicEventRecordEntriesTableReferences),
      EconomicEventRecordEntity,
      PrefetchHooks Function({bool eventId, bool transactionId})
    >;
typedef $$InboxItemEntriesTableCreateCompanionBuilder =
    InboxItemEntriesCompanion Function({
      required String id,
      Value<String> bookId,
      Value<String?> transactionId,
      Value<String?> candidateTransactionId,
      required String reason,
      Value<String> status,
      Value<double?> duplicateConfidence,
      Value<String?> payloadJson,
      required DateTime createdAt,
      Value<DateTime?> resolvedAt,
      Value<int> rowid,
    });
typedef $$InboxItemEntriesTableUpdateCompanionBuilder =
    InboxItemEntriesCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String?> transactionId,
      Value<String?> candidateTransactionId,
      Value<String> reason,
      Value<String> status,
      Value<double?> duplicateConfidence,
      Value<String?> payloadJson,
      Value<DateTime> createdAt,
      Value<DateTime?> resolvedAt,
      Value<int> rowid,
    });

final class $$InboxItemEntriesTableReferences
    extends
        BaseReferences<_$AppDatabase, $InboxItemEntriesTable, InboxItemEntity> {
  $$InboxItemEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TransactionEntriesTable _transactionIdTable(_$AppDatabase db) => db
      .transactionEntries
      .createAlias('inbox_items__transaction_id__transactions__id');

  $$TransactionEntriesTableProcessedTableManager? get transactionId {
    final $_column = $_itemColumn<String>('transaction_id');
    if ($_column == null) return null;
    final manager = $$TransactionEntriesTableTableManager(
      $_db,
      $_db.transactionEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_transactionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TransactionEntriesTable _candidateTransactionIdTable(
    _$AppDatabase db,
  ) => db.transactionEntries.createAlias(
    'inbox_items__candidate_transaction_id__transactions__id',
  );

  $$TransactionEntriesTableProcessedTableManager? get candidateTransactionId {
    final $_column = $_itemColumn<String>('candidate_transaction_id');
    if ($_column == null) return null;
    final manager = $$TransactionEntriesTableTableManager(
      $_db,
      $_db.transactionEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(
      _candidateTransactionIdTable($_db),
    );
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$InboxItemEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $InboxItemEntriesTable> {
  $$InboxItemEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get duplicateConfidence => $composableBuilder(
    column: $table.duplicateConfidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TransactionEntriesTableFilterComposer get transactionId {
    final $$TransactionEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactionEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionEntriesTableFilterComposer(
            $db: $db,
            $table: $db.transactionEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransactionEntriesTableFilterComposer get candidateTransactionId {
    final $$TransactionEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.candidateTransactionId,
      referencedTable: $db.transactionEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionEntriesTableFilterComposer(
            $db: $db,
            $table: $db.transactionEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InboxItemEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $InboxItemEntriesTable> {
  $$InboxItemEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get duplicateConfidence => $composableBuilder(
    column: $table.duplicateConfidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TransactionEntriesTableOrderingComposer get transactionId {
    final $$TransactionEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactionEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.transactionEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TransactionEntriesTableOrderingComposer get candidateTransactionId {
    final $$TransactionEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.candidateTransactionId,
      referencedTable: $db.transactionEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.transactionEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InboxItemEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $InboxItemEntriesTable> {
  $$InboxItemEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<double> get duplicateConfidence => $composableBuilder(
    column: $table.duplicateConfidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => column,
  );

  $$TransactionEntriesTableAnnotationComposer get transactionId {
    final $$TransactionEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.transactionId,
          referencedTable: $db.transactionEntries,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TransactionEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.transactionEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$TransactionEntriesTableAnnotationComposer get candidateTransactionId {
    final $$TransactionEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.candidateTransactionId,
          referencedTable: $db.transactionEntries,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TransactionEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.transactionEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$InboxItemEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InboxItemEntriesTable,
          InboxItemEntity,
          $$InboxItemEntriesTableFilterComposer,
          $$InboxItemEntriesTableOrderingComposer,
          $$InboxItemEntriesTableAnnotationComposer,
          $$InboxItemEntriesTableCreateCompanionBuilder,
          $$InboxItemEntriesTableUpdateCompanionBuilder,
          (InboxItemEntity, $$InboxItemEntriesTableReferences),
          InboxItemEntity,
          PrefetchHooks Function({
            bool transactionId,
            bool candidateTransactionId,
          })
        > {
  $$InboxItemEntriesTableTableManager(
    _$AppDatabase db,
    $InboxItemEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InboxItemEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InboxItemEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InboxItemEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String?> transactionId = const Value.absent(),
                Value<String?> candidateTransactionId = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<double?> duplicateConfidence = const Value.absent(),
                Value<String?> payloadJson = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> resolvedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InboxItemEntriesCompanion(
                id: id,
                bookId: bookId,
                transactionId: transactionId,
                candidateTransactionId: candidateTransactionId,
                reason: reason,
                status: status,
                duplicateConfidence: duplicateConfidence,
                payloadJson: payloadJson,
                createdAt: createdAt,
                resolvedAt: resolvedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> bookId = const Value.absent(),
                Value<String?> transactionId = const Value.absent(),
                Value<String?> candidateTransactionId = const Value.absent(),
                required String reason,
                Value<String> status = const Value.absent(),
                Value<double?> duplicateConfidence = const Value.absent(),
                Value<String?> payloadJson = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> resolvedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InboxItemEntriesCompanion.insert(
                id: id,
                bookId: bookId,
                transactionId: transactionId,
                candidateTransactionId: candidateTransactionId,
                reason: reason,
                status: status,
                duplicateConfidence: duplicateConfidence,
                payloadJson: payloadJson,
                createdAt: createdAt,
                resolvedAt: resolvedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$InboxItemEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({transactionId = false, candidateTransactionId = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (transactionId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.transactionId,
                            referencedTable: $$InboxItemEntriesTableReferences
                                ._transactionIdTable(db),
                            referencedColumn: $$InboxItemEntriesTableReferences
                                ._transactionIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (candidateTransactionId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.candidateTransactionId,
                            referencedTable: $$InboxItemEntriesTableReferences
                                ._candidateTransactionIdTable(db),
                            referencedColumn: $$InboxItemEntriesTableReferences
                                ._candidateTransactionIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [];
                  },
                );
              },
        ),
      );
}

typedef $$InboxItemEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InboxItemEntriesTable,
      InboxItemEntity,
      $$InboxItemEntriesTableFilterComposer,
      $$InboxItemEntriesTableOrderingComposer,
      $$InboxItemEntriesTableAnnotationComposer,
      $$InboxItemEntriesTableCreateCompanionBuilder,
      $$InboxItemEntriesTableUpdateCompanionBuilder,
      (InboxItemEntity, $$InboxItemEntriesTableReferences),
      InboxItemEntity,
      PrefetchHooks Function({bool transactionId, bool candidateTransactionId})
    >;
typedef $$FamilyEntriesTableCreateCompanionBuilder =
    FamilyEntriesCompanion Function({
      required String id,
      required String name,
      required String ownerUserId,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> version,
      Value<int> rowid,
    });
typedef $$FamilyEntriesTableUpdateCompanionBuilder =
    FamilyEntriesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> ownerUserId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> version,
      Value<int> rowid,
    });

final class $$FamilyEntriesTableReferences
    extends BaseReferences<_$AppDatabase, $FamilyEntriesTable, FamilyEntity> {
  $$FamilyEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$BookEntriesTable, List<BookEntity>>
  _bookEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.bookEntries,
    aliasName: 'families__id__books__family_id',
  );

  $$BookEntriesTableProcessedTableManager get bookEntriesRefs {
    final manager = $$BookEntriesTableTableManager(
      $_db,
      $_db.bookEntries,
    ).filter((f) => f.familyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_bookEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $FamilyMemberEntriesTable,
    List<FamilyMemberEntity>
  >
  _familyMemberEntriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.familyMemberEntries,
        aliasName: 'families__id__family_members__family_id',
      );

  $$FamilyMemberEntriesTableProcessedTableManager get familyMemberEntriesRefs {
    final manager = $$FamilyMemberEntriesTableTableManager(
      $_db,
      $_db.familyMemberEntries,
    ).filter((f) => f.familyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _familyMemberEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $FamilyInvitationEntriesTable,
    List<FamilyInvitationEntity>
  >
  _familyInvitationEntriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.familyInvitationEntries,
        aliasName: 'families__id__family_invitations__family_id',
      );

  $$FamilyInvitationEntriesTableProcessedTableManager
  get familyInvitationEntriesRefs {
    final manager = $$FamilyInvitationEntriesTableTableManager(
      $_db,
      $_db.familyInvitationEntries,
    ).filter((f) => f.familyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _familyInvitationEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $FamilyOperationLogEntriesTable,
    List<FamilyOperationLogEntity>
  >
  _familyOperationLogEntriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.familyOperationLogEntries,
        aliasName: 'families__id__family_operation_logs__family_id',
      );

  $$FamilyOperationLogEntriesTableProcessedTableManager
  get familyOperationLogEntriesRefs {
    final manager = $$FamilyOperationLogEntriesTableTableManager(
      $_db,
      $_db.familyOperationLogEntries,
    ).filter((f) => f.familyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _familyOperationLogEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FamilyEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $FamilyEntriesTable> {
  $$FamilyEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> bookEntriesRefs(
    Expression<bool> Function($$BookEntriesTableFilterComposer f) f,
  ) {
    final $$BookEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookEntries,
      getReferencedColumn: (t) => t.familyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookEntriesTableFilterComposer(
            $db: $db,
            $table: $db.bookEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> familyMemberEntriesRefs(
    Expression<bool> Function($$FamilyMemberEntriesTableFilterComposer f) f,
  ) {
    final $$FamilyMemberEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.familyMemberEntries,
      getReferencedColumn: (t) => t.familyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamilyMemberEntriesTableFilterComposer(
            $db: $db,
            $table: $db.familyMemberEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> familyInvitationEntriesRefs(
    Expression<bool> Function($$FamilyInvitationEntriesTableFilterComposer f) f,
  ) {
    final $$FamilyInvitationEntriesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.familyInvitationEntries,
          getReferencedColumn: (t) => t.familyId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FamilyInvitationEntriesTableFilterComposer(
                $db: $db,
                $table: $db.familyInvitationEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> familyOperationLogEntriesRefs(
    Expression<bool> Function($$FamilyOperationLogEntriesTableFilterComposer f)
    f,
  ) {
    final $$FamilyOperationLogEntriesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.familyOperationLogEntries,
          getReferencedColumn: (t) => t.familyId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FamilyOperationLogEntriesTableFilterComposer(
                $db: $db,
                $table: $db.familyOperationLogEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$FamilyEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $FamilyEntriesTable> {
  $$FamilyEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FamilyEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FamilyEntriesTable> {
  $$FamilyEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  Expression<T> bookEntriesRefs<T extends Object>(
    Expression<T> Function($$BookEntriesTableAnnotationComposer a) f,
  ) {
    final $$BookEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookEntries,
      getReferencedColumn: (t) => t.familyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.bookEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> familyMemberEntriesRefs<T extends Object>(
    Expression<T> Function($$FamilyMemberEntriesTableAnnotationComposer a) f,
  ) {
    final $$FamilyMemberEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.familyMemberEntries,
          getReferencedColumn: (t) => t.familyId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FamilyMemberEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.familyMemberEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> familyInvitationEntriesRefs<T extends Object>(
    Expression<T> Function($$FamilyInvitationEntriesTableAnnotationComposer a)
    f,
  ) {
    final $$FamilyInvitationEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.familyInvitationEntries,
          getReferencedColumn: (t) => t.familyId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FamilyInvitationEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.familyInvitationEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> familyOperationLogEntriesRefs<T extends Object>(
    Expression<T> Function($$FamilyOperationLogEntriesTableAnnotationComposer a)
    f,
  ) {
    final $$FamilyOperationLogEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.familyOperationLogEntries,
          getReferencedColumn: (t) => t.familyId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FamilyOperationLogEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.familyOperationLogEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$FamilyEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FamilyEntriesTable,
          FamilyEntity,
          $$FamilyEntriesTableFilterComposer,
          $$FamilyEntriesTableOrderingComposer,
          $$FamilyEntriesTableAnnotationComposer,
          $$FamilyEntriesTableCreateCompanionBuilder,
          $$FamilyEntriesTableUpdateCompanionBuilder,
          (FamilyEntity, $$FamilyEntriesTableReferences),
          FamilyEntity,
          PrefetchHooks Function({
            bool bookEntriesRefs,
            bool familyMemberEntriesRefs,
            bool familyInvitationEntriesRefs,
            bool familyOperationLogEntriesRefs,
          })
        > {
  $$FamilyEntriesTableTableManager(_$AppDatabase db, $FamilyEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FamilyEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FamilyEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FamilyEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> ownerUserId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FamilyEntriesCompanion(
                id: id,
                name: name,
                ownerUserId: ownerUserId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String ownerUserId,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FamilyEntriesCompanion.insert(
                id: id,
                name: name,
                ownerUserId: ownerUserId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FamilyEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                bookEntriesRefs = false,
                familyMemberEntriesRefs = false,
                familyInvitationEntriesRefs = false,
                familyOperationLogEntriesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (bookEntriesRefs) db.bookEntries,
                    if (familyMemberEntriesRefs) db.familyMemberEntries,
                    if (familyInvitationEntriesRefs) db.familyInvitationEntries,
                    if (familyOperationLogEntriesRefs)
                      db.familyOperationLogEntries,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (bookEntriesRefs)
                        await $_getPrefetchedData<
                          FamilyEntity,
                          $FamilyEntriesTable,
                          BookEntity
                        >(
                          currentTable: table,
                          referencedTable: $$FamilyEntriesTableReferences
                              ._bookEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FamilyEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).bookEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.familyId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (familyMemberEntriesRefs)
                        await $_getPrefetchedData<
                          FamilyEntity,
                          $FamilyEntriesTable,
                          FamilyMemberEntity
                        >(
                          currentTable: table,
                          referencedTable: $$FamilyEntriesTableReferences
                              ._familyMemberEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FamilyEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).familyMemberEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.familyId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (familyInvitationEntriesRefs)
                        await $_getPrefetchedData<
                          FamilyEntity,
                          $FamilyEntriesTable,
                          FamilyInvitationEntity
                        >(
                          currentTable: table,
                          referencedTable: $$FamilyEntriesTableReferences
                              ._familyInvitationEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FamilyEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).familyInvitationEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.familyId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (familyOperationLogEntriesRefs)
                        await $_getPrefetchedData<
                          FamilyEntity,
                          $FamilyEntriesTable,
                          FamilyOperationLogEntity
                        >(
                          currentTable: table,
                          referencedTable: $$FamilyEntriesTableReferences
                              ._familyOperationLogEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FamilyEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).familyOperationLogEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.familyId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$FamilyEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FamilyEntriesTable,
      FamilyEntity,
      $$FamilyEntriesTableFilterComposer,
      $$FamilyEntriesTableOrderingComposer,
      $$FamilyEntriesTableAnnotationComposer,
      $$FamilyEntriesTableCreateCompanionBuilder,
      $$FamilyEntriesTableUpdateCompanionBuilder,
      (FamilyEntity, $$FamilyEntriesTableReferences),
      FamilyEntity,
      PrefetchHooks Function({
        bool bookEntriesRefs,
        bool familyMemberEntriesRefs,
        bool familyInvitationEntriesRefs,
        bool familyOperationLogEntriesRefs,
      })
    >;
typedef $$BookEntriesTableCreateCompanionBuilder =
    BookEntriesCompanion Function({
      required String id,
      required String name,
      required String type,
      required String ownerUserId,
      Value<String?> familyId,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<bool> isArchived,
      Value<String?> assetSourceBookId,
      Value<int> version,
      Value<int> rowid,
    });
typedef $$BookEntriesTableUpdateCompanionBuilder =
    BookEntriesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> type,
      Value<String> ownerUserId,
      Value<String?> familyId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isArchived,
      Value<String?> assetSourceBookId,
      Value<int> version,
      Value<int> rowid,
    });

final class $$BookEntriesTableReferences
    extends BaseReferences<_$AppDatabase, $BookEntriesTable, BookEntity> {
  $$BookEntriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FamilyEntriesTable _familyIdTable(_$AppDatabase db) =>
      db.familyEntries.createAlias('books__family_id__families__id');

  $$FamilyEntriesTableProcessedTableManager? get familyId {
    final $_column = $_itemColumn<String>('family_id');
    if ($_column == null) return null;
    final manager = $$FamilyEntriesTableTableManager(
      $_db,
      $_db.familyEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_familyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $FamilyBudgetEntriesTable,
    List<FamilyBudgetEntity>
  >
  _familyBudgetEntriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.familyBudgetEntries,
        aliasName: 'books__id__family_budgets__book_id',
      );

  $$FamilyBudgetEntriesTableProcessedTableManager get familyBudgetEntriesRefs {
    final manager = $$FamilyBudgetEntriesTableTableManager(
      $_db,
      $_db.familyBudgetEntries,
    ).filter((f) => f.bookId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _familyBudgetEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BookEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $BookEntriesTable> {
  $$BookEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetSourceBookId => $composableBuilder(
    column: $table.assetSourceBookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  $$FamilyEntriesTableFilterComposer get familyId {
    final $$FamilyEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.familyEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamilyEntriesTableFilterComposer(
            $db: $db,
            $table: $db.familyEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> familyBudgetEntriesRefs(
    Expression<bool> Function($$FamilyBudgetEntriesTableFilterComposer f) f,
  ) {
    final $$FamilyBudgetEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.familyBudgetEntries,
      getReferencedColumn: (t) => t.bookId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamilyBudgetEntriesTableFilterComposer(
            $db: $db,
            $table: $db.familyBudgetEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BookEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $BookEntriesTable> {
  $$BookEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetSourceBookId => $composableBuilder(
    column: $table.assetSourceBookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  $$FamilyEntriesTableOrderingComposer get familyId {
    final $$FamilyEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.familyEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamilyEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.familyEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookEntriesTable> {
  $$BookEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get ownerUserId => $composableBuilder(
    column: $table.ownerUserId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isArchived => $composableBuilder(
    column: $table.isArchived,
    builder: (column) => column,
  );

  GeneratedColumn<String> get assetSourceBookId => $composableBuilder(
    column: $table.assetSourceBookId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  $$FamilyEntriesTableAnnotationComposer get familyId {
    final $$FamilyEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.familyEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamilyEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.familyEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> familyBudgetEntriesRefs<T extends Object>(
    Expression<T> Function($$FamilyBudgetEntriesTableAnnotationComposer a) f,
  ) {
    final $$FamilyBudgetEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.familyBudgetEntries,
          getReferencedColumn: (t) => t.bookId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FamilyBudgetEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.familyBudgetEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$BookEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookEntriesTable,
          BookEntity,
          $$BookEntriesTableFilterComposer,
          $$BookEntriesTableOrderingComposer,
          $$BookEntriesTableAnnotationComposer,
          $$BookEntriesTableCreateCompanionBuilder,
          $$BookEntriesTableUpdateCompanionBuilder,
          (BookEntity, $$BookEntriesTableReferences),
          BookEntity,
          PrefetchHooks Function({bool familyId, bool familyBudgetEntriesRefs})
        > {
  $$BookEntriesTableTableManager(_$AppDatabase db, $BookEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> ownerUserId = const Value.absent(),
                Value<String?> familyId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isArchived = const Value.absent(),
                Value<String?> assetSourceBookId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookEntriesCompanion(
                id: id,
                name: name,
                type: type,
                ownerUserId: ownerUserId,
                familyId: familyId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isArchived: isArchived,
                assetSourceBookId: assetSourceBookId,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String type,
                required String ownerUserId,
                Value<String?> familyId = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<bool> isArchived = const Value.absent(),
                Value<String?> assetSourceBookId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookEntriesCompanion.insert(
                id: id,
                name: name,
                type: type,
                ownerUserId: ownerUserId,
                familyId: familyId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isArchived: isArchived,
                assetSourceBookId: assetSourceBookId,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BookEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({familyId = false, familyBudgetEntriesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (familyBudgetEntriesRefs) db.familyBudgetEntries,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (familyId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.familyId,
                            referencedTable: $$BookEntriesTableReferences
                                ._familyIdTable(db),
                            referencedColumn: $$BookEntriesTableReferences
                                ._familyIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (familyBudgetEntriesRefs)
                        await $_getPrefetchedData<
                          BookEntity,
                          $BookEntriesTable,
                          FamilyBudgetEntity
                        >(
                          currentTable: table,
                          referencedTable: $$BookEntriesTableReferences
                              ._familyBudgetEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BookEntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).familyBudgetEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.bookId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$BookEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookEntriesTable,
      BookEntity,
      $$BookEntriesTableFilterComposer,
      $$BookEntriesTableOrderingComposer,
      $$BookEntriesTableAnnotationComposer,
      $$BookEntriesTableCreateCompanionBuilder,
      $$BookEntriesTableUpdateCompanionBuilder,
      (BookEntity, $$BookEntriesTableReferences),
      BookEntity,
      PrefetchHooks Function({bool familyId, bool familyBudgetEntriesRefs})
    >;
typedef $$FamilyMemberEntriesTableCreateCompanionBuilder =
    FamilyMemberEntriesCompanion Function({
      required String id,
      required String familyId,
      required String userId,
      required String role,
      required DateTime joinedAt,
      Value<int> rowid,
    });
typedef $$FamilyMemberEntriesTableUpdateCompanionBuilder =
    FamilyMemberEntriesCompanion Function({
      Value<String> id,
      Value<String> familyId,
      Value<String> userId,
      Value<String> role,
      Value<DateTime> joinedAt,
      Value<int> rowid,
    });

final class $$FamilyMemberEntriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $FamilyMemberEntriesTable,
          FamilyMemberEntity
        > {
  $$FamilyMemberEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $FamilyEntriesTable _familyIdTable(_$AppDatabase db) =>
      db.familyEntries.createAlias('family_members__family_id__families__id');

  $$FamilyEntriesTableProcessedTableManager get familyId {
    final $_column = $_itemColumn<String>('family_id')!;

    final manager = $$FamilyEntriesTableTableManager(
      $_db,
      $_db.familyEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_familyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FamilyMemberEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $FamilyMemberEntriesTable> {
  $$FamilyMemberEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get joinedAt => $composableBuilder(
    column: $table.joinedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$FamilyEntriesTableFilterComposer get familyId {
    final $$FamilyEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.familyEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamilyEntriesTableFilterComposer(
            $db: $db,
            $table: $db.familyEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FamilyMemberEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $FamilyMemberEntriesTable> {
  $$FamilyMemberEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get joinedAt => $composableBuilder(
    column: $table.joinedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$FamilyEntriesTableOrderingComposer get familyId {
    final $$FamilyEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.familyEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamilyEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.familyEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FamilyMemberEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FamilyMemberEntriesTable> {
  $$FamilyMemberEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<DateTime> get joinedAt =>
      $composableBuilder(column: $table.joinedAt, builder: (column) => column);

  $$FamilyEntriesTableAnnotationComposer get familyId {
    final $$FamilyEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.familyEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamilyEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.familyEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FamilyMemberEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FamilyMemberEntriesTable,
          FamilyMemberEntity,
          $$FamilyMemberEntriesTableFilterComposer,
          $$FamilyMemberEntriesTableOrderingComposer,
          $$FamilyMemberEntriesTableAnnotationComposer,
          $$FamilyMemberEntriesTableCreateCompanionBuilder,
          $$FamilyMemberEntriesTableUpdateCompanionBuilder,
          (FamilyMemberEntity, $$FamilyMemberEntriesTableReferences),
          FamilyMemberEntity,
          PrefetchHooks Function({bool familyId})
        > {
  $$FamilyMemberEntriesTableTableManager(
    _$AppDatabase db,
    $FamilyMemberEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FamilyMemberEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FamilyMemberEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$FamilyMemberEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> familyId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<DateTime> joinedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FamilyMemberEntriesCompanion(
                id: id,
                familyId: familyId,
                userId: userId,
                role: role,
                joinedAt: joinedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String familyId,
                required String userId,
                required String role,
                required DateTime joinedAt,
                Value<int> rowid = const Value.absent(),
              }) => FamilyMemberEntriesCompanion.insert(
                id: id,
                familyId: familyId,
                userId: userId,
                role: role,
                joinedAt: joinedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FamilyMemberEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({familyId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (familyId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.familyId,
                        referencedTable: $$FamilyMemberEntriesTableReferences
                            ._familyIdTable(db),
                        referencedColumn: $$FamilyMemberEntriesTableReferences
                            ._familyIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FamilyMemberEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FamilyMemberEntriesTable,
      FamilyMemberEntity,
      $$FamilyMemberEntriesTableFilterComposer,
      $$FamilyMemberEntriesTableOrderingComposer,
      $$FamilyMemberEntriesTableAnnotationComposer,
      $$FamilyMemberEntriesTableCreateCompanionBuilder,
      $$FamilyMemberEntriesTableUpdateCompanionBuilder,
      (FamilyMemberEntity, $$FamilyMemberEntriesTableReferences),
      FamilyMemberEntity,
      PrefetchHooks Function({bool familyId})
    >;
typedef $$FamilyInvitationEntriesTableCreateCompanionBuilder =
    FamilyInvitationEntriesCompanion Function({
      required String id,
      required String familyId,
      required String code,
      required String invitedBy,
      Value<String> status,
      required DateTime expiresAt,
      required DateTime createdAt,
      Value<DateTime?> resolvedAt,
      Value<int> rowid,
    });
typedef $$FamilyInvitationEntriesTableUpdateCompanionBuilder =
    FamilyInvitationEntriesCompanion Function({
      Value<String> id,
      Value<String> familyId,
      Value<String> code,
      Value<String> invitedBy,
      Value<String> status,
      Value<DateTime> expiresAt,
      Value<DateTime> createdAt,
      Value<DateTime?> resolvedAt,
      Value<int> rowid,
    });

final class $$FamilyInvitationEntriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $FamilyInvitationEntriesTable,
          FamilyInvitationEntity
        > {
  $$FamilyInvitationEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $FamilyEntriesTable _familyIdTable(_$AppDatabase db) => db
      .familyEntries
      .createAlias('family_invitations__family_id__families__id');

  $$FamilyEntriesTableProcessedTableManager get familyId {
    final $_column = $_itemColumn<String>('family_id')!;

    final manager = $$FamilyEntriesTableTableManager(
      $_db,
      $_db.familyEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_familyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FamilyInvitationEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $FamilyInvitationEntriesTable> {
  $$FamilyInvitationEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get invitedBy => $composableBuilder(
    column: $table.invitedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$FamilyEntriesTableFilterComposer get familyId {
    final $$FamilyEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.familyEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamilyEntriesTableFilterComposer(
            $db: $db,
            $table: $db.familyEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FamilyInvitationEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $FamilyInvitationEntriesTable> {
  $$FamilyInvitationEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get invitedBy => $composableBuilder(
    column: $table.invitedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$FamilyEntriesTableOrderingComposer get familyId {
    final $$FamilyEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.familyEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamilyEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.familyEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FamilyInvitationEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FamilyInvitationEntriesTable> {
  $$FamilyInvitationEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get invitedBy =>
      $composableBuilder(column: $table.invitedBy, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => column,
  );

  $$FamilyEntriesTableAnnotationComposer get familyId {
    final $$FamilyEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.familyEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamilyEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.familyEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FamilyInvitationEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FamilyInvitationEntriesTable,
          FamilyInvitationEntity,
          $$FamilyInvitationEntriesTableFilterComposer,
          $$FamilyInvitationEntriesTableOrderingComposer,
          $$FamilyInvitationEntriesTableAnnotationComposer,
          $$FamilyInvitationEntriesTableCreateCompanionBuilder,
          $$FamilyInvitationEntriesTableUpdateCompanionBuilder,
          (FamilyInvitationEntity, $$FamilyInvitationEntriesTableReferences),
          FamilyInvitationEntity,
          PrefetchHooks Function({bool familyId})
        > {
  $$FamilyInvitationEntriesTableTableManager(
    _$AppDatabase db,
    $FamilyInvitationEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FamilyInvitationEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$FamilyInvitationEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$FamilyInvitationEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> familyId = const Value.absent(),
                Value<String> code = const Value.absent(),
                Value<String> invitedBy = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> expiresAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> resolvedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FamilyInvitationEntriesCompanion(
                id: id,
                familyId: familyId,
                code: code,
                invitedBy: invitedBy,
                status: status,
                expiresAt: expiresAt,
                createdAt: createdAt,
                resolvedAt: resolvedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String familyId,
                required String code,
                required String invitedBy,
                Value<String> status = const Value.absent(),
                required DateTime expiresAt,
                required DateTime createdAt,
                Value<DateTime?> resolvedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FamilyInvitationEntriesCompanion.insert(
                id: id,
                familyId: familyId,
                code: code,
                invitedBy: invitedBy,
                status: status,
                expiresAt: expiresAt,
                createdAt: createdAt,
                resolvedAt: resolvedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FamilyInvitationEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({familyId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (familyId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.familyId,
                        referencedTable:
                            $$FamilyInvitationEntriesTableReferences
                                ._familyIdTable(db),
                        referencedColumn:
                            $$FamilyInvitationEntriesTableReferences
                                ._familyIdTable(db)
                                .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FamilyInvitationEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FamilyInvitationEntriesTable,
      FamilyInvitationEntity,
      $$FamilyInvitationEntriesTableFilterComposer,
      $$FamilyInvitationEntriesTableOrderingComposer,
      $$FamilyInvitationEntriesTableAnnotationComposer,
      $$FamilyInvitationEntriesTableCreateCompanionBuilder,
      $$FamilyInvitationEntriesTableUpdateCompanionBuilder,
      (FamilyInvitationEntity, $$FamilyInvitationEntriesTableReferences),
      FamilyInvitationEntity,
      PrefetchHooks Function({bool familyId})
    >;
typedef $$FamilyOperationLogEntriesTableCreateCompanionBuilder =
    FamilyOperationLogEntriesCompanion Function({
      required String id,
      required String familyId,
      required String actorUserId,
      required String entityType,
      required String entityId,
      required String action,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$FamilyOperationLogEntriesTableUpdateCompanionBuilder =
    FamilyOperationLogEntriesCompanion Function({
      Value<String> id,
      Value<String> familyId,
      Value<String> actorUserId,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> action,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$FamilyOperationLogEntriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $FamilyOperationLogEntriesTable,
          FamilyOperationLogEntity
        > {
  $$FamilyOperationLogEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $FamilyEntriesTable _familyIdTable(_$AppDatabase db) => db
      .familyEntries
      .createAlias('family_operation_logs__family_id__families__id');

  $$FamilyEntriesTableProcessedTableManager get familyId {
    final $_column = $_itemColumn<String>('family_id')!;

    final manager = $$FamilyEntriesTableTableManager(
      $_db,
      $_db.familyEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_familyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FamilyOperationLogEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $FamilyOperationLogEntriesTable> {
  $$FamilyOperationLogEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorUserId => $composableBuilder(
    column: $table.actorUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$FamilyEntriesTableFilterComposer get familyId {
    final $$FamilyEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.familyEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamilyEntriesTableFilterComposer(
            $db: $db,
            $table: $db.familyEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FamilyOperationLogEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $FamilyOperationLogEntriesTable> {
  $$FamilyOperationLogEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorUserId => $composableBuilder(
    column: $table.actorUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get action => $composableBuilder(
    column: $table.action,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$FamilyEntriesTableOrderingComposer get familyId {
    final $$FamilyEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.familyEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamilyEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.familyEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FamilyOperationLogEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FamilyOperationLogEntriesTable> {
  $$FamilyOperationLogEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get actorUserId => $composableBuilder(
    column: $table.actorUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get action =>
      $composableBuilder(column: $table.action, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$FamilyEntriesTableAnnotationComposer get familyId {
    final $$FamilyEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.familyId,
      referencedTable: $db.familyEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FamilyEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.familyEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FamilyOperationLogEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FamilyOperationLogEntriesTable,
          FamilyOperationLogEntity,
          $$FamilyOperationLogEntriesTableFilterComposer,
          $$FamilyOperationLogEntriesTableOrderingComposer,
          $$FamilyOperationLogEntriesTableAnnotationComposer,
          $$FamilyOperationLogEntriesTableCreateCompanionBuilder,
          $$FamilyOperationLogEntriesTableUpdateCompanionBuilder,
          (
            FamilyOperationLogEntity,
            $$FamilyOperationLogEntriesTableReferences,
          ),
          FamilyOperationLogEntity,
          PrefetchHooks Function({bool familyId})
        > {
  $$FamilyOperationLogEntriesTableTableManager(
    _$AppDatabase db,
    $FamilyOperationLogEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FamilyOperationLogEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$FamilyOperationLogEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$FamilyOperationLogEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> familyId = const Value.absent(),
                Value<String> actorUserId = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> action = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FamilyOperationLogEntriesCompanion(
                id: id,
                familyId: familyId,
                actorUserId: actorUserId,
                entityType: entityType,
                entityId: entityId,
                action: action,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String familyId,
                required String actorUserId,
                required String entityType,
                required String entityId,
                required String action,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => FamilyOperationLogEntriesCompanion.insert(
                id: id,
                familyId: familyId,
                actorUserId: actorUserId,
                entityType: entityType,
                entityId: entityId,
                action: action,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FamilyOperationLogEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({familyId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (familyId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.familyId,
                        referencedTable:
                            $$FamilyOperationLogEntriesTableReferences
                                ._familyIdTable(db),
                        referencedColumn:
                            $$FamilyOperationLogEntriesTableReferences
                                ._familyIdTable(db)
                                .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FamilyOperationLogEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FamilyOperationLogEntriesTable,
      FamilyOperationLogEntity,
      $$FamilyOperationLogEntriesTableFilterComposer,
      $$FamilyOperationLogEntriesTableOrderingComposer,
      $$FamilyOperationLogEntriesTableAnnotationComposer,
      $$FamilyOperationLogEntriesTableCreateCompanionBuilder,
      $$FamilyOperationLogEntriesTableUpdateCompanionBuilder,
      (FamilyOperationLogEntity, $$FamilyOperationLogEntriesTableReferences),
      FamilyOperationLogEntity,
      PrefetchHooks Function({bool familyId})
    >;
typedef $$FamilyBudgetEntriesTableCreateCompanionBuilder =
    FamilyBudgetEntriesCompanion Function({
      required String id,
      required String bookId,
      required String monthKey,
      Value<String?> categoryId,
      required int amountInCents,
      Value<String> visibility,
      required String createdBy,
      required String updatedBy,
      Value<int> version,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$FamilyBudgetEntriesTableUpdateCompanionBuilder =
    FamilyBudgetEntriesCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String> monthKey,
      Value<String?> categoryId,
      Value<int> amountInCents,
      Value<String> visibility,
      Value<String> createdBy,
      Value<String> updatedBy,
      Value<int> version,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$FamilyBudgetEntriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $FamilyBudgetEntriesTable,
          FamilyBudgetEntity
        > {
  $$FamilyBudgetEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $BookEntriesTable _bookIdTable(_$AppDatabase db) =>
      db.bookEntries.createAlias('family_budgets__book_id__books__id');

  $$BookEntriesTableProcessedTableManager get bookId {
    final $_column = $_itemColumn<String>('book_id')!;

    final manager = $$BookEntriesTableTableManager(
      $_db,
      $_db.bookEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_bookIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CategoryEntriesTable _categoryIdTable(_$AppDatabase db) => db
      .categoryEntries
      .createAlias('family_budgets__category_id__categories__id');

  $$CategoryEntriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<String>('category_id');
    if ($_column == null) return null;
    final manager = $$CategoryEntriesTableTableManager(
      $_db,
      $_db.categoryEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FamilyBudgetEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $FamilyBudgetEntriesTable> {
  $$FamilyBudgetEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get monthKey => $composableBuilder(
    column: $table.monthKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountInCents => $composableBuilder(
    column: $table.amountInCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$BookEntriesTableFilterComposer get bookId {
    final $$BookEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.bookEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookEntriesTableFilterComposer(
            $db: $db,
            $table: $db.bookEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoryEntriesTableFilterComposer get categoryId {
    final $$CategoryEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categoryEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryEntriesTableFilterComposer(
            $db: $db,
            $table: $db.categoryEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FamilyBudgetEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $FamilyBudgetEntriesTable> {
  $$FamilyBudgetEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get monthKey => $composableBuilder(
    column: $table.monthKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountInCents => $composableBuilder(
    column: $table.amountInCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdBy => $composableBuilder(
    column: $table.createdBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedBy => $composableBuilder(
    column: $table.updatedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$BookEntriesTableOrderingComposer get bookId {
    final $$BookEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.bookEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.bookEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoryEntriesTableOrderingComposer get categoryId {
    final $$CategoryEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categoryEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.categoryEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FamilyBudgetEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FamilyBudgetEntriesTable> {
  $$FamilyBudgetEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get monthKey =>
      $composableBuilder(column: $table.monthKey, builder: (column) => column);

  GeneratedColumn<int> get amountInCents => $composableBuilder(
    column: $table.amountInCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get visibility => $composableBuilder(
    column: $table.visibility,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$BookEntriesTableAnnotationComposer get bookId {
    final $$BookEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.bookId,
      referencedTable: $db.bookEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.bookEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoryEntriesTableAnnotationComposer get categoryId {
    final $$CategoryEntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categoryEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoryEntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categoryEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FamilyBudgetEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FamilyBudgetEntriesTable,
          FamilyBudgetEntity,
          $$FamilyBudgetEntriesTableFilterComposer,
          $$FamilyBudgetEntriesTableOrderingComposer,
          $$FamilyBudgetEntriesTableAnnotationComposer,
          $$FamilyBudgetEntriesTableCreateCompanionBuilder,
          $$FamilyBudgetEntriesTableUpdateCompanionBuilder,
          (FamilyBudgetEntity, $$FamilyBudgetEntriesTableReferences),
          FamilyBudgetEntity,
          PrefetchHooks Function({bool bookId, bool categoryId})
        > {
  $$FamilyBudgetEntriesTableTableManager(
    _$AppDatabase db,
    $FamilyBudgetEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FamilyBudgetEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FamilyBudgetEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$FamilyBudgetEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> monthKey = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<int> amountInCents = const Value.absent(),
                Value<String> visibility = const Value.absent(),
                Value<String> createdBy = const Value.absent(),
                Value<String> updatedBy = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FamilyBudgetEntriesCompanion(
                id: id,
                bookId: bookId,
                monthKey: monthKey,
                categoryId: categoryId,
                amountInCents: amountInCents,
                visibility: visibility,
                createdBy: createdBy,
                updatedBy: updatedBy,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required String monthKey,
                Value<String?> categoryId = const Value.absent(),
                required int amountInCents,
                Value<String> visibility = const Value.absent(),
                required String createdBy,
                required String updatedBy,
                Value<int> version = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => FamilyBudgetEntriesCompanion.insert(
                id: id,
                bookId: bookId,
                monthKey: monthKey,
                categoryId: categoryId,
                amountInCents: amountInCents,
                visibility: visibility,
                createdBy: createdBy,
                updatedBy: updatedBy,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FamilyBudgetEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({bookId = false, categoryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (bookId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.bookId,
                        referencedTable: $$FamilyBudgetEntriesTableReferences
                            ._bookIdTable(db),
                        referencedColumn: $$FamilyBudgetEntriesTableReferences
                            ._bookIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (categoryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.categoryId,
                        referencedTable: $$FamilyBudgetEntriesTableReferences
                            ._categoryIdTable(db),
                        referencedColumn: $$FamilyBudgetEntriesTableReferences
                            ._categoryIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FamilyBudgetEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FamilyBudgetEntriesTable,
      FamilyBudgetEntity,
      $$FamilyBudgetEntriesTableFilterComposer,
      $$FamilyBudgetEntriesTableOrderingComposer,
      $$FamilyBudgetEntriesTableAnnotationComposer,
      $$FamilyBudgetEntriesTableCreateCompanionBuilder,
      $$FamilyBudgetEntriesTableUpdateCompanionBuilder,
      (FamilyBudgetEntity, $$FamilyBudgetEntriesTableReferences),
      FamilyBudgetEntity,
      PrefetchHooks Function({bool bookId, bool categoryId})
    >;
typedef $$AdEventEntriesTableCreateCompanionBuilder =
    AdEventEntriesCompanion Function({
      required String id,
      required String placementId,
      required String eventType,
      required String provider,
      Value<String?> sessionId,
      required DateTime occurredAt,
      Value<String?> metadataJson,
      Value<int> rowid,
    });
typedef $$AdEventEntriesTableUpdateCompanionBuilder =
    AdEventEntriesCompanion Function({
      Value<String> id,
      Value<String> placementId,
      Value<String> eventType,
      Value<String> provider,
      Value<String?> sessionId,
      Value<DateTime> occurredAt,
      Value<String?> metadataJson,
      Value<int> rowid,
    });

class $$AdEventEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $AdEventEntriesTable> {
  $$AdEventEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get placementId => $composableBuilder(
    column: $table.placementId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AdEventEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $AdEventEntriesTable> {
  $$AdEventEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get placementId => $composableBuilder(
    column: $table.placementId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get provider => $composableBuilder(
    column: $table.provider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AdEventEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AdEventEntriesTable> {
  $$AdEventEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get placementId => $composableBuilder(
    column: $table.placementId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<String> get provider =>
      $composableBuilder(column: $table.provider, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => column,
  );
}

class $$AdEventEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AdEventEntriesTable,
          AdEventEntity,
          $$AdEventEntriesTableFilterComposer,
          $$AdEventEntriesTableOrderingComposer,
          $$AdEventEntriesTableAnnotationComposer,
          $$AdEventEntriesTableCreateCompanionBuilder,
          $$AdEventEntriesTableUpdateCompanionBuilder,
          (
            AdEventEntity,
            BaseReferences<_$AppDatabase, $AdEventEntriesTable, AdEventEntity>,
          ),
          AdEventEntity,
          PrefetchHooks Function()
        > {
  $$AdEventEntriesTableTableManager(
    _$AppDatabase db,
    $AdEventEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AdEventEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AdEventEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AdEventEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> placementId = const Value.absent(),
                Value<String> eventType = const Value.absent(),
                Value<String> provider = const Value.absent(),
                Value<String?> sessionId = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<String?> metadataJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AdEventEntriesCompanion(
                id: id,
                placementId: placementId,
                eventType: eventType,
                provider: provider,
                sessionId: sessionId,
                occurredAt: occurredAt,
                metadataJson: metadataJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String placementId,
                required String eventType,
                required String provider,
                Value<String?> sessionId = const Value.absent(),
                required DateTime occurredAt,
                Value<String?> metadataJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AdEventEntriesCompanion.insert(
                id: id,
                placementId: placementId,
                eventType: eventType,
                provider: provider,
                sessionId: sessionId,
                occurredAt: occurredAt,
                metadataJson: metadataJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AdEventEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AdEventEntriesTable,
      AdEventEntity,
      $$AdEventEntriesTableFilterComposer,
      $$AdEventEntriesTableOrderingComposer,
      $$AdEventEntriesTableAnnotationComposer,
      $$AdEventEntriesTableCreateCompanionBuilder,
      $$AdEventEntriesTableUpdateCompanionBuilder,
      (
        AdEventEntity,
        BaseReferences<_$AppDatabase, $AdEventEntriesTable, AdEventEntity>,
      ),
      AdEventEntity,
      PrefetchHooks Function()
    >;
typedef $$TransactionAttachmentEntriesTableCreateCompanionBuilder =
    TransactionAttachmentEntriesCompanion Function({
      required String id,
      required String bookId,
      required String transactionId,
      required String path,
      required String name,
      Value<String> mimeType,
      Value<int> sortOrder,
      Value<int?> sizeInBytes,
      Value<String?> checksum,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$TransactionAttachmentEntriesTableUpdateCompanionBuilder =
    TransactionAttachmentEntriesCompanion Function({
      Value<String> id,
      Value<String> bookId,
      Value<String> transactionId,
      Value<String> path,
      Value<String> name,
      Value<String> mimeType,
      Value<int> sortOrder,
      Value<int?> sizeInBytes,
      Value<String?> checksum,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

final class $$TransactionAttachmentEntriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $TransactionAttachmentEntriesTable,
          TransactionAttachmentEntity
        > {
  $$TransactionAttachmentEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TransactionEntriesTable _transactionIdTable(_$AppDatabase db) => db
      .transactionEntries
      .createAlias('transaction_attachments__transaction_id__transactions__id');

  $$TransactionEntriesTableProcessedTableManager get transactionId {
    final $_column = $_itemColumn<String>('transaction_id')!;

    final manager = $$TransactionEntriesTableTableManager(
      $_db,
      $_db.transactionEntries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_transactionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TransactionAttachmentEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionAttachmentEntriesTable> {
  $$TransactionAttachmentEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeInBytes => $composableBuilder(
    column: $table.sizeInBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TransactionEntriesTableFilterComposer get transactionId {
    final $$TransactionEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactionEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionEntriesTableFilterComposer(
            $db: $db,
            $table: $db.transactionEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionAttachmentEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionAttachmentEntriesTable> {
  $$TransactionAttachmentEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bookId => $composableBuilder(
    column: $table.bookId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeInBytes => $composableBuilder(
    column: $table.sizeInBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checksum => $composableBuilder(
    column: $table.checksum,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TransactionEntriesTableOrderingComposer get transactionId {
    final $$TransactionEntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactionEntries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionEntriesTableOrderingComposer(
            $db: $db,
            $table: $db.transactionEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionAttachmentEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionAttachmentEntriesTable> {
  $$TransactionAttachmentEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bookId =>
      $composableBuilder(column: $table.bookId, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<int> get sizeInBytes => $composableBuilder(
    column: $table.sizeInBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get checksum =>
      $composableBuilder(column: $table.checksum, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$TransactionEntriesTableAnnotationComposer get transactionId {
    final $$TransactionEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.transactionId,
          referencedTable: $db.transactionEntries,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TransactionEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.transactionEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$TransactionAttachmentEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionAttachmentEntriesTable,
          TransactionAttachmentEntity,
          $$TransactionAttachmentEntriesTableFilterComposer,
          $$TransactionAttachmentEntriesTableOrderingComposer,
          $$TransactionAttachmentEntriesTableAnnotationComposer,
          $$TransactionAttachmentEntriesTableCreateCompanionBuilder,
          $$TransactionAttachmentEntriesTableUpdateCompanionBuilder,
          (
            TransactionAttachmentEntity,
            $$TransactionAttachmentEntriesTableReferences,
          ),
          TransactionAttachmentEntity,
          PrefetchHooks Function({bool transactionId})
        > {
  $$TransactionAttachmentEntriesTableTableManager(
    _$AppDatabase db,
    $TransactionAttachmentEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionAttachmentEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$TransactionAttachmentEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$TransactionAttachmentEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bookId = const Value.absent(),
                Value<String> transactionId = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int?> sizeInBytes = const Value.absent(),
                Value<String?> checksum = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionAttachmentEntriesCompanion(
                id: id,
                bookId: bookId,
                transactionId: transactionId,
                path: path,
                name: name,
                mimeType: mimeType,
                sortOrder: sortOrder,
                sizeInBytes: sizeInBytes,
                checksum: checksum,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bookId,
                required String transactionId,
                required String path,
                required String name,
                Value<String> mimeType = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int?> sizeInBytes = const Value.absent(),
                Value<String?> checksum = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionAttachmentEntriesCompanion.insert(
                id: id,
                bookId: bookId,
                transactionId: transactionId,
                path: path,
                name: name,
                mimeType: mimeType,
                sortOrder: sortOrder,
                sizeInBytes: sizeInBytes,
                checksum: checksum,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TransactionAttachmentEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({transactionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (transactionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.transactionId,
                        referencedTable:
                            $$TransactionAttachmentEntriesTableReferences
                                ._transactionIdTable(db),
                        referencedColumn:
                            $$TransactionAttachmentEntriesTableReferences
                                ._transactionIdTable(db)
                                .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TransactionAttachmentEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionAttachmentEntriesTable,
      TransactionAttachmentEntity,
      $$TransactionAttachmentEntriesTableFilterComposer,
      $$TransactionAttachmentEntriesTableOrderingComposer,
      $$TransactionAttachmentEntriesTableAnnotationComposer,
      $$TransactionAttachmentEntriesTableCreateCompanionBuilder,
      $$TransactionAttachmentEntriesTableUpdateCompanionBuilder,
      (
        TransactionAttachmentEntity,
        $$TransactionAttachmentEntriesTableReferences,
      ),
      TransactionAttachmentEntity,
      PrefetchHooks Function({bool transactionId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AccountEntriesTableTableManager get accountEntries =>
      $$AccountEntriesTableTableManager(_db, _db.accountEntries);
  $$CategoryEntriesTableTableManager get categoryEntries =>
      $$CategoryEntriesTableTableManager(_db, _db.categoryEntries);
  $$TransactionEntriesTableTableManager get transactionEntries =>
      $$TransactionEntriesTableTableManager(_db, _db.transactionEntries);
  $$GoalEntriesTableTableManager get goalEntries =>
      $$GoalEntriesTableTableManager(_db, _db.goalEntries);
  $$GoalMilestoneEntriesTableTableManager get goalMilestoneEntries =>
      $$GoalMilestoneEntriesTableTableManager(_db, _db.goalMilestoneEntries);
  $$GoalContributionEntriesTableTableManager get goalContributionEntries =>
      $$GoalContributionEntriesTableTableManager(
        _db,
        _db.goalContributionEntries,
      );
  $$AppSettingEntriesTableTableManager get appSettingEntries =>
      $$AppSettingEntriesTableTableManager(_db, _db.appSettingEntries);
  $$BudgetEntriesTableTableManager get budgetEntries =>
      $$BudgetEntriesTableTableManager(_db, _db.budgetEntries);
  $$RecurringBillEntriesTableTableManager get recurringBillEntries =>
      $$RecurringBillEntriesTableTableManager(_db, _db.recurringBillEntries);
  $$InstallmentPlanEntriesTableTableManager get installmentPlanEntries =>
      $$InstallmentPlanEntriesTableTableManager(
        _db,
        _db.installmentPlanEntries,
      );
  $$MerchantRuleEntriesTableTableManager get merchantRuleEntries =>
      $$MerchantRuleEntriesTableTableManager(_db, _db.merchantRuleEntries);
  $$EconomicEventEntriesTableTableManager get economicEventEntries =>
      $$EconomicEventEntriesTableTableManager(_db, _db.economicEventEntries);
  $$EconomicEventRecordEntriesTableTableManager
  get economicEventRecordEntries =>
      $$EconomicEventRecordEntriesTableTableManager(
        _db,
        _db.economicEventRecordEntries,
      );
  $$InboxItemEntriesTableTableManager get inboxItemEntries =>
      $$InboxItemEntriesTableTableManager(_db, _db.inboxItemEntries);
  $$FamilyEntriesTableTableManager get familyEntries =>
      $$FamilyEntriesTableTableManager(_db, _db.familyEntries);
  $$BookEntriesTableTableManager get bookEntries =>
      $$BookEntriesTableTableManager(_db, _db.bookEntries);
  $$FamilyMemberEntriesTableTableManager get familyMemberEntries =>
      $$FamilyMemberEntriesTableTableManager(_db, _db.familyMemberEntries);
  $$FamilyInvitationEntriesTableTableManager get familyInvitationEntries =>
      $$FamilyInvitationEntriesTableTableManager(
        _db,
        _db.familyInvitationEntries,
      );
  $$FamilyOperationLogEntriesTableTableManager get familyOperationLogEntries =>
      $$FamilyOperationLogEntriesTableTableManager(
        _db,
        _db.familyOperationLogEntries,
      );
  $$FamilyBudgetEntriesTableTableManager get familyBudgetEntries =>
      $$FamilyBudgetEntriesTableTableManager(_db, _db.familyBudgetEntries);
  $$AdEventEntriesTableTableManager get adEventEntries =>
      $$AdEventEntriesTableTableManager(_db, _db.adEventEntries);
  $$TransactionAttachmentEntriesTableTableManager
  get transactionAttachmentEntries =>
      $$TransactionAttachmentEntriesTableTableManager(
        _db,
        _db.transactionAttachmentEntries,
      );
}

mixin _$AccountDaoMixin on DatabaseAccessor<AppDatabase> {
  $AccountEntriesTable get accountEntries => attachedDatabase.accountEntries;
  AccountDaoManager get managers => AccountDaoManager(this);
}

class AccountDaoManager {
  final _$AccountDaoMixin _db;
  AccountDaoManager(this._db);
  $$AccountEntriesTableTableManager get accountEntries =>
      $$AccountEntriesTableTableManager(
        _db.attachedDatabase,
        _db.accountEntries,
      );
}

mixin _$CategoryDaoMixin on DatabaseAccessor<AppDatabase> {
  $CategoryEntriesTable get categoryEntries => attachedDatabase.categoryEntries;
  CategoryDaoManager get managers => CategoryDaoManager(this);
}

class CategoryDaoManager {
  final _$CategoryDaoMixin _db;
  CategoryDaoManager(this._db);
  $$CategoryEntriesTableTableManager get categoryEntries =>
      $$CategoryEntriesTableTableManager(
        _db.attachedDatabase,
        _db.categoryEntries,
      );
}

mixin _$TransactionDaoMixin on DatabaseAccessor<AppDatabase> {
  $CategoryEntriesTable get categoryEntries => attachedDatabase.categoryEntries;
  $AccountEntriesTable get accountEntries => attachedDatabase.accountEntries;
  $TransactionEntriesTable get transactionEntries =>
      attachedDatabase.transactionEntries;
  TransactionDaoManager get managers => TransactionDaoManager(this);
}

class TransactionDaoManager {
  final _$TransactionDaoMixin _db;
  TransactionDaoManager(this._db);
  $$CategoryEntriesTableTableManager get categoryEntries =>
      $$CategoryEntriesTableTableManager(
        _db.attachedDatabase,
        _db.categoryEntries,
      );
  $$AccountEntriesTableTableManager get accountEntries =>
      $$AccountEntriesTableTableManager(
        _db.attachedDatabase,
        _db.accountEntries,
      );
  $$TransactionEntriesTableTableManager get transactionEntries =>
      $$TransactionEntriesTableTableManager(
        _db.attachedDatabase,
        _db.transactionEntries,
      );
}

mixin _$GoalDaoMixin on DatabaseAccessor<AppDatabase> {
  $GoalEntriesTable get goalEntries => attachedDatabase.goalEntries;
  $GoalMilestoneEntriesTable get goalMilestoneEntries =>
      attachedDatabase.goalMilestoneEntries;
  $GoalContributionEntriesTable get goalContributionEntries =>
      attachedDatabase.goalContributionEntries;
  GoalDaoManager get managers => GoalDaoManager(this);
}

class GoalDaoManager {
  final _$GoalDaoMixin _db;
  GoalDaoManager(this._db);
  $$GoalEntriesTableTableManager get goalEntries =>
      $$GoalEntriesTableTableManager(_db.attachedDatabase, _db.goalEntries);
  $$GoalMilestoneEntriesTableTableManager get goalMilestoneEntries =>
      $$GoalMilestoneEntriesTableTableManager(
        _db.attachedDatabase,
        _db.goalMilestoneEntries,
      );
  $$GoalContributionEntriesTableTableManager get goalContributionEntries =>
      $$GoalContributionEntriesTableTableManager(
        _db.attachedDatabase,
        _db.goalContributionEntries,
      );
}

mixin _$AppSettingsDaoMixin on DatabaseAccessor<AppDatabase> {
  $AppSettingEntriesTable get appSettingEntries =>
      attachedDatabase.appSettingEntries;
  AppSettingsDaoManager get managers => AppSettingsDaoManager(this);
}

class AppSettingsDaoManager {
  final _$AppSettingsDaoMixin _db;
  AppSettingsDaoManager(this._db);
  $$AppSettingEntriesTableTableManager get appSettingEntries =>
      $$AppSettingEntriesTableTableManager(
        _db.attachedDatabase,
        _db.appSettingEntries,
      );
}

mixin _$BudgetDaoMixin on DatabaseAccessor<AppDatabase> {
  $CategoryEntriesTable get categoryEntries => attachedDatabase.categoryEntries;
  $BudgetEntriesTable get budgetEntries => attachedDatabase.budgetEntries;
  BudgetDaoManager get managers => BudgetDaoManager(this);
}

class BudgetDaoManager {
  final _$BudgetDaoMixin _db;
  BudgetDaoManager(this._db);
  $$CategoryEntriesTableTableManager get categoryEntries =>
      $$CategoryEntriesTableTableManager(
        _db.attachedDatabase,
        _db.categoryEntries,
      );
  $$BudgetEntriesTableTableManager get budgetEntries =>
      $$BudgetEntriesTableTableManager(_db.attachedDatabase, _db.budgetEntries);
}

mixin _$RecurringBillDaoMixin on DatabaseAccessor<AppDatabase> {
  $RecurringBillEntriesTable get recurringBillEntries =>
      attachedDatabase.recurringBillEntries;
  RecurringBillDaoManager get managers => RecurringBillDaoManager(this);
}

class RecurringBillDaoManager {
  final _$RecurringBillDaoMixin _db;
  RecurringBillDaoManager(this._db);
  $$RecurringBillEntriesTableTableManager get recurringBillEntries =>
      $$RecurringBillEntriesTableTableManager(
        _db.attachedDatabase,
        _db.recurringBillEntries,
      );
}

mixin _$InstallmentPlanDaoMixin on DatabaseAccessor<AppDatabase> {
  $InstallmentPlanEntriesTable get installmentPlanEntries =>
      attachedDatabase.installmentPlanEntries;
  InstallmentPlanDaoManager get managers => InstallmentPlanDaoManager(this);
}

class InstallmentPlanDaoManager {
  final _$InstallmentPlanDaoMixin _db;
  InstallmentPlanDaoManager(this._db);
  $$InstallmentPlanEntriesTableTableManager get installmentPlanEntries =>
      $$InstallmentPlanEntriesTableTableManager(
        _db.attachedDatabase,
        _db.installmentPlanEntries,
      );
}

mixin _$IntelligenceDaoMixin on DatabaseAccessor<AppDatabase> {
  $CategoryEntriesTable get categoryEntries => attachedDatabase.categoryEntries;
  $MerchantRuleEntriesTable get merchantRuleEntries =>
      attachedDatabase.merchantRuleEntries;
  $EconomicEventEntriesTable get economicEventEntries =>
      attachedDatabase.economicEventEntries;
  $AccountEntriesTable get accountEntries => attachedDatabase.accountEntries;
  $TransactionEntriesTable get transactionEntries =>
      attachedDatabase.transactionEntries;
  $EconomicEventRecordEntriesTable get economicEventRecordEntries =>
      attachedDatabase.economicEventRecordEntries;
  $InboxItemEntriesTable get inboxItemEntries =>
      attachedDatabase.inboxItemEntries;
  IntelligenceDaoManager get managers => IntelligenceDaoManager(this);
}

class IntelligenceDaoManager {
  final _$IntelligenceDaoMixin _db;
  IntelligenceDaoManager(this._db);
  $$CategoryEntriesTableTableManager get categoryEntries =>
      $$CategoryEntriesTableTableManager(
        _db.attachedDatabase,
        _db.categoryEntries,
      );
  $$MerchantRuleEntriesTableTableManager get merchantRuleEntries =>
      $$MerchantRuleEntriesTableTableManager(
        _db.attachedDatabase,
        _db.merchantRuleEntries,
      );
  $$EconomicEventEntriesTableTableManager get economicEventEntries =>
      $$EconomicEventEntriesTableTableManager(
        _db.attachedDatabase,
        _db.economicEventEntries,
      );
  $$AccountEntriesTableTableManager get accountEntries =>
      $$AccountEntriesTableTableManager(
        _db.attachedDatabase,
        _db.accountEntries,
      );
  $$TransactionEntriesTableTableManager get transactionEntries =>
      $$TransactionEntriesTableTableManager(
        _db.attachedDatabase,
        _db.transactionEntries,
      );
  $$EconomicEventRecordEntriesTableTableManager
  get economicEventRecordEntries =>
      $$EconomicEventRecordEntriesTableTableManager(
        _db.attachedDatabase,
        _db.economicEventRecordEntries,
      );
  $$InboxItemEntriesTableTableManager get inboxItemEntries =>
      $$InboxItemEntriesTableTableManager(
        _db.attachedDatabase,
        _db.inboxItemEntries,
      );
}

mixin _$FamilyDaoMixin on DatabaseAccessor<AppDatabase> {
  $FamilyEntriesTable get familyEntries => attachedDatabase.familyEntries;
  $BookEntriesTable get bookEntries => attachedDatabase.bookEntries;
  $FamilyMemberEntriesTable get familyMemberEntries =>
      attachedDatabase.familyMemberEntries;
  $FamilyInvitationEntriesTable get familyInvitationEntries =>
      attachedDatabase.familyInvitationEntries;
  $FamilyOperationLogEntriesTable get familyOperationLogEntries =>
      attachedDatabase.familyOperationLogEntries;
  $CategoryEntriesTable get categoryEntries => attachedDatabase.categoryEntries;
  $FamilyBudgetEntriesTable get familyBudgetEntries =>
      attachedDatabase.familyBudgetEntries;
  FamilyDaoManager get managers => FamilyDaoManager(this);
}

class FamilyDaoManager {
  final _$FamilyDaoMixin _db;
  FamilyDaoManager(this._db);
  $$FamilyEntriesTableTableManager get familyEntries =>
      $$FamilyEntriesTableTableManager(_db.attachedDatabase, _db.familyEntries);
  $$BookEntriesTableTableManager get bookEntries =>
      $$BookEntriesTableTableManager(_db.attachedDatabase, _db.bookEntries);
  $$FamilyMemberEntriesTableTableManager get familyMemberEntries =>
      $$FamilyMemberEntriesTableTableManager(
        _db.attachedDatabase,
        _db.familyMemberEntries,
      );
  $$FamilyInvitationEntriesTableTableManager get familyInvitationEntries =>
      $$FamilyInvitationEntriesTableTableManager(
        _db.attachedDatabase,
        _db.familyInvitationEntries,
      );
  $$FamilyOperationLogEntriesTableTableManager get familyOperationLogEntries =>
      $$FamilyOperationLogEntriesTableTableManager(
        _db.attachedDatabase,
        _db.familyOperationLogEntries,
      );
  $$CategoryEntriesTableTableManager get categoryEntries =>
      $$CategoryEntriesTableTableManager(
        _db.attachedDatabase,
        _db.categoryEntries,
      );
  $$FamilyBudgetEntriesTableTableManager get familyBudgetEntries =>
      $$FamilyBudgetEntriesTableTableManager(
        _db.attachedDatabase,
        _db.familyBudgetEntries,
      );
}

mixin _$AdEventDaoMixin on DatabaseAccessor<AppDatabase> {
  $AdEventEntriesTable get adEventEntries => attachedDatabase.adEventEntries;
  AdEventDaoManager get managers => AdEventDaoManager(this);
}

class AdEventDaoManager {
  final _$AdEventDaoMixin _db;
  AdEventDaoManager(this._db);
  $$AdEventEntriesTableTableManager get adEventEntries =>
      $$AdEventEntriesTableTableManager(
        _db.attachedDatabase,
        _db.adEventEntries,
      );
}

mixin _$TransactionAttachmentDaoMixin on DatabaseAccessor<AppDatabase> {
  $CategoryEntriesTable get categoryEntries => attachedDatabase.categoryEntries;
  $AccountEntriesTable get accountEntries => attachedDatabase.accountEntries;
  $TransactionEntriesTable get transactionEntries =>
      attachedDatabase.transactionEntries;
  $TransactionAttachmentEntriesTable get transactionAttachmentEntries =>
      attachedDatabase.transactionAttachmentEntries;
  TransactionAttachmentDaoManager get managers =>
      TransactionAttachmentDaoManager(this);
}

class TransactionAttachmentDaoManager {
  final _$TransactionAttachmentDaoMixin _db;
  TransactionAttachmentDaoManager(this._db);
  $$CategoryEntriesTableTableManager get categoryEntries =>
      $$CategoryEntriesTableTableManager(
        _db.attachedDatabase,
        _db.categoryEntries,
      );
  $$AccountEntriesTableTableManager get accountEntries =>
      $$AccountEntriesTableTableManager(
        _db.attachedDatabase,
        _db.accountEntries,
      );
  $$TransactionEntriesTableTableManager get transactionEntries =>
      $$TransactionEntriesTableTableManager(
        _db.attachedDatabase,
        _db.transactionEntries,
      );
  $$TransactionAttachmentEntriesTableTableManager
  get transactionAttachmentEntries =>
      $$TransactionAttachmentEntriesTableTableManager(
        _db.attachedDatabase,
        _db.transactionAttachmentEntries,
      );
}
