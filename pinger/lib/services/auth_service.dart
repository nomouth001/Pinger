// 2026-01-19 15:00:00 EST - AuthService 구현
// PRD 001 v1.4.4 섹션 3.2.7 보안 인증

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class AuthService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  static const String _pinHashKey = 'pin_hash';
  static const String _pinSetupKey = 'pin_setup_completed';
  static const String _failedAttemptsKey = 'failed_attempts';
  static const String _lockoutTimeKey = 'lockout_time';

  // PIN 설정 여부 확인
  Future<bool> isPinSetup() async {
    final value = await _storage.read(key: _pinSetupKey);
    return value == 'true';
  }

  // PIN 설정 (SHA-256 해싱)
  Future<void> setupPin(String pin) async {
    final hash = sha256.convert(utf8.encode(pin)).toString();
    await _storage.write(key: _pinHashKey, value: hash);
    await _storage.write(key: _pinSetupKey, value: 'true');
    await _resetFailedAttempts();
  }

  // PIN 검증
  Future<bool> verifyPin(String pin) async {
    // 잠금 상태 확인
    if (await _isLocked()) {
      return false;
    }

    final storedHash = await _storage.read(key: _pinHashKey);
    if (storedHash == null) return false;

    final inputHash = sha256.convert(utf8.encode(pin)).toString();
    final isValid = inputHash == storedHash;

    if (isValid) {
      await _resetFailedAttempts();
    } else {
      await _incrementFailedAttempts();
    }

    return isValid;
  }

  // 생체인증 지원 여부 확인
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheckBiometrics && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  // 생체인증 시도
  Future<bool> authenticateWithBiometric() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Pinger 앱을 열기 위해 인증이 필요합니다',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  // 실패 횟수 증가
  Future<void> _incrementFailedAttempts() async {
    final attempts = await _getFailedAttempts();
    final newAttempts = attempts + 1;
    await _storage.write(key: _failedAttemptsKey, value: newAttempts.toString());

    // 5회 실패 시 1분 잠금
    if (newAttempts >= 5) {
      final lockoutTime = DateTime.now().add(const Duration(minutes: 1));
      await _storage.write(key: _lockoutTimeKey, value: lockoutTime.millisecondsSinceEpoch.toString());
    }
  }

  // 실패 횟수 리셋
  Future<void> _resetFailedAttempts() async {
    await _storage.delete(key: _failedAttemptsKey);
    await _storage.delete(key: _lockoutTimeKey);
  }

  // 현재 실패 횟수
  Future<int> _getFailedAttempts() async {
    final value = await _storage.read(key: _failedAttemptsKey);
    return int.tryParse(value ?? '0') ?? 0;
  }

  // 잠금 상태 확인
  Future<bool> _isLocked() async {
    final lockoutTimeStr = await _storage.read(key: _lockoutTimeKey);
    if (lockoutTimeStr == null) return false;

    final lockoutTime = DateTime.fromMillisecondsSinceEpoch(int.parse(lockoutTimeStr));
    final now = DateTime.now();

    if (now.isBefore(lockoutTime)) {
      return true; // 아직 잠금 중
    } else {
      await _resetFailedAttempts(); // 잠금 해제
      return false;
    }
  }

  // 잠금 해제까지 남은 시간 (초)
  Future<int> getRemainingLockoutSeconds() async {
    final lockoutTimeStr = await _storage.read(key: _lockoutTimeKey);
    if (lockoutTimeStr == null) return 0;

    final lockoutTime = DateTime.fromMillisecondsSinceEpoch(int.parse(lockoutTimeStr));
    final now = DateTime.now();

    if (now.isBefore(lockoutTime)) {
      return lockoutTime.difference(now).inSeconds;
    }
    return 0;
  }

  // PIN 변경
  Future<bool> changePin(String oldPin, String newPin) async {
    if (await verifyPin(oldPin)) {
      await setupPin(newPin);
      return true;
    }
    return false;
  }

  // 전체 인증 플로우 (생체인증 우선 → PIN fallback)
  Future<bool> authenticate() async {
    // 생체인증 가능하면 시도
    if (await isBiometricAvailable()) {
      final biometricResult = await authenticateWithBiometric();
      if (biometricResult) {
        await _resetFailedAttempts();
        return true;
      }
    }
    // 생체인증 실패하면 PIN 입력 화면으로
    return false;
  }
}
