// 2026-01-19 14:55:00 EST - LocalDBService 구현
// PRD 001 v1.4.4 섹션 4.4 SQLite 스키마에 따른 구현
// 2026-01-20 01:20:00 EST - DB 초기화 로직 수정 (database closed 오류 해결)

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import '../models/instance.dart';
import '../models/check_history.dart';

class LocalDBService {
  Database? _database;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = join(await getDatabasesPath(), 'pinger.db');
    
    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        // instances 테이블 생성
        await db.execute('''
          CREATE TABLE instances (
            instance_id TEXT PRIMARY KEY,
            alias TEXT NOT NULL,
            ip_address TEXT NOT NULL,
            health_check_url TEXT,
            check_interval INTEGER DEFAULT 300,
            timeout INTEGER DEFAULT 10000,
            failure_count INTEGER DEFAULT 0,
            last_checked_at INTEGER,
            last_status TEXT,
            last_response_time INTEGER,
            last_alert_sent_at INTEGER,
            memo TEXT,
            synced_at INTEGER
          )
        ''');

        // app_config 테이블 생성
        await db.execute('''
          CREATE TABLE app_config (
            config_id TEXT PRIMARY KEY DEFAULT 'default',
            alert_interval INTEGER DEFAULT 600000,
            enable_alerts INTEGER DEFAULT 1,
            synced_at INTEGER
          )
        ''');

        // check_history 테이블 생성
        await db.execute('''
          CREATE TABLE check_history (
            history_id TEXT PRIMARY KEY,
            instance_id TEXT NOT NULL,
            status TEXT NOT NULL,
            response_time INTEGER,
            checked_at INTEGER NOT NULL,
            FOREIGN KEY (instance_id) REFERENCES instances(instance_id) ON DELETE CASCADE
          )
        ''');

        // 히스토리 조회용 인덱스
        await db.execute('''
          CREATE INDEX idx_history_instance_time 
          ON check_history(instance_id, checked_at DESC)
        ''');

        // 기본 app_config 삽입
        await db.insert('app_config', {
          'config_id': 'default',
          'alert_interval': 600000, // 10분 (밀리초)
          'enable_alerts': 1,
          'synced_at': DateTime.now().millisecondsSinceEpoch,
        });
      },
    );
  }

  // 호환성을 위해 initDatabase 메서드 유지 (InstanceProvider에서 사용)
  Future<Database> initDatabase([String? path]) async {
    return await database;
  }

  // ========== 인스턴스 CRUD ==========

  Future<void> insertInstance(Instance instance) async {
    final db = await database;
    await db.insert(
      'instances',
      instance.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateInstance(Instance instance) async {
    final db = await database;
    await db.update(
      'instances',
      instance.toMap(),
      where: 'instance_id = ?',
      whereArgs: [instance.instanceId],
    );
  }

  Future<void> deleteInstance(String instanceId) async {
    final db = await database;
    await db.delete(
      'instances',
      where: 'instance_id = ?',
      whereArgs: [instanceId],
    );
  }

  // 2026-01-23 00:00:00 EST - IP 주소로 인스턴스 조회 추가
  Future<Instance?> getInstanceByIpAddress(String ipAddress) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'instances',
      where: 'ip_address = ?',
      whereArgs: [ipAddress],
    );

    if (maps.isEmpty) {
      return null;
    }

    return Instance.fromMap(maps.first);
  }

  Future<List<Instance>> getAllInstances() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('instances');
    
    return List.generate(maps.length, (i) {
      return Instance.fromMap(maps[i]);
    });
  }

  Future<Instance?> getInstanceById(String instanceId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'instances',
      where: 'instance_id = ?',
      whereArgs: [instanceId],
    );

    if (maps.isEmpty) return null;
    return Instance.fromMap(maps.first);
  }

  // ========== 히스토리 관리 ==========

  Future<void> insertCheckHistory({
    required String instanceId,
    required String status,
    int? responseTime,
    required int checkedAt, // Unix timestamp 초
  }) async {
    final db = await database;
    await db.insert('check_history', {
      'history_id': const Uuid().v4(),
      'instance_id': instanceId,
      'status': status,
      'response_time': responseTime,
      'checked_at': checkedAt,
    });
  }

  Future<List<CheckHistory>> getHistory(String instanceId, {int hours = 24}) async {
    final db = await database;
    // 초 단위로 계산 (check_history.checked_at이 초 단위이므로)
    final cutoffTime = DateTime.now().subtract(Duration(hours: hours)).millisecondsSinceEpoch ~/ 1000;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'check_history',
      where: 'instance_id = ? AND checked_at > ?',
      whereArgs: [instanceId, cutoffTime],
      orderBy: 'checked_at DESC',
      limit: 1000,
    );

    return List.generate(maps.length, (i) {
      return CheckHistory.fromMap(maps[i]);
    });
  }

  // 2026-01-19 16:22:00 EST - getHistoryByInstance 메서드 추가
  Future<List<CheckHistory>> getHistoryByInstance(
    String instanceId, {
    int limit = 100,
  }) async {
    final db = await database;
    final maps = await db.query(
      'check_history',
      where: 'instance_id = ?',
      whereArgs: [instanceId],
      orderBy: 'checked_at DESC',
      limit: limit,
    );

    return List.generate(maps.length, (i) {
      return CheckHistory.fromMap(maps[i]);
    });
  }

  Future<void> cleanOldHistory({int keepDays = 30}) async {
    final db = await database;
    // keepDays일 이상 오래된 히스토리 삭제 (checked_at은 초 단위)
    final cutoffTime = DateTime.now().subtract(Duration(days: keepDays)).millisecondsSinceEpoch ~/ 1000;
    await db.delete(
      'check_history',
      where: 'checked_at < ?',
      whereArgs: [cutoffTime],
    );
  }

  // ========== 앱 설정 ==========

  Future<Map<String, dynamic>?> getAppConfig() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'app_config',
      where: 'config_id = ?',
      whereArgs: ['default'],
    );

    if (maps.isEmpty) return null;
    return maps.first;
  }

  Future<void> updateAppConfig({
    int? alertInterval,
    bool? enableAlerts,
  }) async {
    final db = await database;
    final Map<String, dynamic> updates = {
      'synced_at': DateTime.now().millisecondsSinceEpoch,
    };

    if (alertInterval != null) updates['alert_interval'] = alertInterval;
    if (enableAlerts != null) updates['enable_alerts'] = enableAlerts ? 1 : 0;

    await db.update(
      'app_config',
      updates,
      where: 'config_id = ?',
      whereArgs: ['default'],
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
