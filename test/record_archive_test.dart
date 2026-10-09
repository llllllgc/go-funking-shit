import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lalema/data/backup_files.dart';
import 'package:lalema/data/record_archive.dart';
import 'package:lalema/domain/bowel_record.dart';
import 'package:lalema/domain/record_details.dart';
import 'package:lalema/domain/record_transfer.dart';

void main() {
  final now = DateTime(2026, 10, 9, 12);
  BowelRecord record({
    String id = 'id',
    String note = '备注🌱\n第二行,含"引号"',
    int type = 4,
  }) => BowelRecord(
    recordId: id,
    bristolType: type,
    recordedAt: DateTime(2024, 2, 29, 9, 15),
    updatedAt: now,
    details: RecordDetails(note: note, discomfortMask: 3),
  );
  Uint8List archive(List<BowelRecord> records) => RecordArchiveCodec.encode(
    RecordArchive(records: records, exportedAt: now),
  );
  Uint8List mutate(void Function(Map<String, dynamic>) edit) {
    final map =
        jsonDecode(utf8.decode(archive([record()]))) as Map<String, dynamic>;
    edit(map);
    return Uint8List.fromList(utf8.encode(jsonEncode(map)));
  }

  test(
    'backup round trip preserves identities instants and all optional context',
    () {
      final original = [record(), record(id: 'second', note: '', type: 7)];
      final restored = RecordArchiveCodec.decode(archive(original), now: now);
      expect(
        restored.records.map((r) => r.toMap()),
        original.map((r) => r.toMap()),
      );
      expect(restored.exportedAt, now);
      expect(RecordArchiveCodec.decode(archive([]), now: now).records, isEmpty);
      final bom = Uint8List.fromList([0xef, 0xbb, 0xbf, ...archive(original)]);
      expect(RecordArchiveCodec.decode(bom, now: now).records, hasLength(2));
    },
  );

  test(
    'corrupt, truncated, wrong-version and ambiguous archives are rejected',
    () {
      final cases = <Uint8List>[
        Uint8List.fromList([0xff, 0xfe]),
        Uint8List.fromList(utf8.encode('{')),
        mutate((m) => m['app'] = 'other'),
        mutate((m) => m['formatVersion'] = 2),
        mutate((m) => m['formatVersion'] = 1.0),
        mutate((m) => m['recordCount'] = 2),
        mutate((m) => m['extra'] = 'unknown'),
        mutate((m) => m['records'] = null),
        mutate((m) {
          m['records'] = [...m['records'], ...m['records']];
          m['recordCount'] = 2;
        }),
        mutate((m) => m['records'][0]['bristolType'] = 8),
        mutate((m) => m['records'][0]['recordId'] = ''),
        mutate((m) => m['records'][0]['recordedAt'] = '2024-02-29'),
        mutate(
          (m) => m['records'][0]['updatedAt'] = now
              .add(const Duration(days: 1))
              .millisecondsSinceEpoch,
        ),
        mutate((m) => m['records'][0]['discomforts'] = 16),
        mutate((m) => m['records'][0]['note'] = 'x' * 1001),
        mutate((m) => (m['records'][0] as Map).remove('note')),
        mutate((m) => m['records'][0]['newField'] = 'unsupported'),
      ];
      for (final bytes in cases) {
        expect(
          () => RecordArchiveCodec.decode(bytes, now: now),
          throwsA(isA<ArchiveException>()),
        );
      }
    },
  );

  test(
    'import preview separates exact duplicates and conflicts without overwriting',
    () {
      final original = record();
      final plan = ImportPlan.compare(
        [original],
        [record(note: '修改了'), record(id: 'new')],
      );
      expect(plan.additions.single.recordId, 'new');
      expect(plan.conflicts, 1);
      expect(plan.duplicates, 0);
      final again = ImportPlan.compare([original], [record()]);
      expect(again.duplicates, 1);
      expect(again.additions, isEmpty);
      expect(original.details.note, '备注🌱\n第二行,含"引号"');
    },
  );

  test(
    'CSV protects optional fields by default and escapes content and formulas',
    () {
      final csv = utf8.decode(
        RecordArchiveCodec.csv([
          record(note: '=HYPERLINK("bad")'),
        ], includeDetails: false),
      );
      expect(
        RecordArchiveCodec.csv([record()], includeDetails: false).take(3),
        [0xef, 0xbb, 0xbf],
      );
      expect(csv, contains('2024-02-29T09:15:00.000'));
      expect(csv, contains('光滑柔软'));
      expect(csv, isNot(contains('HYPERLINK')));
      for (final note in ['=1+1', '+cmd', '-cmd', '@cmd', ' \t=cmd']) {
        final detailed = utf8.decode(
          RecordArchiveCodec.csv([record(note: note)], includeDetails: true),
        );
        expect(detailed, contains('"\'$note"'));
      }
      final escaped = utf8.decode(
        RecordArchiveCodec.csv([record()], includeDetails: true),
      );
      expect(escaped, contains('"备注🌱\n第二行,含""引号"""'));
      expect(escaped, contains('腹痛、腹胀'));
    },
  );

  test('bounded file reading rejects growth even when metadata lied', () async {
    expect(
      await readBoundedBytes(
        Stream.fromIterable([
          Uint8List.fromList([1]),
          Uint8List.fromList([2, 3]),
        ]),
      ),
      [1, 2, 3],
    );
    await expectLater(
      readBoundedBytes(
        Stream.fromIterable([
          Uint8List(RecordArchiveCodec.maxBytes),
          Uint8List.fromList([1]),
        ]),
      ),
      throwsA(isA<ArchiveException>()),
    );
  });
}
