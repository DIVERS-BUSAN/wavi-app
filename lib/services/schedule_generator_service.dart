import 'dart:math';
import 'package:flutter/material.dart';
import '../models/schedule.dart';
import '../models/placedetail.dart';
import 'route_service.dart';
import 'visit_duration_service.dart';
import 'schedule_service.dart';

class ScheduleGeneratorService {
  final RouteService _routeService = RouteService();
  final ScheduleService _scheduleService = ScheduleService();

  /// 여행 일정을 자동 생성하는 메인 함수
  Future<List<Schedule>> generateTravelItinerary({
    required List<PlaceCandidate> places,
    required DateTime startDate,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    Location? startLocation, // 출발지 (없으면 첫 번째 장소에서 시작)
    String travelMode = 'CAR', // CAR 또는 FOOT
    int maxPlacesPerDay = 6, // 하루에 방문할 수 있는 최대 장소 수
    int duration = 1, // 여행 기간 (일 단위)
  }) async {
    List<Schedule> schedules = [];

    try {
      // 1. 시간 제약 계산
      Duration dailyAvailableTime = _calculateDailyAvailableTime(
        startTime,
        endTime,
      );

      // 2. 장소들을 우선순위와 거리를 고려해 정렬
      List<PlaceCandidate> sortedPlaces = await _optimizePlaceOrder(
        places,
        startLocation,
        travelMode,
      );

      // 3. 하루 단위로 일정 분배
      List<List<PlaceCandidate>> dailyPlaces = _distributePlacesByDay(
        sortedPlaces,
        dailyAvailableTime,
        maxPlacesPerDay,
      );

      // 4. 각 날짜별로 상세 일정 생성 (duration 만큼만)
      DateTime currentDate = startDate;
      int dayCount = 0;

      for (List<PlaceCandidate> dayPlaces in dailyPlaces) {
        if (dayCount >= duration) break; // 지정된 기간만큼만 생성

        List<Schedule> daySchedules = await _generateDaySchedule(
          places: dayPlaces,
          date: currentDate,
          startTime: startTime,
          endTime: endTime,
          startLocation: startLocation,
          travelMode: travelMode,
        );

        schedules.addAll(daySchedules);
        currentDate = currentDate.add(const Duration(days: 1));
        dayCount++;
      }

      return schedules;
    } catch (e) {
      print('Schedule generation error: $e');
      return [];
    }
  }

  /// 하루 이용 가능한 시간 계산
  Duration _calculateDailyAvailableTime(TimeOfDay start, TimeOfDay end) {
    int startMinutes = start.hour * 60 + start.minute;
    int endMinutes = end.hour * 60 + end.minute;

    // 다음날로 넘어가는 경우 처리
    if (endMinutes < startMinutes) {
      endMinutes += 24 * 60;
    }

    return Duration(minutes: endMinutes - startMinutes);
  }

  /// 장소들을 최적 순서로 정렬 (간단한 nearest neighbor 알고리즘 사용)
  Future<List<PlaceCandidate>> _optimizePlaceOrder(
    List<PlaceCandidate> places,
    Location? startLocation,
    String travelMode,
  ) async {
    if (places.length <= 1) return places;

    List<PlaceCandidate> optimized = [];
    List<PlaceCandidate> remaining = List.from(places);

    // 시작점 설정
    Location currentLocation = startLocation ?? places.first.location;

    while (remaining.isNotEmpty) {
      PlaceCandidate nearest = remaining.first;
      int shortestDuration = double.maxFinite.toInt();

      // 가장 가까운 장소 찾기
      for (PlaceCandidate place in remaining) {
        RouteInfo? routeInfo = await _routeService.getRouteInfo(
          originLat: currentLocation.latitude!,
          originLng: currentLocation.longitude!,
          destLat: place.location.latitude!,
          destLng: place.location.longitude!,
        );

        if (routeInfo != null && routeInfo.duration < shortestDuration) {
          shortestDuration = routeInfo.duration;
          nearest = place;
        }
      }

      optimized.add(nearest);
      remaining.remove(nearest);
      currentLocation = nearest.location;
    }

    return optimized;
  }

