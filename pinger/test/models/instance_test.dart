import 'package:flutter_test/flutter_test.dart';
import 'package:pinger/models/instance.dart';

void main() {
  group('Instance Model Tests', () {
    test('Instance 생성 및 기본값 확인', () {
      final instance = Instance(
        instanceId: 'test-123',
        alias: 'Test Server',
        ipAddress: '192.168.1.1',
        checkInterval: 300,
        timeout: 10000,
        failureCount: 0,
        lastStatus: 'UNKNOWN',
        memo: 'Test memo',
      );

      expect(instance.instanceId, 'test-123');
      expect(instance.alias, 'Test Server');
      expect(instance.ipAddress, '192.168.1.1');
      expect(instance.checkInterval, 300);
      expect(instance.timeout, 10000);
      expect(instance.lastStatus, 'UNKNOWN');
    });

    test('Instance toMap 변환 테스트', () {
      final instance = Instance(
        instanceId: 'test-123',
        alias: 'Test Server',
        ipAddress: '192.168.1.1',
        checkInterval: 300,
        timeout: 10000,
        failureCount: 0,
        lastStatus: 'UNKNOWN',
        memo: 'Test memo',
      );

      final map = instance.toMap();

      expect(map['instance_id'], 'test-123');
      expect(map['alias'], 'Test Server');
      expect(map['ip_address'], '192.168.1.1');
      expect(map['check_interval'], 300);
      expect(map['timeout'], 10000);
      expect(map['last_status'], 'UNKNOWN');
    });

    test('Instance fromMap 변환 테스트', () {
      final map = {
        'instance_id': 'test-123',
        'alias': 'Test Server',
        'ip_address': '192.168.1.1',
        'health_check_url': 'http://192.168.1.1/health',
        'check_interval': 300,
        'timeout': 10000,
        'failure_count': 0,
        'last_checked_at': 1705632000000,
        'last_status': 'UP',
        'last_response_time': 45,
        'last_alert_sent_at': 1705632000000,
        'memo': 'Test memo',
      };

      final instance = Instance.fromMap(map);

      expect(instance.instanceId, 'test-123');
      expect(instance.alias, 'Test Server');
      expect(instance.ipAddress, '192.168.1.1');
      expect(instance.healthCheckUrl, 'http://192.168.1.1/health');
      expect(instance.checkInterval, 300);
      expect(instance.timeout, 10000);
      expect(instance.lastStatus, 'UP');
      expect(instance.lastResponseTime, 45);
    });

    test('Instance copyWith 테스트', () {
      final instance = Instance(
        instanceId: 'test-123',
        alias: 'Test Server',
        ipAddress: '192.168.1.1',
        checkInterval: 300,
        timeout: 10000,
        failureCount: 0,
        lastStatus: 'UNKNOWN',
        memo: 'Test memo',
      );

      final updated = instance.copyWith(
        lastStatus: 'UP',
        lastResponseTime: 50,
      );

      expect(updated.instanceId, instance.instanceId);
      expect(updated.lastStatus, 'UP');
      expect(updated.lastResponseTime, 50);
    });
  });
}
