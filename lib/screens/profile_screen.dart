import 'package:flutter/material.dart';
import '../widgets/custom_app_bar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const CustomAppBar(title: '프로필'),
      body: const SafeArea(
        child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person,
              size: 100,
              color: Colors.teal,
            ),
            SizedBox(height: 20),
            Text(
              '내 프로필',
              style: TextStyle(fontSize: 24),
            ),
          ],
          ),
        ),
      ),
    );
  }
}