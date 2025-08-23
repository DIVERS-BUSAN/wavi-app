import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:wavi_app/models/schedule.dart';
import 'dart:convert';

class PlaceDetails {
  final String placeName;
  final String category;
  final String address;
  final String phone;
  final String placeUrl; // 카카오맵 상세 정보 URL

  PlaceDetails({
    this.placeName = '정보 없음',
    this.category = '정보 없음',
    this.address = '정보 없음',
    this.phone = '정보 없음',
    this.placeUrl = '',
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    return PlaceDetails(
      placeName: json['place_name'] ?? '이름 정보 없음',
      category: json['category_name'] ?? '카테고리 정보 없음',
      address: json['road_address_name'] ?? json['address_name'] ?? '주소 정보 없음',
      phone: json['phone'] ?? '전화번호 정보 없음',
      placeUrl: json['place_url'] ?? '',
    );
  }
}

Future<PlaceDetails?> getPlaceDetails(Location location) async {
  // 장소 이름이 없으면 API를 호출할 수 없으므로 null 반환
  if (location.name.isEmpty) return null;

  final query = Uri.encodeComponent(location.name);
  final url = Uri.parse(
      'https://dapi.kakao.com/v2/local/search/keyword.json?query=$query&x=${location.longitude}&y=${location.latitude}&radius=1000');
  final String API_KEY = dotenv.env['KAKAO_REST_API_KEY'] ?? '';

  try {
    final response = await http.get(
      url,
      headers: {'Authorization': 'KakaoAK $API_KEY'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['documents'] != null && data['documents'].isNotEmpty) {
        // 검색 결과 중 첫 번째 항목(가장 정확도 높은 항목)을 사용
        return PlaceDetails.fromJson(data['documents'][0]);
      }
    }
    return null; // 검색 결과가 없을 경우
  } catch (e) {
    print('장소 상세 정보 API 오류: $e');
    return null;
  }
}