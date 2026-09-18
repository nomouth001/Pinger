// 2026-01-19 15:05:00 EST - PIN 설정 화면 구현
// PRD 001 v1.4.4 섹션 6.2 UI/UX 설계

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  
  bool _isConfirming = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handlePinSubmit() async {
    if (!_isConfirming) {
      // 첫 번째 PIN 입력
      if (_pinController.text.length != 6) {
        setState(() {
          _errorMessage = 'PIN은 6자리여야 합니다';
        });
        return;
      }
      
      setState(() {
        _isConfirming = true;
        _errorMessage = '';
      });
    } else {
      // PIN 확인
      if (_pinController.text != _confirmController.text) {
        setState(() {
          _errorMessage = 'PIN이 일치하지 않습니다';
          _confirmController.clear();
        });
        return;
      }

      // PIN 저장
      await _authService.setupPin(_pinController.text);
      
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PIN 설정'),
        backgroundColor: const Color(0xFF2196F3),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 80,
              color: Color(0xFF2196F3),
            ),
            const SizedBox(height: 32),
            Text(
              _isConfirming ? 'PIN 확인' : 'PIN 설정 (6자리)',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isConfirming 
                  ? '동일한 PIN을 다시 입력하세요'
                  : '앱 잠금에 사용할 PIN을 입력하세요',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // PIN 입력 필드
            if (!_isConfirming)
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, letterSpacing: 16),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  hintText: '● ● ● ● ● ●',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                onSubmitted: (_) => _handlePinSubmit(),
              )
            else
              TextField(
                controller: _confirmController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, letterSpacing: 16),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  hintText: '● ● ● ● ● ●',
                  border: OutlineInputBorder(),
                  counterText: '',
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
              ),
            
            const SizedBox(height: 32),
            
            // 확인 버튼
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _handlePinSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  _isConfirming ? 'PIN 설정 완료' : '다음',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            
            // 뒤로 버튼
            if (_isConfirming)
              TextButton(
                onPressed: () {
                  setState(() {
                    _isConfirming = false;
                    _confirmController.clear();
                    _errorMessage = '';
                  });
                },
                child: const Text('이전으로'),
              ),
          ],
        ),
      ),
    );
  }
}
