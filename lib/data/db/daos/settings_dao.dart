import 'package:drift/drift.dart';

import '../../../domain/models/models.dart';
import '../database.dart';
import '../tables.dart';

part 'settings_dao.g.dart';

@DriftAccessor(tables: [AppSettingsTable])
class SettingsDao extends DatabaseAccessor<AppDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.attachedDatabase);

  SimpleSelectStatement<$AppSettingsTableTable, AppSettings> _row() =>
      select(appSettingsTable)
        ..where((s) => s.id.equals(AppSettings.singletonId));

  Stream<AppSettings> watch() => _row().watchSingle();

  Future<AppSettings> get() => _row().getSingle();

  Future<void> write(AppSettings settings) =>
      into(appSettingsTable).insertOnConflictUpdate(settings.toInsertable());

  /// Inserts the default row if it is missing; never overwrites.
  Future<void> ensureRow() => into(appSettingsTable).insert(
    AppSettings.defaults.toInsertable(),
    mode: InsertMode.insertOrIgnore,
  );
}
