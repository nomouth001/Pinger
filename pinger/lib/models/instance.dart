// 2026-01-19 14:50:00 EST - Instance 데이터 모델 구현
// PRD 001 v1.4.4 섹션 4.4 스키마에 따른 구현
// 2026-01-19 16:20:00 EST - fromJson 메서드 추가

class Instance {
  final String instanceId;
  final String alias;
  final String ipAddress;
  final String? healthCheckUrl;
  final int checkInterval; // 초 단위
  final int timeout; // 밀리초
  final int failureCount;
  final int? lastCheckedAt; // Unix timestamp 밀리초
  final String lastStatus; // UP, DOWN, UNKNOWN
  final int? lastResponseTime; // ms
  final int lastAlertSentAt; // Unix timestamp 밀리초
  final List<Map<String, dynamic>>? recentChecks;
  final String memo;

  Instance({
    required this.instanceId,
    required this.alias,
    required this.ipAddress,
    this.healthCheckUrl,
    this.checkInterval = 300, // 기본 5분
    this.timeout = 10000, // 기본 10초
    this.failureCount = 0,
    this.lastCheckedAt,
    this.lastStatus = 'UNKNOWN',
    this.lastResponseTime,
    this.lastAlertSentAt = 0,
    this.recentChecks,
    this.memo = '',
  });

  // DynamoDB/SQLite 데이터 → Instance 객체
  factory Instance.fromMap(Map<String, dynamic> map) {
    return Instance(
      instanceId: map['instance_id'] as String,
      alias: map['alias'] as String,
      ipAddress: map['ip_address'] as String,
      healthCheckUrl: map['health_check_url'] as String?,
      checkInterval: map['check_interval'] as int? ?? 300,
      timeout: map['timeout'] as int? ?? 10000,
      failureCount: map['failure_count'] as int? ?? 0,
      lastCheckedAt: map['last_checked_at'] as int?,
      lastStatus: map['last_status'] as String? ?? 'UNKNOWN',
      lastResponseTime: map['last_response_time'] as int?,
      lastAlertSentAt: map['last_alert_sent_at'] as int? ?? 0,
      recentChecks: map['recent_checks'] != null
          ? List<Map<String, dynamic>>.from(map['recent_checks'] as List)
          : null,
      memo: map['memo'] as String? ?? '',
    );
  }

  // Instance 객체 → DynamoDB/SQLite 데이터
  Map<String, dynamic> toMap() {
    return {
      'instance_id': instanceId,
      'alias': alias,
      'ip_address': ipAddress,
      'health_check_url': healthCheckUrl,
      'check_interval': checkInterval,
      'timeout': timeout,
      'failure_count': failureCount,
      'last_checked_at': lastCheckedAt,
      'last_status': lastStatus,
      'last_response_time': lastResponseTime,
      'last_alert_sent_at': lastAlertSentAt,
      'memo': memo,
    };
  }

  // 일부 필드만 업데이트
  Instance copyWith({
    String? alias,
    String? ipAddress,
    String? healthCheckUrl,
    int? checkInterval,
    int? timeout,
    int? failureCount,
    int? lastCheckedAt,
    String? lastStatus,
    int? lastResponseTime,
    int? lastAlertSentAt,
    List<Map<String, dynamic>>? recentChecks,
    String? memo,
  }) {
    return Instance(
      instanceId: instanceId, // ID는 변경 불가
      alias: alias ?? this.alias,
      ipAddress: ipAddress ?? this.ipAddress,
      healthCheckUrl: healthCheckUrl ?? this.healthCheckUrl,
      checkInterval: checkInterval ?? this.checkInterval,
      timeout: timeout ?? this.timeout,
      failureCount: failureCount ?? this.failureCount,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      lastStatus: lastStatus ?? this.lastStatus,
      lastResponseTime: lastResponseTime ?? this.lastResponseTime,
      lastAlertSentAt: lastAlertSentAt ?? this.lastAlertSentAt,
      recentChecks: recentChecks ?? this.recentChecks,
      memo: memo ?? this.memo,
    );
  }

  // JSON 역직렬화 (API 응답용)
  factory Instance.fromJson(Map<String, dynamic> json) {
    return Instance.fromMap(json);
  }

  // JSON 직렬화 (API 요청용)
  Map<String, dynamic> toJson() {
    return toMap();
  }

  @override
  String toString() {
    return 'Instance(id: $instanceId, alias: $alias, ip: $ipAddress, status: $lastStatus)';
  }
}
