import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const CustomAppBar(title: '알림'),
      body: const SafeArea(
        child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications,
              size: 100,
              color: Colors.orange,
            ),
            SizedBox(height: 20),
            Text(
              '알림 센터',
              style: TextStyle(fontSize: 24),
            ),
          ],
          ),
        ),
      ),
    );
  }
}