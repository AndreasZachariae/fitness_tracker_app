import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/domain/names.dart';

void main() {
  test('cleanName trims and collapses whitespace', () {
    expect(cleanName('  Bank   drücken \n'), 'Bank drücken');
  });

  test('nameKey ignores case including umlauts', () {
    expect(nameKey('Übung A'), nameKey('übung a'));
    expect(nameKey('KNIEBEUGE'), nameKey(' kniebeuge '));
    expect(nameKey('Rudern'), isNot(nameKey('Rudern 2')));
  });

  test('isValidName', () {
    expect(isValidName('Plank'), isTrue);
    expect(isValidName('   '), isFalse);
    expect(isValidName(''), isFalse);
    expect(isValidName('x' * maxNameLength), isTrue);
    expect(isValidName('x' * (maxNameLength + 1)), isFalse);
  });

  test('compareNames sorts German names alphabetically', () {
    final names = ['Zug', 'ärmel', 'Übung', 'Ast', 'Straße', 'Strand', 'apfel'];
    names.sort(compareNames);
    expect(names, [
      'apfel',
      'ärmel',
      'Ast',
      'Strand',
      'Straße',
      'Übung',
      'Zug',
    ]);
  });
}