  /// 장소들을 날짜별로 분배
  List<List<PlaceCandidate>> _distributePlacesByDay(
    List<PlaceCandidate> places,
    Duration dailyAvailableTime,
    int maxPlacesPerDay,
  ) {
    List<List<PlaceCandidate>> dailyPlaces = [];
    List<PlaceCandidate> currentDay = [];
    int currentDayDuration = 0; // 분 단위

    int availableMinutes = dailyAvailableTime.inMinutes;

    for (PlaceCandidate place in places) {
      int visitDuration = VisitDurationService.calculateVisitDuration(
        category: place.category,
      );

      // 예상 이동시간 (평균 15분으로 가정)
      int estimatedTravelTime = currentDay.isEmpty ? 0 : 15;
      int totalTimeNeeded = visitDuration + estimatedTravelTime;

      // 현재 날에 추가 가능한지 확인
      if (currentDay.length < maxPlacesPerDay &&
          currentDayDuration + totalTimeNeeded <= availableMinutes) {
        currentDay.add(place);
        currentDayDuration += totalTimeNeeded;
      } else {
        // 새로운 날로 넘어감
        if (currentDay.isNotEmpty) {
          dailyPlaces.add(currentDay);
        }
        currentDay = [place];
        currentDayDuration = visitDuration;
      }
    }

    // 마지막 날 추가
    if (currentDay.isNotEmpty) {
      dailyPlaces.add(currentDay);
    }

    return dailyPlaces;
  }

  /// 하루 일정 상세 생성
  Future<List<Schedule>> _generateDaySchedule({
    required List<PlaceCandidate> places,
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    Location? startLocation,
    required String travelMode,
  }) async {
    List<Schedule> daySchedules = [];

    DateTime currentTime = DateTime(
      date.year,
      date.month,
      date.day,
      startTime.hour,
      startTime.minute,
    );

    Location? previousLocation = startLocation;

    for (int i = 0; i < places.length; i++) {
      PlaceCandidate place = places[i];

      // 이동시간 계산
      int travelDuration = 0;
      if (previousLocation != null) {
        RouteInfo? routeInfo = await _routeService.getFutureRouteInfo(
          originLat: previousLocation.latitude!,
          originLng: previousLocation.longitude!,
          destLat: place.location.latitude!,
          destLng: place.location.longitude!,
          departureTime: currentTime,
        );

        travelDuration = routeInfo?.durationInMinutes ?? 15;
      }

      // 이동시간만큼 시간 추가
      DateTime endTime = currentTime.add(Duration(minutes: travelDuration));

      // 체류시간 계산
      int visitDuration = VisitDurationService.calculateVisitDuration(
        category: place.category,
        visitTime: currentTime,
      );

      // 일정 생성
      Schedule schedule = Schedule(
        id: _generateScheduleId(),
        title: place.title,
        description: place.description,
        dateTime: currentTime,
        EnddateTime: endTime,
        location: place.location,
        color: _getColorForCategory(place.category),
        isAlarmEnabled: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isEvent: true,
      );

      daySchedules.add(schedule);

      // 다음 장소로 이동하기 위한 시간 업데이트
      currentTime = currentTime.add(Duration(minutes: visitDuration));
      previousLocation = place.location;
    }

    return daySchedules;
  }

