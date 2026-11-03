// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'body_weight_dao.dart';

// ignore_for_file: type=lint
mixin _$BodyWeightDaoMixin on DatabaseAccessor<AppDatabase> {
  $BodyWeightEntriesTable get bodyWeightEntries =>
      attachedDatabase.bodyWeightEntries;
  BodyWeightDaoManager get managers => BodyWeightDaoManager(this);
}

class BodyWeightDaoManager {
  final _$BodyWeightDaoMixin _db;
  BodyWeightDaoManager(this._db);
  $$BodyWeightEntriesTableTableManager get bodyWeightEntries =>
      $$BodyWeightEntriesTableTableManager(
        _db.attachedDatabase,
        _db.bodyWeightEntries,
      );
}
