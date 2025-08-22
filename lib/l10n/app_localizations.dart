import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko')
  ];

  // Main navigation labels
  String get mapTab;
  String get scheduleTab;
  String get chatTab;
  String get notificationTab;
  String get profileTab;

  // Chat screen
  String get chatTitle;
  String get typeMessage;
  String get voiceInput;
  String get sendMessage;

  // Common
  String get cancel;
  String get confirm;
  String get settings;
  String get language;
  String get korean;
  String get english;
  
  // Map screen
  String get mapTitle;
  String get currentLocation;
  String get searchLocation;
  String get navigate;
  String get scheduleLocation;
  String get chooseTravelMode;
  String get howToTravel;
  String get walking;
  String get driving;
  
  // Schedule screen
  String get scheduleTitle;
  String get addSchedule;
  String get today;
  String get noSchedules;
  String get scheduleDetails;
  
  // Notification screen
  String get notificationTitle;
  String get noNotifications;
  String get markAsRead;
  
  // Chat screen additional
  String get clearChatHistory;
  String get apiConnectionTest;
  String get customRecommendations;
  String get touristInfo;
  String get trafficInfo;
  String get weatherCheck;
  String get deleteChatConfirm;
  String get cannotUndo;
  
  // Snackbar messages
  String get chatHistoryDeleted;
  String get scheduleDeleted;
  String get scheduleCreated;
  String get micPermissionRequired;
  String get voiceChatModeStarted;
  String get listeningToVoice;
  String get gettingCurrentLocation;
  String get goToSchedule;
  
  // Status texts
  String get scheduled;
  String get completed;
  String get overdue;
  String get upcomingNotifications;
  String get notificationHistory;
  
  // Notification time formats
  String get onTime;
  String minutesBefore(int minutes);
  String hoursBefore(int hours);
  String daysBefore(int days);
  
  // Welcome messages
  String get welcomeMessageKo;
  String get welcomeMessageEn;
  
  // Date picker
  String get selectDate;
  String get selectTime;
  
  // Notification empty states
  String get noUpcomingNotifications;
  String get addScheduleWithAlerts;
  String get noNotificationHistory;
  
  // Schedule screen
  String get noSchedulesOnDate;
  String get selectDateToViewSchedules;
  String scheduleCount(int count);
  String get edit;
  String get delete;
  String get deleteSchedule;
  String get deleteScheduleConfirm;
  String get scheduleTitleField;
  String get scheduleDescription;
  String get dateAndTime;
  String get location;
  String get selectLocation;
  String get alarmSettings;
  String get alarmTime;
  String get aiVoiceAlarm;
  String get aiVoiceAlarmDescription;
  String get add;
  String get scheduleAdded;
  String get scheduleUpdated;
  String get saveScheduleFailed;
  String get newSchedule;
  String get editSchedule;
  String get enterTitle;
  String get optional;
  String get required;
  
  // Map screen additional
  String get myLocation;
  String get scheduleContent;
  String get address;
  String get coordinates;
  String get latitude;
  String get longitude;
  String get close;
  String get currentLocationLoading;
  String get listView;
  String get kakaoNavRequired;
  String get kakaoNavInstallPrompt;
  String get install;
  String get navigationFailed;
  String get navigationError;
  String get cannotOpenInstallPage;
  String get cannotGetCurrentLocation;
  String dailySchedule(DateTime date);
  String navigatingTo(String destination);
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'ko': return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue on GitHub with a '
    'reproducible sample app and the gen-l10n configuration that was used.'
  );
}