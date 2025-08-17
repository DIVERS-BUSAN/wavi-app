import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const CustomAppBar(title: '일정'),
      body: const SafeArea(
        child: Center(
          child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_month,
              size: 100,
              color: Colors.green,
            ),
            SizedBox(height: 20),
            Text(
              '일정 관리',
              style: TextStyle(fontSize: 24),
            ),
          ],
          ),
        ),
      ),
    );
  }
}