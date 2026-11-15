import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_ble/universal_ble.dart';

import '../domain/heart_rate.dart';

/// Can GymLog use a Bluetooth heart rate monitor right now?
enum HeartRateAvailability {
  /// Before Android 12 Bluetooth scanning needs the location permission,
  /// which GymLog does not ask for.
  unsupported,
  bluetoothOff,
  noPermission,
  ready,
}

/// Answer to the request for "Geräte in der Nähe" (1.6.3). [blocked]:
/// denied for good, Android does not ask again – only the app settings help.
enum HeartRatePermission { granted, denied, blocked }

/// A heart rate monitor found nearby.
typedef HeartRateDevice = ({String id, String name});

/// Standard Bluetooth heart rate monitors (1.5.0): chest straps and watches
/// that "broadcast heart rate", e.g. Garmin Forerunner and epix.
abstract interface class HeartRateMonitor {
  Future<HeartRateAvailability> availability();

  /// Asks for the Bluetooth permissions (no location).
  Future<HeartRatePermission> requestPermission();

  /// Android's settings of GymLog, to allow a blocked permission (1.6.3).
  Future<void> openAppSettings();

  /// Monitors nearby until the subscription is cancelled.
  Stream<HeartRateDevice> scan();

  /// Connects and emits each value (beats per minute, RR intervals sent?).
  /// Ends with an error when the connection is lost; cancelling the
  /// subscription disconnects.
  Stream<HeartRateReading> heartRate(String deviceId);
}

final class BluetoothHeartRateMonitor implements HeartRateMonitor {
  BluetoothHeartRateMonitor();

  static const _service = '0000180d-0000-1000-8000-00805f9b34fb';
  static const _measurement = '00002a37-0000-1000-8000-00805f9b34fb';

  /// Implemented in android/app/src/main/kotlin/de/gymlog/app/MainActivity.kt.
  static const _device = MethodChannel('de.gymlog.app/device');

  Future<int> _sdkInt() async {
    try {
      return await _device.invokeMethod<int>('sdkInt') ?? 0;
    } on Object {
      return 0;
    }
  }

  @override
  Future<HeartRateAvailability> availability() async {
    if (await _sdkInt() < 31) return HeartRateAvailability.unsupported;
    try {
      // 1.6.3: checked by GymLog itself, not by the plugin.
      if (!await _granted()) return HeartRateAvailability.noPermission;
      return switch (await UniversalBle.getBluetoothAvailabilityState()) {
        AvailabilityState.poweredOn => HeartRateAvailability.ready,
        AvailabilityState.unauthorized => HeartRateAvailability.noPermission,
        AvailabilityState.unsupported => HeartRateAvailability.unsupported,
        _ => HeartRateAvailability.bluetoothOff,
      };
    } on Object catch (e) {
      debugPrint('Bluetooth availability failed: $e');
      return HeartRateAvailability.unsupported;
    }
  }

  Future<bool> _granted() async {
    try {
      return await _device.invokeMethod<bool>('bluetoothGranted') ?? false;
    } on MissingPluginException {
      return UniversalBle.hasPermissions();
    }
  }

  /// 1.6.3: requested through MainActivity. In the shrunk release app the
  /// plugin never showed Android's dialog (works in the DEV app).
  @override
  Future<HeartRatePermission> requestPermission() async {
    try {
      return HeartRatePermission.values.byName(
        await _device.invokeMethod<String>('requestBluetooth') ?? 'denied',
      );
    } on Object catch (e) {
      debugPrint('Bluetooth permission: $e');
      return HeartRatePermission.denied;
    }
  }

  @override
  Future<void> openAppSettings() async {
    try {
      await _device.invokeMethod<void>('openAppSettings');
    } on Object catch (e) {
      debugPrint('App settings: $e');
    }
  }

  @override
  Stream<HeartRateDevice> scan() {
    StreamSubscription<BleDevice>? results;
    late final StreamController<HeartRateDevice> controller;
    controller = StreamController<HeartRateDevice>(
      onListen: () async {
        results = UniversalBle.scanStream.listen((d) {
          final name = d.name;
          controller.add((
            id: d.deviceId,
            name: name == null || name.isEmpty ? d.deviceId : name,
          ));
        });
        try {
          await UniversalBle.startScan(
            scanFilter: ScanFilter(withServices: [_service]),
          );
        } on Object catch (e) {
          controller.addError(e);
        }
      },
      onCancel: () async {
        await results?.cancel();
        try {
          await UniversalBle.stopScan();
        } on Object {
          // Already stopped.
        }
      },
    );
    return controller.stream;
  }

  @override
  Stream<HeartRateReading> heartRate(String deviceId) {
    StreamSubscription<Uint8List>? values;
    StreamSubscription<bool>? connection;
    late final StreamController<HeartRateReading> controller;
    controller = StreamController<HeartRateReading>(
      onListen: () async {
        try {
          await UniversalBle.connect(
            deviceId,
            timeout: const Duration(seconds: 20),
          );
          connection = UniversalBle.connectionStream(deviceId)
              .listen((connected) {
                if (!connected && !controller.isClosed) {
                  controller.addError(const HeartRateConnectionLost());
                  unawaited(controller.close());
                }
              });
          await UniversalBle.discoverServices(deviceId);
          values =
              UniversalBle.characteristicValueStream(
                deviceId,
                _measurement,
              ).listen((bytes) {
                if (parseHeartRateReading(bytes) case final reading?) {
                  controller.add(reading);
                }
              });
          await UniversalBle.subscribeNotifications(
            deviceId,
            _service,
            _measurement,
          );
        } on Object catch (e) {
          if (!controller.isClosed) {
            controller.addError(e);
            unawaited(controller.close());
          }
        }
      },
      onCancel: () async {
        await values?.cancel();
        await connection?.cancel();
        try {
          await UniversalBle.disconnect(deviceId);
        } on Object {
          // Already gone.
        }
      },
    );
    return controller.stream;
  }
}

/// The monitor went out of range or stopped broadcasting.
final class HeartRateConnectionLost implements Exception {
  const HeartRateConnectionLost();
}

final heartRateMonitorProvider = Provider<HeartRateMonitor>(
  (ref) => BluetoothHeartRateMonitor(),
);
