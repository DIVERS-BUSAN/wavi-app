import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/schedule.dart';
import 'kakao_navi_service.dart';
import 'package:geolocator/geolocator.dart';

class ScheduleService {

  static const String _scheduleKey = 'schedules';
  final Uuid _uuid = const Uuid();

  Future<List<Schedule>> getAllSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final schedulesJson = prefs.getStringList(_scheduleKey) ?? [];

    // 🚨 JSON 원본 로그 찍기
    for (final raw in schedulesJson) {
      print("📦 Raw JSON in prefs: $raw");
    }

    final schedules = schedulesJson
        .map((json) => Schedule.fromJson(jsonDecode(json)))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    // 🚨 파싱된 결과 로그 찍기
    for (final s in schedules) {
      print("✅ Loaded Schedule: ${s.toJson()}");
    }

    return schedules;
  }



  Future<bool> addSchedule({
    required String title,
    String? description,
    required DateTime dateTime,
    required DateTime EnddateTime,
    Location? location,
    bool isAlarmEnabled = false,
    DateTime? alarmDateTime,
    bool isAiVoiceEnabled = false,
    ScheduleColor color = ScheduleColor.blue,
  }) async {
    try {
      final schedule = Schedule(
        id: _uuid.v4(),
        title: title,
        description: description,
        dateTime: dateTime,
        EnddateTime: EnddateTime,
        location: location,
        isAlarmEnabled: isAlarmEnabled,
        alarmDateTime: alarmDateTime,
        isAiVoiceEnabled: isAiVoiceEnabled,
        color: color,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isEvent: true,
      );

      final schedules = await getAllSchedules();
      schedules.add(schedule);

      // ✅ 시간순 정렬
      schedules.sort((a, b) => a.dateTime.compareTo(b.dateTime));

      // ✅ 첫 일정 → 현재 위치에서 출발
      if (schedules.length == 1 && schedules.first.isEvent) {
        final travel = await createTravelSchedule(b: schedules.first);
        if (travel != null) schedules.add(travel);
      }

      // ✅ 일반 일정 사이 이동일정
      for (int i = 0; i < schedules.length - 1; i++) {
        final current = schedules[i];
        final next = schedules[i + 1];

        if (current.isEvent && next.isEvent) {
          final travel = await createTravelSchedule(a: current, b: next);
          if (travel != null) schedules.add(travel);
        }
      }

      // ✅ 다시 정렬 후 최종 저장
      schedules.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      final saved = await _saveSchedules(schedules);
      print("💾 최종 저장 완료? $saved / 총 ${schedules.length}개 일정");
      return saved;
    } catch (e, stack) {
      print("❌ addSchedule error: $e, $stack");
      return false;
    }
  }

  Future<Schedule?> createTravelSchedule({Schedule? a, required Schedule b}) async {
    final kakaoService = KakaoNaviService();

    double startLat;
    double startLng;
    DateTime departureTime;

    if (a == null) {
      // ✅ 첫 일정: 현재 위치에서 출발
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      startLat = position.latitude;
      startLng = position.longitude;
      departureTime = DateTime.now();
    } else {
      // ✅ 일반 일정: 앞 일정 종료 후 출발
      if (a.location == null || b.location == null) return null;
      if (a.EnddateTime == null) {
        print("⚠️ ${a.title} 일정에 EnddateTime 없음 → 이동일정 생성 스킵");
        return null;
      }

      startLat = a.location!.latitude!;
      startLng = a.location!.longitude!;
      departureTime = a.EnddateTime;
    }

    final durationSec = await kakaoService.getTravelTime(
      startLat: startLat,
      startLng: startLng,
      endLat: b.location!.latitude!,
      endLng: b.location!.longitude!,
      departureTime: departureTime,
    );

    if (durationSec != null) {
      final durationMin = (durationSec / 60).round(); // 소요 시간 (분)
      final travelSchedule = Schedule(
        id: _uuid.v4(),
        title: "${a == null ? "현재 위치" : a.title} → ${b.title} ($durationMin분)",
        description: "이동시간 (약 ${durationMin}분 소요)",
        dateTime: departureTime,
        EnddateTime: departureTime.add(Duration(seconds: durationSec)),
        location: b.location,
        isAlarmEnabled: false,
        alarmDateTime: null,
        isAiVoiceEnabled: false,
        color: ScheduleColor.orange,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isEvent: false, // ✅ 자동 생성된 이동 일정
      );

      print("🚗 이동일정 생성됨: ${travelSchedule.toJson()}");
      return travelSchedule; // ✅ 저장하지 않고 반환만
    } else {
      print("⚠️ Kakao API가 duration 반환 안 함 (b=${b.title})");
      return null;
    }
  }




  Future<bool> updateSchedule(Schedule updatedSchedule) async {
    try {
      final schedules = await getAllSchedules();
      final index = schedules.indexWhere((s) => s.id == updatedSchedule.id);
      
      if (index == -1) return false;
      
      schedules[index] = updatedSchedule.copyWith(updatedAt: DateTime.now());
      
      return await _saveSchedules(schedules);
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteSchedule(String id) async {
    try {
      final schedules = await getAllSchedules();

      // 1. 삭제 대상 찾기
      final target = schedules.firstWhere((s) => s.id == id);

      // 2. 먼저 해당 일정 삭제
      schedules.removeWhere((s) => s.id == id);

      // 3. 연관된 이동일정도 같이 삭제
      schedules.removeWhere((s) {
        if (!s.isEvent) {
          final title = s.title; // 예: "[이동] ㄱㄱ → ㄴㄴ"
          return title.contains(target.title);
        }
        return false;
      });

      // 4. 다시 저장
      return await _saveSchedules(schedules);
    } catch (e) {
      return false;
    }
  }

  Future<bool> clearAllTravelSchedules() async {
    try {
      final schedules = await getAllSchedules();

      // 이동일정만 걸러서 삭제
      schedules.removeWhere((s) => s.isEvent == false);

      // 다시 저장
      return await _saveSchedules(schedules);
    } catch (e) {
      print("❌ clearAllTravelSchedules error: $e");
      return false;
    }
  }

  Future<Schedule?> getScheduleById(String id) async {
    final schedules = await getAllSchedules();
    try {
      return schedules.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<List<Schedule>> getSchedulesByDate(DateTime date) async {
    final schedules = await getAllSchedules();
    return schedules.where((s) {
      return s.dateTime.year == date.year &&
          s.dateTime.month == date.month &&
          s.dateTime.day == date.day;
    }).toList();
  }

  Future<List<Schedule>> getUpcomingSchedules() async {
    final schedules = await getAllSchedules();
    final now = DateTime.now();
    
    return schedules.where((s) => s.dateTime.isAfter(now)).toList();
  }

  Future<bool> _saveSchedules(List<Schedule> schedules) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final schedulesJson = schedules
          .map((schedule) => jsonEncode(schedule.toJson()))
          .toList();
      
      return await prefs.setStringList(_scheduleKey, schedulesJson);
    } catch (e) {
      return false;
    }
  }
}