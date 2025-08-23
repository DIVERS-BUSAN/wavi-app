import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:io' show Platform;
import '../widgets/custom_app_bar.dart';
import '../widgets/chat_bubble.dart';
import '../models/chat_message.dart';
import '../services/openai_service.dart';
import '../services/schedule_service.dart';
import '../models/schedule.dart';
import '../providers/language_provider.dart';
import '../l10n/app_localizations.dart';
import '../utils/toast_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import '../services/tourism_service.dart';
import '../services/schedule_generator_service.dart';
import '../services/visit_duration_service.dart';
import '../widgets/location_selection_dialog.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final OpenAIService _openAIService = OpenAIService();
  final ScheduleService _scheduleService = ScheduleService();
  final TourismService _tourismService = TourismService();
  final ScheduleGeneratorService _scheduleGeneratorService = ScheduleGeneratorService();

  static const String _messagesKey = 'chat_messages';

  late FlutterTts _flutterTts;
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isTyping = false;
  bool _speechEnabled = false;
  bool _isTtsPlaying = false;
  bool _voiceChatMode = false;
  String _lastWords = '';

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
    _initializeTts();
    _loadChatHistory();
  }

  void _initializeSpeech() async {
    try {
      _speech = stt.SpeechToText();
      _speechEnabled = await _speech.initialize(
        onError: (val) {
          print('Speech Error: $val');
          setState(() {
            _isListening = false;
            _voiceChatMode = false;
          });
        },
        onStatus: (val) {
          print('Speech Status: $val');
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        debugLogging: true,
      );
      if (mounted) {
        setState(() {});
      }
      print('Speech enabled: $_speechEnabled');
    } catch (e) {
      print('Speech initialization error: $e');
      setState(() => _speechEnabled = false);
    }
  }

  Future<void> _setTtsLanguage(bool isEnglish) async {
    try {
      if (isEnglish) {
        // 영어 TTS 설정
        await _flutterTts.setLanguage("en-US");

        // 사용 가능한 음성 목록에서 영어 음성 찾기
        var voices = await _flutterTts.getVoices;
        var englishVoices = voices
            .where((voice) => voice["locale"].toString().startsWith("en"))
            .toList();

        if (englishVoices.isNotEmpty) {
          await _flutterTts.setVoice({
            "name": englishVoices.first["name"],
            "locale": englishVoices.first["locale"],
          });
        }
      } else {
        // 한국어 TTS 설정
        await _flutterTts.setLanguage("ko-KR");

        // 사용 가능한 음성 목록에서 한국어 음성 찾기 (Yuna 우선)
        var voices = await _flutterTts.getVoices;
        var koreanVoices = voices
            .where((voice) => voice["locale"].toString().startsWith("ko"))
            .toList();

        // Yuna 음성을 우선적으로 찾기
        var yunaVoice = koreanVoices.firstWhere(
          (voice) => voice["name"].toString().contains("Yuna"),
          orElse: () => koreanVoices.isNotEmpty ? koreanVoices.first : null,
        );

        if (yunaVoice != null) {
          await _flutterTts.setVoice({
            "name": yunaVoice["name"],
            "locale": yunaVoice["locale"],
          });
        }
      }

      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
    } catch (e) {
      print("TTS language setting error: $e");
    }
  }

  void _initializeTts() async {
    _flutterTts = FlutterTts();

    try {
      // 사용 가능한 음성 목록 확인
      var voices = await _flutterTts.getVoices;

      // 한국어 음성 찾기 (Yuna 우선)
      var koreanVoices = voices
          .where((voice) => voice["locale"].toString().startsWith("ko"))
          .toList();

      // Yuna 음성을 우선적으로 찾기
      var yunaVoice = koreanVoices.firstWhere(
        (voice) => voice["name"].toString().contains("Yuna"),
        orElse: () => koreanVoices.isNotEmpty ? koreanVoices.first : null,
      );

      // iOS 전용 설정 (macOS에서는 setSharedInstance가 지원되지 않음)
      if (Platform.isIOS) {
        try {
          await _flutterTts.setSharedInstance(true);
          await _flutterTts.setIosAudioCategory(
            IosTextToSpeechAudioCategory.playback,
            [
              IosTextToSpeechAudioCategoryOptions.allowBluetooth,
              IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
              IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            ],
            IosTextToSpeechAudioMode.voicePrompt,
          );
        } catch (e) {
          print("iOS specific settings failed: $e");
        }
      }

      // 한국어 언어 설정
      await _flutterTts.setLanguage("ko-KR");

      // 최적의 한국어 음성 설정
      if (yunaVoice != null) {
        await _flutterTts.setVoice({
          "name": yunaVoice["name"],
          "locale": yunaVoice["locale"],
        });
        print("Set Korean voice: ${yunaVoice["name"]}");
      }

      // 음성 매개변수 설정
      await _flutterTts.setSpeechRate(0.5); // 자연스러운 속도
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      // TTS 에러 핸들링
      _flutterTts.setErrorHandler((msg) {
        print("TTS Error: $msg");
      });

      // TTS 완료 핸들링
      _flutterTts.setCompletionHandler(() {
        print("TTS Completed");
        setState(() => _isTtsPlaying = false);

        // 음성 대화 모드에서 TTS가 끝나면 자동으로 다시 음성 인식 시작
        if (_voiceChatMode && !_isListening && _speechEnabled) {
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (_voiceChatMode && !_isListening) {
              _startListening();
            }
          });
        }
      });

      // TTS 시작 핸들링
      _flutterTts.setStartHandler(() {
        print("TTS Started");
        setState(() => _isTtsPlaying = true);
      });

      print("TTS initialized successfully with Korean voice");
    } catch (e) {
      print("TTS initialization error: $e");
    }
  }

  Future<void> _loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = prefs.getStringList(_messagesKey) ?? [];

      if (messagesJson.isEmpty) {
        // 첫 실행시 환영 메시지 추가
        _addWelcomeMessage();
      } else {
        // 저장된 채팅 기록 불러오기
        final loadedMessages = messagesJson
            .map((json) => ChatMessage.fromJson(jsonDecode(json)))
            .toList();

        setState(() {
          _messages.addAll(loadedMessages);
        });
      }
    } catch (e) {
      print('채팅 기록 불러오기 실패: $e');
      _addWelcomeMessage();
    }
  }

  void _addWelcomeMessage() {
    // 환영 메시지는 동적으로 생성하므로 저장하지 않음
    // 채팅 화면에서 build 시점에 동적으로 추가됨
  }

  Future<void> _saveChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson = _messages
          .take(50) // 최근 50개 메시지만 저장
          .map((message) => jsonEncode(message.toJson()))
          .toList();

      await prefs.setStringList(_messagesKey, messagesJson);
    } catch (e) {
      print('채팅 기록 저장 실패: $e');
    }
  }

  void _toggleListening() async {
    if (!_speechEnabled) {
      final l10n = AppLocalizations.of(context);
      ToastUtils.showError(l10n.micPermissionRequired, context: context);
      return;
    }

    if (!_isListening && !_isTtsPlaying) {
      // 음성 대화 모드 시작
      setState(() => _voiceChatMode = true);
      _startListening();
    } else if (_isListening) {
      _stopListening();
    } else if (_voiceChatMode) {
      // 음성 대화 모드 종료
      setState(() => _voiceChatMode = false);
      if (_isTtsPlaying) {
        await _flutterTts.stop();
      }
    }
  }

  void _startListening() async {
    try {
      setState(() => _isListening = true);

      // 현재 언어 설정에 맞는 locale 설정 (안전하게)
      String localeId = 'ko_KR';
      try {
        final languageProvider = Provider.of<LanguageProvider>(
          context,
          listen: false,
        );
        localeId = languageProvider.isEnglish ? 'en_US' : 'ko_KR';
      } catch (e) {
        print('LanguageProvider 접근 실패: $e');
        // 기본값으로 한국어 사용
      }

      await _speech.listen(
        onResult: (val) {
          setState(() {
            _lastWords = val.recognizedWords;
            _textController.text = _lastWords;
          });

          // 음성 인식이 완료되면 자동으로 메시지 전송
          if (val.finalResult && _lastWords.isNotEmpty) {
            Future.delayed(const Duration(milliseconds: 500), () {
              _sendMessage(_lastWords);
              setState(() {
                _isListening = false;
                _lastWords = '';
              });
            });
          }
        },
        localeId: localeId,
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
      );

      final l10n = AppLocalizations.of(context);
      if (_voiceChatMode) {
        ToastUtils.showInfo(l10n.voiceChatModeStarted, context: context);
      } else {
        ToastUtils.showInfo(l10n.listeningToVoice, context: context);
      }
    } catch (e) {
      print('Start listening error: $e');
      setState(() => _isListening = false);
    }
  }

  void _stopListening() async {
    try {
      await _speech.stop();
      setState(() => _isListening = false);

      // 수동으로 중지했을 때도 인식된 텍스트가 있으면 전송
      if (_lastWords.isNotEmpty) {
        _sendMessage(_lastWords);
        setState(() => _lastWords = '');
      }
    } catch (e) {
      print('Stop listening error: $e');
      setState(() => _isListening = false);
    }
  }

  String removeEmojis(String input) {
    final emojiRegex = RegExp(
      r'[\u{1F600}-\u{1F64F}' // Emoticons
      r'\u{1F300}-\u{1F5FF}' // Symbols & pictographs
      r'\u{1F680}-\u{1F6FF}' // Transport & map
      r'\u{2600}-\u{26FF}' // Misc symbols
      r'\u{2700}-\u{27BF}]', // Dingbats
      unicode: true,
    );
    return input.replaceAll(emojiRegex, '');
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMessage = ChatMessage(content: text, type: MessageType.user);

    setState(() {
      _messages.add(userMessage);
      _textController.clear();
      _isTyping = true;
    });

    _scrollToBottom();
    _saveChatHistory();

    if (_isScheduleRequest(text)) {
      await _handleScheduleCreation(text);
      return;
    }
    try {
      // OpenAI API 호출
      // 현재 언어 설정 가져오기 (안전하게)
      LanguageProvider? languageProvider;
      bool isEnglish = false;
      try {
        languageProvider = Provider.of<LanguageProvider>(
          context,
          listen: false,
        );
        isEnglish = languageProvider.isEnglish;
      } catch (e) {
        print('LanguageProvider 접근 실패: $e');
        // 기본값으로 한국어 사용
        isEnglish = false;
      }
      final intent = await _openAIService.classifyIntent(text);
      ChatMessage? response;

      if (intent == "tourism") {
        // 2️⃣ 관광 질문이면 RAG 서버에서 context 가져오기
        final context = await _tourismService.fetchTourismContext(text);
        print("intent가 tourism임.");

        // 3️⃣ context + 질문을 GPT에 전달
        response = await _openAIService.sendMessage([
          ChatMessage(
            content:
                "사용자 질문: $text\n\n참조 데이터: $context\n\n이 정보를 바탕으로 친절하게 답변해줘.",
            type: MessageType.user,
          ),
        ]);
      } else {
        // 4️⃣ 일반 대화면 기존 방식
        response = await _openAIService.sendMessage(
          _messages,
          isEnglish: isEnglish,
        );
      }

      if (response != null) {
        setState(() {
          _messages.add(response!);
          _isTyping = false;
        });

        // TTS로 응답 읽기 (언어에 맞는 TTS 설정)
        await _setTtsLanguage(isEnglish);
        final cleanText = removeEmojis(response.content);
        var result = await _flutterTts.speak(cleanText);
        if (result == 1) {
          print("TTS Speaking: ${response.content}");
        } else {
          print("TTS Failed to speak");
        }
      } else {
        final errorMsg = isEnglish
            ? 'Unable to receive AI response.'
            : 'AI 응답을 받을 수 없습니다.';
        throw Exception(errorMsg);
      }
    } catch (e) {
      print('OpenAI API 오류: $e');

      final errorMessage = ChatMessage(
        content:
            '죄송합니다. 현재 서버에 문제가 있어 응답할 수 없습니다. 잠시 후 다시 시도해주세요.\n\n오류: ${e.toString()}',
        type: MessageType.assistant,
      );

      setState(() {
        _messages.add(errorMessage);
        _isTyping = false;
      });

      await _flutterTts.speak('죄송합니다. 현재 서버에 문제가 있어 응답할 수 없습니다.');
    }

    _scrollToBottom();
    _saveChatHistory();
  }

  // 일정 생성 요청인지 확인
  bool _isScheduleRequest(String text) {
    final scheduleKeywords = [
      '일정',
      '약속',
      '미팅',
      '회의',
      '만남',
      '스케줄',
      '등록',
      '생성',
      '추가',
      '만들어',
      '예약',
      '내일',
      '오늘',
      '모레',
      '다음주',
      '이번주',
      '시간',
      '날짜',
      '알림',
      '리마인더',
      '여행',
      '관광',
      '여행일정',
      '관광일정',
      '여행계획',
      '일정짜',
      '계획짜',
      '코스',
      '여행코스',
      '관광코스',
      '투어',
      '당일치기',
      '부산',
    ];

    final lowerText = text.toLowerCase();
    return scheduleKeywords.any((keyword) => lowerText.contains(keyword));
  }

  // 일정 생성 처리
  Future<void> _handleScheduleCreation(String text) async {
    try {
      // 여행 일정 생성 요청인지 확인
      if (_isTravelItineraryRequest(text)) {
        await _handleTravelItineraryCreation(text);
        return;
      }

      // 기존 단일 일정 생성 로직
      // OpenAI를 통해 일정 정보 추출
      final extractionPrompt =
          '''
다음 텍스트에서 일정 정보를 추출해주세요:
"$text"

다음 JSON 형식으로 정확히 응답해주세요:
{
  "title": "일정 제목",
  "description": "일정 설명 (없으면 null)",
  "datetime": "YYYY-MM-DD HH:mm 형식",
  "location": "구체적인 장소명 (예: 스타벅스 강남역점, 코엑스, 홍대입구역 등. 없으면 null)",
  "hasAlarm": true/false
}

중요한 규칙:
1. datetime은 반드시 "YYYY-MM-DD HH:mm" 형식으로 작성하세요
2. location은 가능한 구체적이고 검색 가능한 장소명으로 작성하세요
3. "카페", "식당" 같은 일반적인 단어보다는 "스타벅스", "맥도날드" 같은 구체적인 이름을 선호하세요
4. 응답은 오직 JSON 형식만 포함하고 다른 텍스트는 포함하지 마세요

현재 시간: ${DateTime.now().toString()}
오늘 날짜: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}
''';

      final extractionMessages = [
        ChatMessage(content: extractionPrompt, type: MessageType.user),
      ];

      final response = await _openAIService.sendMessage(extractionMessages);

      if (response != null) {
        await _processScheduleData(response.content, text);
      } else {
        throw Exception('일정 정보를 추출할 수 없습니다.');
      }
    } catch (e) {
      print('일정 생성 오류: $e');
      await _respondWithError('일정 생성 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  // 여행 일정 생성 요청인지 확인
  bool _isTravelItineraryRequest(String text) {
    final travelKeywords = [
      '여행일정',
      '관광일정',
      '여행계획',
      '일정짜',
      '계획짜',
      '여행코스',
      '관광코스',
      '투어',
      '당일치기',
      '여행',
      '관광',
    ];

    final lowerText = text.toLowerCase();
    return travelKeywords.any((keyword) => lowerText.contains(keyword)) &&
           (lowerText.contains('짜') || lowerText.contains('만들') || 
            lowerText.contains('계획') || lowerText.contains('추천'));
  }

  // 여행 일정 자동 생성 처리
  Future<void> _handleTravelItineraryCreation(String text) async {
    try {
      setState(() => _isTyping = true);

      // AI에게 여행 정보 추출 요청
      final extractionPrompt = '''
다음 사용자 요청에서 여행 정보를 정확히 추출해주세요:
"$text"

다음 JSON 형식으로 응답해주세요:
{
  "destination": "여행 목적지 (예: 부산, 서울, 제주)",
  "date": "여행 시작 날짜 (YYYY-MM-DD 형식)",
  "duration": "여행 기간 (일 단위, 당일치기면 1)",
  "startTime": "시작 시간 (HH:mm 형식, 기본값: 09:00)",
  "endTime": "종료 시간 (HH:mm 형식, 기본값: 18:00)",
  "interests": ["관심사나 선호하는 장소 유형들 배열"]
}

중요한 규칙:
1. "오늘"이면 오늘 날짜, "내일"이면 내일 날짜, "모레"면 모레 날짜로 정확히 설정
2. "당일치기", "하루", "일일"이 포함되면 duration은 1로 설정
3. 특별한 언급이 없으면 당일치기(duration: 1)로 처리

현재 시간: ${DateTime.now()}
오늘 날짜: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}
내일 날짜: ${DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 1)))}
모레 날짜: ${DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 2)))}
''';

      final response = await _openAIService.sendMessage([
        ChatMessage(content: extractionPrompt, type: MessageType.user),
      ]);

      if (response != null) {
        await _processTravelItineraryData(response.content, text);
      } else {
        throw Exception('여행 정보를 추출할 수 없습니다.');
      }
    } catch (e) {
      print('여행 일정 생성 오류: $e');
      await _respondWithError('여행 일정 생성 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  // 여행 일정 데이터 처리
  Future<void> _processTravelItineraryData(String responseContent, String originalText) async {
    try {
      // JSON 파싱
      final jsonStart = responseContent.indexOf('{');
      final jsonEnd = responseContent.lastIndexOf('}') + 1;

      if (jsonStart == -1 || jsonEnd <= jsonStart) {
        throw Exception('유효한 JSON 형식을 찾을 수 없습니다.');
      }

      final jsonString = responseContent.substring(jsonStart, jsonEnd);
      final travelData = jsonDecode(jsonString);

      // 여행 정보 추출
      final destination = travelData['destination'] ?? '서울';
      final dateStr = travelData['date'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
      final durationValue = travelData['duration'];
      int duration = 1;
      
      // duration을 안전하게 정수로 변환
      if (durationValue != null) {
        if (durationValue is int) {
          duration = durationValue;
        } else if (durationValue is String) {
          duration = int.tryParse(durationValue) ?? 1;
        }
      }
      
      final startTimeStr = travelData['startTime'] ?? '09:00';
      final endTimeStr = travelData['endTime'] ?? '18:00';
      final interests = List<String>.from(travelData['interests'] ?? []);

      // 날짜와 시간 파싱
      final startDate = DateTime.parse(dateStr);
      final startTimeParts = startTimeStr.split(':');
      final endTimeParts = endTimeStr.split(':');
      
      final startTime = TimeOfDay(
        hour: int.parse(startTimeParts[0]),
        minute: int.parse(startTimeParts[1]),
      );
      
      final endTime = TimeOfDay(
        hour: int.parse(endTimeParts[0]),
        minute: int.parse(endTimeParts[1]),
      );

      // 진행 상황 메시지
      final durationText = duration == 1 ? '당일치기' : '${duration}일 여행';
      final progressMessage = ChatMessage(
        content: '🗺️ $destination $durationText 일정을 생성하고 있습니다...\n\n📅 날짜: ${DateFormat('yyyy년 MM월 dd일').format(startDate)} ($durationText)\n⏰ 시간: ${startTimeStr} - ${endTimeStr}\n📍 관심사: ${interests.join(', ')}',
        type: MessageType.assistant,
      );

      setState(() {
        _messages.add(progressMessage);
        _isTyping = false;
      });
      _scrollToBottom();

      // 목적지 기반으로 인기 장소 검색 (여러 검색어로 시도)
      List<Location> places = [];
      
      final searchQueries = [
        '$destination 관광지',
        '$destination 맛집', 
        '$destination 여행',
        '$destination',
        '$destination 명소',
      ];
      
      for (String query in searchQueries) {
        final searchResults = await _searchKakaoPlaces(query, limit: 5);
        places.addAll(searchResults);
        if (places.length >= 10) break;
      }
      
      // 중복 제거
      final uniquePlaces = <String, Location>{};
      for (final place in places) {
        uniquePlaces[place.name] = place;
      }
      places = uniquePlaces.values.toList();

      if (places.isEmpty) {
        // 기본 장소들로 대체
        places = _getDefaultPlacesForDestination(destination);
        if (places.isEmpty) {
          throw Exception('$destination의 관광 정보를 찾을 수 없습니다.');
        }
      }

      // PlaceCandidate 목록 생성
      List<PlaceCandidate> candidates = [];
      for (int i = 0; i < places.length && i < 6; i++) {
        final place = places[i];
        candidates.add(PlaceCandidate(
          title: place.name,
          description: '$destination 여행',
          location: place,
          category: _getCategoryFromPlace(place.name),
          priority: 10 - i, // 순서대로 우선순위 부여
        ));
      }

      setState(() => _isTyping = true);

      // 일정 생성
      final schedules = await _scheduleGeneratorService.generateTravelItinerary(
        places: candidates,
        startDate: startDate,
        startTime: startTime,
        endTime: endTime,
        maxPlacesPerDay: 5,
        duration: duration, // 여행 기간 적용
      );

      if (schedules.isNotEmpty) {
        // 생성된 일정 저장
        final success = await _scheduleGeneratorService.saveGeneratedSchedules(schedules);

        if (success) {
          // 상세한 성공 메시지 생성
          final durationText = duration == 1 ? '당일치기' : '${duration}일';
          String scheduleText = '✅ $destination $durationText 여행 일정이 생성되었습니다!\n\n';
          
          DateTime? currentDate;
          Location? previousLocation;
          
          for (int i = 0; i < schedules.length; i++) {
            final schedule = schedules[i];
            
            // 날짜가 바뀌면 날짜 표시
            if (currentDate == null || 
                currentDate.day != schedule.dateTime.day ||
                currentDate.month != schedule.dateTime.month) {
              currentDate = schedule.dateTime;
              scheduleText += '📅 ${DateFormat('MM월 dd일 (E)', 'ko_KR').format(currentDate)}\n';
              scheduleText += '\n';
            }
            
            // 이동시간 계산 및 표시
            if (previousLocation != null && schedule.location != null) {
              try {
                final routeInfo = await _scheduleGeneratorService.getRouteInfo(
                  originLat: previousLocation.latitude!,
                  originLng: previousLocation.longitude!,
                  destLat: schedule.location!.latitude!,
                  destLng: schedule.location!.longitude!,
                );
                
                if (routeInfo != null) {
                  scheduleText += '🚗 이동시간: ${routeInfo.durationInMinutes}분 (${routeInfo.distanceInKm.toStringAsFixed(1)}km)\n';
                  scheduleText += '\n';
                }
              } catch (e) {
                scheduleText += '🚗 이동시간: 약 15분\n';
                scheduleText += '\n';
              }
            }
            
            // 일정 시간
            scheduleText += '⏰ ${DateFormat('HH:mm').format(schedule.dateTime)} ${schedule.title}\n';
          
            
            // 체류시간 계산 및 표시
            final category = _getCategoryFromPlace(schedule.title);
            final visitDuration = VisitDurationService.calculateVisitDuration(
              category: category,
              visitTime: schedule.dateTime,
            );
            final endTime = schedule.dateTime.add(Duration(minutes: visitDuration));
            
            scheduleText += '⌚ 체류시간: ${visitDuration}분 (${DateFormat('HH:mm').format(endTime)}까지)\n';
            scheduleText += '\n';
            
            previousLocation = schedule.location;
          }

          // 총 소요시간 및 요약
          if (schedules.isNotEmpty) {
            final firstSchedule = schedules.first;
            final lastSchedule = schedules.last;
            final totalDuration = lastSchedule.dateTime.difference(firstSchedule.dateTime);
        
            scheduleText += '📊 여행 요약\n';
            scheduleText += '• 총 ${schedules.length}개 장소 방문\n';
            scheduleText += '• 여행 시간: ${DateFormat('HH:mm').format(firstSchedule.dateTime)} - ${DateFormat('HH:mm').format(lastSchedule.dateTime)}\n';
            scheduleText += '• 소요 시간: ${totalDuration.inHours}시간 ${totalDuration.inMinutes % 60}분\n\n';
          }

          scheduleText += '🗺️ 지도 화면에서 일정을 확인하고 길찾기를 이용해보세요!';

          final successMessage = ChatMessage(
            content: scheduleText,
            type: MessageType.assistant,
          );

          setState(() {
            _messages.add(successMessage);
            _isTyping = false;
          });

          // TTS로 성공 메시지 읽기
          await _flutterTts.speak('$destination 여행 일정을 성공적으로 생성했습니다. 지도 화면에서 확인해보세요.');
        } else {
          throw Exception('일정 저장에 실패했습니다.');
        }
      } else {
        throw Exception('일정을 생성할 수 없습니다.');
      }
    } catch (e) {
      print('여행 일정 처리 오류: $e');
      await _respondWithError('여행 일정 생성 중 오류가 발생했습니다: ${e.toString()}');
    }

    setState(() => _isTyping = false);
    _scrollToBottom();
    _saveChatHistory();
  }

  // 장소명에서 카테고리 추정
  String _getCategoryFromPlace(String placeName) {
    final lowerName = placeName.toLowerCase();
    
    if (lowerName.contains('박물관') || lowerName.contains('미술관')) {
      return '박물관';
    } else if (lowerName.contains('해변') || lowerName.contains('바다')) {
      return '해변';
    } else if (lowerName.contains('산') || lowerName.contains('등산')) {
      return '산';
    } else if (lowerName.contains('공원') || lowerName.contains('정원')) {
      return '공원';
    } else if (lowerName.contains('카페') || lowerName.contains('스타벅스')) {
      return '카페';
    } else if (lowerName.contains('식당') || lowerName.contains('맛집')) {
      return '음식점';
    } else if (lowerName.contains('시장') || lowerName.contains('쇼핑')) {
      return '시장';
    } else {
      return '관광명소';
    }
  }

  // 목적지별 기본 장소 목록 제공
  List<Location> _getDefaultPlacesForDestination(String destination) {
    final Map<String, List<Map<String, dynamic>>> defaultPlaces = {
      '부산': [
        {'name': '해운대해수욕장', 'address': '부산 해운대구 우동', 'lat': 35.1587, 'lng': 129.1603},
        {'name': '광안리해수욕장', 'address': '부산 수영구 광안2동', 'lat': 35.1532, 'lng': 129.1183},
        {'name': '자갈치시장', 'address': '부산 중구 남포동4가', 'lat': 35.0966, 'lng': 129.0305},
        {'name': '감천문화마을', 'address': '부산 사하구 감천2동', 'lat': 35.0976, 'lng': 129.0114},
        {'name': '태종대', 'address': '부산 영도구 전망로', 'lat': 35.0513, 'lng': 129.0865},
        {'name': '부산타워', 'address': '부산 중구 용두산길', 'lat': 35.1014, 'lng': 129.0325},
      ],
    };

    final lowerDestination = destination.toLowerCase();
    String? key;
    
    for (String dest in defaultPlaces.keys) {
      if (lowerDestination.contains(dest)) {
        key = dest;
        break;
      }
    }

    if (key != null) {
      return defaultPlaces[key]!.map((place) => Location(
        name: place['name'],
        address: place['address'],
        latitude: place['lat'],
        longitude: place['lng'],
      )).toList();
    }

    return [];
  }

  // 일정 데이터 처리
  Future<void> _processScheduleData(
    String responseContent,
    String originalText,
  ) async {
    try {
      // JSON 응답에서 일정 정보 파싱
      final jsonStart = responseContent.indexOf('{');
      final jsonEnd = responseContent.lastIndexOf('}') + 1;

      if (jsonStart == -1 || jsonEnd <= jsonStart) {
        throw Exception('유효한 JSON 형식을 찾을 수 없습니다.');
      }

      final jsonString = responseContent.substring(jsonStart, jsonEnd);
      print('추출된 JSON: $jsonString');

      final scheduleData = jsonDecode(jsonString);
      print('파싱된 일정 데이터: $scheduleData');

      // 일정 생성
      final title = scheduleData['title'] ?? '새 일정';
      final description = scheduleData['description'];
      final datetimeStr = scheduleData['datetime'];
      final locationName = scheduleData['location'];
      final hasAlarm = scheduleData['hasAlarm'] ?? false;

      print('추출된 정보 - 제목: $title, 날짜: $datetimeStr, 장소: $locationName');

      if (datetimeStr == null) {
        throw Exception('날짜와 시간 정보가 필요합니다.');
      }

      final dateTime = DateTime.parse(datetimeStr.replaceAll(' ', 'T'));

      // Location 객체 생성 - 실제 장소 검색
      Location? location;
      if (locationName != null && locationName.isNotEmpty) {
        print('장소 검색 시작: $locationName');
        final searchResults = await _searchKakaoPlaces(locationName, limit: 5);
        
        if (searchResults.isNotEmpty) {
          // 여러 위치가 검색된 경우 사용자에게 선택하게 함
          if (searchResults.length > 1) {
            location = await _showLocationSelectionDialog(searchResults, locationName);
          } else {
            // 하나만 검색된 경우 바로 사용
            location = searchResults.first;
          }
          
          if (location != null) {
            print(
              '선택된 장소: ${location.name}, 위도: ${location.latitude}, 경도: ${location.longitude}',
            );
          }
        } else {
          print('장소 검색 실패, 이름만 저장: $locationName');
          // 장소를 찾지 못한 경우 이름만 저장
          location = Location(name: locationName);
        }
      }

      // 일정 저장
      final success = await _scheduleService.addSchedule(
        title: title,
        description: description,
        dateTime: dateTime,
        location: location,
        isAlarmEnabled: hasAlarm,
        alarmDateTime: hasAlarm
            ? dateTime.subtract(const Duration(minutes: 10))
            : null,
        color: ScheduleColor.blue,
      );

      if (success) {
        final successMessage = ChatMessage(
          content:
              '✅ 일정이 성공적으로 생성되었습니다!\n\n'
              '📋 제목: $title\n'
              '📅 날짜: ${DateFormat('yyyy년 MM월 dd일 HH시 mm분').format(dateTime)}\n'
              '${location != null ? '📍 장소: ${location.name}\n' : ''}'
              '${location?.address != null ? '   주소: ${location!.address}\n' : ''}'
              '${description != null ? '📝 설명: $description\n' : ''}'
              '${hasAlarm ? '⏰ 알림: 10분 전' : ''}\n\n'
              '💡 일정 화면이나 지도 화면으로 이동하시면 등록된 일정을 확인하실 수 있습니다.',
          type: MessageType.assistant,
        );

        setState(() {
          _messages.add(successMessage);
          _isTyping = false;
        });

        await _flutterTts.speak(
          '일정이 성공적으로 생성되었습니다. $title이 ${DateFormat('MM월 dd일 HH시 mm분').format(dateTime)}에 등록되었습니다.',
        );
      } else {
        throw Exception('일정 저장에 실패했습니다.');
      }
    } catch (e) {
      print('일정 데이터 처리 오류: $e');
      await _respondWithError('일정 정보를 처리하는 중 오류가 발생했습니다. 다시 시도해주세요.');
    }

    _scrollToBottom();
    _saveChatHistory();
  }

  // 위치 선택 다이얼로그 표시
  Future<Location?> _showLocationSelectionDialog(
    List<Location> locations,
    String originalLocationName,
  ) async {
    if (!mounted) return null;
    
    return await showDialog<Location?>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return LocationSelectionDialog(
          locationOptions: locations,
          originalLocationName: originalLocationName,
          onLocationSelected: (Location? selectedLocation) {
            // 이 콜백은 더 이상 사용하지 않음 - pop으로 직접 처리
          },
        );
      },
    );
  }

  // 카카오 장소 검색 (여러 결과 반환)
  Future<List<Location>> _searchKakaoPlaces(String query, {int limit = 5}) async {
    final List<Location> results = [];
    
    try {
      final String restApiKey = dotenv.env['KAKAO_REST_API_KEY'] ?? '';
      if (restApiKey.isEmpty) {
        print('카카오 REST API 키가 설정되지 않음');
        return results;
      }

      final String url =
          'https://dapi.kakao.com/v2/local/search/keyword.json?query=${Uri.encodeComponent(query)}&size=$limit';
      print('카카오 API 요청 URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'KakaoAK $restApiKey'},
      );

      print('카카오 API 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(
          utf8.decode(response.bodyBytes),
        );
        final List<dynamic> documents = data['documents'];

        print('검색 결과 개수: ${documents.length}');

        for (final place in documents) {
          final location = Location(
            name: place['place_name'],
            address: place['road_address_name'] ?? place['address_name'],
            latitude: double.tryParse(place['y'].toString()),
            longitude: double.tryParse(place['x'].toString()),
          );
          
          results.add(location);
          print(
            '검색된 장소: ${location.name}, ${location.address}, ${location.latitude}, ${location.longitude}',
          );
        }
      } else {
        print('카카오 API 오류: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      print('장소 검색 중 오류: $e');
    }

    return results;
  }

  // 단일 카카오 장소 검색 (기존 호환성 유지)
  Future<Location?> _searchKakaoPlace(String query) async {
    try {
      final String restApiKey = dotenv.env['KAKAO_REST_API_KEY'] ?? '';
      if (restApiKey.isEmpty) {
        print('카카오 REST API 키가 설정되지 않음');
        return null;
      }

      final String url =
          'https://dapi.kakao.com/v2/local/search/keyword.json?query=${Uri.encodeComponent(query)}&size=1';
      print('카카오 API 요청 URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'KakaoAK $restApiKey'},
      );

      print('카카오 API 응답 상태: ${response.statusCode}');

      if (response.statusCode == 200) {
        final results = await _searchKakaoPlaces(query, limit: 1);
        return results.isNotEmpty ? results.first : null;
      } else {
        print('카카오 API 오류: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      print('카카오 장소 검색 오류: $e');
    }
    return null;
  }

  // 오류 응답
  Future<void> _respondWithError(String errorMessage) async {
    final errorResponse = ChatMessage(
      content: '❌ $errorMessage',
      type: MessageType.assistant,
    );

    setState(() {
      _messages.add(errorResponse);
      _isTyping = false;
    });

    await _flutterTts.speak(errorMessage);
    _scrollToBottom();
    _saveChatHistory();
  }

  Future<void> _clearChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_messagesKey);

      setState(() {
        _messages.clear();
      });

      _addWelcomeMessage();

      final l10n = AppLocalizations.of(context);
      ToastUtils.showSuccess(l10n.chatHistoryDeleted, context: context);
    } catch (e) {
      print('채팅 기록 삭제 실패: $e');
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _flutterTts.stop();
    if (_speechEnabled) {
      _speech.stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Image.asset('assets/images/wavi-logo.png', height: 25),
            ),
            const SizedBox(width: 10),
            Text(
              l10n.chatTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF041E42).withOpacity(0.95),
                const Color(0xFF041E42).withOpacity(0.85),
                const Color(0xFF0A3D62).withOpacity(0.9),
              ],
            ),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              switch (value) {
                case 'clear':
                  _showClearHistoryDialog();
                  break;
                case 'api_test':
                  _testApiConnection();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline),
                    const SizedBox(width: 8),
                    Text(l10n.clearChatHistory),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'api_test',
                child: Row(
                  children: [
                    const Icon(Icons.wifi_protected_setup),
                    const SizedBox(width: 8),
                    Text(l10n.apiConnectionTest),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.blue[50]!.withOpacity(0.3), Colors.white],
                  ),
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 10, bottom: 10),
                  itemCount:
                      _messages.length +
                      1 +
                      (_isTyping ? 1 : 0), // +1 for welcome message
                  itemBuilder: (context, index) {
                    // 환영 메시지 (항상 첫 번째)
                    if (index == 0) {
                      final languageProvider = Provider.of<LanguageProvider>(
                        context,
                      );
                      final welcomeContent = languageProvider.isEnglish
                          ? 'Hello! I\'m WAVI, your AI assistant. \n\nI can help you with schedule management, navigation, and answer various questions!\n\nWhat can I help you with?'
                          : '안녕하세요! 저는 웨이비(WAVI) AI 비서입니다. \n\n일정 관리, 길찾기, 그리고 다양한 질문에 답변해드릴게요!\n\n무엇을 도와드릴까요?';

                      final welcomeMessage = ChatMessage(
                        content: welcomeContent,
                        type: MessageType.assistant,
                      );

                      return ChatBubble(message: welcomeMessage);
                    }

                    // 타이핑 인디케이터
                    if (index == _messages.length + 1 && _isTyping) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: const Color(0xFF041E42),
                              child: Image.asset(
                                'assets/images/wavi-logo-white.png',
                                width: 25,
                                height: 25,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const SizedBox(
                                width: 40,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF041E42),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // 실제 채팅 메시지들
                    return ChatBubble(message: _messages[index - 1]);
                  },
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: (_isListening || _voiceChatMode)
                              ? Colors.red.withOpacity(0.1)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: (_isListening || _voiceChatMode)
                              ? Border.all(color: Colors.red, width: 2)
                              : null,
                        ),
                        child: IconButton(
                          icon: Icon(
                            _voiceChatMode
                                ? (_isListening ? Icons.mic : Icons.stop)
                                : _isListening
                                ? Icons.mic
                                : Icons.mic_none,
                            color: _voiceChatMode
                                ? Colors.red
                                : _isListening
                                ? Colors.red
                                : _speechEnabled
                                ? const Color(0xFF041E42)
                                : Colors.grey,
                            size: 28,
                          ),
                          onPressed: _speechEnabled ? _toggleListening : null,
                          tooltip: _voiceChatMode
                              ? '음성 대화 모드 종료'
                              : _isListening
                              ? '음성 인식 중지'
                              : _speechEnabled
                              ? '음성 대화 모드 시작'
                              : '음성 인식 비활성화',
                        ),
                      ),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: TextField(
                            controller: _textController,
                            decoration: InputDecoration(
                              hintText: l10n.typeMessage,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: _sendMessage,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF041E42),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () => _sendMessage(_textController.text),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.only(
                top: 8,
                bottom: 30, // 플로팅 액션 버튼을 위한 여백 추가
                left: 8,
                right: 8,
              ),
              color: Colors.grey[50],
              child: Row(
                children: [
                  Expanded(
                    child: _buildQuickAction(
                      Icons.tips_and_updates,
                      l10n.customRecommendations,
                    ),
                  ),
                  Expanded(
                    child: _buildQuickAction(
                      Icons.directions_car,
                      l10n.touristInfo,
                    ),
                  ),
                  Expanded(
                    child: _buildQuickAction(Icons.school, l10n.trafficInfo),
                  ),
                  Expanded(
                    child: _buildQuickAction(Icons.wb_sunny, l10n.weatherCheck),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label) {
    return InkWell(
      onTap: () => _sendMessage(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF041E42), size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showClearHistoryDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearChatHistory),
        content: Text('${l10n.deleteChatConfirm}\n${l10n.cannotUndo}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _clearChatHistory();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              l10n.clearChatHistory,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _testApiConnection() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('API 연결을 테스트하는 중...'),
          ],
        ),
      ),
    );

    try {
      final isValid = await _openAIService.validateApiKey();
      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(isValid ? 'API 연결 성공' : 'API 연결 실패'),
          content: Text(
            isValid
                ? 'OpenAI API에 성공적으로 연결되었습니다!'
                : 'API 키가 유효하지 않거나 연결에 문제가 있습니다.\n.env 파일의 OPENAI_API_KEY를 확인해주세요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('연결 테스트 실패'),
          content: Text('오류: ${e.toString()}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        ),
      );
    }
  }
}
