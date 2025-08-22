import 'app_localizations.dart';
import 'package:intl/intl.dart';

class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn() : super('en');

  @override
  String get chooseTravelMode => 'Choose Travel Mode';

  @override
  String get howToTravel => 'How would you like to travel?';

  @override
  String get walking => 'Walking';

  @override
  String get driving => 'Driving';

  @override
  String get mapTab => 'Map';

  @override
  String get scheduleTab => 'Schedule';

  @override
  String get chatTab => 'Chat';

  @override
  String get notificationTab => 'Notifications';

  @override
  String get profileTab => 'Profile';

  @override
  String get chatTitle => 'AI Chat';

  @override
  String get typeMessage => 'Type a message...';

  @override
  String get voiceInput => 'Voice Input';

  @override
  String get sendMessage => 'Send';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get korean => 'Korean';

  @override
  String get english => 'English';
  
  // Map screen
  @override
  String get mapTitle => 'Map';

  @override
  String get currentLocation => 'Current Location';

  @override
  String get searchLocation => 'Search Location';

  @override
  String get navigate => 'Navigate';

  @override
  String get scheduleLocation => 'Schedule Location';
  
  // Schedule screen
  @override
  String get scheduleTitle => 'Schedule';

  @override
  String get addSchedule => 'Add Schedule';

  @override
  String get today => 'Today';

  @override
  String get noSchedules => 'No schedules registered';

  @override
  String get scheduleDetails => 'Schedule Details';
  
  // Notification screen
  @override
  String get notificationTitle => 'Notifications';

  @override
  String get noNotifications => 'No new notifications';

  @override
  String get markAsRead => 'Mark as Read';
  
  // Chat screen additional
  @override
  String get clearChatHistory => 'Clear Chat History';

  @override
  String get apiConnectionTest => 'API Connection Test';

  @override
  String get customRecommendations => 'Tips';

  @override
  String get touristInfo => 'Places';

  @override
  String get trafficInfo => 'Traffic';

  @override
  String get weatherCheck => 'Weather';

  @override
  String get deleteChatConfirm => 'Delete all chat history?';

  @override
  String get cannotUndo => 'This action cannot be undone';
  
  // Snackbar messages
  @override
  String get chatHistoryDeleted => 'Chat history deleted';

  @override
  String get scheduleDeleted => 'Schedule deleted';

  @override
  String get scheduleCreated => 'Schedule created';

  @override
  String get micPermissionRequired => 'Voice recognition unavailable. Please check microphone permissions.';

  @override
  String get voiceChatModeStarted => '🎤 Voice chat mode - Please speak (tap mic button to exit)';

  @override
  String get listeningToVoice => '🎤 Listening... Please speak';

  @override
  String get gettingCurrentLocation => 'Getting current location...';

  @override
  String get goToSchedule => 'Go to schedule';
  
  // Status texts
  @override
  String get scheduled => 'Scheduled';

  @override
  String get completed => 'Completed';

  @override
  String get overdue => 'Overdue';

  @override
  String get upcomingNotifications => 'Upcoming';

  @override
  String get notificationHistory => 'History';
  
  // Notification time formats
  @override
  String get onTime => 'On time alert';

  @override
  String minutesBefore(int minutes) => '$minutes minutes before';

  @override
  String hoursBefore(int hours) => '$hours hours before';

  @override
  String daysBefore(int days) => '$days days before';
  
  // Welcome messages
  @override
  String get welcomeMessageKo => '안녕하세요! 저는 웨이비(WAVI) AI 비서입니다. \n\n일정 관리, 길찾기, 그리고 다양한 질문에 답변해드릴게요!\n\n무엇을 도와드릴까요?';

  @override
  String get welcomeMessageEn => 'Hello! I\'m WAVI, your AI assistant. \n\nI can help you with schedule management, navigation, and answer various questions!\n\nWhat can I help you with?';
  
  // Date picker
  @override
  String get selectDate => 'Select Date';

  @override
  String get selectTime => 'Select Time';
  
  // Notification empty states
  @override
  String get noUpcomingNotifications => 'No upcoming notifications';

  @override
  String get addScheduleWithAlerts => 'Add schedules and set up alerts';

  @override
  String get noNotificationHistory => 'No notification history';
  
  // Schedule screen
  @override
  String get noSchedulesOnDate => 'No schedules registered';

  @override
  String get selectDateToViewSchedules => 'Select a date to view schedules';

  @override
  String scheduleCount(int count) => '$count schedule${count != 1 ? 's' : ''}';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get deleteSchedule => 'Delete Schedule';

  @override
  String get deleteScheduleConfirm => 'Do you want to delete this schedule?';

  @override
  String get scheduleTitleField => 'Schedule Title';

  @override
  String get scheduleDescription => 'Schedule Description';

  @override
  String get dateAndTime => 'Date and Time';

  @override
  String get location => 'Location';

  @override
  String get selectLocation => 'Select Location';

  @override
  String get alarmSettings => 'Alarm Settings';

  @override
  String get alarmTime => 'Alarm Time';

  @override
  String get aiVoiceAlarm => 'AI Voice Alarm';

  @override
  String get aiVoiceAlarmDescription => 'AI assistant will notify you with voice announcement';

  @override
  String get add => 'Add';

  @override
  String get scheduleAdded => 'Schedule added';

  @override
  String get scheduleUpdated => 'Schedule updated';

  @override
  String get saveScheduleFailed => 'Failed to save schedule. Please try again.';

  @override
  String get newSchedule => 'New Schedule';

  @override
  String get editSchedule => 'Edit Schedule';

  @override
  String get enterTitle => 'Please enter a title';

  @override
  String get optional => '';

  @override
  String get required => ' *';
  
  // Map screen additional
  @override
  String get myLocation => 'My Location';
  
  @override
  String get scheduleContent => 'Schedule Content:';
  
  @override
  String get address => 'Address:';
  
  @override
  String get coordinates => 'Coordinates:';
  
  @override
  String get latitude => 'Latitude';
  
  @override
  String get longitude => 'Longitude';
  
  @override
  String get close => 'Close';
  
  @override
  String get currentLocationLoading => 'Getting location...';
  
  @override
  String get listView => 'List View';
  
  @override
  String get kakaoNavRequired => 'KakaoNav Required';
  
  @override
  String get kakaoNavInstallPrompt => 'KakaoNav app is required for navigation.\nInstall from App Store?';
  
  @override
  String get install => 'Install';
  
  @override
  String navigatingTo(String destination) => 'Starting navigation to $destination.';
  
  @override
  String get navigationFailed => 'Navigation failed';
  
  @override
  String get navigationError => 'An error occurred while starting navigation.';
  
  @override
  String get cannotOpenInstallPage => 'Cannot open installation page.';
  
  @override
  String get cannotGetCurrentLocation => 'Cannot get current location.';
  
  @override
  String dailySchedule(DateTime date) => DateFormat('MMM dd Schedule').format(date);
}