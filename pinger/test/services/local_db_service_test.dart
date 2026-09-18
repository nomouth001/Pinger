import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pinger/services/local_db_service.dart';
import 'package:pinger/models/instance.dart';
import 'package:uuid/uuid.dart';

void main() {
  // sqflite_common_ffi 초기화
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('LocalDBService Tests', () {
    test('데이터베이스 초기화 및 테이블 생성', () async {
      final dbService = LocalDBService();
      await dbService.initDatabase(inMemoryDatabasePath);
      
      final db = await dbService.database;
      
      // instances 테이블 확인
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='instances'"
      );
      expect(tables.isNotEmpty, true);
      
      // check_history 테이블 확인
      final historyTables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='check_history'"
      );
      expect(historyTables.isNotEmpty, true);
      
      await dbService.close();
    });

    test('인스턴스 삽입 및 조회', () async {
      final dbService = LocalDBService();
      await dbService.initDatabase(inMemoryDatabasePath);
      
      final instance = Instance(
        instanceId: const Uuid().v4(),
        alias: 'Test Server',
        ipAddress: '192.168.1.1',
        checkInterval: 300,
        timeout: 10000,
        failureCount: 0,
        lastStatus: 'UNKNOWN',
        memo: 'Test',
      );

      // 삽입
      await dbService.insertInstance(instance);

      // 조회
      final instances = await dbService.getAllInstances();
      expect(instances.length, 1);
      expect(instances[0].alias, 'Test Server');
      expect(instances[0].ipAddress, '192.168.1.1');
      
      await dbService.close();
    });

    test('인스턴스 업데이트', () async {
      final dbService = LocalDBService();
      await dbService.initDatabase(inMemoryDatabasePath);
      
      final instance = Instance(
        instanceId: const Uuid().v4(),
        alias: 'Test Server',
        ipAddress: '192.168.1.1',
        checkInterval: 300,
        timeout: 10000,
        failureCount: 0,
        lastStatus: 'UNKNOWN',
        memo: 'Test',
      );

      await dbService.insertInstance(instance);

      // 업데이트
      final updated = instance.copyWith(
        alias: 'Updated Server',
        lastStatus: 'UP',
      );
      await dbService.updateInstance(updated);

      // 확인
      final result = await dbService.getInstanceById(instance.instanceId);
      expect(result?.alias, 'Updated Server');
      expect(result?.lastStatus, 'UP');
      
      await dbService.close();
    });

    test('인스턴스 삭제', () async {
      final dbService = LocalDBService();
      await dbService.initDatabase(inMemoryDatabasePath);
      
      final instance = Instance(
        instanceId: const Uuid().v4(),
        alias: 'Test Server',
        ipAddress: '192.168.1.1',
        checkInterval: 300,
        timeout: 10000,
        failureCount: 0,
        lastStatus: 'UNKNOWN',
        memo: 'Test',
      );

      await dbService.insertInstance(instance);

      // 삭제
      await dbService.deleteInstance(instance.instanceId);

      // 확인
      final instances = await dbService.getAllInstances();
      expect(instances.length, 0);
      
      await dbService.close();
    });

    test('히스토리 삽입 및 조회', () async {
      final dbService = LocalDBService();
      await dbService.initDatabase(inMemoryDatabasePath);
      
      final instance = Instance(
        instanceId: const Uuid().v4(),
        alias: 'Test Server',
        ipAddress: '192.168.1.1',
        checkInterval: 300,
        timeout: 10000,
        failureCount: 0,
        lastStatus: 'UNKNOWN',
        memo: 'Test',
      );

      await dbService.insertInstance(instance);

      // 히스토리 삽입 (최근 24시간 기준)
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000; // 초 단위
      await dbService.insertCheckHistory(
        instanceId: instance.instanceId,
        status: 'UP',
        responseTime: 50,
        checkedAt: now,
      );

      // 조회
      final history = await dbService.getHistory(instance.instanceId, hours: 24);
      expect(history.length, 1);
      expect(history[0].status, 'UP');
      expect(history[0].responseTime, 50);
      
      await dbService.close();
    });
  });
}
