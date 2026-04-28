import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class LockService {
  LockService._();
  static final instance = LockService._();

  static const _kPin = 'pin_hash';
  static const _kEnabled = 'lock_enabled';
  static const _kBio = 'biometric_enabled';
  static const _kAutolockSec = 'autolock_seconds';

  final _storage = const FlutterSecureStorage();
  final _auth = LocalAuthentication();

  DateTime? _lastUnlock;

  Future<bool> isEnabled() async => (await _storage.read(key: _kEnabled)) == '1';
  Future<bool> isBioEnabled() async => (await _storage.read(key: _kBio)) == '1';
  Future<int> autolockSeconds() async {
    final v = await _storage.read(key: _kAutolockSec);
    return int.tryParse(v ?? '') ?? 60;
  }

  Future<void> setEnabled(bool v) async =>
      _storage.write(key: _kEnabled, value: v ? '1' : '0');

  Future<void> setBioEnabled(bool v) async =>
      _storage.write(key: _kBio, value: v ? '1' : '0');

  Future<void> setAutolockSeconds(int s) async =>
      _storage.write(key: _kAutolockSec, value: s.toString());

  Future<bool> hasPin() async {
    final v = await _storage.read(key: _kPin);
    return v != null && v.isNotEmpty;
  }

  String _hash(String pin) =>
      sha256.convert(utf8.encode('pfm:$pin')).toString();

  Future<void> setPin(String pin) async {
    await _storage.write(key: _kPin, value: _hash(pin));
  }

  Future<bool> verifyPin(String pin) async {
    final v = await _storage.read(key: _kPin);
    if (v == null) return false;
    return v == _hash(pin);
  }

  Future<void> clearPin() async {
    await _storage.delete(key: _kPin);
  }

  Future<bool> tryBiometric() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      if (!canCheck || !supported) return false;
      return await _auth.authenticate(
        localizedReason: 'Unlock app',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      debugPrint('biometric error: $e');
      return false;
    }
  }

  void markUnlocked() => _lastUnlock = DateTime.now();

  Future<bool> needsUnlock() async {
    if (!await isEnabled()) return false;
    if (_lastUnlock == null) return true;
    final s = await autolockSeconds();
    return DateTime.now().difference(_lastUnlock!).inSeconds > s;
  }
}
