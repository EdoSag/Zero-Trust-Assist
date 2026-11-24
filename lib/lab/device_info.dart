import 'package:flutter/services.dart';

/// What the phone looked like at one moment of a test: which phone, how much
/// memory is free, how hot it is and how much battery is left.
class DeviceSnapshot {
  const DeviceSnapshot({
    required this.manufacturer,
    required this.model,
    required this.soc,
    required this.sdk,
    required this.totalRamBytes,
    required this.availableRamBytes,
    required this.lowMemory,
    required this.appMemoryBytes,
    required this.freeStorageBytes,
    required this.thermalStatus,
    required this.batteryPercent,
    required this.charging,
  });

  factory DeviceSnapshot.fromMap(Map<Object?, Object?> map) {
    int number(String key) => (map[key] as num?)?.toInt() ?? 0;
    return DeviceSnapshot(
      manufacturer: map['manufacturer'] as String? ?? '',
      model: map['model'] as String? ?? '',
      soc: map['soc'] as String? ?? '',
      sdk: number('sdk'),
      totalRamBytes: number('totalRamBytes'),
      availableRamBytes: number('availableRamBytes'),
      lowMemory: map['lowMemory'] as bool? ?? false,
      appMemoryBytes: number('appMemoryBytes'),
      freeStorageBytes: number('freeStorageBytes'),
      thermalStatus: number('thermalStatus'),
      batteryPercent: number('batteryPercent'),
      charging: map['charging'] as bool? ?? false,
    );
  }

  final String manufacturer;
  final String model;

  /// The chip, for example "Google Tensor G5".
  final String soc;

  /// Android API level.
  final int sdk;
  final int totalRamBytes;

  /// Memory Android could still hand out.
  final int availableRamBytes;

  /// Whether Android considers itself short of memory.
  final bool lowMemory;

  /// This app's own share of memory, model included.
  final int appMemoryBytes;

  /// Free space where the models are stored.
  final int freeStorageBytes;

  /// Android's heat level, 0 (none) to 6 (shutdown). See [thermalLabel].
  final int thermalStatus;
  final int batteryPercent;
  final bool charging;

  /// "Google Pixel 10 Pro", without repeating the maker when the model name
  /// already starts with it.
  String get phoneName {
    if (model.toLowerCase().startsWith(manufacturer.toLowerCase())) {
      return model;
    }
    return '$manufacturer $model'.trim();
  }

  Map<String, Object?> toJson() => {
    'manufacturer': manufacturer,
    'model': model,
    'soc': soc,
    'sdk': sdk,
    'total_ram_bytes': totalRamBytes,
    'available_ram_bytes': availableRamBytes,
    'low_memory': lowMemory,
    'app_memory_bytes': appMemoryBytes,
    'free_storage_bytes': freeStorageBytes,
    'thermal_status': thermalStatus,
    'thermal_label': thermalLabel(thermalStatus),
    'battery_percent': batteryPercent,
    'charging': charging,
  };
}

/// Android's name for a heat level (`PowerManager.THERMAL_STATUS_*`).
String thermalLabel(int status) => switch (status) {
  0 => 'none',
  1 => 'light',
  2 => 'moderate',
  3 => 'severe',
  4 => 'critical',
  5 => 'emergency',
  6 => 'shutdown',
  _ => 'unknown',
};

/// Reads the phone's state through the app's own Android code
/// (`MainActivity.kt`). Returns nothing on other platforms and in tests.
class DeviceInfo {
  const DeviceInfo();

  static const MethodChannel _channel = MethodChannel('zt_assist/device');

  Future<DeviceSnapshot?> snapshot() async {
    try {
      final map = await _channel.invokeMapMethod<Object?, Object?>('snapshot');
      return map == null ? null : DeviceSnapshot.fromMap(map);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Keeps the screen on, so a long test is not paused by the screen lock.
  Future<void> keepAwake(bool on) async {
    try {
      await _channel.invokeMethod<void>('keepAwake', on);
    } on MissingPluginException {
      // Nothing to keep awake off Android.
    } on PlatformException {
      // The test still runs; the user may have to tap the screen.
    }
  }
}
