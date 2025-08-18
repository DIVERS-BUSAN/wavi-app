import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../widgets/custom_app_bar.dart';
import '../models/schedule.dart';
import '../services/schedule_service.dart';
import '../services/notification_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final ScheduleService _scheduleService = ScheduleService();
  final NotificationService _notificationService = NotificationService();
  
  List<Schedule> _upcomingSchedules = [];
  List<Schedule> _completedSchedules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    
    final allSchedules = await _scheduleService.getAllSchedules();
    final now = DateTime.now();
    
    // 알림이 설정된 일정들만 필터링
    final schedulesWithAlarms = allSchedules.where((s) => s.isAlarmEnabled).toList();
    
    setState(() {
      _upcomingSchedules = schedulesWithAlarms
          .where((s) => s.dateTime.isAfter(now))
          .toList();
      
      _completedSchedules = schedulesWithAlarms
          .where((s) => s.dateTime.isBefore(now))
          .toList()
          ..sort((a, b) => b.dateTime.compareTo(a.dateTime)); // 최신순 정렬
      
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const CustomAppBar(title: '알림'),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: const TabBar(
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.all(Radius.circular(25)),
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.grey,
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.schedule, size: 18),
                                SizedBox(width: 4),
                                Text('예정된 알림'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.history, size: 18),
                                SizedBox(width: 4),
                                Text('알림 히스토리'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildUpcomingNotifications(),
                          _buildNotificationHistory(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildUpcomingNotifications() {
    if (_upcomingSchedules.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_off,
              size: 80,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '예정된 알림이 없습니다',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              '일정을 추가하고 알림을 설정해보세요',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _upcomingSchedules.length,
      itemBuilder: (context, index) {
        final schedule = _upcomingSchedules[index];
        return _buildNotificationCard(schedule, isUpcoming: true);
      },
    );
  }

  Widget _buildNotificationHistory() {
    if (_completedSchedules.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '알림 히스토리가 없습니다',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _completedSchedules.length,
      itemBuilder: (context, index) {
        final schedule = _completedSchedules[index];
        return _buildNotificationCard(schedule, isUpcoming: false);
      },
    );
  }

  Widget _buildNotificationCard(Schedule schedule, {required bool isUpcoming}) {
    final now = DateTime.now();
    final isOverdue = schedule.dateTime.isBefore(now);
    
    // 알림 시간 계산
    String notificationTimeText = '';
    if (schedule.alarmDateTime != null) {
      final difference = schedule.dateTime.difference(schedule.alarmDateTime!).inMinutes;
      if (difference == 0) {
        notificationTimeText = '정시에 알림';
      } else if (difference < 60) {
        notificationTimeText = '${difference}분 전 알림';
      } else if (difference < 1440) {
        notificationTimeText = '${difference ~/ 60}시간 전 알림';
      } else {
        notificationTimeText = '${difference ~/ 1440}일 전 알림';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // TODO: 해당 일정으로 이동하는 기능 추가
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${schedule.title} 일정으로 이동')),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Color(schedule.color.colorValue),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                schedule.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isUpcoming 
                                    ? (isOverdue ? Colors.red : Colors.orange)
                                    : Colors.grey,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                isUpcoming 
                                    ? (isOverdue ? '지연됨' : '예정')
                                    : '완료',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.schedule, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('MM월 dd일 HH:mm').format(schedule.dateTime),
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.alarm, size: 14, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text(
                              notificationTimeText,
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        if (schedule.location != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 14, color: Colors.red),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  schedule.location!.name,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (schedule.description != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    schedule.description!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}