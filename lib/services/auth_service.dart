import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import '../utils/constants.dart';

class AuthService {
  // Singleton Pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Hashing Helper: Never store raw PINs.
  String _hashMpin(String pin) {
    var bytes = utf8.encode(pin);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Save the MPIN securely after hashing it.
  Future<void> setMpin(String pin) async {
    String hashedPin = _hashMpin(pin);
    await _storage.write(key: Constants.keyMpinHash, value: hashedPin);
  }

  /// Verify the entered PIN against the stored hash.
  Future<bool> verifyMpin(String inputPin) async {
    String? storedHash = await _storage.read(key: Constants.keyMpinHash);
    if (storedHash == null) return false; // No MPIN set

    String inputHash = _hashMpin(inputPin);
    return storedHash == inputHash;
  }

  /// check if biometrics are available on the device
  Future<bool> isBiometricsAvailable() async {
    try {
      bool canCheck = await _localAuth.canCheckBiometrics;
      bool isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Prompt the user to authenticate with FaceID/Fingerprint.
  /// Returns [true] if successful, [false] if failed or canceled.
  Future<bool> authenticateBiometric() async {
    try {
      bool isAvailable = await isBiometricsAvailable();
      if (!isAvailable) return false;

      return await _localAuth.authenticate(
        localizedReason: 'Scan to unlock your CipherSpend Vault',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      print("Biometric Error: $e");
      return false;
    }
  }

  /// Check if the user has enabled biometric login previously
  Future<bool> isBiometricEnabled() async {
    String? value = await _storage.read(key: Constants.keyBiometricEnabled);
    return value == 'true';
  }

  /// Enable or Disable biometric login
  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(
        key: Constants.keyBiometricEnabled, value: enabled ? 'true' : 'false');
  }
}
