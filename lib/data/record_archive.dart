import 'dart:convert';
import 'dart:typed_data';

import '../domain/bowel_record.dart';
import '../domain/bristol_type.dart';
import '../domain/record_details.dart';

class ArchiveException implements Exception {
  const ArchiveException(this.message);
  final String message;
  @override
  String toString() => message;
}

class RecordArchive {
  RecordArchive({required List<BowelRecord> records, required this.exportedAt})
    : records = List.unmodifiable(records);
  final List<BowelRecord> records;
  final DateTime exportedAt;
}

abstract final class RecordArchiveCodec {
  static const maxBytes = 32 * 1024 * 1024;
  static const maxRecords = 100000;
  static const formatVersion = 1;

  static Uint8List encode(RecordArchive archive) {
    validateRecords(archive.records, now: archive.exportedAt);
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'app': 'lalema',
          'formatVersion': formatVersion,
          'exportedAt': archive.exportedAt.millisecondsSinceEpoch,
          'recordCount': archive.records.length,
          'records': [for (final record in archive.records) record.toMap()],
        }),
      ),
    );
    if (bytes.length > maxBytes) {
      throw const ArchiveException('备份超过 32 MB，暂时无法处理。');
    }
    return bytes;
  }

  static RecordArchive decode(Uint8List bytes, {required DateTime now}) {
    if (bytes.length > maxBytes) {
      throw const ArchiveException('文件超过 32 MB，请选择较小的备份。');
    }
    try {
      var source = utf8.decode(bytes);
      if (source.startsWith('\uFEFF')) source = source.substring(1);
      final value = jsonDecode(source);
      if (value is! Map<String, dynamic> || value['app'] != 'lalema') {
        throw const ArchiveException('这不是拉了么的 JSON 备份文件。');
      }
      if (value['formatVersion'] != formatVersion ||
          value['formatVersion'] is! int) {
        throw const ArchiveException('暂不支持此备份版本，请先更新应用。');
      }
      _requireKeys(value, const {
        'app',
        'formatVersion',
        'exportedAt',
        'recordCount',
        'records',
      });
      final rows = value['records'];
      if (rows is! List ||
          value['recordCount'] is! int ||
          rows.length != value['recordCount']) {
        throw const ArchiveException('备份记录数量不完整，未导入任何记录。');
      }
      if (rows.length > maxRecords) {
        throw const ArchiveException('备份超过 100000 条记录，暂时无法处理。');
      }
      final exportedAt = _readTime(value['exportedAt'], now);
      final records = <BowelRecord>[];
      for (final row in rows) {
        if (row is! Map<String, dynamic>) throw const FormatException();
        _requireKeys(row, const {
          'recordId',
          'bristolType',
          'recordedAt',
          'updatedAt',
          'note',
          'discomforts',
        });
        if (row['recordId'] is! String ||
            row['bristolType'] is! int ||
            row['note'] is! String ||
            row['discomforts'] is! int) {
          throw const FormatException();
        }
        records.add(
          BowelRecord(
            recordId: row['recordId'] as String,
            bristolType: row['bristolType'] as int,
            recordedAt: _readTime(row['recordedAt'], now),
            updatedAt: _readTime(row['updatedAt'], now),
            details: RecordDetails(
              note: row['note'] as String,
              discomfortMask: row['discomforts'] as int,
            ),
          ),
        );
      }
      validateRecords(records, now: now);
      return RecordArchive(records: records, exportedAt: exportedAt);
    } on ArchiveException {
      rethrow;
    } catch (_) {
      throw const ArchiveException('备份文件损坏或格式不正确，未导入任何记录。');
    }
  }

  static void validateRecords(
    List<BowelRecord> records, {
    required DateTime now,
  }) {
    if (records.length > maxRecords) {
      throw const ArchiveException('备份超过 100000 条记录，暂时无法处理。');
    }
    final ids = <String>{};
    for (final record in records) {
      if (record.recordId.trim().isEmpty ||
          record.recordId.length > 128 ||
          RegExp(r'[\x00-\x1f\x7f]').hasMatch(record.recordId) ||
          record.bristolType < 1 ||
          record.bristolType > 7) {
        throw const ArchiveException('备份包含无效记录，未导入任何记录。');
      }
      if (!ids.add(record.recordId)) {
        throw const ArchiveException('备份内有重复的记录编号，请检查文件。');
      }
      _readTime(record.recordedAt.millisecondsSinceEpoch, now);
      _readTime(record.updatedAt.millisecondsSinceEpoch, now);
      try {
        record.details.validated();
      } catch (_) {
        throw const ArchiveException('备份中的备注或不适信息无效，未导入任何记录。');
      }
    }
  }

  static DateTime _readTime(Object? value, DateTime now) {
    if (value is! int ||
        value < DateTime.utc(1900).millisecondsSinceEpoch ||
        value > now.millisecondsSinceEpoch) {
      throw const ArchiveException('备份时间超出范围，请检查文件和设备时间。');
    }
    return DateTime.fromMillisecondsSinceEpoch(value);
  }

  static void _requireKeys(Map<String, dynamic> map, Set<String> keys) {
    if (map.length != keys.length || !map.keys.every(keys.contains)) {
      throw const ArchiveException('备份字段不兼容或不完整，未导入任何记录。');
    }
  }

  /// Human-readable export, not an import format. All cells are quoted and
  /// spreadsheet formula prefixes are neutralized, including after whitespace.
  static Uint8List csv(
    List<BowelRecord> records, {
    required bool includeDetails,
  }) {
    final rows = <List<String>>[
      [
        '发生时间（含时区）',
        'Bristol 类型',
        '形态',
        if (includeDetails) ...['不适', '备注'],
      ],
      for (final record in records)
        [
          _localIso(record.recordedAt),
          '${record.bristolType}',
          bristolTypeFor(record.bristolType)?.label ?? '',
          if (includeDetails) ...[
            record.details.discomforts.map((value) => value.label).join('、'),
            record.details.note,
          ],
        ],
    ];
    return Uint8List.fromList(
      utf8.encode(
        '\uFEFF${rows.map((row) => row.map(_csvCell).join(',')).join('\r\n')}\r\n',
      ),
    );
  }

  static String _csvCell(String value) {
    final trimmed = value.trimLeft();
    if (RegExp(r'^[=+@\-\t\r\n]').hasMatch(trimmed) ||
        RegExp(r'^[\t\r\n]').hasMatch(value)) {
      value = "'$value";
    }
    return '"${value.replaceAll('"', '""')}"';
  }

  static String _localIso(DateTime value) {
    final local = value.toLocal();
    final offset = local.timeZoneOffset;
    final minutes = offset.inMinutes.abs();
    final sign = offset.isNegative ? '-' : '+';
    return '${local.toIso8601String()}$sign${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
  }
}
