import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';
import '../models/schedule.dart';
import 'ai_voice_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final AiVoiceService _aiVoiceService = AiVoiceService();

  Future<void> initialize() async {
    // 타임존 초기화
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    // AI 음성 서비스 초기화
    await _aiVoiceService.initialize();

    // 안드로이드 초기화 설정
    const AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 초기화 설정
    const DarwinInitializationSettings darwinInitializationSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: androidInitializationSettings,
      iOS: darwinInitializationSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );

    // 권한 요청
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // 안드로이드 13 이상에서는 알림 권한 요청 필요
      await Permission.notification.request();
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }

  void _onDidReceiveNotificationResponse(NotificationResponse response) async {
    if (kDebugMode) {
      print('Notification clicked: ${response.payload}');
    }
    
    // AI 비서 음성 알림 재생
    if (response.payload != null) {
      try {
        // TODO: 실제 일정 데이터를 가져와서 AI 비서가 읽어주도록 구현
        // 현재는 간단한 음성 안내만 제공
        await _aiVoiceService.announceSchedule(Schedule(
          id: response.payload!,
          title: '알림을 확인해주세요',
          dateTime: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      } catch (e) {
        if (kDebugMode) {
          print('AI 음성 알림 실패: $e');
        }
      }
    }
  }

  Future<void> scheduleNotification(Schedule schedule) async {
    if (!schedule.isAlarmEnabled || schedule.alarmDateTime == null) {
      return;
    }

    final scheduledDate = tz.TZDateTime.from(
      schedule.alarmDateTime!,
      tz.local,
    );

    // 현재 시간보다 이전이면 알림을 설정하지 않음
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      return;
    }

    try {
      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'schedule_channel',
        '일정 알림',
        channelDescription: '등록된 일정에 대한 알림입니다.',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );

      const DarwinNotificationDetails darwinNotificationDetails =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: darwinNotificationDetails,
      );

      String body = '일정 시간: ${_formatDateTime(schedule.dateTime)}';
      if (schedule.location != null) {
        body += '\n장소: ${schedule.location!.name}';
      }

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        schedule.id.hashCode, // notification ID
        '📅 ${schedule.title}',
        body,
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: schedule.id,
      );

      // AI 비서 음성 알림도 예약
      if (schedule.isAiVoiceEnabled) {
        _scheduleAiVoiceNotification(schedule, scheduledDate);
      }

      if (kDebugMode) {
        print('알림 예약 완료: ${schedule.title} at $scheduledDate');
        if (schedule.isAiVoiceEnabled) {
          print('AI 음성 알림도 함께 예약됨');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('알림 예약 실패: $e');
        print('알림 없이 일정만 저장됩니다.');
      }
      // 알림 설정 실패해도 일정 저장은 계속 진행
    }
  }

  Future<void> cancelNotification(String scheduleId) async {
    await _flutterLocalNotificationsPlugin.cancel(scheduleId.hashCode);
    if (kDebugMode) {
      print('알림 취소 완료: $scheduleId');
    }
  }

  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
    if (kDebugMode) {
      print('모든 알림 취소 완료');
    }
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  void _scheduleAiVoiceNotification(Schedule schedule, tz.TZDateTime scheduledDate) {
    // 간단한 AI 음성 알림 스케줄링
    // 실제로는 더 정교한 스케줄링 시스템이 필요하지만,
    // 현재는 알림이 울릴 때 AI가 음성으로 안내하는 방식으로 구현
    
    Future.delayed(scheduledDate.difference(tz.TZDateTime.now(tz.local)), () async {
      try {
        await _aiVoiceService.announceSchedule(schedule);
      } catch (e) {
        if (kDebugMode) {
          print('AI 음성 알림 실행 실패: $e');
        }
      }
    });
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.month}월 ${dateTime.day}일 ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // 알림 시간 옵션들
  static const List<NotificationOption> notificationOptions = [
    NotificationOption('정시에', 0),
    NotificationOption('5분 전', 5),
    NotificationOption('10분 전', 10),
    NotificationOption('15분 전', 15),
    NotificationOption('30분 전', 30),
    NotificationOption('1시간 전', 60),
    NotificationOption('2시간 전', 120),
    NotificationOption('1일 전', 1440),
  ];
}

class NotificationOption {
  final String label;
  final int minutesBefore;

  const NotificationOption(this.label, this.minutesBefore);
}