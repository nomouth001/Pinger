// 2026-01-19 15:50:00 EST - 인스턴스 상세 화면 구현
// PRD 001 v1.4.4 섹션 6.2.2 상세 화면
// 2026-01-19 16:23:00 EST - 불필요한 import 제거

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/instance.dart';
import '../models/check_history.dart';
import '../services/local_db_service.dart';
import 'instance_form_screen.dart';

class InstanceDetailScreen extends StatefulWidget {
  final String instanceId;

  const InstanceDetailScreen({super.key, required this.instanceId});

  @override
  State<InstanceDetailScreen> createState() => _InstanceDetailScreenState();
}

class _InstanceDetailScreenState extends State<InstanceDetailScreen> {
  final LocalDBService _dbService = LocalDBService();
  
  Instance? _instance;
  List<CheckHistory> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _instance = await _dbService.getInstanceById(widget.instanceId);
      _history = await _dbService.getHistoryByInstance(widget.instanceId, limit: 100);
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('로딩 중...'),
          backgroundColor: const Color(0xFF2196F3),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_instance == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('오류'),
          backgroundColor: const Color(0xFF2196F3),
        ),
        body: const Center(child: Text('인스턴스를 찾을 수 없습니다')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_instance!.alias),
        backgroundColor: const Color(0xFF2196F3),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InstanceFormScreen(instance: _instance),
                ),
              );
              _loadData();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 현재 상태 카드
              _buildStatusCard(),
              
              // 기본 정보 카드
              _buildInfoCard(),
              
              // 응답 시간 차트
              if (_history.isNotEmpty) _buildResponseTimeChart(),
              
              // 히스토리 리스트
              _buildHistoryList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final statusColor = _instance!.lastStatus == 'UP'
        ? const Color(0xFF4CAF50)
        : _instance!.lastStatus == 'DOWN'
            ? const Color(0xFFF44336)
            : Colors.grey;
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _instance!.lastStatus,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (_instance!.lastResponseTime != null)
            Text(
              '${_instance!.lastResponseTime}ms',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
              ),
            ),
          const SizedBox(height: 4),
          if (_instance!.lastCheckedAt != null)
            Text(
              '마지막 체크: ${DateFormat('MM/dd HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(_instance!.lastCheckedAt!))}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '기본 정보',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(),
          _buildInfoRow('IP 주소', _instance!.ipAddress),
          if (_instance!.healthCheckUrl != null)
            _buildInfoRow('Health Check URL', _instance!.healthCheckUrl!),
          _buildInfoRow('체크 주기', '${_instance!.checkInterval}초'),
          _buildInfoRow('타임아웃', '${_instance!.timeout ~/ 1000}초'),
          _buildInfoRow('실패 횟수', '${_instance!.failureCount}회'),
          if (_instance!.memo.isNotEmpty)
            _buildInfoRow('메모', _instance!.memo),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponseTimeChart() {
    // 최근 24시간 데이터만 사용
    final now = DateTime.now();
    final oneDayAgo = now.subtract(const Duration(hours: 24));
    
    final recentHistory = _history
        .where((h) => 
          h.responseTime != null &&
          DateTime.fromMillisecondsSinceEpoch(h.checkedAt * 1000).isAfter(oneDayAgo)
        )
        .toList()
        .reversed
        .toList();

    if (recentHistory.isEmpty) {
      return const SizedBox.shrink();
    }

    // 차트 데이터 생성
    final spots = recentHistory.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        entry.value.responseTime!.toDouble(),
      );
    }).toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '응답 시간 추이 (24시간)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text('${value.toInt()}ms');
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: const Color(0xFF2196F3),
                    barWidth: 2,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF2196F3).withOpacity(0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '체크 히스토리',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_history.length}개',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const Divider(),
          
          if (_history.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('히스토리가 없습니다'),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _history.length > 50 ? 50 : _history.length,
              itemBuilder: (context, index) {
                final item = _history[index];
                final time = DateTime.fromMillisecondsSinceEpoch(item.checkedAt * 1000);
                
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    item.status == 'UP' ? Icons.check_circle : Icons.error,
                    color: item.status == 'UP' 
                        ? const Color(0xFF4CAF50) 
                        : const Color(0xFFF44336),
                    size: 20,
                  ),
                  title: Text(
                    DateFormat('MM/dd HH:mm:ss').format(time),
                    style: const TextStyle(fontSize: 14),
                  ),
                  trailing: item.responseTime != null
                      ? Text(
                          '${item.responseTime}ms',
                          style: const TextStyle(fontSize: 12),
                        )
                      : null,
                );
              },
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
