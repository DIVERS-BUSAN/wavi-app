import 'package:flutter/material.dart';
import 'screens/map_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/notification_screen.dart';
import 'screens/profile_screen.dart';
import 'services/notification_service.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  
  // 로케일 데이터 초기화
  await initializeDateFormatting('ko_KR', null);
  
  await dotenv.load(fileName: ".env");
  AuthRepository.initialize(
      appKey: dotenv.env['KAKAO_JS_APP_KEY']! ?? '',
      baseUrl: 'http://localhost'
  );

  // 알림 서비스 초기화
  await NotificationService().initialize();

  runApp(const WaviApp());
}

class WaviApp extends StatelessWidget {
  const WaviApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WAVI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF041E42)),
        useMaterial3: true,
      ),
      home: const MainScreen(
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const MapScreen(),
    const ScheduleScreen(),
    const ChatScreen(),
    const NotificationScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      floatingActionButton: Container(
        width: 70,
        height: 70,
        child: FloatingActionButton(
          backgroundColor: const Color(0xFF041E42),
          onPressed: () {
            setState(() {
              _selectedIndex = 2; // AI 대화 화면으로 이동
            });
          },
          child: Image.asset(
            'assets/images/wavi-logo-white.png',
            width: 50,
            height: 50,
          ),
          elevation: 8,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Container(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: Icon(
                  Icons.map,
                  color: _selectedIndex == 0 ? const Color(0xFF041E42) : Colors.grey,
                ),
                onPressed: () => _onItemTapped(0),
              ),
              IconButton(
                icon: Icon(
                  Icons.calendar_month,
                  color: _selectedIndex == 1 ? const Color(0xFF041E42) : Colors.grey,
                ),
                onPressed: () => _onItemTapped(1),
              ),
              const SizedBox(width: 70), // AI 대화 버튼 공간
              IconButton(
                icon: Icon(
                  Icons.notifications,
                  color: _selectedIndex == 3 ? const Color(0xFF041E42) : Colors.grey,
                ),
                onPressed: () => _onItemTapped(3),
              ),
              IconButton(
                icon: Icon(
                  Icons.person,
                  color: _selectedIndex == 4 ? const Color(0xFF041E42) : Colors.grey,
                ),
                onPressed: () => _onItemTapped(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}