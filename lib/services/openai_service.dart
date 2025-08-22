import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';

class OpenAIService {
  static const String _baseUrl = 'https://api.openai.com/v1';
  static const String _model = 'gpt-3.5-turbo';
  
  late final String _apiKey;
  
  OpenAIService() {
    _apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (_apiKey.isEmpty && kDebugMode) {
      print('Warning: OPENAI_API_KEY not found in environment variables');
    }
  }

  Future<ChatMessage?> sendMessage(List<ChatMessage> messages, {bool isEnglish = false}) async {
    if (_apiKey.isEmpty) {
      throw Exception('OpenAI API key가 설정되지 않았습니다. .env 파일을 확인해주세요.');
    }

    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      };

      // ChatMessage를 OpenAI API 형식으로 변환
      final apiMessages = messages
          .where((msg) => msg.type != MessageType.system || msg.content.isNotEmpty)
          .map((msg) => {
                'role': _getApiRole(msg.type),
                'content': msg.content,
              })
          .toList();

      // 언어별 시스템 메시지 추가 (웨이비 AI 비서 역할 정의)
      final systemMessage = isEnglish ? {
        'role': 'system',
        'content': '''You are an AI assistant named "WAVI". 
You are a friendly and helpful AI assistant that helps users with schedule management, Kakao Navigation integration, and daily conversations.
You have the following characteristics:

1. Communicate with a friendly and warm tone
2. Provide professional answers to schedule management and navigation-related questions
3. Communicate naturally in English
4. Provide concise yet helpful responses
5. Use emojis appropriately when necessary

Please provide helpful answers to the user's questions.'''
      } : {
        'role': 'system',
        'content': '''당신은 "웨이비(WAVI)"라는 이름의 AI 비서입니다. 
사용자의 일정 관리, 카카오 네비게이션 연동, 그리고 일상 대화를 도와주는 친근하고 도움이 되는 AI 비서입니다.
다음과 같은 특징을 가지고 있습니다:

1. 친근하고 따뜻한 말투로 대화합니다
2. 일정 관리와 네비게이션 관련 질문에 전문적으로 답변합니다
3. 한국어로 자연스럽게 대화합니다
4. 간결하면서도 도움이 되는 답변을 제공합니다
5. 필요시 이모지를 적절히 사용합니다

사용자의 질문에 도움이 되는 답변을 해주세요.'''
      };

      apiMessages.insert(0, systemMessage);

      final requestBody = {
        'model': _model,
        'messages': apiMessages,
        'max_tokens': 1000,
        'temperature': 0.7,
        'top_p': 1.0,
        'frequency_penalty': 0.0,
        'presence_penalty': 0.0,
      };

      if (kDebugMode) {
        print('OpenAI API Request: ${jsonEncode(requestBody)}');
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: headers,
        body: jsonEncode(requestBody),
      );

      if (kDebugMode) {
        print('OpenAI API Response Status: ${response.statusCode}');
        print('OpenAI API Response Body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] as String;
        
        return ChatMessage(
          content: content.trim(),
          type: MessageType.assistant,
        );
      } else if (response.statusCode == 401) {
        throw Exception('OpenAI API 인증에 실패했습니다. API 키를 확인해주세요.');
      } else if (response.statusCode == 429) {
        throw Exception('API 요청 한도를 초과했습니다. 잠시 후 다시 시도해주세요.');
      } else if (response.statusCode == 500) {
        throw Exception('OpenAI 서버에 문제가 발생했습니다. 잠시 후 다시 시도해주세요.');
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error']['message'] ?? 'Unknown error';
        throw Exception('API 요청 실패: $errorMessage');
      }
    } catch (e) {
      if (kDebugMode) {
        print('OpenAI Service Error: $e');
      }
      
      if (e is SocketException) {
        throw Exception('인터넷 연결을 확인해주세요.');
      } else if (e is HttpException) {
        throw Exception('네트워크 오류가 발생했습니다.');
      } else {
        rethrow;
      }
    }
  }

  String _getApiRole(MessageType type) {
    switch (type) {
      case MessageType.user:
        return 'user';
      case MessageType.assistant:
        return 'assistant';
      case MessageType.system:
        return 'system';
    }
  }

  // 채팅 기록 요약을 위한 메서드 (메모리 관리)
  Future<String> summarizeConversation(List<ChatMessage> messages) async {
    if (messages.length < 10) return '';

    try {
      final conversationText = messages
          .take(messages.length - 5) // 마지막 5개 메시지는 유지
          .map((msg) => '${msg.type == MessageType.user ? 'User' : 'Assistant'}: ${msg.content}')
          .join('\n');

      final summaryMessages = [
        {
          'role': 'system',
          'content': '다음 대화를 간결하게 요약해주세요. 주요 내용과 맥락을 유지하되, 길이는 200자 이내로 해주세요.'
        },
        {
          'role': 'user', 
          'content': conversationText
        }
      ];

      final requestBody = {
        'model': _model,
        'messages': summaryMessages,
        'max_tokens': 150,
        'temperature': 0.3,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] as String;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Conversation summary failed: $e');
      }
    }
    
    return '';
  }

  // API 키 유효성 검사
  Future<bool> validateApiKey() async {
    if (_apiKey.isEmpty) return false;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/models'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
        },
      );
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}