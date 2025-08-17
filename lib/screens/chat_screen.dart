import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:io' show Platform;
import '../widgets/custom_app_bar.dart';
import '../widgets/chat_bubble.dart';
import '../models/chat_message.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  
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
    _addWelcomeMessage();
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

  void _addWelcomeMessage() {
    setState(() {
      _messages.add(
        ChatMessage(
          text: '안녕하세요! 저는 WAVI AI입니다. 🤖\n무엇을 도와드릴까요?',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
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

    setState(() {
      _messages.add(
        ChatMessage(
          text: text,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _textController.clear();
      _isTyping = true;
    });

    _scrollToBottom();

    // AI 응답 시뮬레이션 (실제로는 GPT API 호출)
    await Future.delayed(const Duration(seconds: 1));
    
    String response = _getAIResponse(text);
    
    setState(() {
      _messages.add(
        ChatMessage(
          text: response,
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
      _isTyping = false;
    });

    // TTS로 응답 읽기
    var result = await _flutterTts.speak(response);
    if (result == 1) {
      print("TTS Speaking: $response");
    } else {
      print("TTS Failed to speak");
    }
    
    _scrollToBottom();
  }

  String _getAIResponse(String query) {
    // 간단한 응답 시뮬레이션
    if (query.contains('날씨')) {
      return '오늘은 맑은 날씨입니다! ☀️\n외출하기 좋은 날이네요.';
    } else if (query.contains('안녕')) {
      return '안녕하세요! 반갑습니다! 😊\n오늘 하루는 어떠셨나요?';
    } else if (query.contains('길찾기') || query.contains('네비')) {
      return '목적지를 알려주시면 최적의 경로를 안내해드리겠습니다! 🗺️';
    } else {
      return '네, 알겠습니다. "$query"에 대해 도움을 드리겠습니다.';
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
          IconButton(
            icon: const Icon(Icons.safety_check, color: Colors.white),
            onPressed: () {
              // 안전모드 토글
            },
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
}