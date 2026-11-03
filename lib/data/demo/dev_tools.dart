import '../../core/build_info.dart';
import '../../core/clock.dart';
import '../repositories/maintenance_repository.dart';
import 'demo_data.dart' as demo;

/// Dev-only data tools (SPEC §6.7). Refuse to run in the release app.
class DevTools {
  DevTools(this._maintenance, this._clock, {this.enabled = isDevBuild});

  final MaintenanceRepository _maintenance;
  final Clock _clock;

  /// Only `true` in the DEV app.
  final bool enabled;

  /// Replaces all data by 16 weeks of demo training.
  Future<DataCounts> generateDemoData() async {
    _guard();
    await _maintenance.replaceAll(demo.generateDemoData(now: _clock.now()));
    return _maintenance.counts();
  }

  /// Deletes all data and resets the settings.
  Future<void> deleteAllData() async {
    _guard();
    await _maintenance.wipeAll();
  }

  void _guard() {
    if (!enabled) {
      throw StateError('Dev tools are not available in the release app.');
    }
  }
}
