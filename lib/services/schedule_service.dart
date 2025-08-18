import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/schedule.dart';

class ScheduleService {
  static const String _scheduleKey = 'schedules';
  final Uuid _uuid = const Uuid();

  Future<List<Schedule>> getAllSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final schedulesJson = prefs.getStringList(_scheduleKey) ?? [];
    
    return schedulesJson
        .map((json) => Schedule.fromJson(jsonDecode(json)))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  Future<bool> addSchedule({
    required String title,
    String? description,
    required DateTime dateTime,
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
        location: location,
        isAlarmEnabled: isAlarmEnabled,
        alarmDateTime: alarmDateTime,
        isAiVoiceEnabled: isAiVoiceEnabled,
        color: color,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final schedules = await getAllSchedules();
      schedules.add(schedule);
      
      return await _saveSchedules(schedules);
    } catch (e) {
      return false;
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
      schedules.removeWhere((s) => s.id == id);
      
      return await _saveSchedules(schedules);
    } catch (e) {
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