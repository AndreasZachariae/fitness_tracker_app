import 'package:flutter_test/flutter_test.dart';
import 'package:gymlog/domain/models/local_date.dart';

void main() {
  test('parse and format YYYY-MM-DD', () {
    final d = LocalDate.parse('2026-11-03');
    expect((d.year, d.month, d.day), (2026, 11, 3));
    expect(d.toIsoString(), '2026-11-03');
    expect(LocalDate(5, 1, 9).toIsoString(), '0005-01-09');
  });

  for (final invalid in [
    '2026-02-30',
    '2026-13-01',
    '2026-1-01',
    '03.11.2026',
    '',
    '2026-11-03T00:00',
  ]) {
    test('rejects "$invalid"', () {
      expect(() => LocalDate.parse(invalid), throwsFormatException);
    });
  }

  test('constructor rejects impossible dates', () {
    expect(() => LocalDate(2026, 2, 29), throwsArgumentError);
    expect(LocalDate(2028, 2, 29).day, 29);
  });

  test('addDays across month, year and DST changes', () {
    expect(LocalDate(2026, 12, 31).addDays(1), LocalDate(2027, 1, 1));
    expect(LocalDate(2026, 3, 1).addDays(-1), LocalDate(2026, 2, 28));
    // DST in Europe: 2026-03-29 and 2026-10-25
    expect(LocalDate(2026, 3, 28).addDays(2), LocalDate(2026, 3, 30));
    expect(LocalDate(2026, 10, 24).addDays(2), LocalDate(2026, 10, 26));
  });

  test('differenceInDays, ordering and weekday', () {
    expect(LocalDate(2026, 11, 3).differenceInDays(LocalDate(2026, 10, 3)), 31);
    expect(LocalDate(2026, 1, 1).isBefore(LocalDate(2026, 1, 2)), isTrue);
    expect(LocalDate(2026, 1, 2).isAfter(LocalDate(2026, 1, 1)), isTrue);
    expect(LocalDate(2026, 11, 3).weekday, DateTime.tuesday);
    expect(LocalDate(2026, 11, 8).weekday, DateTime.sunday);
  });

  test('fromDateTime uses the local day', () {
    final local = DateTime(2026, 11, 3, 23, 59);
    expect(LocalDate.fromDateTime(local), LocalDate(2026, 11, 3));
    expect(LocalDate.fromDateTime(local.toUtc()), LocalDate(2026, 11, 3));
  });

  test('equality and hashCode', () {
    expect(LocalDate(2026, 11, 3), LocalDate.parse('2026-11-03'));
    expect({
      LocalDate(2026, 11, 3),
      LocalDate.parse('2026-11-03'),
    }, hasLength(1));
  });
}
