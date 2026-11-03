import 'package:drift/drift.dart';

import '../../../domain/models/models.dart';
import '../database.dart';
import '../tables.dart';

part 'body_weight_dao.g.dart';

@DriftAccessor(tables: [BodyWeightEntries])
class BodyWeightDao extends DatabaseAccessor<AppDatabase>
    with _$BodyWeightDaoMixin {
  BodyWeightDao(super.attachedDatabase);

  /// All entries, newest day first.
  Stream<List<BodyWeightEntry>> watchAll() => (select(
    bodyWeightEntries,
  )..orderBy([(b) => OrderingTerm.desc(b.date)])).watch();

  /// All entries, oldest day first.
  Future<List<BodyWeightEntry>> getAllAscending() => (select(
    bodyWeightEntries,
  )..orderBy([(b) => OrderingTerm.asc(b.date)])).get();

  Future<BodyWeightEntry?> findByDate(LocalDate date) => (select(
    bodyWeightEntries,
  )..where((b) => b.date.equalsValue(date))).getSingleOrNull();

  Future<BodyWeightEntry?> findById(int id) => (select(
    bodyWeightEntries,
  )..where((b) => b.id.equals(id))).getSingleOrNull();

  Future<int> insertEntry(BodyWeightEntriesCompanion row) =>
      into(bodyWeightEntries).insert(row);

  Future<void> updateEntry(BodyWeightEntry entry) =>
      update(bodyWeightEntries).replace(entry.toInsertable());

  Future<int> deleteById(int id) =>
      (delete(bodyWeightEntries)..where((b) => b.id.equals(id))).go();
}
