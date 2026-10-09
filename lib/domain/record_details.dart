import 'package:characters/characters.dart';

/// Optional context about one occurrence. Absence means not recorded, not
/// evidence that a symptom was absent. Stable bits are persisted in SQLite.
enum Discomfort {
  pain(1, '腹痛'),
  bloating(2, '腹胀'),
  urgency(4, '急迫'),
  straining(8, '费力');

  const Discomfort(this.bit, this.label);
  final int bit;
  final String label;
}

class RecordDetails {
  const RecordDetails({this.note = '', this.discomfortMask = 0});

  static const maxNoteLength = 1000;
  final String note;
  final int discomfortMask;

  bool get isEmpty => note.trim().isEmpty && discomfortMask == 0;
  bool contains(Discomfort value) => discomfortMask & value.bit != 0;
  Iterable<Discomfort> get discomforts => Discomfort.values.where(contains);

  RecordDetails validated({bool trimNote = true}) {
    if (note.characters.length > maxNoteLength ||
        discomfortMask < 0 ||
        discomfortMask > 15) {
      throw ArgumentError('Invalid optional record details');
    }
    return RecordDetails(
      note: trimNote ? note.trim() : note,
      discomfortMask: discomfortMask,
    );
  }
}
