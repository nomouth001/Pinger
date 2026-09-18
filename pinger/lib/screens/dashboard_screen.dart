// 2026-01-19 15:10:00 EST - 대시보드 화면 구현
// PRD 001 v1.4.4 섹션 6.2.1 대시보드 UI
// 2026-01-19 15:52:00 EST - 상세 화면 연결
// 2026-01-19 15:57:00 EST - 설정 화면 연결

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/instance_provider.dart';
import '../widgets/instance_card.dart';
import 'instance_form_screen.dart';
import 'instance_detail_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // 초기 데이터 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<InstanceProvider>(context, listen: false).loadInstances();
      }
    });
  }

  Future<void> _refreshInstances() async {
    await Provider.of<InstanceProvider>(context, listen: false).loadInstances();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pinger'),
        backgroundColor: const Color(0xFF2196F3),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              // 2026-01-19 15:57:00 EST - 설정 화면으로 이동
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<InstanceProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.instances.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Color(0xFFF44336),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '오류: ${provider.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshInstances,
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshInstances,
            child: Column(
              children: [
                // 전체 상태 요약 카드
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
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
                        '전체 상태',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatusChip(
                            '전체',
                            provider.totalInstances,
                            Colors.grey,
                          ),
                          _buildStatusChip(
                            'UP',
                            provider.upInstances,
                            const Color(0xFF4CAF50),
                          ),
                          _buildStatusChip(
                            'DOWN',
                            provider.downInstances,
                            const Color(0xFFF44336),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 인스턴스 리스트
                Expanded(
                  child: provider.instances.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.dns_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '등록된 인스턴스가 없습니다',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '+ 버튼을 눌러 인스턴스를 추가하세요',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: provider.instances.length,
                          itemBuilder: (context, index) {
                            return InstanceCard(
                              instance: provider.instances[index],
                              onTap: () async {
                                // 2026-01-19 15:52:00 EST - 상세 화면 연결
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => InstanceDetailScreen(
                                      instanceId: provider.instances[index].instanceId,
                                    ),
                                  ),
                                );
                                _refreshInstances();
                              },
                              onDelete: () async {
                                final confirm = await _showDeleteDialog(
                                  context,
                                  provider.instances[index].alias,
                                );
                                if (confirm == true) {
                                  await provider.deleteInstance(
                                    provider.instances[index].instanceId,
                                  );
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const InstanceFormScreen(),
            ),
          );
          _refreshInstances();
        },
        backgroundColor: const Color(0xFF2196F3),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatusChip(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Future<bool?> _showDeleteDialog(BuildContext context, String alias) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('인스턴스 삭제'),
        content: Text('$alias를 삭제하시겠습니까?\n히스토리도 함께 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFF44336),
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}
