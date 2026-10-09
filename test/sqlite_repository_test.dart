import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/data/sqlite_bowel_record_repository.dart';
import 'package:lalema/domain/bowel_record.dart';
import 'package:lalema/domain/record_details.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final now = DateTime(2026, 10, 9, 12);
  late Directory temporary;
  late String databasePath;
  final opened = <SqliteBowelRecordRepository>[];

  Future<SqliteBowelRecordRepository> open() async {
    final repository = await SqliteBowelRecordRepository.open(
      databasePath: databasePath,
      factory: databaseFactoryFfi,
      now: () => now,
    );
    opened.add(repository);
    return repository;
  }

  setUp(() async {
    sqfliteFfiInit();
    temporary = await Directory.systemTemp.createTemp('lalema-sqlite-');
    databasePath = '${temporary.path}/records.db';
  });
  tearDown(() async {
    for (final repository in opened) {
      await repository.close();
    }
    opened.clear();
    await temporary.delete(recursive: true);
  });

  test('upgrades a real v1 database without changing old records', () async {
    final legacy = await databaseFactoryFfi.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE bowel_records (recordId TEXT PRIMARY KEY NOT NULL, bristolType INTEGER NOT NULL, recordedAt INTEGER NOT NULL, updatedAt INTEGER NOT NULL)',
          );
          await db.execute(
            'CREATE INDEX index_bowel_records_recordedAt ON bowel_records(recordedAt)',
          );
        },
      ),
    );
    final occurredAt = DateTime(2024, 2, 29, 8).millisecondsSinceEpoch;
    await legacy.insert('bowel_records', {
      'recordId': 'legacy-id',
      'bristolType': 4,
      'recordedAt': occurredAt,
      'updatedAt': occurredAt,
    });
    await legacy.close();
    final repository = await open();
    final record = (await repository.loadAll()).single;
    expect(record.recordId, 'legacy-id');
    expect(record.recordedAt.millisecondsSinceEpoch, occurredAt);
    expect(record.updatedAt.millisecondsSinceEpoch, occurredAt);
    expect(record.details.isEmpty, isTrue);
    await repository.updateType(
      'legacy-id',
      3,
      details: const RecordDetails(note: '旧记录补充', discomfortMask: 8),
    );
    await repository.close();
    final reopened = await open();
    final updated = (await reopened.loadAll()).single;
    expect(updated.recordId, record.recordId);
    expect(updated.recordedAt, record.recordedAt);
    expect(updated.details.note, '旧记录补充');
    expect(updated.details.contains(Discomfort.straining), isTrue);
  });

  test(
    'create edit delete and restore retain optional details after reopening',
    () async {
      final repository = await open();
      final original = await repository.create(
        4,
        recordedAt: now.subtract(const Duration(days: 1)),
        details: const RecordDetails(
          note: '  饮食变化\n含逗号,引号"  ',
          discomfortMask: 3,
        ),
      );
      expect(original.details.note, '饮食变化\n含逗号,引号"');
      await repository.updateType(original.recordId, 5);
      final updated = (await repository.loadAll()).single;
      expect(updated.details.note, original.details.note);
      await repository.delete(original.recordId);
      expect(await repository.loadAll(), isEmpty);
      await repository.restore(updated);
      await repository.close();
      final reopened = await open();
      final restored = (await reopened.loadAll()).single;
      expect(restored.toMap(), updated.toMap());
      await expectLater(
        reopened.restore(restored),
        throwsA(isA<DatabaseException>()),
      );
      expect(await reopened.loadAll(), hasLength(1));
      await reopened.updateType(
        restored.recordId,
        5,
        details: const RecordDetails(),
      );
      expect((await reopened.loadAll()).single.details.isEmpty, isTrue);
    },
  );

  test('invalid updates leave original data intact', () async {
    final repository = await open();
    final record = await repository.create(
      4,
      details: const RecordDetails(note: '保留这条备注'),
    );
    for (final bad in [
      RecordDetails(note: 'x' * 1001),
      const RecordDetails(discomfortMask: 16),
    ]) {
      await expectLater(
        repository.updateType(record.recordId, 2, details: bad),
        throwsArgumentError,
      );
      expect((await repository.loadAll()).single.toMap(), record.toMap());
    }
    await expectLater(repository.create(8), throwsArgumentError);
    await expectLater(
      repository.create(4, recordedAt: now.add(const Duration(minutes: 1))),
      throwsArgumentError,
    );
    await expectLater(repository.updateType('missing', 3), throwsStateError);
    await expectLater(repository.delete('missing'), throwsStateError);
    expect(await repository.loadAll(), hasLength(1));
  });

  test('note limit counts visible characters including emoji', () async {
    final repository = await open();
    final record = await repository.create(
      4,
      details: RecordDetails(note: '🌱' * 1000),
    );
    expect(record.details.note, '🌱' * 1000);
    await expectLater(
      repository.create(4, details: RecordDetails(note: '🌱' * 1001)),
      throwsArgumentError,
    );
    expect(await repository.loadAll(), hasLength(1));
  });

  test('reads legacy maps and rejects malformed details', () {
    final map = <String, Object>{
      'recordId': 'id',
      'bristolType': 4,
      'recordedAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    };
    expect(BowelRecord.fromMap(map).details.isEmpty, isTrue);
    expect(
      () => BowelRecord.fromMap({...map, 'discomforts': -1}),
      throwsArgumentError,
    );
  });
}
