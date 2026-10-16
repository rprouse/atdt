// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'archive_database.dart';

// ignore_for_file: type=lint
class $IssuesTable extends Issues with TableInfo<$IssuesTable, Issue> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IssuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<int> number = GeneratedColumn<int>(
    'number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _releaseDateMeta = const VerificationMeta(
    'releaseDate',
  );
  @override
  late final GeneratedColumn<DateTime> releaseDate = GeneratedColumn<DateTime>(
    'release_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceChecksumMeta = const VerificationMeta(
    'sourceChecksum',
  );
  @override
  late final GeneratedColumn<String> sourceChecksum = GeneratedColumn<String>(
    'source_checksum',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    number,
    releaseDate,
    title,
    fetchedAt,
    sourceChecksum,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'issues';
  @override
  VerificationContext validateIntegrity(
    Insertable<Issue> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('number')) {
      context.handle(
        _numberMeta,
        number.isAcceptableOrUnknown(data['number']!, _numberMeta),
      );
    }
    if (data.containsKey('release_date')) {
      context.handle(
        _releaseDateMeta,
        releaseDate.isAcceptableOrUnknown(
          data['release_date']!,
          _releaseDateMeta,
        ),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    if (data.containsKey('source_checksum')) {
      context.handle(
        _sourceChecksumMeta,
        sourceChecksum.isAcceptableOrUnknown(
          data['source_checksum']!,
          _sourceChecksumMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceChecksumMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {number};
  @override
  Issue map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Issue(
      number: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}number'],
      )!,
      releaseDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}release_date'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
      sourceChecksum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_checksum'],
      )!,
    );
  }

  @override
  $IssuesTable createAlias(String alias) {
    return $IssuesTable(attachedDatabase, alias);
  }
}

