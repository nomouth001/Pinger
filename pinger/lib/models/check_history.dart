// 2026-01-19 14:52:00 EST - CheckHistory 데이터 모델 구현
// PRD 001 v1.4.4 섹션 4.4 check_history 테이블 스키마

class CheckHistory {
  final String historyId;
  final String instanceId;
  final String status; // UP, DOWN
  final int? responseTime; // ms
  final int checkedAt; // Unix timestamp 초 (DynamoDB recent_checks.time과 동일)

  CheckHistory({
    required this.historyId,
    required this.instanceId,
    required this.status,
    this.responseTime,
    required this.checkedAt,
  });

  factory CheckHistory.fromMap(Map<String, dynamic> map) {
    return CheckHistory(
      historyId: map['history_id'] as String,
      instanceId: map['instance_id'] as String,
      status: map['status'] as String,
      responseTime: map['response_time'] as int?,
      checkedAt: map['checked_at'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'history_id': historyId,
      'instance_id': instanceId,
      'status': status,
      'response_time': responseTime,
      'checked_at': checkedAt,
    };
  }

  @override
  String toString() {
    return 'CheckHistory(id: $historyId, instance: $instanceId, status: $status, time: $checkedAt)';
  }
}
