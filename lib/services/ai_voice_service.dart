import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/schedule.dart';

class AiVoiceService {
  static final AiVoiceService _instance = AiVoiceService._internal();
  factory AiVoiceService() => _instance;
  AiVoiceService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isPlaying = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // TTS 설정
      await _flutterTts.setLanguage('ko-KR');
      await _flutterTts.setSpeechRate(0.8); // 조금 느리게
      await _flutterTts.setVolume(0.9);
      await _flutterTts.setPitch(1.0);

      // iOS 설정
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _flutterTts.setSharedInstance(true);
      }

      // TTS 이벤트 리스너 설정
      _flutterTts.setStartHandler(() {
        _isPlaying = true;
      });

      _flutterTts.setCompletionHandler(() {
        _isPlaying = false;
      });

      _flutterTts.setErrorHandler((message) {
        _isPlaying = false;
      });

      _isInitialized = true;
      if (kDebugMode) {
        print('AI Voice Service 초기화 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AI Voice Service 초기화 실패: $e');
      }
    }
  }

  Future<void> announceSchedule(Schedule schedule) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final announcement = _createAnnouncement(schedule);
      await _flutterTts.speak(announcement);
      
      if (kDebugMode) {
        print('AI 음성 알림: $announcement');
      }
    } catch (e) {
      if (kDebugMode) {
        print('AI 음성 알림 실패: $e');
      }
    }
  }

  String _createAnnouncement(Schedule schedule) {
    final now = DateTime.now();
    final timeUntil = schedule.dateTime.difference(now);
    
    String greeting = _getGreeting();
    String timeInfo = _getTimeInfo(schedule.dateTime, timeUntil);
    String locationInfo = schedule.location != null 
        ? ', 장소는 ${schedule.location!.name}입니다' 
        : '';
    String description = schedule.description != null && schedule.description!.isNotEmpty
        ? '. ${schedule.description}'
        : '';

    if (timeUntil.inMinutes <= 0) {
      // 일정 시간이 됐거나 지났을 때
      return '$greeting 일정 시간이 되었습니다. ${schedule.title}$timeInfo$locationInfo$description. 준비해주세요!';
    } else if (timeUntil.inMinutes <= 30) {
      // 30분 이내 일정
      return '$greeting 곧 일정이 있습니다. ${schedule.title}$timeInfo$locationInfo$description. 미리 준비해주세요.';
    } else {
      // 일반 알림
      return '$greeting 일정을 알려드립니다. ${schedule.title}$timeInfo$locationInfo$description';
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    
    if (hour < 6) {
      return '안녕하세요,';
    } else if (hour < 12) {
      return '좋은 아침입니다,';
    } else if (hour < 17) {
      return '안녕하세요,';
    } else if (hour < 21) {
      return '좋은 저녁입니다,';
    } else {
      return '안녕하세요,';
    }
  }

  String _getTimeInfo(DateTime scheduleTime, Duration timeUntil) {
    if (timeUntil.inMinutes <= 0) {
      return '이 ${_formatTime(scheduleTime)}에 예정되어 있습니다';
    } else if (timeUntil.inDays > 0) {
      return '이 ${timeUntil.inDays}일 후 ${_formatTime(scheduleTime)}에 예정되어 있습니다';
    } else if (timeUntil.inHours > 0) {
      return '이 ${timeUntil.inHours}시간 후 ${_formatTime(scheduleTime)}에 예정되어 있습니다';
    } else {
      return '이 ${timeUntil.inMinutes}분 후 ${_formatTime(scheduleTime)}에 예정되어 있습니다';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour;
    final minute = dateTime.minute;
    
    String hourStr = hour > 12 ? '오후 ${hour - 12}' : 
                     hour == 12 ? '오후 12' :
                     hour == 0 ? '오전 12' : '오전 $hour';
    
    String minuteStr = minute == 0 ? '시' : '시 ${minute}분';
    
    return '$hourStr$minuteStr';
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _isPlaying = false;
    } catch (e) {
      if (kDebugMode) {
        print('AI 음성 정지 실패: $e');
      }
    }
  }

  Future<bool> isPlaying() async {
    return _isPlaying;
  }

}