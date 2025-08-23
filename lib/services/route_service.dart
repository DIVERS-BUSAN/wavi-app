import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/schedule.dart';

class RouteService {
  static const String _baseUrl = 'https://apis-navi.kakaomobility.com';
  
  static String get _apiKey => dotenv.env['KAKAO_REST_API_KEY'] ?? '';

  // 두 지점 간의 이동 시간과 거리를 계산
  Future<RouteInfo?> getRouteInfo({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String priority = 'RECOMMEND', // RECOMMEND, TIME, DISTANCE
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/v1/directions');
      
      final response = await http.get(
        url.replace(queryParameters: {
          'origin': '$originLng,$originLat',
          'destination': '$destLng,$destLat',
          'priority': priority,
        }),
        headers: {
          'Authorization': 'KakaoAK $_apiKey',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data != null && 
            data['routes'] != null && 
            data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final summary = route?['summary'];
          
          if (summary != null) {
            return RouteInfo(
              duration: summary['duration'] ?? 0, // 초 단위
              distance: summary['distance'] ?? 0, // 미터 단위
              taxiFare: summary['fare']?['taxi'] ?? 0,
              tollFare: summary['fare']?['toll'] ?? 0,
            );
          }
        }
      }
      
      print('Route API Error: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Route calculation error: $e');
      return null;
    }
  }

  // 미래 특정 시간의 이동 시간 계산
  Future<RouteInfo?> getFutureRouteInfo({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required DateTime departureTime,
    String priority = 'RECOMMEND',
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/v1/future/directions');
      
      // 출발 시간을 yyyyMMddHHmm 형식으로 변환
      final departureTimeStr = 
          '${departureTime.year.toString().padLeft(4, '0')}'
          '${departureTime.month.toString().padLeft(2, '0')}'
          '${departureTime.day.toString().padLeft(2, '0')}'
          '${departureTime.hour.toString().padLeft(2, '0')}'
          '${departureTime.minute.toString().padLeft(2, '0')}';
      
      final response = await http.get(
        url.replace(queryParameters: {
          'origin': '$originLng,$originLat',
          'destination': '$destLng,$destLat',
          'departure_time': departureTimeStr,
          'priority': priority,
        }),
        headers: {
          'Authorization': 'KakaoAK $_apiKey',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data != null && 
            data['routes'] != null && 
            data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final summary = route?['summary'];
          
          if (summary != null) {
            return RouteInfo(
              duration: summary['duration'] ?? 0,
              distance: summary['distance'] ?? 0,
              taxiFare: summary['fare']?['taxi'] ?? 0,
              tollFare: summary['fare']?['toll'] ?? 0,
            );
          }
        }
      }
      
      print('Future Route API Error: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Future route calculation error: $e');
      return null;
    }
  }

  // 여러 경유지를 포함한 경로 계산
  Future<MultiRouteInfo?> getMultiWaypointRoute({
    required double originLat,
    required double originLng,
    required List<Location> waypoints,
    required double destLat,
    required double destLng,
    String priority = 'RECOMMEND',
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/v1/waypoints/directions');
      
      // 경유지 좌표 문자열 생성
      final waypointsStr = waypoints
          .map((wp) => '${wp.longitude},${wp.latitude}')
          .join('|');
      
      final response = await http.get(
        url.replace(queryParameters: {
          'origin': '$originLng,$originLat',
          'destination': '$destLng,$destLat',
          'waypoints': waypointsStr,
          'priority': priority,
        }),
        headers: {
          'Authorization': 'KakaoAK $_apiKey',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data != null && 
            data['routes'] != null && 
            data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final summary = route?['summary'];
          
          if (summary != null) {
            return MultiRouteInfo(
              totalDuration: summary['duration'] ?? 0,
              totalDistance: summary['distance'] ?? 0,
              sections: _parseSections(route['sections'] ?? []),
            );
          }
        }
      }
      
      print('Multi-waypoint Route API Error: ${response.statusCode} - ${response.body}');
      return null;
    } catch (e) {
      print('Multi-waypoint route calculation error: $e');
      return null;
    }
  }

  List<RouteSection> _parseSections(List<dynamic> sectionsData) {
    return sectionsData.map<RouteSection>((section) {
      final summary = section['summary'];
      return RouteSection(
        duration: summary['duration'] ?? 0,
        distance: summary['distance'] ?? 0,
      );
    }).toList();
  }
}

// 경로 정보 모델
class RouteInfo {
  final int duration; // 초 단위
  final int distance; // 미터 단위
  final int taxiFare;
  final int tollFare;

  RouteInfo({
    required this.duration,
    required this.distance,
    this.taxiFare = 0,
    this.tollFare = 0,
  });

  // 분 단위로 변환
  int get durationInMinutes => (duration / 60).round();
  
  // km 단위로 변환
  double get distanceInKm => distance / 1000.0;
}

// 여러 구간 경로 정보
class MultiRouteInfo {
  final int totalDuration;
  final int totalDistance;
  final List<RouteSection> sections;

  MultiRouteInfo({
    required this.totalDuration,
    required this.totalDistance,
    required this.sections,
  });

  int get totalDurationInMinutes => (totalDuration / 60).round();
  double get totalDistanceInKm => totalDistance / 1000.0;
}

// 개별 구간 정보
class RouteSection {
  final int duration;
  final int distance;

  RouteSection({
    required this.duration,
    required this.distance,
  });

  int get durationInMinutes => (duration / 60).round();
  double get distanceInKm => distance / 1000.0;
}