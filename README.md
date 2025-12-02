# WAVI (Web-based AI Voice Interaction)

WAVI는 AI 기반 음성 대화를 통한 스마트 여행 도우미 애플리케이션입니다. 음성 인식, AI 챗봇, 카카오 지도/네비게이션 기능을 통합하여 사용자에게 편리한 여행 경험을 제공합니다.

## 주요 기능

### 🗣️ AI 음성 대화
- **음성 인식 (STT)**: 사용자의 음성을 텍스트로 변환
- **음성 출력 (TTS)**: AI 응답을 음성으로 출력
- **Google Generative AI**: 자연스러운 대화형 AI 어시스턴트

### 🗺️ 지도 및 네비게이션
- **카카오 지도 통합**: 실시간 지도 표시 및 장소 검색
- **카카오 네비게이션**: 목적지까지의 경로 안내
- **위치 기반 서비스**: GPS를 활용한 현재 위치 추적
- **대중교통 정보**: 교통편 안내 및 경로 검색

### 📅 일정 관리
- **스케줄 생성**: AI 기반 여행 일정 자동 생성
- **캘린더 뷰**: 직관적인 일정 관리 인터페이스
- **알림 기능**: 일정 시간에 맞춘 푸시 알림
- **방문 장소 관리**: 관광지 정보 및 방문 예정 시간 관리

### 🌐 다국어 지원
- 한국어 (ko)
- 영어 (en)
- 실시간 언어 전환 기능

### 🔔 알림 시스템
- 여행 일정 알림
- 중요 이벤트 알림
- 로컬 알림 지원

## 기술 스택

### 프레임워크 & 언어
- **Flutter** (SDK ^3.9.0)
- **Dart**

### 주요 라이브러리
- **AI & 음성**
  - `google_generative_ai`: Google AI 통합
  - `speech_to_text`: 음성 인식
  - `flutter_tts`: 텍스트 음성 변환

- **지도 & 네비게이션**
  - `kakao_map_plugin`: 카카오 지도
  - `kakao_flutter_sdk_navi`: 카카오 네비게이션
  - `geolocator`: 위치 서비스

- **상태 관리 & UI**
  - `provider`: 상태 관리
  - `table_calendar`: 캘린더 UI
  - `flutter_local_notifications`: 로컬 알림

- **기타**
  - `http`: HTTP 통신
  - `flutter_dotenv`: 환경 변수 관리
  - `shared_preferences`: 로컬 데이터 저장
  - `intl`: 국제화 지원

## 프로젝트 구조

```
lib/
├── l10n/                      # 다국어 지원 파일
│   ├── app_localizations.dart
│   ├── app_localizations_ko.dart
│   └── app_localizations_en.dart
├── models/                    # 데이터 모델
│   ├── chat_message.dart
│   ├── schedule.dart
│   ├── location.dart
│   └── placedetail.dart
├── providers/                 # 상태 관리
│   └── language_provider.dart
├── screens/                   # UI 화면
│   ├── map_screen.dart
│   ├── schedule_screen.dart
│   ├── chat_screen.dart
│   ├── notification_screen.dart
│   └── profile_screen.dart
├── services/                  # 비즈니스 로직
│   ├── ai_voice_service.dart
│   ├── openai_service.dart
│   ├── kakao_navi_service.dart
│   ├── route_service.dart
│   ├── tourism_service.dart
│   ├── schedule_service.dart
│   ├── schedule_generator_service.dart
│   ├── visit_duration_service.dart
│   └── notification_service.dart
├── widgets/                   # 재사용 가능한 위젯
│   ├── custom_app_bar.dart
│   ├── chat_bubble.dart
│   ├── location_picker.dart
│   ├── location_selection_dialog.dart
│   ├── place_detail_viewer.dart
│   └── color_picker.dart
├── utils/                     # 유틸리티
│   └── toast_utils.dart
└── main.dart                  # 앱 진입점
```

## 시작하기

### 사전 요구사항
- Flutter SDK (^3.9.0)
- Dart SDK
- Android Studio / Xcode (모바일 개발용)
- 카카오 개발자 계정 (지도/네비게이션 API용)
- Google AI API 키

### 환경 설정

1. 저장소 클론
```bash
git clone <repository-url>
cd wavi-app
```

2. 의존성 설치
```bash
flutter pub get
```

3. 환경 변수 설정

프로젝트 루트에 `.env` 파일을 생성하고 다음 정보를 입력하세요:

```env
KAKAO_NATIVE_APP_KEY=your_kakao_native_app_key
KAKAO_JS_APP_KEY=your_kakao_js_app_key
GOOGLE_AI_API_KEY=your_google_ai_api_key
```

4. 애셋 준비
- `assets/images/` 폴더에 필요한 이미지 파일을 추가하세요
- 특히 `wavi-logo-white.png` 파일이 필요합니다

### 실행

```bash
# 개발 모드 실행
flutter run

# 특정 플랫폼 실행
flutter run -d chrome        # 웹
flutter run -d macos         # macOS
flutter run -d android       # Android
flutter run -d ios           # iOS
```

### 빌드

```bash
# Android APK 빌드
flutter build apk

# iOS 빌드
flutter build ios

# 웹 빌드
flutter build web

# macOS 앱 빌드
flutter build macos
```

## 지원 플랫폼

- ✅ Android
- ✅ iOS
- ✅ Web
- ✅ macOS
- ✅ Linux
- ✅ Windows

## 주요 화면

1. **지도 화면** - 카카오 지도를 통한 장소 검색 및 네비게이션
2. **일정 화면** - 여행 일정 관리 및 캘린더 뷰
3. **AI 챗봇 화면** - 음성/텍스트 기반 AI 대화
4. **알림 화면** - 예정된 일정 및 알림 확인
5. **프로필 화면** - 사용자 설정 및 언어 변경

## 권한 요구사항

- **위치 권한**: GPS 기반 위치 서비스
- **마이크 권한**: 음성 인식 기능
- **알림 권한**: 일정 알림 표시
- **인터넷 권한**: API 통신 및 지도 서비스

## 개발 정보

### 버전
- **Current Version**: 1.0.0+1
- **Flutter SDK**: ^3.9.0

### 코드 품질
- `flutter_lints` 적용
- `analysis_options.yaml`로 코드 스타일 관리

## 라이선스

이 프로젝트는 비공개 프로젝트입니다 (`publish_to: 'none'`).

## 문의

프로젝트에 대한 문의사항이 있으시면 이슈를 등록해주세요.

---

**Made with Flutter 💙**
