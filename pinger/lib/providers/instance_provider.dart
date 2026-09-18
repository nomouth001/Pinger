// 2026-01-19 15:02:00 EST - InstanceProvider 구현
// PRD 001 v1.4.4 섹션 4.1 Flutter 상태 관리
// 2026-01-19 16:05:00 EST - DB 초기화 로직 추가
// 2026-01-20 01:20:00 EST - DB 초기화 간소화 (LocalDBService가 자동 처리)
// 2026-01-22 23:30:00 EST - 클라우드 동기화 추가 (로컬 + 클라우드 이중 저장)

import 'package:flutter/foundation.dart';
import '../models/instance.dart';
import '../services/local_db_service.dart';
import '../services/api_service.dart';

class InstanceProvider with ChangeNotifier {
  final LocalDBService _dbService = LocalDBService();
  ApiService? _apiService; // 외부에서 주입받음
  
  List<Instance> _instances = [];
  bool _isLoading = false;
  String? _error;

  List<Instance> get instances => _instances;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // 2026-01-22 23:30:00 EST - ApiService 주입 메서드 추가
  void setApiService(ApiService apiService) {
    _apiService = apiService;
  }

  // 2026-01-23 00:00:00 EST - DynamoDB 동기화 추가
  // 인스턴스 목록 불러오기
  Future<void> loadInstances() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. 클라우드에서 최신 데이터 가져오기
      if (_apiService != null) {
        final cloudInstances = await _apiService!.getInstances();
        
        if (cloudInstances.isNotEmpty) {
          // 2. 로컬 DB에 저장 (ConflictAlgorithm.replace로 upsert)
          for (final cloudInstance in cloudInstances) {
            await _dbService.insertInstance(cloudInstance);
            
            // 3. recent_checks를 check_history 테이블로 동기화
            if (cloudInstance.recentChecks != null && cloudInstance.recentChecks!.isNotEmpty) {
              for (final check in cloudInstance.recentChecks!) {
                try {
                  await _dbService.insertCheckHistory(
                    instanceId: cloudInstance.instanceId,
                    status: check['status'] as String,
                    responseTime: check['rt'] as int?,
                    checkedAt: check['time'] as int,
                  );
                } catch (e) {
                  // 이미 존재하는 히스토리는 무시
                  debugPrint('히스토리 중복 스킵: $e');
                }
              }
            }
          }
          
          debugPrint('✅ 클라우드 동기화 완료: ${cloudInstances.length}개');
        } else {
          debugPrint('⚠️ 클라우드에 인스턴스 없음');
        }
      } else {
        debugPrint('⚠️ API 서비스 없음');
      }
      
      // 3. 로컬 DB에서 읽기
      _instances = await _dbService.getAllInstances();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('❌ loadInstances 오류: $e');
    }
  }

  // 2026-01-23 00:00:00 EST - 클라우드 동기화 및 중복 방지 추가
  // 인스턴스 추가
  Future<void> addInstance(Instance instance) async {
    try {
      // 0. IP 주소 중복 체크 (클라우드)
      if (_apiService != null) {
        final existingInstance = await _apiService!.getInstanceByIpAddress(instance.ipAddress);
        if (existingInstance != null) {
          // 이미 존재하면 업데이트
          debugPrint('⚠️ IP 주소 중복, 기존 인스턴스 업데이트: ${existingInstance.instanceId}');
          final updatedInstance = existingInstance.copyWith(
            alias: instance.alias,
            healthCheckUrl: instance.healthCheckUrl,
            checkInterval: instance.checkInterval,
            timeout: instance.timeout,
            memo: instance.memo,
          );
          await updateInstance(updatedInstance);
          return;
        }
      }
      
      // 1. 클라우드에 먼저 저장 (백엔드가 instance_id 생성)
      if (_apiService != null) {
        final cloudInstance = await _apiService!.addInstance(instance);
        if (cloudInstance != null) {
          // 백엔드에서 생성된 ID로 로컬 저장
          await _dbService.insertInstance(cloudInstance);
        } else {
          // 클라우드 저장 실패 시 로컬에만 저장
          debugPrint('⚠️ 클라우드 저장 실패, 로컬에만 저장');
          await _dbService.insertInstance(instance);
        }
      } else {
        // API 서비스 없으면 로컬에만 저장
        await _dbService.insertInstance(instance);
      }
      
      await loadInstances(); // 새로고침
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('❌ addInstance 오류: $e');
      rethrow;
    }
  }

  // 2026-01-22 23:30:00 EST - 클라우드 동기화 추가
  // 인스턴스 업데이트
  Future<void> updateInstance(Instance instance) async {
    try {
      // 클라우드 업데이트
      if (_apiService != null) {
        final success = await _apiService!.updateInstance(instance);
        if (!success) {
          debugPrint('⚠️ 클라우드 업데이트 실패');
        }
      }
      
      // 로컬 업데이트
      await _dbService.updateInstance(instance);
      await loadInstances(); // 새로고침
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('❌ updateInstance 오류: $e');
      rethrow;
    }
  }

  // 2026-01-22 23:30:00 EST - 클라우드 동기화 추가
  // 인스턴스 삭제
  Future<void> deleteInstance(String instanceId) async {
    try {
      // 클라우드 삭제
      if (_apiService != null) {
        final success = await _apiService!.deleteInstance(instanceId);
        if (!success) {
          debugPrint('⚠️ 클라우드 삭제 실패');
        }
      }
      
      // 로컬 삭제
      await _dbService.deleteInstance(instanceId);
      await loadInstances(); // 새로고침
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('❌ deleteInstance 오류: $e');
      rethrow;
    }
  }

  // ID로 인스턴스 찾기
  Instance? getInstanceById(String instanceId) {
    try {
      return _instances.firstWhere((inst) => inst.instanceId == instanceId);
    } catch (e) {
      return null;
    }
  }

  // 통계
  int get totalInstances => _instances.length;
  int get upInstances => _instances.where((i) => i.lastStatus == 'UP').length;
  int get downInstances => _instances.where((i) => i.lastStatus == 'DOWN').length;
}