class Issue extends DataClass implements Insertable<Issue> {
  final int number;
  final DateTime? releaseDate;
  final String? title;
  final DateTime fetchedAt;
  final String sourceChecksum;
  const Issue({
    required this.number,
    this.releaseDate,
    this.title,
    required this.fetchedAt,
    required this.sourceChecksum,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['number'] = Variable<int>(number);
    if (!nullToAbsent || releaseDate != null) {
      map['release_date'] = Variable<DateTime>(releaseDate);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    map['source_checksum'] = Variable<String>(sourceChecksum);
    return map;
  }

  IssuesCompanion toCompanion(bool nullToAbsent) {
    return IssuesCompanion(
      number: Value(number),
      releaseDate: releaseDate == null && nullToAbsent
          ? const Value.absent()
          : Value(releaseDate),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      fetchedAt: Value(fetchedAt),
      sourceChecksum: Value(sourceChecksum),
    );
  }

  factory Issue.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Issue(
      number: serializer.fromJson<int>(json['number']),
      releaseDate: serializer.fromJson<DateTime?>(json['releaseDate']),
      title: serializer.fromJson<String?>(json['title']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
      sourceChecksum: serializer.fromJson<String>(json['sourceChecksum']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'number': serializer.toJson<int>(number),
      'releaseDate': serializer.toJson<DateTime?>(releaseDate),
      'title': serializer.toJson<String?>(title),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
      'sourceChecksum': serializer.toJson<String>(sourceChecksum),
    };
  }

  Issue copyWith({
    int? number,
    Value<DateTime?> releaseDate = const Value.absent(),
    Value<String?> title = const Value.absent(),
    DateTime? fetchedAt,
    String? sourceChecksum,
  }) => Issue(
    number: number ?? this.number,
    releaseDate: releaseDate.present ? releaseDate.value : this.releaseDate,
    title: title.present ? title.value : this.title,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    sourceChecksum: sourceChecksum ?? this.sourceChecksum,
  );
  Issue copyWithCompanion(IssuesCompanion data) {
    return Issue(
      number: data.number.present ? data.number.value : this.number,
      releaseDate: data.releaseDate.present
          ? data.releaseDate.value
          : this.releaseDate,
      title: data.title.present ? data.title.value : this.title,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
      sourceChecksum: data.sourceChecksum.present
          ? data.sourceChecksum.value
          : this.sourceChecksum,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Issue(')
          ..write('number: $number, ')
          ..write('releaseDate: $releaseDate, ')
          ..write('title: $title, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('sourceChecksum: $sourceChecksum')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(number, releaseDate, title, fetchedAt, sourceChecksum);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Issue &&
          other.number == this.number &&
          other.releaseDate == this.releaseDate &&
          other.title == this.title &&
          other.fetchedAt == this.fetchedAt &&
          other.sourceChecksum == this.sourceChecksum);
}

class IssuesCompanion extends UpdateCompanion<Issue> {
  final Value<int> number;
  final Value<DateTime?> releaseDate;
  final Value<String?> title;
  final Value<DateTime> fetchedAt;
  final Value<String> sourceChecksum;
  const IssuesCompanion({
    this.number = const Value.absent(),
    this.releaseDate = const Value.absent(),
    this.title = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.sourceChecksum = const Value.absent(),
  });
  IssuesCompanion.insert({
    this.number = const Value.absent(),
    this.releaseDate = const Value.absent(),
    this.title = const Value.absent(),
    required DateTime fetchedAt,
    required String sourceChecksum,
  }) : fetchedAt = Value(fetchedAt),
       sourceChecksum = Value(sourceChecksum);
  static Insertable<Issue> custom({
    Expression<int>? number,
    Expression<DateTime>? releaseDate,
    Expression<String>? title,
    Expression<DateTime>? fetchedAt,
    Expression<String>? sourceChecksum,
  }) {
    return RawValuesInsertable({
      if (number != null) 'number': number,
      if (releaseDate != null) 'release_date': releaseDate,
      if (title != null) 'title': title,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (sourceChecksum != null) 'source_checksum': sourceChecksum,
    });
  }

  IssuesCompanion copyWith({
    Value<int>? number,
    Value<DateTime?>? releaseDate,
    Value<String?>? title,
    Value<DateTime>? fetchedAt,
    Value<String>? sourceChecksum,
  }) {
    return IssuesCompanion(
      number: number ?? this.number,
      releaseDate: releaseDate ?? this.releaseDate,
      title: title ?? this.title,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      sourceChecksum: sourceChecksum ?? this.sourceChecksum,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (number.present) {
      map['number'] = Variable<int>(number.value);
    }
    if (releaseDate.present) {
      map['release_date'] = Variable<DateTime>(releaseDate.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (sourceChecksum.present) {
      map['source_checksum'] = Variable<String>(sourceChecksum.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IssuesCompanion(')
          ..write('number: $number, ')
          ..write('releaseDate: $releaseDate, ')
          ..write('title: $title, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('sourceChecksum: $sourceChecksum')
          ..write(')'))
        .toString();
  }
}

class $PhilesTable extends Philes with TableInfo<$PhilesTable, Phile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _issueMeta = const VerificationMeta('issue');
  @override
  late final GeneratedColumn<int> issue = GeneratedColumn<int>(
    'issue',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES issues (number) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _numberMeta = const VerificationMeta('number');
  @override
  late final GeneratedColumn<int> number = GeneratedColumn<int>(
    'number',
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
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _encodingMeta = const VerificationMeta(
    'encoding',
  );
  @override
  late final GeneratedColumn<String> encoding = GeneratedColumn<String>(
    'encoding',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lineCountMeta = const VerificationMeta(
    'lineCount',
  );
  @override
  late final GeneratedColumn<int> lineCount = GeneratedColumn<int>(
    'line_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _longestLineMeta = const VerificationMeta(
    'longestLine',
  );
  @override
  late final GeneratedColumn<int> longestLine = GeneratedColumn<int>(
    'longest_line',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inventoryMeta = const VerificationMeta(
    'inventory',
  );
  @override
  late final GeneratedColumn<Uint8List> inventory = GeneratedColumn<Uint8List>(
    'inventory',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    issue,
    number,
    title,
    author,
    encoding,
    lineCount,
    longestLine,
    inventory,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'philes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Phile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('issue')) {
      context.handle(
        _issueMeta,
        issue.isAcceptableOrUnknown(data['issue']!, _issueMeta),
      );
    } else if (isInserting) {
      context.missing(_issueMeta);
    }
    if (data.containsKey('number')) {
      context.handle(
        _numberMeta,
        number.isAcceptableOrUnknown(data['number']!, _numberMeta),
      );
    } else if (isInserting) {
      context.missing(_numberMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('encoding')) {
      context.handle(
        _encodingMeta,
        encoding.isAcceptableOrUnknown(data['encoding']!, _encodingMeta),
      );
    } else if (isInserting) {
      context.missing(_encodingMeta);
    }
    if (data.containsKey('line_count')) {
      context.handle(
        _lineCountMeta,
        lineCount.isAcceptableOrUnknown(data['line_count']!, _lineCountMeta),
      );
    } else if (isInserting) {
      context.missing(_lineCountMeta);
    }
    if (data.containsKey('longest_line')) {
      context.handle(
        _longestLineMeta,
        longestLine.isAcceptableOrUnknown(
          data['longest_line']!,
          _longestLineMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_longestLineMeta);
    }
    if (data.containsKey('inventory')) {
      context.handle(
        _inventoryMeta,
        inventory.isAcceptableOrUnknown(data['inventory']!, _inventoryMeta),
      );
    } else if (isInserting) {
      context.missing(_inventoryMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {issue, number},
  ];
  @override
  Phile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Phile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      issue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}issue'],
      )!,
      number: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}number'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      encoding: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encoding'],
      )!,
      lineCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line_count'],
      )!,
      longestLine: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}longest_line'],
      )!,
      inventory: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}inventory'],
      )!,
    );
  }

  @override
  $PhilesTable createAlias(String alias) {
    return $PhilesTable(attachedDatabase, alias);
  }
}

class Phile extends DataClass implements Insertable<Phile> {
  final int id;
  final int issue;
  final int number;
  final String title;
  final String? author;
  final String encoding;
  final int lineCount;
  final int longestLine;

  /// Distinct code points, little-endian uint32 (font coverage, Stage E).
  final Uint8List inventory;
  const Phile({
    required this.id,
    required this.issue,
    required this.number,
    required this.title,
    this.author,
    required this.encoding,
    required this.lineCount,
    required this.longestLine,
    required this.inventory,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['issue'] = Variable<int>(issue);
    map['number'] = Variable<int>(number);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    map['encoding'] = Variable<String>(encoding);
    map['line_count'] = Variable<int>(lineCount);
    map['longest_line'] = Variable<int>(longestLine);
    map['inventory'] = Variable<Uint8List>(inventory);
    return map;
  }

  PhilesCompanion toCompanion(bool nullToAbsent) {
    return PhilesCompanion(
      id: Value(id),
      issue: Value(issue),
      number: Value(number),
      title: Value(title),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      encoding: Value(encoding),
      lineCount: Value(lineCount),
      longestLine: Value(longestLine),
      inventory: Value(inventory),
    );
  }

  factory Phile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Phile(
      id: serializer.fromJson<int>(json['id']),
      issue: serializer.fromJson<int>(json['issue']),
      number: serializer.fromJson<int>(json['number']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String?>(json['author']),
      encoding: serializer.fromJson<String>(json['encoding']),
      lineCount: serializer.fromJson<int>(json['lineCount']),
      longestLine: serializer.fromJson<int>(json['longestLine']),
      inventory: serializer.fromJson<Uint8List>(json['inventory']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'issue': serializer.toJson<int>(issue),
      'number': serializer.toJson<int>(number),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String?>(author),
      'encoding': serializer.toJson<String>(encoding),
      'lineCount': serializer.toJson<int>(lineCount),
      'longestLine': serializer.toJson<int>(longestLine),
      'inventory': serializer.toJson<Uint8List>(inventory),
    };
  }

  Phile copyWith({
    int? id,
    int? issue,
    int? number,
    String? title,
    Value<String?> author = const Value.absent(),
    String? encoding,
    int? lineCount,
    int? longestLine,
    Uint8List? inventory,
  }) => Phile(
    id: id ?? this.id,
    issue: issue ?? this.issue,
    number: number ?? this.number,
    title: title ?? this.title,
    author: author.present ? author.value : this.author,
    encoding: encoding ?? this.encoding,
    lineCount: lineCount ?? this.lineCount,
    longestLine: longestLine ?? this.longestLine,
    inventory: inventory ?? this.inventory,
  );
  Phile copyWithCompanion(PhilesCompanion data) {
    return Phile(
      id: data.id.present ? data.id.value : this.id,
      issue: data.issue.present ? data.issue.value : this.issue,
      number: data.number.present ? data.number.value : this.number,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      encoding: data.encoding.present ? data.encoding.value : this.encoding,
      lineCount: data.lineCount.present ? data.lineCount.value : this.lineCount,
      longestLine: data.longestLine.present
          ? data.longestLine.value
          : this.longestLine,
      inventory: data.inventory.present ? data.inventory.value : this.inventory,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Phile(')
          ..write('id: $id, ')
          ..write('issue: $issue, ')
          ..write('number: $number, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('encoding: $encoding, ')
          ..write('lineCount: $lineCount, ')
          ..write('longestLine: $longestLine, ')
          ..write('inventory: $inventory')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    issue,
    number,
    title,
    author,
    encoding,
    lineCount,
    longestLine,
    $driftBlobEquality.hash(inventory),
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Phile &&
          other.id == this.id &&
          other.issue == this.issue &&
          other.number == this.number &&
          other.title == this.title &&
          other.author == this.author &&
          other.encoding == this.encoding &&
          other.lineCount == this.lineCount &&
          other.longestLine == this.longestLine &&
          $driftBlobEquality.equals(other.inventory, this.inventory));
}

class PhilesCompanion extends UpdateCompanion<Phile> {
  final Value<int> id;
  final Value<int> issue;
  final Value<int> number;
  final Value<String> title;
  final Value<String?> author;
  final Value<String> encoding;
  final Value<int> lineCount;
  final Value<int> longestLine;
  final Value<Uint8List> inventory;
  const PhilesCompanion({
    this.id = const Value.absent(),
    this.issue = const Value.absent(),
    this.number = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.encoding = const Value.absent(),
    this.lineCount = const Value.absent(),
    this.longestLine = const Value.absent(),
    this.inventory = const Value.absent(),
  });
  PhilesCompanion.insert({
    this.id = const Value.absent(),
    required int issue,
    required int number,
    required String title,
    this.author = const Value.absent(),
    required String encoding,
    required int lineCount,
    required int longestLine,
    required Uint8List inventory,
  }) : issue = Value(issue),
       number = Value(number),
       title = Value(title),
       encoding = Value(encoding),
       lineCount = Value(lineCount),
       longestLine = Value(longestLine),
       inventory = Value(inventory);
  static Insertable<Phile> custom({
    Expression<int>? id,
    Expression<int>? issue,
    Expression<int>? number,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? encoding,
    Expression<int>? lineCount,
    Expression<int>? longestLine,
    Expression<Uint8List>? inventory,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (issue != null) 'issue': issue,
      if (number != null) 'number': number,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (encoding != null) 'encoding': encoding,
      if (lineCount != null) 'line_count': lineCount,
      if (longestLine != null) 'longest_line': longestLine,
      if (inventory != null) 'inventory': inventory,
    });
  }

  PhilesCompanion copyWith({
    Value<int>? id,
    Value<int>? issue,
    Value<int>? number,
    Value<String>? title,
    Value<String?>? author,
    Value<String>? encoding,
    Value<int>? lineCount,
    Value<int>? longestLine,
    Value<Uint8List>? inventory,
  }) {
    return PhilesCompanion(
      id: id ?? this.id,
      issue: issue ?? this.issue,
      number: number ?? this.number,
      title: title ?? this.title,
      author: author ?? this.author,
      encoding: encoding ?? this.encoding,
      lineCount: lineCount ?? this.lineCount,
      longestLine: longestLine ?? this.longestLine,
      inventory: inventory ?? this.inventory,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (issue.present) {
      map['issue'] = Variable<int>(issue.value);
    }
    if (number.present) {
      map['number'] = Variable<int>(number.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (encoding.present) {
      map['encoding'] = Variable<String>(encoding.value);
    }
    if (lineCount.present) {
      map['line_count'] = Variable<int>(lineCount.value);
    }
    if (longestLine.present) {
      map['longest_line'] = Variable<int>(longestLine.value);
    }
    if (inventory.present) {
      map['inventory'] = Variable<Uint8List>(inventory.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhilesCompanion(')
          ..write('id: $id, ')
          ..write('issue: $issue, ')
          ..write('number: $number, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('encoding: $encoding, ')
          ..write('lineCount: $lineCount, ')
          ..write('longestLine: $longestLine, ')
          ..write('inventory: $inventory')
          ..write(')'))
        .toString();
  }
}

class $PhileTextChunksTable extends PhileTextChunks
    with TableInfo<$PhileTextChunksTable, PhileTextChunk> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhileTextChunksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _phileIdMeta = const VerificationMeta(
    'phileId',
  );
  @override
  late final GeneratedColumn<int> phileId = GeneratedColumn<int>(
    'phile_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES philes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _chunkMeta = const VerificationMeta('chunk');
  @override
  late final GeneratedColumn<int> chunk = GeneratedColumn<int>(
    'chunk',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firstLineMeta = const VerificationMeta(
    'firstLine',
  );
  @override
  late final GeneratedColumn<int> firstLine = GeneratedColumn<int>(
    'first_line',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lineCountMeta = const VerificationMeta(
    'lineCount',
  );
  @override
  late final GeneratedColumn<int> lineCount = GeneratedColumn<int>(
    'line_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<Uint8List> data = GeneratedColumn<Uint8List>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    phileId,
    chunk,
    firstLine,
    lineCount,
    data,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'phile_text';
  @override
  VerificationContext validateIntegrity(
    Insertable<PhileTextChunk> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('phile_id')) {
      context.handle(
        _phileIdMeta,
        phileId.isAcceptableOrUnknown(data['phile_id']!, _phileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_phileIdMeta);
    }
    if (data.containsKey('chunk')) {
      context.handle(
        _chunkMeta,
        chunk.isAcceptableOrUnknown(data['chunk']!, _chunkMeta),
      );
    } else if (isInserting) {
      context.missing(_chunkMeta);
    }
    if (data.containsKey('first_line')) {
      context.handle(
        _firstLineMeta,
        firstLine.isAcceptableOrUnknown(data['first_line']!, _firstLineMeta),
      );
    } else if (isInserting) {
      context.missing(_firstLineMeta);
    }
    if (data.containsKey('line_count')) {
      context.handle(
        _lineCountMeta,
        lineCount.isAcceptableOrUnknown(data['line_count']!, _lineCountMeta),
      );
    } else if (isInserting) {
      context.missing(_lineCountMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {phileId, chunk};
  @override
  PhileTextChunk map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PhileTextChunk(
      phileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}phile_id'],
      )!,
      chunk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chunk'],
      )!,
      firstLine: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}first_line'],
      )!,
      lineCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}line_count'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}data'],
      )!,
    );
  }

  @override
  $PhileTextChunksTable createAlias(String alias) {
    return $PhileTextChunksTable(attachedDatabase, alias);
  }
}

class PhileTextChunk extends DataClass implements Insertable<PhileTextChunk> {
  final int phileId;
  final int chunk;
  final int firstLine;
  final int lineCount;

  /// UTF-8 lines, each followed by '\n'.
  final Uint8List data;
  const PhileTextChunk({
    required this.phileId,
    required this.chunk,
    required this.firstLine,
    required this.lineCount,
    required this.data,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['phile_id'] = Variable<int>(phileId);
    map['chunk'] = Variable<int>(chunk);
    map['first_line'] = Variable<int>(firstLine);
    map['line_count'] = Variable<int>(lineCount);
    map['data'] = Variable<Uint8List>(data);
    return map;
  }

  PhileTextChunksCompanion toCompanion(bool nullToAbsent) {
    return PhileTextChunksCompanion(
      phileId: Value(phileId),
      chunk: Value(chunk),
      firstLine: Value(firstLine),
      lineCount: Value(lineCount),
      data: Value(data),
    );
  }

  factory PhileTextChunk.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PhileTextChunk(
      phileId: serializer.fromJson<int>(json['phileId']),
      chunk: serializer.fromJson<int>(json['chunk']),
      firstLine: serializer.fromJson<int>(json['firstLine']),
      lineCount: serializer.fromJson<int>(json['lineCount']),
      data: serializer.fromJson<Uint8List>(json['data']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'phileId': serializer.toJson<int>(phileId),
      'chunk': serializer.toJson<int>(chunk),
      'firstLine': serializer.toJson<int>(firstLine),
      'lineCount': serializer.toJson<int>(lineCount),
      'data': serializer.toJson<Uint8List>(data),
    };
  }

  PhileTextChunk copyWith({
    int? phileId,
    int? chunk,
    int? firstLine,
    int? lineCount,
    Uint8List? data,
  }) => PhileTextChunk(
    phileId: phileId ?? this.phileId,
    chunk: chunk ?? this.chunk,
    firstLine: firstLine ?? this.firstLine,
    lineCount: lineCount ?? this.lineCount,
    data: data ?? this.data,
  );
  PhileTextChunk copyWithCompanion(PhileTextChunksCompanion data) {
    return PhileTextChunk(
      phileId: data.phileId.present ? data.phileId.value : this.phileId,
      chunk: data.chunk.present ? data.chunk.value : this.chunk,
      firstLine: data.firstLine.present ? data.firstLine.value : this.firstLine,
      lineCount: data.lineCount.present ? data.lineCount.value : this.lineCount,
      data: data.data.present ? data.data.value : this.data,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PhileTextChunk(')
          ..write('phileId: $phileId, ')
          ..write('chunk: $chunk, ')
          ..write('firstLine: $firstLine, ')
          ..write('lineCount: $lineCount, ')
          ..write('data: $data')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    phileId,
    chunk,
    firstLine,
    lineCount,
    $driftBlobEquality.hash(data),
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhileTextChunk &&
          other.phileId == this.phileId &&
          other.chunk == this.chunk &&
          other.firstLine == this.firstLine &&
          other.lineCount == this.lineCount &&
          $driftBlobEquality.equals(other.data, this.data));
}

class PhileTextChunksCompanion extends UpdateCompanion<PhileTextChunk> {
  final Value<int> phileId;
  final Value<int> chunk;
  final Value<int> firstLine;
  final Value<int> lineCount;
  final Value<Uint8List> data;
  final Value<int> rowid;
  const PhileTextChunksCompanion({
    this.phileId = const Value.absent(),
    this.chunk = const Value.absent(),
    this.firstLine = const Value.absent(),
    this.lineCount = const Value.absent(),
    this.data = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PhileTextChunksCompanion.insert({
    required int phileId,
    required int chunk,
    required int firstLine,
    required int lineCount,
    required Uint8List data,
    this.rowid = const Value.absent(),
  }) : phileId = Value(phileId),
       chunk = Value(chunk),
       firstLine = Value(firstLine),
       lineCount = Value(lineCount),
       data = Value(data);
  static Insertable<PhileTextChunk> custom({
    Expression<int>? phileId,
    Expression<int>? chunk,
    Expression<int>? firstLine,
    Expression<int>? lineCount,
    Expression<Uint8List>? data,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (phileId != null) 'phile_id': phileId,
      if (chunk != null) 'chunk': chunk,
      if (firstLine != null) 'first_line': firstLine,
      if (lineCount != null) 'line_count': lineCount,
      if (data != null) 'data': data,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PhileTextChunksCompanion copyWith({
    Value<int>? phileId,
    Value<int>? chunk,
    Value<int>? firstLine,
    Value<int>? lineCount,
    Value<Uint8List>? data,
    Value<int>? rowid,
  }) {
    return PhileTextChunksCompanion(
      phileId: phileId ?? this.phileId,
      chunk: chunk ?? this.chunk,
      firstLine: firstLine ?? this.firstLine,
      lineCount: lineCount ?? this.lineCount,
      data: data ?? this.data,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (phileId.present) {
      map['phile_id'] = Variable<int>(phileId.value);
    }
    if (chunk.present) {
      map['chunk'] = Variable<int>(chunk.value);
    }
    if (firstLine.present) {
      map['first_line'] = Variable<int>(firstLine.value);
    }
    if (lineCount.present) {
      map['line_count'] = Variable<int>(lineCount.value);
    }
    if (data.present) {
      map['data'] = Variable<Uint8List>(data.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhileTextChunksCompanion(')
          ..write('phileId: $phileId, ')
          ..write('chunk: $chunk, ')
          ..write('firstLine: $firstLine, ')
          ..write('lineCount: $lineCount, ')
          ..write('data: $data, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReadingStatesTable extends ReadingStates
    with TableInfo<$ReadingStatesTable, ReadingState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _phileIdMeta = const VerificationMeta(
    'phileId',
  );
  @override
  late final GeneratedColumn<int> phileId = GeneratedColumn<int>(
    'phile_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES philes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _topLineIndexMeta = const VerificationMeta(
    'topLineIndex',
  );
  @override
  late final GeneratedColumn<int> topLineIndex = GeneratedColumn<int>(
    'top_line_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fractionIntoLineMeta = const VerificationMeta(
    'fractionIntoLine',
  );
  @override
  late final GeneratedColumn<double> fractionIntoLine = GeneratedColumn<double>(
    'fraction_into_line',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _columnOffsetMeta = const VerificationMeta(
    'columnOffset',
  );
  @override
  late final GeneratedColumn<double> columnOffset = GeneratedColumn<double>(
    'column_offset',
    aliasedName,
    false,
    type: DriftSqlType.double,
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
    phileId,
    topLineIndex,
    fractionIntoLine,
    columnOffset,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('phile_id')) {
      context.handle(
        _phileIdMeta,
        phileId.isAcceptableOrUnknown(data['phile_id']!, _phileIdMeta),
      );
    }
    if (data.containsKey('top_line_index')) {
      context.handle(
        _topLineIndexMeta,
        topLineIndex.isAcceptableOrUnknown(
          data['top_line_index']!,
          _topLineIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_topLineIndexMeta);
    }
    if (data.containsKey('fraction_into_line')) {
      context.handle(
        _fractionIntoLineMeta,
        fractionIntoLine.isAcceptableOrUnknown(
          data['fraction_into_line']!,
          _fractionIntoLineMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fractionIntoLineMeta);
    }
    if (data.containsKey('column_offset')) {
      context.handle(
        _columnOffsetMeta,
        columnOffset.isAcceptableOrUnknown(
          data['column_offset']!,
          _columnOffsetMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_columnOffsetMeta);
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
  Set<GeneratedColumn> get $primaryKey => {phileId};
  @override
  ReadingState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingState(
      phileId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}phile_id'],
      )!,
      topLineIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}top_line_index'],
      )!,
      fractionIntoLine: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fraction_into_line'],
      )!,
      columnOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}column_offset'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ReadingStatesTable createAlias(String alias) {
    return $ReadingStatesTable(attachedDatabase, alias);
  }
}

class ReadingState extends DataClass implements Insertable<ReadingState> {
  final int phileId;
  final int topLineIndex;
  final double fractionIntoLine;
  final double columnOffset;
  final DateTime updatedAt;
  const ReadingState({
    required this.phileId,
    required this.topLineIndex,
    required this.fractionIntoLine,
    required this.columnOffset,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['phile_id'] = Variable<int>(phileId);
    map['top_line_index'] = Variable<int>(topLineIndex);
    map['fraction_into_line'] = Variable<double>(fractionIntoLine);
    map['column_offset'] = Variable<double>(columnOffset);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ReadingStatesCompanion toCompanion(bool nullToAbsent) {
    return ReadingStatesCompanion(
      phileId: Value(phileId),
      topLineIndex: Value(topLineIndex),
      fractionIntoLine: Value(fractionIntoLine),
      columnOffset: Value(columnOffset),
      updatedAt: Value(updatedAt),
    );
  }

  factory ReadingState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingState(
      phileId: serializer.fromJson<int>(json['phileId']),
      topLineIndex: serializer.fromJson<int>(json['topLineIndex']),
      fractionIntoLine: serializer.fromJson<double>(json['fractionIntoLine']),
      columnOffset: serializer.fromJson<double>(json['columnOffset']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'phileId': serializer.toJson<int>(phileId),
      'topLineIndex': serializer.toJson<int>(topLineIndex),
      'fractionIntoLine': serializer.toJson<double>(fractionIntoLine),
      'columnOffset': serializer.toJson<double>(columnOffset),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ReadingState copyWith({
    int? phileId,
    int? topLineIndex,
    double? fractionIntoLine,
    double? columnOffset,
    DateTime? updatedAt,
  }) => ReadingState(
    phileId: phileId ?? this.phileId,
    topLineIndex: topLineIndex ?? this.topLineIndex,
    fractionIntoLine: fractionIntoLine ?? this.fractionIntoLine,
    columnOffset: columnOffset ?? this.columnOffset,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ReadingState copyWithCompanion(ReadingStatesCompanion data) {
    return ReadingState(
      phileId: data.phileId.present ? data.phileId.value : this.phileId,
      topLineIndex: data.topLineIndex.present
          ? data.topLineIndex.value
          : this.topLineIndex,
      fractionIntoLine: data.fractionIntoLine.present
          ? data.fractionIntoLine.value
          : this.fractionIntoLine,
      columnOffset: data.columnOffset.present
          ? data.columnOffset.value
          : this.columnOffset,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingState(')
          ..write('phileId: $phileId, ')
          ..write('topLineIndex: $topLineIndex, ')
          ..write('fractionIntoLine: $fractionIntoLine, ')
          ..write('columnOffset: $columnOffset, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    phileId,
    topLineIndex,
    fractionIntoLine,
    columnOffset,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingState &&
          other.phileId == this.phileId &&
          other.topLineIndex == this.topLineIndex &&
          other.fractionIntoLine == this.fractionIntoLine &&
          other.columnOffset == this.columnOffset &&
          other.updatedAt == this.updatedAt);
}

class ReadingStatesCompanion extends UpdateCompanion<ReadingState> {
  final Value<int> phileId;
  final Value<int> topLineIndex;
  final Value<double> fractionIntoLine;
  final Value<double> columnOffset;
  final Value<DateTime> updatedAt;
  const ReadingStatesCompanion({
    this.phileId = const Value.absent(),
    this.topLineIndex = const Value.absent(),
    this.fractionIntoLine = const Value.absent(),
    this.columnOffset = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ReadingStatesCompanion.insert({
    this.phileId = const Value.absent(),
    required int topLineIndex,
    required double fractionIntoLine,
    required double columnOffset,
    required DateTime updatedAt,
  }) : topLineIndex = Value(topLineIndex),
       fractionIntoLine = Value(fractionIntoLine),
       columnOffset = Value(columnOffset),
       updatedAt = Value(updatedAt);
  static Insertable<ReadingState> custom({
    Expression<int>? phileId,
    Expression<int>? topLineIndex,
    Expression<double>? fractionIntoLine,
    Expression<double>? columnOffset,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (phileId != null) 'phile_id': phileId,
      if (topLineIndex != null) 'top_line_index': topLineIndex,
      if (fractionIntoLine != null) 'fraction_into_line': fractionIntoLine,
      if (columnOffset != null) 'column_offset': columnOffset,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ReadingStatesCompanion copyWith({
    Value<int>? phileId,
    Value<int>? topLineIndex,
    Value<double>? fractionIntoLine,
    Value<double>? columnOffset,
    Value<DateTime>? updatedAt,
  }) {
    return ReadingStatesCompanion(
      phileId: phileId ?? this.phileId,
      topLineIndex: topLineIndex ?? this.topLineIndex,
      fractionIntoLine: fractionIntoLine ?? this.fractionIntoLine,
      columnOffset: columnOffset ?? this.columnOffset,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (phileId.present) {
      map['phile_id'] = Variable<int>(phileId.value);
    }
    if (topLineIndex.present) {
      map['top_line_index'] = Variable<int>(topLineIndex.value);
    }
    if (fractionIntoLine.present) {
      map['fraction_into_line'] = Variable<double>(fractionIntoLine.value);
    }
    if (columnOffset.present) {
      map['column_offset'] = Variable<double>(columnOffset.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingStatesCompanion(')
          ..write('phileId: $phileId, ')
          ..write('topLineIndex: $topLineIndex, ')
          ..write('fractionIntoLine: $fractionIntoLine, ')
          ..write('columnOffset: $columnOffset, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$ArchiveDatabase extends GeneratedDatabase {
  _$ArchiveDatabase(QueryExecutor e) : super(e);
  $ArchiveDatabaseManager get managers => $ArchiveDatabaseManager(this);
  late final $IssuesTable issues = $IssuesTable(this);
  late final $PhilesTable philes = $PhilesTable(this);
  late final $PhileTextChunksTable phileTextChunks = $PhileTextChunksTable(
    this,
  );
  late final $ReadingStatesTable readingStates = $ReadingStatesTable(this);
  late final Index phileTextByLine = Index(
    'phile_text_by_line',
    'CREATE INDEX phile_text_by_line ON phile_text (phile_id, first_line)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    issues,
    philes,
    phileTextChunks,
    readingStates,
    phileTextByLine,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'issues',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('philes', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'philes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('phile_text', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'philes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('reading_state', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$IssuesTableCreateCompanionBuilder = IssuesCompanion Function({
  Value<int> number,
  Value<DateTime?> releaseDate,
  Value<String?> title,
  required DateTime fetchedAt,
  required String sourceChecksum,
});
typedef $$IssuesTableUpdateCompanionBuilder = IssuesCompanion Function({
  Value<int> number,
  Value<DateTime?> releaseDate,
  Value<String?> title,
  Value<DateTime> fetchedAt,
  Value<String> sourceChecksum,
});

final class $$IssuesTableReferences
    extends BaseReferences<_$ArchiveDatabase, $IssuesTable, Issue> {
  $$IssuesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PhilesTable, List<Phile>> _philesRefsTable(
    _$ArchiveDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.philes,
    aliasName: 'issues__number__philes__issue',
  );

  $$PhilesTableProcessedTableManager get philesRefs {
    final manager = $$PhilesTableTableManager(
      $_db,
      $_db.philes,
    ).filter((f) => f.issue.number.sqlEquals($_itemColumn<int>('number')!));

    final cache = $_typedResult.readTableOrNull(_philesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$IssuesTableFilterComposer
    extends Composer<_$ArchiveDatabase, $IssuesTable> {
  $$IssuesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceChecksum => $composableBuilder(
    column: $table.sourceChecksum,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> philesRefs(
    Expression<bool> Function($$PhilesTableFilterComposer f) f,
  ) {
    final $$PhilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.number,
      referencedTable: $db.philes,
      getReferencedColumn: (t) => t.issue,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhilesTableFilterComposer(
            $db: $db,
            $table: $db.philes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$IssuesTableOrderingComposer
    extends Composer<_$ArchiveDatabase, $IssuesTable> {
  $$IssuesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceChecksum => $composableBuilder(
    column: $table.sourceChecksum,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$IssuesTableAnnotationComposer
    extends Composer<_$ArchiveDatabase, $IssuesTable> {
  $$IssuesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<DateTime> get releaseDate => $composableBuilder(
    column: $table.releaseDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  GeneratedColumn<String> get sourceChecksum => $composableBuilder(
    column: $table.sourceChecksum,
    builder: (column) => column,
  );

  Expression<T> philesRefs<T extends Object>(
    Expression<T> Function($$PhilesTableAnnotationComposer a) f,
  ) {
    final $$PhilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.number,
      referencedTable: $db.philes,
      getReferencedColumn: (t) => t.issue,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhilesTableAnnotationComposer(
            $db: $db,
            $table: $db.philes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$IssuesTableTableManager
    extends
        RootTableManager<
          _$ArchiveDatabase,
          $IssuesTable,
          Issue,
          $$IssuesTableFilterComposer,
          $$IssuesTableOrderingComposer,
          $$IssuesTableAnnotationComposer,
          $$IssuesTableCreateCompanionBuilder,
          $$IssuesTableUpdateCompanionBuilder,
          (Issue, $$IssuesTableReferences),
          Issue,
          PrefetchHooks Function({bool philesRefs})
        > {
  $$IssuesTableTableManager(_$ArchiveDatabase db, $IssuesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IssuesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IssuesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IssuesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> number = const Value.absent(),
                Value<DateTime?> releaseDate = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<String> sourceChecksum = const Value.absent(),
              }) => IssuesCompanion(
                number: number,
                releaseDate: releaseDate,
                title: title,
                fetchedAt: fetchedAt,
                sourceChecksum: sourceChecksum,
              ),
          createCompanionCallback:
              ({
                Value<int> number = const Value.absent(),
                Value<DateTime?> releaseDate = const Value.absent(),
                Value<String?> title = const Value.absent(),
                required DateTime fetchedAt,
                required String sourceChecksum,
              }) => IssuesCompanion.insert(
                number: number,
                releaseDate: releaseDate,
                title: title,
                fetchedAt: fetchedAt,
                sourceChecksum: sourceChecksum,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$IssuesTable, Issue>(table),
                  $$IssuesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({philesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (philesRefs) db.philes],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (philesRefs)
                    await $_getPrefetchedData<Issue, $IssuesTable, Phile>(
                      currentTable: table,
                      referencedTable: $$IssuesTableReferences._philesRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$IssuesTableReferences(db, table, p0).philesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.issue == item.number),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$IssuesTableProcessedTableManager =
    ProcessedTableManager<
      _$ArchiveDatabase,
      $IssuesTable,
      Issue,
      $$IssuesTableFilterComposer,
      $$IssuesTableOrderingComposer,
      $$IssuesTableAnnotationComposer,
      $$IssuesTableCreateCompanionBuilder,
      $$IssuesTableUpdateCompanionBuilder,
      (Issue, $$IssuesTableReferences),
      Issue,
      PrefetchHooks Function({bool philesRefs})
    >;
typedef $$PhilesTableCreateCompanionBuilder = PhilesCompanion Function({
  Value<int> id,
  required int issue,
  required int number,
  required String title,
  Value<String?> author,
  required String encoding,
  required int lineCount,
  required int longestLine,
  required Uint8List inventory,
});
typedef $$PhilesTableUpdateCompanionBuilder = PhilesCompanion Function({
  Value<int> id,
  Value<int> issue,
  Value<int> number,
  Value<String> title,
  Value<String?> author,
  Value<String> encoding,
  Value<int> lineCount,
  Value<int> longestLine,
  Value<Uint8List> inventory,
});

final class $$PhilesTableReferences
    extends BaseReferences<_$ArchiveDatabase, $PhilesTable, Phile> {
  $$PhilesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $IssuesTable _issueTable(_$ArchiveDatabase db) =>
      db.issues.createAlias('philes__issue__issues__number');

  $$IssuesTableProcessedTableManager get issue {
    final $_column = $_itemColumn<int>('issue')!;

    final manager = $$IssuesTableTableManager(
      $_db,
      $_db.issues,
    ).filter((f) => f.number.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_issueTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PhileTextChunksTable, List<PhileTextChunk>>
  _phileTextChunksRefsTable(_$ArchiveDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.phileTextChunks,
        aliasName: 'philes__id__phile_text__phile_id',
      );

  $$PhileTextChunksTableProcessedTableManager get phileTextChunksRefs {
    final manager = $$PhileTextChunksTableTableManager(
      $_db,
      $_db.phileTextChunks,
    ).filter((f) => f.phileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _phileTextChunksRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ReadingStatesTable, List<ReadingState>>
  _readingStatesRefsTable(_$ArchiveDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.readingStates,
        aliasName: 'philes__id__reading_state__phile_id',
      );

  $$ReadingStatesTableProcessedTableManager get readingStatesRefs {
    final manager = $$ReadingStatesTableTableManager(
      $_db,
      $_db.readingStates,
    ).filter((f) => f.phileId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_readingStatesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PhilesTableFilterComposer
    extends Composer<_$ArchiveDatabase, $PhilesTable> {
  $$PhilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encoding => $composableBuilder(
    column: $table.encoding,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lineCount => $composableBuilder(
    column: $table.lineCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get longestLine => $composableBuilder(
    column: $table.longestLine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get inventory => $composableBuilder(
    column: $table.inventory,
    builder: (column) => ColumnFilters(column),
  );

  $$IssuesTableFilterComposer get issue {
    final $$IssuesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.issue,
      referencedTable: $db.issues,
      getReferencedColumn: (t) => t.number,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IssuesTableFilterComposer(
            $db: $db,
            $table: $db.issues,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> phileTextChunksRefs(
    Expression<bool> Function($$PhileTextChunksTableFilterComposer f) f,
  ) {
    final $$PhileTextChunksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.phileTextChunks,
      getReferencedColumn: (t) => t.phileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhileTextChunksTableFilterComposer(
            $db: $db,
            $table: $db.phileTextChunks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> readingStatesRefs(
    Expression<bool> Function($$ReadingStatesTableFilterComposer f) f,
  ) {
    final $$ReadingStatesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.readingStates,
      getReferencedColumn: (t) => t.phileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReadingStatesTableFilterComposer(
            $db: $db,
            $table: $db.readingStates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PhilesTableOrderingComposer
    extends Composer<_$ArchiveDatabase, $PhilesTable> {
  $$PhilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get number => $composableBuilder(
    column: $table.number,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encoding => $composableBuilder(
    column: $table.encoding,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lineCount => $composableBuilder(
    column: $table.lineCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get longestLine => $composableBuilder(
    column: $table.longestLine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get inventory => $composableBuilder(
    column: $table.inventory,
    builder: (column) => ColumnOrderings(column),
  );

  $$IssuesTableOrderingComposer get issue {
    final $$IssuesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.issue,
      referencedTable: $db.issues,
      getReferencedColumn: (t) => t.number,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IssuesTableOrderingComposer(
            $db: $db,
            $table: $db.issues,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PhilesTableAnnotationComposer
    extends Composer<_$ArchiveDatabase, $PhilesTable> {
  $$PhilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get number =>
      $composableBuilder(column: $table.number, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get encoding =>
      $composableBuilder(column: $table.encoding, builder: (column) => column);

  GeneratedColumn<int> get lineCount =>
      $composableBuilder(column: $table.lineCount, builder: (column) => column);

  GeneratedColumn<int> get longestLine => $composableBuilder(
    column: $table.longestLine,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get inventory =>
      $composableBuilder(column: $table.inventory, builder: (column) => column);

  $$IssuesTableAnnotationComposer get issue {
    final $$IssuesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.issue,
      referencedTable: $db.issues,
      getReferencedColumn: (t) => t.number,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IssuesTableAnnotationComposer(
            $db: $db,
            $table: $db.issues,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> phileTextChunksRefs<T extends Object>(
    Expression<T> Function($$PhileTextChunksTableAnnotationComposer a) f,
  ) {
    final $$PhileTextChunksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.phileTextChunks,
      getReferencedColumn: (t) => t.phileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhileTextChunksTableAnnotationComposer(
            $db: $db,
            $table: $db.phileTextChunks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> readingStatesRefs<T extends Object>(
    Expression<T> Function($$ReadingStatesTableAnnotationComposer a) f,
  ) {
    final $$ReadingStatesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.readingStates,
      getReferencedColumn: (t) => t.phileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReadingStatesTableAnnotationComposer(
            $db: $db,
            $table: $db.readingStates,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PhilesTableTableManager
    extends
        RootTableManager<
          _$ArchiveDatabase,
          $PhilesTable,
          Phile,
          $$PhilesTableFilterComposer,
          $$PhilesTableOrderingComposer,
          $$PhilesTableAnnotationComposer,
          $$PhilesTableCreateCompanionBuilder,
          $$PhilesTableUpdateCompanionBuilder,
          (Phile, $$PhilesTableReferences),
          Phile,
          PrefetchHooks Function({
            bool issue,
            bool phileTextChunksRefs,
            bool readingStatesRefs,
          })
        > {
  $$PhilesTableTableManager(_$ArchiveDatabase db, $PhilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> issue = const Value.absent(),
                Value<int> number = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String> encoding = const Value.absent(),
                Value<int> lineCount = const Value.absent(),
                Value<int> longestLine = const Value.absent(),
                Value<Uint8List> inventory = const Value.absent(),
              }) => PhilesCompanion(
                id: id,
                issue: issue,
                number: number,
                title: title,
                author: author,
                encoding: encoding,
                lineCount: lineCount,
                longestLine: longestLine,
                inventory: inventory,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int issue,
                required int number,
                required String title,
                Value<String?> author = const Value.absent(),
                required String encoding,
                required int lineCount,
                required int longestLine,
                required Uint8List inventory,
              }) => PhilesCompanion.insert(
                id: id,
                issue: issue,
                number: number,
                title: title,
                author: author,
                encoding: encoding,
                lineCount: lineCount,
                longestLine: longestLine,
                inventory: inventory,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PhilesTable, Phile>(table),
                  $$PhilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                issue = false,
                phileTextChunksRefs = false,
                readingStatesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (phileTextChunksRefs) db.phileTextChunks,
                    if (readingStatesRefs) db.readingStates,
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
                        if (issue) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.issue,
                            referencedTable: $$PhilesTableReferences
                                ._issueTable(db),
                            referencedColumn: $$PhilesTableReferences
                                ._issueTable(db)
                                .number,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (phileTextChunksRefs)
                        await $_getPrefetchedData<
                          Phile,
                          $PhilesTable,
                          PhileTextChunk
                        >(
                          currentTable: table,
                          referencedTable: $$PhilesTableReferences
                              ._phileTextChunksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PhilesTableReferences(
                                db,
                                table,
                                p0,
                              ).phileTextChunksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.phileId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (readingStatesRefs)
                        await $_getPrefetchedData<
                          Phile,
                          $PhilesTable,
                          ReadingState
                        >(
                          currentTable: table,
                          referencedTable: $$PhilesTableReferences
                              ._readingStatesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PhilesTableReferences(
                                db,
                                table,
                                p0,
                              ).readingStatesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.phileId == item.id,
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

typedef $$PhilesTableProcessedTableManager =
    ProcessedTableManager<
      _$ArchiveDatabase,
      $PhilesTable,
      Phile,
      $$PhilesTableFilterComposer,
      $$PhilesTableOrderingComposer,
      $$PhilesTableAnnotationComposer,
      $$PhilesTableCreateCompanionBuilder,
      $$PhilesTableUpdateCompanionBuilder,
      (Phile, $$PhilesTableReferences),
      Phile,
      PrefetchHooks Function({
        bool issue,
        bool phileTextChunksRefs,
        bool readingStatesRefs,
      })
    >;
typedef $$PhileTextChunksTableCreateCompanionBuilder =
    PhileTextChunksCompanion Function({
      required int phileId,
      required int chunk,
      required int firstLine,
      required int lineCount,
      required Uint8List data,
      Value<int> rowid,
    });
typedef $$PhileTextChunksTableUpdateCompanionBuilder =
    PhileTextChunksCompanion Function({
      Value<int> phileId,
      Value<int> chunk,
      Value<int> firstLine,
      Value<int> lineCount,
      Value<Uint8List> data,
      Value<int> rowid,
    });

final class $$PhileTextChunksTableReferences
    extends
        BaseReferences<
          _$ArchiveDatabase,
          $PhileTextChunksTable,
          PhileTextChunk
        > {
  $$PhileTextChunksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PhilesTable _phileIdTable(_$ArchiveDatabase db) =>
      db.philes.createAlias('phile_text__phile_id__philes__id');

  $$PhilesTableProcessedTableManager get phileId {
    final $_column = $_itemColumn<int>('phile_id')!;

    final manager = $$PhilesTableTableManager(
      $_db,
      $_db.philes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_phileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PhileTextChunksTableFilterComposer
    extends Composer<_$ArchiveDatabase, $PhileTextChunksTable> {
  $$PhileTextChunksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get chunk => $composableBuilder(
    column: $table.chunk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get firstLine => $composableBuilder(
    column: $table.firstLine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lineCount => $composableBuilder(
    column: $table.lineCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  $$PhilesTableFilterComposer get phileId {
    final $$PhilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.phileId,
      referencedTable: $db.philes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhilesTableFilterComposer(
            $db: $db,
            $table: $db.philes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PhileTextChunksTableOrderingComposer
    extends Composer<_$ArchiveDatabase, $PhileTextChunksTable> {
  $$PhileTextChunksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get chunk => $composableBuilder(
    column: $table.chunk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get firstLine => $composableBuilder(
    column: $table.firstLine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lineCount => $composableBuilder(
    column: $table.lineCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  $$PhilesTableOrderingComposer get phileId {
    final $$PhilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.phileId,
      referencedTable: $db.philes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhilesTableOrderingComposer(
            $db: $db,
            $table: $db.philes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PhileTextChunksTableAnnotationComposer
    extends Composer<_$ArchiveDatabase, $PhileTextChunksTable> {
  $$PhileTextChunksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get chunk =>
      $composableBuilder(column: $table.chunk, builder: (column) => column);

  GeneratedColumn<int> get firstLine =>
      $composableBuilder(column: $table.firstLine, builder: (column) => column);

  GeneratedColumn<int> get lineCount =>
      $composableBuilder(column: $table.lineCount, builder: (column) => column);

  GeneratedColumn<Uint8List> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  $$PhilesTableAnnotationComposer get phileId {
    final $$PhilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.phileId,
      referencedTable: $db.philes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhilesTableAnnotationComposer(
            $db: $db,
            $table: $db.philes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PhileTextChunksTableTableManager
    extends
        RootTableManager<
          _$ArchiveDatabase,
          $PhileTextChunksTable,
          PhileTextChunk,
          $$PhileTextChunksTableFilterComposer,
          $$PhileTextChunksTableOrderingComposer,
          $$PhileTextChunksTableAnnotationComposer,
          $$PhileTextChunksTableCreateCompanionBuilder,
          $$PhileTextChunksTableUpdateCompanionBuilder,
          (PhileTextChunk, $$PhileTextChunksTableReferences),
          PhileTextChunk,
          PrefetchHooks Function({bool phileId})
        > {
  $$PhileTextChunksTableTableManager(
    _$ArchiveDatabase db,
    $PhileTextChunksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhileTextChunksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhileTextChunksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhileTextChunksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> phileId = const Value.absent(),
                Value<int> chunk = const Value.absent(),
                Value<int> firstLine = const Value.absent(),
                Value<int> lineCount = const Value.absent(),
                Value<Uint8List> data = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhileTextChunksCompanion(
                phileId: phileId,
                chunk: chunk,
                firstLine: firstLine,
                lineCount: lineCount,
                data: data,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int phileId,
                required int chunk,
                required int firstLine,
                required int lineCount,
                required Uint8List data,
                Value<int> rowid = const Value.absent(),
              }) => PhileTextChunksCompanion.insert(
                phileId: phileId,
                chunk: chunk,
                firstLine: firstLine,
                lineCount: lineCount,
                data: data,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PhileTextChunksTable, PhileTextChunk>(table),
                  $$PhileTextChunksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({phileId = false}) {
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
                    if (phileId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.phileId,
                        referencedTable: $$PhileTextChunksTableReferences
                            ._phileIdTable(db),
                        referencedColumn: $$PhileTextChunksTableReferences
                            ._phileIdTable(db)
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

typedef $$PhileTextChunksTableProcessedTableManager =
    ProcessedTableManager<
      _$ArchiveDatabase,
      $PhileTextChunksTable,
      PhileTextChunk,
      $$PhileTextChunksTableFilterComposer,
      $$PhileTextChunksTableOrderingComposer,
      $$PhileTextChunksTableAnnotationComposer,
      $$PhileTextChunksTableCreateCompanionBuilder,
      $$PhileTextChunksTableUpdateCompanionBuilder,
      (PhileTextChunk, $$PhileTextChunksTableReferences),
      PhileTextChunk,
      PrefetchHooks Function({bool phileId})
    >;
typedef $$ReadingStatesTableCreateCompanionBuilder =
    ReadingStatesCompanion Function({
      Value<int> phileId,
      required int topLineIndex,
      required double fractionIntoLine,
      required double columnOffset,
      required DateTime updatedAt,
    });
typedef $$ReadingStatesTableUpdateCompanionBuilder =
    ReadingStatesCompanion Function({
      Value<int> phileId,
      Value<int> topLineIndex,
      Value<double> fractionIntoLine,
      Value<double> columnOffset,
      Value<DateTime> updatedAt,
    });

final class $$ReadingStatesTableReferences
    extends
        BaseReferences<_$ArchiveDatabase, $ReadingStatesTable, ReadingState> {
  $$ReadingStatesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PhilesTable _phileIdTable(_$ArchiveDatabase db) =>
      db.philes.createAlias('reading_state__phile_id__philes__id');

  $$PhilesTableProcessedTableManager get phileId {
    final $_column = $_itemColumn<int>('phile_id')!;

    final manager = $$PhilesTableTableManager(
      $_db,
      $_db.philes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_phileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ReadingStatesTableFilterComposer
    extends Composer<_$ArchiveDatabase, $ReadingStatesTable> {
  $$ReadingStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get topLineIndex => $composableBuilder(
    column: $table.topLineIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fractionIntoLine => $composableBuilder(
    column: $table.fractionIntoLine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get columnOffset => $composableBuilder(
    column: $table.columnOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PhilesTableFilterComposer get phileId {
    final $$PhilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.phileId,
      referencedTable: $db.philes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhilesTableFilterComposer(
            $db: $db,
            $table: $db.philes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingStatesTableOrderingComposer
    extends Composer<_$ArchiveDatabase, $ReadingStatesTable> {
  $$ReadingStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get topLineIndex => $composableBuilder(
    column: $table.topLineIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fractionIntoLine => $composableBuilder(
    column: $table.fractionIntoLine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get columnOffset => $composableBuilder(
    column: $table.columnOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PhilesTableOrderingComposer get phileId {
    final $$PhilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.phileId,
      referencedTable: $db.philes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhilesTableOrderingComposer(
            $db: $db,
            $table: $db.philes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingStatesTableAnnotationComposer
    extends Composer<_$ArchiveDatabase, $ReadingStatesTable> {
  $$ReadingStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get topLineIndex => $composableBuilder(
    column: $table.topLineIndex,
    builder: (column) => column,
  );

  GeneratedColumn<double> get fractionIntoLine => $composableBuilder(
    column: $table.fractionIntoLine,
    builder: (column) => column,
  );

  GeneratedColumn<double> get columnOffset => $composableBuilder(
    column: $table.columnOffset,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$PhilesTableAnnotationComposer get phileId {
    final $$PhilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.phileId,
      referencedTable: $db.philes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PhilesTableAnnotationComposer(
            $db: $db,
            $table: $db.philes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingStatesTableTableManager
    extends
        RootTableManager<
          _$ArchiveDatabase,
          $ReadingStatesTable,
          ReadingState,
          $$ReadingStatesTableFilterComposer,
          $$ReadingStatesTableOrderingComposer,
          $$ReadingStatesTableAnnotationComposer,
          $$ReadingStatesTableCreateCompanionBuilder,
          $$ReadingStatesTableUpdateCompanionBuilder,
          (ReadingState, $$ReadingStatesTableReferences),
          ReadingState,
          PrefetchHooks Function({bool phileId})
        > {
  $$ReadingStatesTableTableManager(
    _$ArchiveDatabase db,
    $ReadingStatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> phileId = const Value.absent(),
                Value<int> topLineIndex = const Value.absent(),
                Value<double> fractionIntoLine = const Value.absent(),
                Value<double> columnOffset = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ReadingStatesCompanion(
                phileId: phileId,
                topLineIndex: topLineIndex,
                fractionIntoLine: fractionIntoLine,
                columnOffset: columnOffset,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> phileId = const Value.absent(),
                required int topLineIndex,
                required double fractionIntoLine,
                required double columnOffset,
                required DateTime updatedAt,
              }) => ReadingStatesCompanion.insert(
                phileId: phileId,
                topLineIndex: topLineIndex,
                fractionIntoLine: fractionIntoLine,
                columnOffset: columnOffset,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReadingStatesTable, ReadingState>(table),
                  $$ReadingStatesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({phileId = false}) {
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
                    if (phileId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.phileId,
                        referencedTable: $$ReadingStatesTableReferences
                            ._phileIdTable(db),
                        referencedColumn: $$ReadingStatesTableReferences
                            ._phileIdTable(db)
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

typedef $$ReadingStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$ArchiveDatabase,
      $ReadingStatesTable,
      ReadingState,
      $$ReadingStatesTableFilterComposer,
      $$ReadingStatesTableOrderingComposer,
      $$ReadingStatesTableAnnotationComposer,
      $$ReadingStatesTableCreateCompanionBuilder,
      $$ReadingStatesTableUpdateCompanionBuilder,
      (ReadingState, $$ReadingStatesTableReferences),
      ReadingState,
      PrefetchHooks Function({bool phileId})
    >;

class $ArchiveDatabaseManager {
  final _$ArchiveDatabase _db;
  $ArchiveDatabaseManager(this._db);
  $$IssuesTableTableManager get issues =>
      $$IssuesTableTableManager(_db, _db.issues);
  $$PhilesTableTableManager get philes =>
      $$PhilesTableTableManager(_db, _db.philes);
  $$PhileTextChunksTableTableManager get phileTextChunks =>
      $$PhileTextChunksTableTableManager(_db, _db.phileTextChunks);
  $$ReadingStatesTableTableManager get readingStates =>
      $$ReadingStatesTableTableManager(_db, _db.readingStates);
}
