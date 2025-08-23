import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class KakaoNaviService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: "https://apis-navi.kakaomobility.com",
    headers: {
      "Authorization": "KakaoAK ${dotenv.env['KAKAO_REST_API_KEY']}", // 카카오 REST API 키 넣기
    },
  ));

  // 단순 duration(소요 시간)만 구하는 함수
  Future<int?> getTravelTime({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    required DateTime departureTime,
  }) async {
    final response = await _dio.get(
      "/v1/directions",
      queryParameters: {
        "origin": "$startLng,$startLat",     // ✅ 경도,위도 순서
        "destination": "$endLng,$endLat",   // ✅ 경도,위도 순서
        "priority": "RECOMMEND",
      },
    );

    print("📦 Kakao response: ${response.data}");

    if (response.statusCode == 200) {
      final data = response.data;
      if (data != null &&
          data["routes"] != null &&
          data["routes"].isNotEmpty &&
          data["routes"][0]["summary"] != null) {
        final duration = data["routes"][0]["summary"]["duration"];
        return duration; // 초 단위
      }
    } else {
      print("❌ Kakao API error: ${response.statusCode}, ${response.statusMessage}");
    }
    return null;
  }

  // 🚀 실제 경로(polyline) + duration까지 뽑는 함수
  Future<KakaoRoute?> getRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    final response = await _dio.get(
      "/v1/directions",
      queryParameters: {
        "origin": "$startLng,$startLat",
        "destination": "$endLng,$endLat",
        "priority": "RECOMMEND",
      },
    );

    print("📦 Kakao response: ${response.data}");

    if (response.statusCode == 200) {
      final data = response.data;
      if (data != null && data["routes"] != null && data["routes"].isNotEmpty) {
        final summary = data["routes"][0]["summary"];
        final duration = summary["duration"];

        // polyline 좌표 추출
        final sections = data["routes"][0]["sections"] as List;
        final List<List<double>> path = [];
        for (var section in sections) {
          for (var road in section["roads"]) {
            final vertexes = (road["vertexes"] as List).cast<double>();
            for (int i = 0; i < vertexes.length; i += 2) {
              path.add([vertexes[i], vertexes[i + 1]]); // [lng, lat]
            }
          }
        }

        return KakaoRoute(duration: duration, path: path);
      }
    }
    return null;
  }
}

// 경로 데이터 모델
class KakaoRoute {
  final int duration; // 초 단위
  final List<List<double>> path; // [[lng, lat], [lng, lat], ...]

  KakaoRoute({required this.duration, required this.path});
}
