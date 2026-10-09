import 'record_details.dart';

class BowelRecord {
  const BowelRecord({
    required this.recordId,
    required this.bristolType,
    required this.recordedAt,
    required this.updatedAt,
    this.details = const RecordDetails(),
  });

  final String recordId;
  final int bristolType;
  final DateTime recordedAt;
  final DateTime updatedAt;
  final RecordDetails details;

  Map<String, Object> toMap() => <String, Object>{
    'recordId': recordId,
    'bristolType': bristolType,
    'recordedAt': recordedAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    'note': details.note,
    'discomforts': details.discomfortMask,
  };

  factory BowelRecord.fromMap(Map<String, Object?> map) {
    return BowelRecord(
      recordId: map['recordId']! as String,
      bristolType: map['bristolType']! as int,
      recordedAt: DateTime.fromMillisecondsSinceEpoch(
        map['recordedAt']! as int,
      ),
      details: RecordDetails(
        note: map['note'] as String? ?? '',
        discomfortMask: map['discomforts'] as int? ?? 0,
      ).validated(),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt']! as int),
    );
  }
}
