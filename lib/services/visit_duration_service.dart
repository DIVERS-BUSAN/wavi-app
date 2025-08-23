import 'dart:math';
import '../models/placedetail.dart';

class VisitDurationService {
  // 장소 카테고리별 기본 체류시간 (분 단위)
  static const Map<String, DurationRange> _categoryDurations = {
    // 관광명소
    '관광명소': DurationRange(60, 120),
    '명소': DurationRange(60, 120),
    '관광': DurationRange(60, 120),
    '여행': DurationRange(60, 120),
    '테마파크': DurationRange(240, 480),
    '놀이공원': DurationRange(240, 480),
    '동물원': DurationRange(180, 300),
    '수족관': DurationRange(120, 240),
    '전망대': DurationRange(30, 90),
    
    // 문화시설
    '박물관': DurationRange(120, 180),
    '미술관': DurationRange(90, 150),
    '갤러리': DurationRange(60, 120),
    '전시관': DurationRange(90, 150),
    '문화센터': DurationRange(120, 240),
    '공연장': DurationRange(120, 180),
    '극장': DurationRange(120, 180),
    
    // 자연/야외
    '해변': DurationRange(120, 240),
    '바다': DurationRange(120, 240),
    '공원': DurationRange(60, 180),
    '산': DurationRange(180, 360),
    '등산': DurationRange(180, 360),
    '하이킹': DurationRange(120, 300),
    '숲': DurationRange(90, 180),
    '정원': DurationRange(45, 90),
    '호수': DurationRange(60, 120),
    '강': DurationRange(60, 120),
    
    // 음식점
    '한식': DurationRange(60, 90),
    '중식': DurationRange(60, 90),
    '일식': DurationRange(60, 90),
    '양식': DurationRange(90, 120),
    '이탈리아': DurationRange(90, 120),
    '피자': DurationRange(60, 90),
    '치킨': DurationRange(45, 75),
    '족발': DurationRange(90, 120),
    '삼겹살': DurationRange(90, 120),
    '바베큐': DurationRange(90, 120),
    '회': DurationRange(90, 120),
    '해산물': DurationRange(90, 120),
    '뷔페': DurationRange(90, 150),
    '분식': DurationRange(30, 60),
    '패스트푸드': DurationRange(30, 45),
    '음식점': DurationRange(60, 90),
    '식당': DurationRange(60, 90),
    '레스토랑': DurationRange(90, 120),
    
    // 카페/디저트
    '카페': DurationRange(45, 90),
    '커피': DurationRange(30, 60),
    '디저트': DurationRange(30, 60),
    '베이커리': DurationRange(20, 40),
    '아이스크림': DurationRange(15, 30),
    
    // 쇼핑
    '쇼핑몰': DurationRange(120, 240),
    '백화점': DurationRange(120, 300),
    '마트': DurationRange(45, 90),
    '시장': DurationRange(60, 120),
    '전통시장': DurationRange(90, 150),
    '쇼핑': DurationRange(90, 180),
    '상점': DurationRange(30, 60),
    '매장': DurationRange(30, 60),
    
    // 숙박
    '호텔': DurationRange(480, 720), // 8-12시간 (체크인-체크아웃)
    '모텔': DurationRange(480, 720),
    '펜션': DurationRange(480, 720),
    '게스트하우스': DurationRange(480, 720),
    '리조트': DurationRange(480, 720),
    
    // 운동/레저
    '체육관': DurationRange(60, 120),
    '수영장': DurationRange(60, 120),
    '골프': DurationRange(240, 360),
    '볼링': DurationRange(90, 150),
    '노래방': DurationRange(60, 150),
    'PC방': DurationRange(120, 240),
    '찜질방': DurationRange(180, 360),
    '사우나': DurationRange(90, 180),
    
    // 종교시설
    '교회': DurationRange(60, 120),
    '성당': DurationRange(60, 120),
    '절': DurationRange(45, 90),
    '사찰': DurationRange(45, 90),
    '종교': DurationRange(60, 120),
    
    // 교통/기타
    '지하철': DurationRange(5, 15),
    '버스': DurationRange(5, 20),
    '기차': DurationRange(10, 30),
    '공항': DurationRange(120, 180),
    '터미널': DurationRange(30, 60),
    '주차장': DurationRange(5, 15),
    
    // 의료/건강
    '병원': DurationRange(60, 180),
    '약국': DurationRange(10, 20),
    '마사지': DurationRange(60, 120),
    '스파': DurationRange(120, 240),
    
    // 교육
    '학교': DurationRange(60, 480),
    '도서관': DurationRange(120, 300),
    '학원': DurationRange(60, 120),
    
    // 기본값
    '기타': DurationRange(45, 90),
  };

