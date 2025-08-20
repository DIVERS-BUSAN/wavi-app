import 'app_localizations.dart';
import 'package:intl/intl.dart';

class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo() : super('ko');

  @override
  String get mapTab => '지도';

  @override
  String get scheduleTab => '일정';

  @override
  String get chatTab => '채팅';

  @override
  String get notificationTab => '알림';

  @override
  String get profileTab => '프로필';

  @override
  String get chatTitle => 'AI 채팅';

  @override
  String get typeMessage => '메시지를 입력하세요...';

  @override
  String get voiceInput => '음성 입력';

  @override
  String get sendMessage => '전송';

  @override
  String get cancel => '취소';

  @override
  String get confirm => '확인';

  @override
  String get settings => '설정';

  @override
  String get language => '언어';

  @override
  String get korean => '한국어';

  @override
  String get english => '영어';
  
  // Map screen
  @override
  String get mapTitle => '지도';

  @override
  String get currentLocation => '현재 위치';

  @override
  String get searchLocation => '장소 검색';

  @override
  String get navigate => '길찾기';

  @override
  String get scheduleLocation => '일정 장소';
  
  // Schedule screen
  @override
  String get scheduleTitle => '일정';

  @override
  String get addSchedule => '일정 추가';

  @override
  String get today => '오늘';

  @override
  String get noSchedules => '등록된 일정이 없습니다';

  @override
  String get scheduleDetails => '일정 상세';
  
  // Notification screen
  @override
  String get notificationTitle => '알림';

  @override
  String get noNotifications => '새로운 알림이 없습니다';

  @override
  String get markAsRead => '읽음으로 표시';
  
  // Chat screen additional
  @override
  String get clearChatHistory => '채팅 기록 삭제';

  @override
  String get apiConnectionTest => 'API 연결 테스트';

  @override
  String get customRecommendations => '맞춤 추천';

  @override
  String get touristInfo => '관광지 정보';

  @override
  String get trafficInfo => '교통 안내';

  @override
  String get weatherCheck => '날씨 확인';

  @override
  String get deleteChatConfirm => '모든 채팅 기록을 삭제하시겠습니까?';

  @override
  String get cannotUndo => '이 작업은 되돌릴 수 없습니다';
  
  // Snackbar messages
  @override
  String get chatHistoryDeleted => '채팅 기록이 삭제되었습니다';

  @override
  String get scheduleDeleted => '일정이 삭제되었습니다';

  @override
  String get scheduleCreated => '일정이 생성되었습니다';

  @override
  String get micPermissionRequired => '음성 인식을 사용할 수 없습니다. 마이크 권한을 확인해주세요.';

  @override
  String get voiceChatModeStarted => '🎤 음성 대화 모드 - 말씀해주세요 (마이크 버튼으로 종료)';

  @override
  String get listeningToVoice => '🎤 음성 인식 중... 말씀해주세요';

  @override
  String get gettingCurrentLocation => '현재 위치 가져오는 중...';

  @override
  String get goToSchedule => '일정으로 이동';
  
  // Status texts
  @override
  String get scheduled => '예정';

  @override
  String get completed => '완료';

  @override
  String get overdue => '지연됨';

  @override
  String get upcomingNotifications => '예정된 알림';

  @override
  String get notificationHistory => '알림 히스토리';
  
  // Notification time formats
  @override
  String get onTime => '정시에 알림';

  @override
  String minutesBefore(int minutes) => '${minutes}분 전 알림';

  @override
  String hoursBefore(int hours) => '${hours}시간 전 알림';

  @override
  String daysBefore(int days) => '${days}일 전 알림';
  
  // Welcome messages
  @override
  String get welcomeMessageKo => '안녕하세요! 저는 웨이비(WAVI) AI 비서입니다. \n\n일정 관리, 길찾기, 그리고 다양한 질문에 답변해드릴게요!\n\n무엇을 도와드릴까요?';

  @override
  String get welcomeMessageEn => 'Hello! I\'m WAVI, your AI assistant. \n\nI can help you with schedule management, navigation, and answer various questions!\n\nWhat can I help you with?';
  
  // Date picker
  @override
  String get selectDate => '날짜 선택';

  @override
  String get selectTime => '시간 선택';
  
  // Notification empty states
  @override
  String get noUpcomingNotifications => '예정된 알림이 없습니다';

  @override
  String get addScheduleWithAlerts => '일정을 추가하고 알림을 설정해보세요';

  @override
  String get noNotificationHistory => '알림 히스토리가 없습니다';
  
  // Schedule screen
  @override
  String get noSchedulesOnDate => '등록된 일정이 없습니다';

  @override
  String get selectDateToViewSchedules => '날짜를 선택하여 일정을 확인하세요';

  @override
  String scheduleCount(int count) => '$count개 일정';

  @override
  String get edit => '수정';

  @override
  String get delete => '삭제';

  @override
  String get deleteSchedule => '일정 삭제';

  @override
  String get deleteScheduleConfirm => '이 일정을 삭제하시겠습니까?';

  @override
  String get scheduleTitleField => '일정 제목';

  @override
  String get scheduleDescription => '일정 설명';

  @override
  String get dateAndTime => '날짜 및 시간';

  @override
  String get location => '장소';

  @override
  String get selectLocation => '장소를 선택하세요';

  @override
  String get alarmSettings => '알림 설정';

  @override
  String get alarmTime => '알림 시간';

  @override
  String get aiVoiceAlarm => 'AI 비서 음성 알림';

  @override
  String get aiVoiceAlarmDescription => 'AI 비서가 일정 내용을 음성으로 알려드립니다';

  @override
  String get add => '추가';

  @override
  String get scheduleAdded => '일정이 추가되었습니다';

  @override
  String get scheduleUpdated => '일정이 수정되었습니다';

  @override
  String get saveScheduleFailed => '일정 저장에 실패했습니다. 다시 시도해주세요.';

  @override
  String get newSchedule => '새 일정 추가';

  @override
  String get editSchedule => '일정 수정';

  @override
  String get enterTitle => '제목을 입력해주세요';

  @override
  String get optional => '';

  @override
  String get required => '*';
  
  // Map screen additional
  @override
  String get myLocation => '내 위치';
  
  @override
  String get scheduleContent => '일정 내용:';
  
  @override
  String get address => '주소:';
  
  @override
  String get coordinates => '좌표:';
  
  @override
  String get latitude => '위도';
  
  @override
  String get longitude => '경도';
  
  @override
  String get close => '닫기';
  
  @override
  String get currentLocationLoading => '현재 위치 가져오는 중...';
  
  @override
  String get listView => '목록보기';
  
  @override
  String get kakaoNavRequired => '카카오 네비게이션 설치 필요';
  
  @override
  String get kakaoNavInstallPrompt => '길찾기 기능을 사용하려면 카카오 네비게이션 앱이 필요합니다.\n앱스토어에서 카카오 네비게이션을 설치하시겠습니까?';
  
  @override
  String get install => '설치하기';
  
  @override
  String navigatingTo(String destination) => '$destination로 길찾기를 시작합니다.';
  
  @override
  String get navigationFailed => '네비게이션 실행에 실패했습니다';
  
  @override
  String get navigationError => '길찾기 실행 중 오류가 발생했습니다.';
  
  @override
  String get cannotOpenInstallPage => '설치 페이지를 열 수 없습니다.';
  
  @override
  String get cannotGetCurrentLocation => '현재 위치를 가져올 수 없습니다.';
  
  @override
  String dailySchedule(DateTime date) => DateFormat('MM월 dd일 일정').format(date);
}