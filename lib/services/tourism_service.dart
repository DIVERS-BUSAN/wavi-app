import 'dart:convert';
import 'package:http/http.dart' as http;

class TourismService {
  final String _baseUrl = "http://52.79.194.171:3000";

  Future<String> fetchTourismContext(String query) async {
    final response = await http.post(
      Uri.parse("$_baseUrl/rag"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"message": query}),
    );
    print("$_baseUrl/rag");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["context"] ?? "";
    } else {
      throw Exception("RAG 서버 오류: ${response.statusCode}");
    }
  }
}
