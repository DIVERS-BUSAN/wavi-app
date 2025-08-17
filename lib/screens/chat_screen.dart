import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const CustomAppBar(title: 'AI 대화'),
      body: const SafeArea(
        child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble,
              size: 100,
              color: Colors.purple,
            ),
            SizedBox(height: 20),
            Text(
              'AI 비서와 대화하기',
              style: TextStyle(fontSize: 24),
            ),
          ],
          ),
        ),
      ),
    );
  }
}