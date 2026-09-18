// 2026-01-19 16:08:00 EST - AppConfig 모델 구현
// PRD 001 v1.4.4 섹션 4.4 SQLite 스키마

class AppConfig {
  final String configId;
  final int alertInterval; // 밀리초
  final bool enableAlerts;
  final int syncedAt; // Unix timestamp 밀리초

  AppConfig({
    this.configId = 'default',
    this.alertInterval = 600000, // 기본 10분
    this.enableAlerts = true,
    required this.syncedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'config_id': configId,
      'alert_interval': alertInterval,
      'enable_alerts': enableAlerts ? 1 : 0,
      'synced_at': syncedAt,
    };
  }

  factory AppConfig.fromMap(Map<String, dynamic> map) {
    return AppConfig(
      configId: map['config_id'] as String,
      alertInterval: map['alert_interval'] as int,
      enableAlerts: (map['enable_alerts'] as int) == 1,
      syncedAt: map['synced_at'] as int,
    );
  }

  AppConfig copyWith({
    String? configId,
    int? alertInterval,
    bool? enableAlerts,
    int? syncedAt,
  }) {
    return AppConfig(
      configId: configId ?? this.configId,
      alertInterval: alertInterval ?? this.alertInterval,
      enableAlerts: enableAlerts ?? this.enableAlerts,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}
