// 2026-01-19 15:07:00 EST - PIN 인증 화면 구현
// PRD 001 v1.4.4 섹션 6.2 UI/UX 설계

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';

class PinAuthScreen extends StatefulWidget {
  const PinAuthScreen({super.key});

  @override
  State<PinAuthScreen> createState() => _PinAuthScreenState();
}

class _PinAuthScreenState extends State<PinAuthScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _pinController = TextEditingController();
  
  String _errorMessage = '';
  int _remainingLockoutSeconds = 0;

  @override
  void initState() {
    super.initState();
    _tryBiometric();
    _checkLockout();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _tryBiometric() async {
    final result = await _authService.authenticate();
    if (result && mounted) {
      Navigator.of(context).pushReplacementNamed('/dashboard');
    }
  }

  Future<void> _checkLockout() async {
    final remaining = await _authService.getRemainingLockoutSeconds();
    if (remaining > 0) {
      setState(() {
        _remainingLockoutSeconds = remaining;
      });
      _startLockoutTimer();
    }
  }

  void _startLockoutTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_remainingLockoutSeconds > 0) {
        setState(() {
          _remainingLockoutSeconds--;
        });
        _startLockoutTimer();
      }
    });
  }

  Future<void> _handlePinSubmit() async {
    if (_remainingLockoutSeconds > 0) {
      setState(() {
        _errorMessage = '$_remainingLockoutSeconds초 후 다시 시도하세요';
      });
      return;
    }

    if (_pinController.text.length != 6) {
      setState(() {
        _errorMessage = 'PIN은 6자리여야 합니다';
      });
      return;
    }

    final isValid = await _authService.verifyPin(_pinController.text);
    
    if (isValid) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    } else {
      // 실패 - 잠금 상태 확인
      await _checkLockout();
      
      setState(() {
        _errorMessage = _remainingLockoutSeconds > 0
            ? '5회 실패! $_remainingLockoutSeconds초 후 다시 시도하세요'
            : 'PIN이 올바르지 않습니다';
        _pinController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = _remainingLockoutSeconds > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 로고
              const Icon(
                Icons.security,
                size: 100,
                color: Color(0xFF2196F3),
              ),
              const SizedBox(height: 24),
              const Text(
                'Pinger',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2196F3),
                ),
              ),
              const SizedBox(height: 48),
              
              // PIN 입력 안내
              Text(
                isLocked ? '잠금 상태' : 'PIN 입력',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isLocked 
                    ? '$_remainingLockoutSeconds초 후 다시 시도하세요'
                    : '6자리 PIN을 입력하세요',
                style: TextStyle(
                  fontSize: 14,
                  color: isLocked ? const Color(0xFFF44336) : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),
              
              // PIN 입력 필드
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                textAlign: TextAlign.center,
                enabled: !isLocked,
                style: const TextStyle(fontSize: 32, letterSpacing: 16),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: '● ● ● ● ● ●',
                  border: const OutlineInputBorder(),
                  counterText: '',
                  filled: true,
                  fillColor: isLocked ? Colors.grey[200] : Colors.white,
                ),
                onSubmitted: (_) => _handlePinSubmit(),
              ),
              
              const SizedBox(height: 16),
              
              // 에러 메시지
              if (_errorMessage.isNotEmpty)
                Text(
                  _errorMessage,
                  style: const TextStyle(
                    color: Color(0xFFF44336),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              
              const SizedBox(height: 32),
              
              // 확인 버튼
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLocked ? null : _handlePinSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey,
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // 생체인증 버튼
              if (!isLocked)
                TextButton.icon(
                  onPressed: _tryBiometric,
                  icon: const Icon(Icons.fingerprint),
                  label: const Text('생체인증 사용'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