  // 시간대별 체류시간 조정 계수
  static const Map<int, double> _timeMultipliers = {
    6: 0.7,   // 아침 일찍
    7: 0.8,   
    8: 0.9,   
    9: 1.0,   // 오전
    10: 1.0,
    11: 1.0,
    12: 1.2,  // 점심시간
    13: 1.1,
    14: 1.0,  // 오후
    15: 1.0,
    16: 1.0,
    17: 1.0,
    18: 1.2,  // 저녁시간
    19: 1.1,
    20: 1.0,
    21: 0.9,  // 늦은 시간
    22: 0.8,
  };

  // 요일별 체류시간 조정 계수
  static const Map<int, double> _weekdayMultipliers = {
    DateTime.monday: 0.9,
    DateTime.tuesday: 0.9,
    DateTime.wednesday: 0.9,
    DateTime.thursday: 0.9,
    DateTime.friday: 1.0,
    DateTime.saturday: 1.2,
    DateTime.sunday: 1.1,
  };

  /// 장소의 카테고리와 시간을 기반으로 체류시간을 산정
  static int calculateVisitDuration({
    required String category,
    DateTime? visitTime,
    bool isWeekend = false,
  }) {
    // 기본 체류시간 범위 찾기
    DurationRange? range = _findCategoryDuration(category);
    range ??= _categoryDurations['기타']!;

    // 기본 체류시간 (범위의 중간값)
    int baseDuration = ((range.min + range.max) / 2).round();

    // 시간대별 조정
    if (visitTime != null) {
      int hour = visitTime.hour;
      double timeMultiplier = _timeMultipliers[hour] ?? 1.0;
      baseDuration = (baseDuration * timeMultiplier).round();

      // 요일별 조정
      int weekday = visitTime.weekday;
      double weekdayMultiplier = _weekdayMultipliers[weekday] ?? 1.0;
      baseDuration = (baseDuration * weekdayMultiplier).round();
    }

    // 최소 15분, 최대 8시간 제한
    baseDuration = baseDuration.clamp(15, 480);
    
    // 15분 단위로 반올림
    return ((baseDuration / 15).round() * 15);
  }

  /// 여러 키워드를 포함한 카테고리에서 적절한 체류시간 찾기
  static DurationRange? _findCategoryDuration(String category) {
    String lowerCategory = category.toLowerCase();
    
    // 정확히 일치하는 카테고리 찾기
    for (String key in _categoryDurations.keys) {
      if (lowerCategory.contains(key.toLowerCase())) {
        return _categoryDurations[key];
      }
    }
    
    return null;
  }

  /// 장소 상세정보를 기반으로 체류시간 산정
  static int calculateVisitDurationFromPlaceDetail({
    required PlaceDetails placeDetail,
    DateTime? visitTime,
  }) {
    return calculateVisitDuration(
      category: placeDetail.category,
      visitTime: visitTime,
      isWeekend: visitTime?.weekday == DateTime.saturday || 
                visitTime?.weekday == DateTime.sunday,
    );
  }

  /// 체류시간 범위 조회 (UI에서 사용할 수 있도록)
  static DurationRange getVisitDurationRange(String category) {
    return _findCategoryDuration(category) ?? _categoryDurations['기타']!;
  }

  /// 추천 체류시간 텍스트 생성
  static String getRecommendedDurationText(String category) {
    DurationRange range = getVisitDurationRange(category);
    
    if (range.min < 60 && range.max < 60) {
      return '${range.min}분 ~ ${range.max}분';
    } else if (range.min >= 60 && range.max >= 60) {
      double minHours = range.min / 60;
      double maxHours = range.max / 60;
      
      if (minHours == minHours.floor() && maxHours == maxHours.floor()) {
        return '${minHours.toInt()}시간 ~ ${maxHours.toInt()}시간';
      } else {
        return '${minHours.toStringAsFixed(1)}시간 ~ ${maxHours.toStringAsFixed(1)}시간';
      }
    } else {
      double hours = range.max / 60;
      return '${range.min}분 ~ ${hours.toStringAsFixed(1)}시간';
    }
  }
}

/// 체류시간 범위 모델
class DurationRange {
  final int min; // 분 단위
  final int max; // 분 단위

  const DurationRange(this.min, this.max);

  int get average => ((min + max) / 2).round();
}