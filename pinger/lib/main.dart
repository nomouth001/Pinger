// 2026-01-19 15:18:00 EST - Main.dart 구현
// PRD 001 v1.4.4 전체 앱 진입점 및 라우팅
// 2026-01-19 15:40:00 EST - FCM 통합
// 2026-01-20 01:05:00 EST - Firebase 초기화 추가
// 2026-01-22 EST - Lambda API 연결 설정

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';  // Firebase Core 추가
import 'package:firebase_messaging/firebase_messaging.dart';
import 'providers/instance_provider.dart';
import 'services/auth_service.dart';
import 'services/fcm_service.dart';
import 'services/api_service.dart';
import 'screens/auth/pin_setup_screen.dart';
import 'screens/auth/pin_auth_screen.dart';
import 'screens/dashboard_screen.dart';

// 로컬 설정 파일을 --dart-define-from-file로 전달합니다.
const String API_BASE_URL = String.fromEnvironment('API_BASE_URL');
const String API_KEY = String.fromEnvironment('API_KEY');

// Background 메시지 핸들러 (Top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();  // 백그라운드에서도 초기화
  await firebaseMessagingBackgroundHandler(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase 초기화 (가장 먼저!)
  await Firebase.initializeApp();
  
  // FCM Background Handler 등록
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  runApp(const PingerApp());
}

class PingerApp extends StatelessWidget {
  const PingerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 2026-01-22 23:30:00 EST - ApiService를 Provider에 주입
    // ApiService 싱글톤 생성
    final apiService = ApiService(
      baseUrl: API_BASE_URL,
      apiKey: API_KEY,
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final provider = InstanceProvider();
            provider.setApiService(apiService); // API 서비스 주입
            return provider;
          },
        ),
        Provider<ApiService>.value(value: apiService),  // API Service 제공
      ],
      child: MaterialApp(
        title: 'Pinger',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2196F3),
          ),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
        routes: {
          '/pin-setup': (context) => const PinSetupScreen(),
          '/pin-auth': (context) => const PinAuthScreen(),
          '/dashboard': (context) => const DashboardScreen(),
        },
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();
  final FCMService _fcmService = FCMService();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // 2026-01-22 23:30:00 EST - FCM 초기화 후 토큰 자동 전송
    // FCM 초기화
    await _fcmService.initialize();
    
    // FCM 토큰을 백엔드로 전송
    if (_fcmService.fcmToken != null &&
        API_BASE_URL.isNotEmpty && API_KEY.isNotEmpty) {
      await _fcmService.sendTokenToBackend(API_BASE_URL, API_KEY);
    }
    
    // 짧은 스플래시 화면
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    // PIN 설정 여부 확인
    final isPinSetup = await _authService.isPinSetup();

    if (!mounted) return;

    if (isPinSetup) {
      // PIN 설정됨 → 인증 화면
      Navigator.of(context).pushReplacementNamed('/pin-auth');
    } else {
      // PIN 미설정 → 설정 화면
      Navigator.of(context).pushReplacementNamed('/pin-setup');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2196F3),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.security,
              size: 100,
              color: Colors.white,
            ),
            const SizedBox(height: 24),
            const Text(
              'Pinger',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Instance Monitor',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
