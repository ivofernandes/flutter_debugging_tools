import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Cross-platform device information commonly needed by app integrations.
abstract final class DeviceUtils {
  static Future<bool>? _isEmulator;

  /// Whether the current target is Android or iOS.
  static bool get isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Whether the current target is Linux, macOS, or Windows.
  static bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  /// A stable, human-readable name for the current target platform.
  static String get platformName {
    if (kIsWeb) return 'web';

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.fuchsia => 'fuchsia',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.linux => 'linux',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
    };
  }

  /// Whether the app is running in an Android emulator or iOS simulator.
  ///
  /// Web, desktop, and other platforms return `false`. The device metadata
  /// request is cached so multiple features can query this getter without
  /// invoking the platform channel repeatedly.
  static Future<bool> get isEmulator => _isEmulator ??= _detectEmulator();

  /// Alias for [isEmulator] using Apple's simulator terminology.
  static Future<bool> get isSimulator => isEmulator;

  /// Whether the app is running on a physical Android or iOS device.
  ///
  /// Returns `false` for non-mobile targets, where the physical-device
  /// distinction is not relevant.
  static Future<bool> get isPhysicalMobileDevice async {
    if (!isMobile) return false;
    return !await isEmulator;
  }

  /// Whether heart-rate simulation should start without explicit opt-in.
  ///
  /// Simulation is enabled by default only on an emulator or simulator, so a
  /// physical device continues to use its real sensor integration.
  static Future<bool> get heartRateSimulationEnabledByDefault => isEmulator;

  /// Whether cadence simulation should start without explicit opt-in.
  ///
  /// Simulation is enabled by default only on an emulator or simulator, so a
  /// physical device continues to use its real sensor integration.
  static Future<bool> get cadenceSimulationEnabledByDefault => isEmulator;

  static Future<bool> _detectEmulator() async {
    if (kIsWeb) return false;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final info = await DeviceInfoPlugin().androidInfo;
      return !info.isPhysicalDevice;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final info = await DeviceInfoPlugin().iosInfo;
      return !info.isPhysicalDevice;
    }

    return false;
  }
}
