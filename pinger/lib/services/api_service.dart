// 2026-01-19 15:32:00 EST - API 서비스 구현
// PRD 001 v1.4.4 섹션 4.4 API 통신
// 2026-01-19 16:24:00 EST - print → debugPrint 변경

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/instance.dart';

class ApiService {
  final String baseUrl;
  final String apiKey;

  ApiService({
    required this.baseUrl,
    required this.apiKey,
  });

  // 공통 헤더
  Map<String, String> get _headers {
    if (baseUrl.isEmpty || apiKey.isEmpty) {
      throw StateError('API_BASE_URL and API_KEY must be configured at build time.');
    }
    return {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
      };
  }

  // FCM 토큰 전송
  Future<bool> updateFcmToken(String fcmToken) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/config'),
        headers: _headers,
        body: jsonEncode({'fcm_token': fcmToken}),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ FCM 토큰 전송 실패: $e');
      return false;
    }
  }

  // 알림 설정 업데이트
  Future<bool> updateAlertConfig({
    int? alertInterval,
    bool? enableAlerts,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (alertInterval != null) body['alert_interval'] = alertInterval;
      if (enableAlerts != null) body['enable_alerts'] = enableAlerts;

      final response = await http.put(
        Uri.parse('$baseUrl/config'),
        headers: _headers,
        body: jsonEncode(body),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ 알림 설정 업데이트 실패: $e');
      return false;
    }
  }

  // 인스턴스 추가 (클라우드 동기화)
  Future<Instance?> addInstance(Instance instance) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/instances'),
        headers: _headers,
        body: jsonEncode({
          'alias': instance.alias,
          'ip_address': instance.ipAddress,
          'health_check_url': instance.healthCheckUrl,
          'check_interval': instance.checkInterval,
          'timeout': instance.timeout,
          'memo': instance.memo,
        }),
      );

      if (response.statusCode == 201) {
        return Instance.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      debugPrint('❌ 인스턴스 추가 실패: $e');
      return null;
    }
  }

  // 인스턴스 목록 조회
  Future<List<Instance>> getInstances() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/instances'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Instance.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('❌ 인스턴스 목록 조회 실패: $e');
      return [];
    }
  }

  // 인스턴스 수정
  Future<bool> updateInstance(Instance instance) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/instances/${instance.instanceId}'),
        headers: _headers,
        body: jsonEncode({
          'alias': instance.alias,
          'ip_address': instance.ipAddress,
          'health_check_url': instance.healthCheckUrl,
          'check_interval': instance.checkInterval,
          'timeout': instance.timeout,
          'memo': instance.memo,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ 인스턴스 수정 실패: $e');
      return false;
    }
  }

  // 인스턴스 삭제
  Future<bool> deleteInstance(String instanceId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/instances/$instanceId'),
        headers: _headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ 인스턴스 삭제 실패: $e');
      return false;
    }
  }

  // 클라우드 → 로컬 동기화 (최신 상태 가져오기)
  Future<List<Instance>> syncFromCloud() async {
    return await getInstances();
  }

  // 2026-01-23 00:00:00 EST - IP 주소로 인스턴스 조회 추가
  Future<Instance?> getInstanceByIpAddress(String ipAddress) async {
    try {
      final instances = await getInstances();
      return instances.firstWhere(
        (instance) => instance.ipAddress == ipAddress,
        orElse: () => throw Exception('Not found'),
      );
    } catch (e) {
      debugPrint('❌ IP로 인스턴스 조회 실패: $e');
      return null;
    }
  }
}
