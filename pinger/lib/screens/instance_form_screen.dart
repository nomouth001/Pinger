// 2026-01-19 15:15:00 EST - 인스턴스 추가/수정 폼 구현
// PRD 001 v1.4.4 섹션 6.2.3 인스턴스 추가/수정 화면
// 2026-01-19 16:25:00 EST - 불필요한 import 제거, $ 이스케이프
// 2026-01-20 01:15:00 EST - 테스트 핑 기능 추가

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import '../models/instance.dart';
import '../providers/instance_provider.dart';

class InstanceFormScreen extends StatefulWidget {
  final Instance? instance;

  const InstanceFormScreen({super.key, this.instance});

  @override
  State<InstanceFormScreen> createState() => _InstanceFormScreenState();
}

class _InstanceFormScreenState extends State<InstanceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _aliasController;
  late TextEditingController _ipController;
  late TextEditingController _healthCheckUrlController;
  late TextEditingController _memoController;
  
  int _checkInterval = 300; // 기본 5분
  int _timeout = 10; // 기본 10초
  bool _isSaving = false;
  bool _isTesting = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _aliasController = TextEditingController(text: widget.instance?.alias);
    _ipController = TextEditingController(text: widget.instance?.ipAddress);
    _healthCheckUrlController = TextEditingController(
      text: widget.instance?.healthCheckUrl,
    );
    _memoController = TextEditingController(text: widget.instance?.memo);
    
    if (widget.instance != null) {
      _checkInterval = widget.instance!.checkInterval;
      _timeout = widget.instance!.timeout ~/ 1000; // 밀리초 → 초
    }
  }

  @override
  void dispose() {
    _aliasController.dispose();
    _ipController.dispose();
    _healthCheckUrlController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _saveInstance() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final provider = Provider.of<InstanceProvider>(context, listen: false);
      
      final instance = Instance(
        instanceId: widget.instance?.instanceId ?? const Uuid().v4(),
        alias: _aliasController.text.trim(),
        ipAddress: _ipController.text.trim(),
        healthCheckUrl: _healthCheckUrlController.text.trim().isEmpty
            ? null
            : _healthCheckUrlController.text.trim(),
        checkInterval: _checkInterval,
        timeout: _timeout * 1000, // 초 → 밀리초
        failureCount: widget.instance?.failureCount ?? 0,
        lastCheckedAt: widget.instance?.lastCheckedAt,
        lastStatus: widget.instance?.lastStatus ?? 'UNKNOWN',
        lastResponseTime: widget.instance?.lastResponseTime,
        lastAlertSentAt: widget.instance?.lastAlertSentAt ?? 0,
        recentChecks: widget.instance?.recentChecks,
        memo: _memoController.text.trim(),
      );

      if (widget.instance == null) {
        await provider.addInstance(instance);
      } else {
        await provider.updateInstance(instance);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.instance == null ? '인스턴스가 추가되었습니다' : '인스턴스가 수정되었습니다',
            ),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류: $e'),
            backgroundColor: const Color(0xFFF44336),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // 테스트 핑 수행
  Future<void> _testPing() async {
    final ip = _ipController.text.trim();
    final healthCheckUrl = _healthCheckUrlController.text.trim();
    
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('IP 주소 또는 도메인을 입력하세요'),
          backgroundColor: Color(0xFFF44336),
        ),
      );
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final url = healthCheckUrl.isNotEmpty 
          ? healthCheckUrl 
          : 'http://$ip/';
      
      final startTime = DateTime.now();
      final response = await http.get(
        Uri.parse(url),
      ).timeout(Duration(seconds: _timeout));
      final responseTime = DateTime.now().difference(startTime).inMilliseconds;

      if (mounted) {
        setState(() {
          _testResult = '✅ 성공!\n'
              '상태 코드: ${response.statusCode}\n'
              '응답 시간: ${responseTime}ms';
          _isTesting = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('테스트 성공: ${response.statusCode} (${responseTime}ms)'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _testResult = '❌ 타임아웃\n'
              '${_timeout}초 내에 응답 없음';
          _isTesting = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('테스트 실패: 타임아웃 (${_timeout}초)'),
            backgroundColor: const Color(0xFFF44336),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testResult = '❌ 실패\n$e';
          _isTesting = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('테스트 실패: $e'),
            backgroundColor: const Color(0xFFF44336),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.instance == null ? '인스턴스 추가' : '인스턴스 수정'),
        backgroundColor: const Color(0xFF2196F3),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 별칭
              TextFormField(
                controller: _aliasController,
                decoration: const InputDecoration(
                  labelText: '별칭 *',
                  hintText: '예: AlphaChart Production',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '별칭을 입력하세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // IP 주소 또는 도메인
              TextFormField(
                controller: _ipController,
                decoration: const InputDecoration(
                  labelText: 'IP 주소 또는 도메인 *',
                  hintText: '예: 54.180.123.45 또는 example.com',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'IP 주소 또는 도메인을 입력하세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Health Check URL
              TextFormField(
                controller: _healthCheckUrlController,
                decoration: const InputDecoration(
                  labelText: 'Health Check URL (선택)',
                  hintText: '예: https://example.com/health',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 8),
              
              // 테스트 핑 버튼
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isTesting ? null : _testPing,
                  icon: _isTesting 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering),
                  label: Text(_isTesting ? '테스트 중...' : '연결 테스트'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2196F3),
                    side: const BorderSide(color: Color(0xFF2196F3)),
                  ),
                ),
              ),
              
              // 테스트 결과 표시
              if (_testResult != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _testResult!.startsWith('✅')
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFEBEE),
                    border: Border.all(
                      color: _testResult!.startsWith('✅')
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFF44336),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _testResult!,
                    style: TextStyle(
                      color: _testResult!.startsWith('✅')
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFC62828),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // 체크 주기
              const Text(
                '체크 주기',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildIntervalChip(60, '1분'),
                  _buildIntervalChip(180, '3분'),
                  _buildIntervalChip(300, '5분'),
                  _buildIntervalChip(600, '10분'),
                ],
              ),
              const SizedBox(height: 24),

              // 타임아웃
              Row(
                children: [
                  const Text(
                    '타임아웃',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$_timeout초',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                ],
              ),
              Slider(
                value: _timeout.toDouble(),
                min: 1,
                max: 30,
                divisions: 29,
                label: '$_timeout초',
                onChanged: (value) {
                  setState(() {
                    _timeout = value.toInt();
                  });
                },
              ),
              const SizedBox(height: 16),

              // 메모
              TextFormField(
                controller: _memoController,
                decoration: const InputDecoration(
                  labelText: '메모',
                  hintText: r'예: $7/month, 1GB RAM',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              // 저장 버튼
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveInstance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          '저장',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntervalChip(int seconds, String label) {
    final isSelected = _checkInterval == seconds;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _checkInterval = seconds;
        });
      },
      selectedColor: const Color(0xFF2196F3),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
      ),
    );
  }
}
