import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/domain/serialization/csv.dart';

void main() {
  final fields = <(Object?, String)>[
    (null, ''),
    ('Bankdrücken', 'Bankdrücken'),
    ('a,b', '"a,b"'),
    ('Er sagte "ja"', '"Er sagte ""ja"""'),
    ('Zeile 1\nZeile 2', '"Zeile 1\nZeile 2"'),
    ('x\r', '"x\r"'),
    (' Leerzeichen', '" Leerzeichen"'),
    (62.5, '62.5'),
    (80.0, '80'),
    (83.33333, '83.33'),
    (10, '10'),
    (true, 'true'),
    (false, 'false'),
  ];
  for (final (value, expected) in fields) {
    test('csvField($value) → $expected', () {
      expect(csvField(value), expected);
    });
  }

  test('document: header, CRLF line ends, no BOM', () {
    final csv = toCsv(
      ['a', 'b'],
      [
        [1, 'x,y'],
        [null, 2.5],
      ],
    );
    expect(csv, 'a,b\r\n1,"x,y"\r\n,2.5\r\n');
    expect(csv.codeUnitAt(0), isNot(0xFEFF));
  });

  test('isoWithOffset uses the local offset', () {
    final t = DateTime.utc(2026, 11, 3, 17, 20);
    final local = t.toLocal();
    final text = isoWithOffset(t);
    expect(DateTime.parse(text).toUtc(), t);
    expect(text, startsWith('${local.year}-11-0'));
    expect(
      text,
      matches(RegExp(r'^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d[+-]\d\d:\d\d$')),
    );
  });
}
