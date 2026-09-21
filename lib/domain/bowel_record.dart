class BowelRecord {
  const BowelRecord({
    required this.recordId,
    required this.bristolType,
    required this.recordedAt,
    required this.updatedAt,
  });

  final String recordId;
  final int bristolType;
  final DateTime recordedAt;
  final DateTime updatedAt;

  Map<String, Object> toMap() => <String, Object>{
    'recordId': recordId,
    'bristolType': bristolType,
    'recordedAt': recordedAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
  };

  factory BowelRecord.fromMap(Map<String, Object?> map) {
    return BowelRecord(
      recordId: map['recordId']! as String,
      bristolType: map['bristolType']! as int,
      recordedAt: DateTime.fromMillisecondsSinceEpoch(
        map['recordedAt']! as int,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt']! as int),
    );
  }
}
