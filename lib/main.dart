import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/map_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/notification_screen.dart';
import 'screens/profile_screen.dart';
import 'services/notification_service.dart';
import 'providers/language_provider.dart';
import 'l10n/app_localizations.dart';
import 'utils/toast_utils.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kakao_flutter_sdk_common/kakao_flutter_sdk_common.dart';
import 'services/schedule_service.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  //await ScheduleService().clearAllTravelSchedules();
  
  // 로케일 데이터 초기화
  await initializeDateFormatting('ko_KR', null);
  
  await dotenv.load(fileName: ".env");

  //  Flutter SDK 초기화
  KakaoSdk.init(
    nativeAppKey: dotenv.env['KAKAO_NATIVE_APP_KEY']! ?? '',
    javaScriptAppKey: dotenv.env['KAKAO_JS_APP_KEY']! ?? '',
  );

  AuthRepository.initialize(
      appKey: dotenv.env['KAKAO_JS_APP_KEY']! ?? '',
      baseUrl: 'http://localhost'
  );

  // 알림 서비스 초기화
  await NotificationService().initialize();

  runApp(
    ChangeNotifierProvider(
      create: (context) => LanguageProvider(),
      child: const WaviApp(),
    ),
  );
}

class WaviApp extends StatelessWidget {
  const WaviApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return MaterialApp(
          title: 'WAVI',
          navigatorKey: NavigationService.navigatorKey,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF041E42)),
            useMaterial3: true,
          ),
          locale: languageProvider.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MainScreen(),
        );
      },
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

  List<Widget> _screens = [];
  
  @override
  void initState() {
    super.initState();
    _buildScreens();
  }
  
  void _buildScreens() {
    _screens = [
      const MapScreen(),
      const ScheduleScreen(),
      const ChatScreen(),
      const NotificationScreen(),
      const ProfileScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    
    return Scaffold(
      body: _screens[_selectedIndex],
      floatingActionButton: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              const Color(0xFF041E42),
              const Color(0xFF0A3D62),
              const Color(0xFF1B4F72),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF041E42).withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(35),
            splashColor: Colors.white.withOpacity(0.2),
            highlightColor: Colors.white.withOpacity(0.1),
            onTap: () {
              setState(() {
                _selectedIndex = 2; // AI 대화 화면으로 이동
              });
            },
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Image.asset(
                    'assets/images/wavi-logo-white.png',
                    width: 46,
                    height: 46,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
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