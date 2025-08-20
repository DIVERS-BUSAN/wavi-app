import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:io' show Platform;
import '../widgets/custom_app_bar.dart';
import '../widgets/chat_bubble.dart';
import '../models/chat_message.dart';
import '../services/openai_service.dart';
import '../services/schedule_service.dart';
import '../models/schedule.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

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
  

  void _initializeTts() async {
    _flutterTts = FlutterTts();
    
    try {
      // 사용 가능한 음성 목록 확인
      var voices = await _flutterTts.getVoices;
      
      // 한국어 음성 찾기 (Yuna 우선)
      var koreanVoices = voices.where((voice) => 
          voice["locale"].toString().startsWith("ko")
      ).toList();
      
      // Yuna 음성을 우선적으로 찾기
      var yunaVoice = koreanVoices.firstWhere(
        (voice) => voice["name"].toString().contains("Yuna"),
        orElse: () => koreanVoices.isNotEmpty ? koreanVoices.first : null,
      );
      
      // iOS 전용 설정 (macOS에서는 setSharedInstance가 지원되지 않음)
      if (Platform.isIOS) {
        try {
          await _flutterTts.setSharedInstance(true);
          await _flutterTts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback,
              [
                IosTextToSpeechAudioCategoryOptions.allowBluetooth,
                IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
                IosTextToSpeechAudioCategoryOptions.mixWithOthers,
              ],
              IosTextToSpeechAudioMode.voicePrompt
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
          "locale": yunaVoice["locale"]
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
    final welcomeMessage = ChatMessage(
      content: '안녕하세요! 저는 웨이비(WAVI) AI 비서입니다. \n\n일정 관리, 길찾기, 그리고 다양한 질문에 답변해드릴게요!\n\n무엇을 도와드릴까요?',
      type: MessageType.assistant,
    );
    
    setState(() {
      _messages.add(welcomeMessage);
    });
    
    _saveChatHistory();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('음성 인식을 사용할 수 없습니다. 마이크 권한을 확인해주세요.')),
      );
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
        localeId: 'ko_KR',
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 2),
        partialResults: true,
      );
      
      if (_voiceChatMode) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎤 음성 대화 모드 - 말씀해주세요 (마이크 버튼으로 종료)'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎤 음성 인식 중... 말씀해주세요'),
            duration: Duration(seconds: 2),
          ),
        );
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

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // 사용자 메시지 추가
    final userMessage = ChatMessage(
      content: text,
      type: MessageType.user,
    );

    setState(() {
      _messages.add(userMessage);
      _textController.clear();
      _isTyping = true;
    });

    _scrollToBottom();
    _saveChatHistory();

    // 일정 생성 요청인지 확인
    if (_isScheduleRequest(text)) {
      await _handleScheduleCreation(text);
      return;
    }

    try {
      // OpenAI API 호출
      final response = await _openAIService.sendMessage(_messages);
      
      if (response != null) {
        setState(() {
          _messages.add(response);
          _isTyping = false;
        });

        // TTS로 응답 읽기
        var result = await _flutterTts.speak(response.content);
        if (result == 1) {
          print("TTS Speaking: ${response.content}");
        } else {
          print("TTS Failed to speak");
        }
      } else {
        throw Exception('AI 응답을 받을 수 없습니다.');
      }
    } catch (e) {
      print('OpenAI API 오류: $e');
      
      // 오류 발생시 기본 응답
      final errorMessage = ChatMessage(
        content: '죄송합니다. 현재 서버에 문제가 있어 응답할 수 없습니다. 잠시 후 다시 시도해주세요.\n\n오류: ${e.toString()}',
        type: MessageType.assistant,
      );
      
      setState(() {
        _messages.add(errorMessage);
        _isTyping = false;
      });
      
      // 오류 메시지도 TTS로 읽기
      await _flutterTts.speak('죄송합니다. 현재 서버에 문제가 있어 응답할 수 없습니다.');
    }
    
    _scrollToBottom();
    _saveChatHistory();
  }

  // 일정 생성 요청인지 확인
  bool _isScheduleRequest(String text) {
    final scheduleKeywords = [
      '일정', '약속', '미팅', '회의', '만남', '스케줄',
      '등록', '생성', '추가', '만들어', '예약',
      '내일', '오늘', '모레', '다음주', '이번주',
      '시간', '날짜', '알림', '리마인더'
    ];
    
    final lowerText = text.toLowerCase();
    return scheduleKeywords.any((keyword) => lowerText.contains(keyword));
  }

  // 일정 생성 처리
  Future<void> _handleScheduleCreation(String text) async {
    try {
      // OpenAI를 통해 일정 정보 추출
      final extractionPrompt = '''
다음 텍스트에서 일정 정보를 추출해주세요:
"$text"

다음 JSON 형식으로 응답해주세요:
{
  "title": "일정 제목",
  "description": "일정 설명 (없으면 null)",
  "datetime": "YYYY-MM-DD HH:mm 형식",
  "location": "장소명 (없으면 null)",
  "hasAlarm": true/false
}

현재 시간: ${DateTime.now().toString()}
오늘 날짜: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}

응답은 반드시 유효한 JSON 형식이어야 합니다.
''';

      final extractionMessages = [
        ChatMessage(content: extractionPrompt, type: MessageType.user)
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

  // 일정 데이터 처리
  Future<void> _processScheduleData(String responseContent, String originalText) async {
    try {
      // JSON 응답에서 일정 정보 파싱
      final jsonStart = responseContent.indexOf('{');
      final jsonEnd = responseContent.lastIndexOf('}') + 1;
      
      if (jsonStart == -1 || jsonEnd <= jsonStart) {
        throw Exception('유효한 JSON 형식을 찾을 수 없습니다.');
      }
      
      final jsonString = responseContent.substring(jsonStart, jsonEnd);
      final scheduleData = jsonDecode(jsonString);
      
      // 일정 생성
      final title = scheduleData['title'] ?? '새 일정';
      final description = scheduleData['description'];
      final datetimeStr = scheduleData['datetime'];
      final locationName = scheduleData['location'];
      final hasAlarm = scheduleData['hasAlarm'] ?? false;
      
      if (datetimeStr == null) {
        throw Exception('날짜와 시간 정보가 필요합니다.');
      }
      
      final dateTime = DateTime.parse(datetimeStr.replaceAll(' ', 'T'));
      
      // Location 객체 생성 (필요시)
      Location? location;
      if (locationName != null && locationName.isNotEmpty) {
        location = Location(name: locationName);
      }
      
      // 일정 저장
      final success = await _scheduleService.addSchedule(
        title: title,
        description: description,
        dateTime: dateTime,
        location: location,
        isAlarmEnabled: hasAlarm,
        alarmDateTime: hasAlarm ? dateTime.subtract(const Duration(minutes: 10)) : null,
        color: ScheduleColor.blue,
      );
      
      if (success) {
        final successMessage = ChatMessage(
          content: '✅ 일정이 성공적으로 생성되었습니다!\n\n'
              '📋 제목: $title\n'
              '📅 날짜: ${DateFormat('yyyy년 MM월 dd일 HH시 mm분').format(dateTime)}\n'
              '${location != null ? '📍 장소: ${location.name}\n' : ''}'
              '${description != null ? '📝 설명: $description\n' : ''}'
              '${hasAlarm ? '⏰ 알림: 10분 전' : ''}',
          type: MessageType.assistant,
        );
        
        setState(() {
          _messages.add(successMessage);
          _isTyping = false;
        });
        
        await _flutterTts.speak('일정이 성공적으로 생성되었습니다. $title이 ${DateFormat('MM월 dd일 HH시 mm분').format(dateTime)}에 등록되었습니다.');
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
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('채팅 기록이 삭제되었습니다')),
      );
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
              child: Image.asset(
                'assets/images/wavi-logo.png',
                height: 25,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'AI 비서',
              style: TextStyle(
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
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline),
                    SizedBox(width: 8),
                    Text('채팅 기록 삭제'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'api_test',
                child: Row(
                  children: [
                    Icon(Icons.wifi_protected_setup),
                    SizedBox(width: 8),
                    Text('API 연결 테스트'),
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
                    colors: [
                      Colors.blue[50]!.withOpacity(0.3),
                      Colors.white,
                    ],
                  ),
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 10, bottom: 10),
                  itemCount: _messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length && _isTyping) {
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
                    return ChatBubble(message: _messages[index]);
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
                          color: (_isListening || _voiceChatMode) ? Colors.red.withOpacity(0.1) : Colors.transparent,
                          shape: BoxShape.circle,
                          border: (_isListening || _voiceChatMode) ? Border.all(color: Colors.red, width: 2) : null,
                        ),
                        child: IconButton(
                          icon: Icon(
                            _voiceChatMode ? (_isListening ? Icons.mic : Icons.stop) :
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: _voiceChatMode ? Colors.red :
                                  _isListening ? Colors.red : 
                                  _speechEnabled ? const Color(0xFF041E42) : Colors.grey,
                            size: 28,
                          ),
                          onPressed: _speechEnabled ? _toggleListening : null,
                          tooltip: _voiceChatMode ? '음성 대화 모드 종료' :
                                  _isListening ? '음성 인식 중지' : 
                                  _speechEnabled ? '음성 대화 모드 시작' : '음성 인식 비활성화',
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
                            decoration: const InputDecoration(
                              hintText: 'WAVI에게 메시지를 보내보세요...',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
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
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildQuickAction(Icons.tips_and_updates, '맞춤 추천'),
                  _buildQuickAction(Icons.directions_car, '관광지 정보'),
                  _buildQuickAction(Icons.school, '교통 안내'),
                  _buildQuickAction(Icons.wb_sunny, '날씨 확인'),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF041E42), size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('채팅 기록 삭제'),
        content: const Text('모든 채팅 기록을 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _clearChatHistory();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
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
              : 'API 키가 유효하지 않거나 연결에 문제가 있습니다.\n.env 파일의 OPENAI_API_KEY를 확인해주세요.'
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