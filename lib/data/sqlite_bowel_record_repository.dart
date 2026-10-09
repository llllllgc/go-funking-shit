import 'privacy_services.dart';
import '../domain/record_transfer.dart';
import 'record_archive.dart';
import '../domain/record_details.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../domain/bowel_record.dart';
import 'bowel_record_repository.dart';

class SqliteBowelRecordRepository
    implements BowelRecordRepository, AppLockStore {
  SqliteBowelRecordRepository._(this._database, this._uuid, this._now);

  static const schemaVersion = 3;
  static const _table = 'bowel_records';
  final Database _database;
  final Uuid _uuid;
  final DateTime Function() _now;

  static Future<SqliteBowelRecordRepository> open({
    String? databasePath,
    DatabaseFactory? factory,
    DateTime Function()? now,
  }) async {
    final dbFactory = factory ?? databaseFactory;
    final location =
        databasePath ??
        path.join(await dbFactory.getDatabasesPath(), 'lalema.db');
    final database = await dbFactory.openDatabase(
      location,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE $_table (
              recordId TEXT PRIMARY KEY NOT NULL,
              bristolType INTEGER NOT NULL CHECK(bristolType BETWEEN 1 AND 7),
              recordedAt INTEGER NOT NULL,
              updatedAt INTEGER NOT NULL,
              note TEXT NOT NULL DEFAULT '',
              discomforts INTEGER NOT NULL DEFAULT 0 CHECK(discomforts BETWEEN 0 AND 15)
            )
          ''');
          await db.execute(
            'CREATE INDEX index_bowel_records_recordedAt ON $_table(recordedAt)',
          );
          await _createSettings(db);
        },
        onUpgrade: (db, oldVersion, _) async {
          // sqflite wraps onUpgrade in a transaction. Never rebuild or clear
          // the table: existing identities and occurrence times stay intact.
          if (oldVersion < 2) {
            await db.execute(
              "ALTER TABLE $_table ADD COLUMN note TEXT NOT NULL DEFAULT ''",
            );
            await db.execute(
              'ALTER TABLE $_table ADD COLUMN discomforts INTEGER NOT NULL DEFAULT 0',
            );
          }
          if (oldVersion < 3) await _createSettings(db);
        },
      ),
    );
    return SqliteBowelRecordRepository._(
      database,
      const Uuid(),
      now ?? DateTime.now,
    );
  }

  static Future<void> _createSettings(Database db) => db.execute(
    'CREATE TABLE app_settings (key TEXT PRIMARY KEY NOT NULL, value INTEGER NOT NULL CHECK(value IN (0,1)))',
  );

  @override
  Future<bool> readLockEnabled() async {
    final rows = await _database.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['app_lock'],
    );
    if (rows.isEmpty) return false;
    final value = rows.single['value'];
    if (value != 0 && value != 1) throw StateError('Invalid app lock setting');
    return value == 1;
  }

  @override
  Future<void> writeLockEnabled(bool enabled) async {
    await _database.insert('app_settings', {
      'key': 'app_lock',
      'value': enabled ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> close() => _database.close();

  @override
  Future<List<BowelRecord>> loadAll() async {
    final rows = await _database.query(
      _table,
      orderBy: 'recordedAt DESC, recordId DESC',
    );
    return rows.map(BowelRecord.fromMap).toList(growable: false);
  }

  @override
  Future<BowelRecord> create(
    int bristolType, {
    DateTime? recordedAt,
    RecordDetails details = const RecordDetails(),
  }) async {
    _requireValidType(bristolType);
    final now = _now();
    _requireValidTime(recordedAt, now);
    final record = BowelRecord(
      recordId: _uuid.v4(),
      bristolType: bristolType,
      recordedAt: recordedAt ?? now,
      updatedAt: now,
      details: details.validated(),
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
    RecordDetails? details,
  }) async {
    if (recordId.trim().isEmpty) {
      throw ArgumentError('recordId must not be blank');
    }
    _requireValidType(bristolType);
    final now = _now();
    _requireValidTime(recordedAt, now);
    final changed = await _database.update(
      _table,
      <String, Object>{
        'bristolType': bristolType,
        if (details != null) ...{
          'note': details.validated().note,
          'discomforts': details.discomfortMask,
        },
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

  @override
  Future<void> restore(BowelRecord record) async {
    _requireValidType(record.bristolType);
    _requireValidTime(record.recordedAt, _now());
    record.details.validated();
    if (record.recordId.trim().isEmpty) {
      throw ArgumentError('recordId must not be blank');
    }
    await _database.insert(
      _table,
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<ImportPlan> importRecords(List<BowelRecord> records) async {
    final incoming = List<BowelRecord>.unmodifiable(records);
    RecordArchiveCodec.validateRecords(incoming, now: _now());
    return _database.transaction((txn) async {
      final local = (await txn.query(_table)).map(BowelRecord.fromMap).toList();
      final plan = ImportPlan.compare(local, incoming);
      final batch = txn.batch();
      for (final record in plan.additions) {
        batch.insert(
          _table,
          record.toMap(),
          conflictAlgorithm: ConflictAlgorithm.abort,
        );
      }
      await batch.commit(noResult: true);
      return plan;
    });
  }

  @override
  Future<int> deleteAll() => _database.delete(_table);

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
