// 2026-01-19 15:55:00 EST - 설정 화면 구현
// PRD 001 v1.4.4 섹션 6.2.4 설정 화면
// 2026-01-23 00:25:00 EST - FCM 토큰 표시 추가

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/local_db_service.dart';
import '../services/fcm_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final LocalDBService _dbService = LocalDBService();
  final FCMService _fcmService = FCMService();
  
  bool _enableAlerts = true;
  int _alertInterval = 600000; // 10분 (밀리초)
  bool _isLoading = true;
  String? _fcmToken;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final config = await _dbService.getAppConfig();
      if (config != null) {
        setState(() {
          _enableAlerts = config['enable_alerts'] == 1;
          _alertInterval = config['alert_interval'] ?? 600000;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
      
      // 2026-01-23 00:25:00 EST - FCM 토큰 로드
      // FCM 초기화 및 토큰 가져오기
      await _fcmService.initialize();
      setState(() {
        _fcmToken = _fcmService.fcmToken;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    try {
      await _dbService.updateAppConfig(
        alertInterval: _alertInterval,
        enableAlerts: _enableAlerts,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('설정이 저장되었습니다'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('설정 저장 실패: $e'),
            backgroundColor: const Color(0xFFF44336),
          ),
        );
      }
    }
  }

  Future<void> _changePin() async {
    final oldPinController = TextEditingController();
    final newPinController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('PIN 변경'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: '현재 PIN',
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: newPinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: '새 PIN',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              final success = await _authService.changePin(
                oldPinController.text,
                newPinController.text,
              );
              if (context.mounted) {
                Navigator.pop(context, success);
              }
            },
            child: const Text('변경'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN이 변경되었습니다'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    } else if (result == false && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN 변경 실패: 현재 PIN이 올바르지 않습니다'),
          backgroundColor: Color(0xFFF44336),
        ),
      );
    }
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('히스토리 삭제'),
        content: const Text('모든 체크 히스토리를 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFF44336),
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _dbService.cleanOldHistory(keepDays: 0);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('히스토리가 삭제되었습니다'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('삭제 실패: $e'),
              backgroundColor: const Color(0xFFF44336),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        backgroundColor: const Color(0xFF2196F3),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // 알림 설정
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '알림 설정',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                ),
                
                SwitchListTile(
                  title: const Text('푸시 알림 활성화'),
                  subtitle: const Text('인스턴스 다운 시 알림 받기'),
                  value: _enableAlerts,
                  onChanged: (value) {
                    setState(() {
                      _enableAlerts = value;
                    });
                    _saveSettings();
                  },
                ),
                
                ListTile(
                  title: const Text('재알림 간격'),
                  subtitle: Text('현재: ${_alertInterval ~/ 60000}분'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final result = await showDialog<int>(
                      context: context,
                      builder: (context) => SimpleDialog(
                        title: const Text('재알림 간격 선택'),
                        children: [
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(context, 300000),
                            child: const Text('5분'),
                          ),
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(context, 600000),
                            child: const Text('10분'),
                          ),
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(context, 1800000),
                            child: const Text('30분'),
                          ),
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(context, 3600000),
                            child: const Text('1시간'),
                          ),
                        ],
                      ),
                    );
                    
                    if (result != null) {
                      setState(() {
                        _alertInterval = result;
                      });
                      _saveSettings();
                    }
                  },
                ),
                
                const Divider(),
                
                // 2026-01-23 00:25:00 EST - FCM 토큰 표시 추가
                // FCM 토큰 정보
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'FCM 토큰',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                ),
                
                ListTile(
                  leading: const Icon(Icons.key_outlined),
                  title: const Text('FCM 토큰'),
                  subtitle: Text(
                    _fcmToken ?? '토큰 없음',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: _fcmToken != null
                        ? () {
                            Clipboard.setData(ClipboardData(text: _fcmToken!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('토큰이 클립보드에 복사되었습니다'),
                                backgroundColor: Color(0xFF4CAF50),
                              ),
                            );
                          }
                        : null,
                  ),
                ),
                
                const Divider(),
                
                // 보안 설정
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '보안',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                ),
                
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('PIN 변경'),
                  subtitle: const Text('앱 잠금 PIN 변경'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _changePin,
                ),
                
                const Divider(),
                
                // 데이터 관리
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '데이터 관리',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                ),
                
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Color(0xFFF44336)),
                  title: const Text('히스토리 삭제'),
                  subtitle: const Text('모든 체크 히스토리 삭제'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _clearHistory,
                ),
                
                const Divider(),
                
                // 앱 정보
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '앱 정보',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                ),
                
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('버전'),
                  subtitle: Text('v1.0.0'),
                ),
                
                const ListTile(
                  leading: Icon(Icons.description_outlined),
                  title: Text('라이선스'),
                  subtitle: Text('MIT License'),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _dbService.close();
    super.dispose();
  }
}