  /// 일정 ID 생성
  String _generateScheduleId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        Random().nextInt(1000).toString();
  }

  /// 카테고리에 따른 색상 결정
  ScheduleColor _getColorForCategory(String category) {
    String lowerCategory = category.toLowerCase();

    if (lowerCategory.contains('음식') ||
        lowerCategory.contains('식당') ||
        lowerCategory.contains('카페') ||
        lowerCategory.contains('레스토랑')) {
      return ScheduleColor.orange;
    } else if (lowerCategory.contains('관광') ||
        lowerCategory.contains('명소') ||
        lowerCategory.contains('박물관') ||
        lowerCategory.contains('미술관')) {
      return ScheduleColor.blue;
    } else if (lowerCategory.contains('쇼핑') ||
        lowerCategory.contains('마트') ||
        lowerCategory.contains('백화점')) {
      return ScheduleColor.purple;
    } else if (lowerCategory.contains('자연') ||
        lowerCategory.contains('공원') ||
        lowerCategory.contains('해변') ||
        lowerCategory.contains('산')) {
      return ScheduleColor.green;
    } else {
      return ScheduleColor.grey;
    }
  }

  /// RouteInfo를 외부에서 접근할 수 있도록 하는 메서드
  Future<RouteInfo?> getRouteInfo({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    return await _routeService.getRouteInfo(
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
    );
  }

  /// 생성된 일정을 데이터베이스에 저장
  Future<bool> saveGeneratedSchedules(List<Schedule> schedules) async {
    try {
      for (Schedule schedule in schedules) {
        await _scheduleService.addSchedule(
          title: schedule.title,
          description: schedule.description,
          dateTime: schedule.dateTime,
          EnddateTime: schedule.EnddateTime,
          location: schedule.location,
          isAlarmEnabled: schedule.isAlarmEnabled,
          alarmDateTime: schedule.alarmDateTime,
          color: schedule.color,
        );
      }
      return true;
    } catch (e) {
      print('Failed to save generated schedules: $e');
      return false;
    }
  }

  /// 장소 후보 검증 (필수 정보가 있는지 확인)
  bool _isValidPlaceCandidate(PlaceCandidate place) {
    return place.location.latitude != null &&
        place.location.longitude != null &&
        place.title.isNotEmpty;
  }

  /// 일정 시간 충돌 검사
  Future<List<Schedule>> _checkScheduleConflicts(
    List<Schedule> newSchedules,
    DateTime startDate,
    DateTime endDate,
  ) async {
    List<Schedule> allSchedules = await _scheduleService.getAllSchedules();

    // 해당 기간의 일정만 필터링
    List<Schedule> existingSchedules = allSchedules.where((schedule) {
      return schedule.dateTime.isAfter(
            startDate.subtract(const Duration(days: 1)),
          ) &&
          schedule.dateTime.isBefore(endDate.add(const Duration(days: 1)));
    }).toList();

    List<Schedule> conflicts = [];

    for (Schedule newSchedule in newSchedules) {
      for (Schedule existing in existingSchedules) {
        if (_schedulesOverlap(newSchedule, existing)) {
          conflicts.add(existing);
        }
      }
    }

    return conflicts;
  }

  /// 두 일정이 시간적으로 겹치는지 확인
  bool _schedulesOverlap(Schedule schedule1, Schedule schedule2) {
    // 간단한 겹침 검사 (1시간씩 소요된다고 가정)
    DateTime end1 = schedule1.dateTime.add(const Duration(hours: 1));
    DateTime end2 = schedule2.dateTime.add(const Duration(hours: 1));

    return schedule1.dateTime.isBefore(end2) &&
        end1.isAfter(schedule2.dateTime);
  }
}

/// 장소 후보 모델
class PlaceCandidate {
  final String title;
  final String description;
  final Location location;
  final String category;
  final int priority; // 1-10, 높을수록 우선순위 높음
  final int? estimatedDuration; // 분 단위, null이면 자동 계산

  PlaceCandidate({
    required this.title,
    this.description = '',
    required this.location,
    required this.category,
    this.priority = 5,
    this.estimatedDuration,
  });

  /// PlaceDetails에서 PlaceCandidate 생성
  static PlaceCandidate fromPlaceDetails(
    PlaceDetails placeDetails,
    Location location, {
    int priority = 5,
  }) {
    return PlaceCandidate(
      title: location.name,
      description: placeDetails.category,
      location: location,
      category: placeDetails.category,
      priority: priority,
    );
  }
}

/// 일정 생성 옵션
class ScheduleGenerationOptions {
  final Duration maxTravelTime; // 최대 이동시간
  final bool includeRestTime; // 휴식시간 포함 여부
  final bool optimizeForDistance; // 거리 최적화 우선
  final List<String> preferredCategories; // 선호 카테고리
  final List<String> avoidCategories; // 회피 카테고리

  ScheduleGenerationOptions({
    this.maxTravelTime = const Duration(hours: 8),
    this.includeRestTime = true,
    this.optimizeForDistance = true,
    this.preferredCategories = const [],
    this.avoidCategories = const [],
  });
}
