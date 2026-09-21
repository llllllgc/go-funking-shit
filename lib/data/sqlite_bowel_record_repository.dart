import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../domain/bowel_record.dart';
import 'bowel_record_repository.dart';

class SqliteBowelRecordRepository implements BowelRecordRepository {
  SqliteBowelRecordRepository._(this._database, this._uuid);

  static const _table = 'bowel_records';
  final Database _database;
  final Uuid _uuid;

  static Future<SqliteBowelRecordRepository> open() async {
    final databasePath = path.join(await getDatabasesPath(), 'lalema.db');
    final database = await openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE $_table (
            recordId TEXT PRIMARY KEY NOT NULL,
            bristolType INTEGER NOT NULL,
            recordedAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX index_bowel_records_recordedAt '
          'ON $_table(recordedAt)',
        );
      },
    );
    return SqliteBowelRecordRepository._(database, const Uuid());
  }

  @override
  Future<List<BowelRecord>> loadAll() async {
    final rows = await _database.query(
      _table,
      orderBy: 'recordedAt DESC, recordId DESC',
    );
    return rows.map(BowelRecord.fromMap).toList(growable: false);
  }

  @override
  Future<BowelRecord> create(int bristolType, {DateTime? recordedAt}) async {
    _requireValidType(bristolType);
    final now = DateTime.now();
    _requireValidTime(recordedAt, now);
    final record = BowelRecord(
      recordId: _uuid.v4(),
      bristolType: bristolType,
      recordedAt: recordedAt ?? now,
      updatedAt: now,
    );
    await _database.insert(
      _table,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return record;
  }

  @override
  Future<void> updateType(
    String recordId,
    int bristolType, {
    DateTime? recordedAt,
  }) async {
    if (recordId.trim().isEmpty) {
      throw ArgumentError('recordId must not be blank');
    }
    _requireValidType(bristolType);
    final now = DateTime.now();
    _requireValidTime(recordedAt, now);
    final changed = await _database.update(
      _table,
      <String, Object>{
        'bristolType': bristolType,
        if (recordedAt != null) 'recordedAt': recordedAt.millisecondsSinceEpoch,
        'updatedAt': now.millisecondsSinceEpoch,
      },
      where: 'recordId = ?',
      whereArgs: <Object>[recordId],
    );
    if (changed != 1) throw StateError('Record no longer exists');
  }

  @override
  Future<void> delete(String recordId) async {
    if (recordId.trim().isEmpty) {
      throw ArgumentError('recordId must not be blank');
    }
    final changed = await _database.delete(
      _table,
      where: 'recordId = ?',
      whereArgs: <Object>[recordId],
    );
    if (changed != 1) throw StateError('Record no longer exists');
  }

  void _requireValidType(int value) {
    if (value < 1 || value > 7) {
      throw ArgumentError.value(
        value,
        'bristolType',
        'must be between 1 and 7',
      );
    }
  }

  void _requireValidTime(DateTime? value, DateTime now) {
    if (value != null &&
        (value.isBefore(DateTime(1900)) || value.isAfter(now))) {
      throw ArgumentError.value(value, 'recordedAt', 'must be a past time');
    }
  }
}
