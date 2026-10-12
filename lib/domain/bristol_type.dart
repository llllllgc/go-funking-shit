class BristolType {
  const BristolType(this.number, this.label);

  final int number;
  final String label;

  // The list uses position labels; persisted Bristol values keep their meaning.
  String get code => switch (number) {
    4 => '01',
    1 => '04',
    _ => number.toString().padLeft(2, '0'),
  };

  String get assetPath =>
      'assets/icons/ic_bristol_${number.toString().padLeft(2, '0')}.svg';
}

const bristolTypes = <BristolType>[
  BristolType(4, '光滑柔软'),
  BristolType(2, '成块偏硬'),
  BristolType(3, '成形有裂纹'),
  BristolType(1, '颗粒偏硬'),
  BristolType(5, '柔软小块'),
  BristolType(6, '松散糊状'),
  BristolType(7, '水样偏稀'),
];

BristolType? bristolTypeFor(int number) {
  for (final type in bristolTypes) {
    if (type.number == number) return type;
  }
  return null;
}
