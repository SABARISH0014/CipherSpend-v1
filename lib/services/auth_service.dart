import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Added this
import 'package:crypto/crypto.dart';
import '../utils/constants.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // --- Hashing Helper ---
  String _hashMpin(String pin) {
    var bytes = utf8.encode(pin);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  // --- Registration Check ---
  Future<bool> isUserRegistered() async {
    // Check if Setup Flag is true in SharedPrefs
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(Constants.prefIsSetupComplete) ?? false;
  }

  // --- Save MPIN ---
  Future<void> saveMpin(String pin) async {
    String hashedPin = _hashMpin(pin);
    await _storage.write(key: Constants.keyMpinHash, value: hashedPin);
  }

  // --- Validate MPIN ---
  Future<bool> validateMpin(String inputPin) async {
    String? storedHash = await _storage.read(key: Constants.keyMpinHash);
    if (storedHash == null) return false;
    String inputHash = _hashMpin(inputPin);
    return storedHash == inputHash;
  }

  // --- Biometric Auth ---
  Future<bool> authenticateBiometric() async {
    try {
      bool canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return false;
      return await _localAuth.authenticate(
        localizedReason: 'Scan to unlock Vault',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  // --- [NEW] NUCLEAR WIPE (Kill Switch Helper) ---
  Future<void> nuclearWipe() async {
    // 1. Wipe Secure Storage (MPIN, Biometrics)
    await _storage.deleteAll();

    // 2. Wipe Shared Preferences (Profile, Budget, Setup Flag)
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // 3. Force reload to ensure disk is clean
    await prefs.reload();
  }
}
