// 2026-01-19 15:30:00 EST - FCM 서비스 구현
// PRD 001 v1.4.4 섹션 4.5 FCM 푸시 알림
// 2026-01-22 23:30:00 EST - FCM 토큰 백엔드 전송 구현
// 2026-01-23 00:45:00 EST - 안드로이드 알림 채널 추가

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  // 2026-01-23 00:45:00 EST - 로컬 알림 플러그인 추가
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // FCM 초기화
  Future<void> initialize() async {
    // Firebase 초기화
    await Firebase.initializeApp();
    
    // 2026-01-23 00:45:00 EST - 안드로이드 알림 채널 생성
    await _initializeLocalNotifications();
    
    // 알림 권한 요청
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ FCM 알림 권한 승인됨');
      
      // FCM 토큰 얻기
      _fcmToken = await _messaging.getToken();
      debugPrint('📱 FCM Token 수신됨');
      
      // 토큰 갱신 리스너
      _messaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        debugPrint('🔄 FCM Token 갱신됨');
        // TODO: 백엔드에 새 토큰 전송
      });
      
      // Foreground 메시지 핸들러
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Background 메시지 핸들러 (백그라운드에서 앱이 열릴 때)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
      
      // Terminated 상태에서 푸시로 열린 경우
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }
    } else {
      debugPrint('❌ FCM 알림 권한 거부됨');
    }
  }

  // 2026-01-23 00:45:00 EST - 로컬 알림 초기화 및 채널 생성
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = 
      AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('🔔 로컬 알림 클릭됨: ${details.payload}');
      },
    );
    
    // 안드로이드 알림 채널 생성
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'pinger_default_channel',
      'Pinger Alerts',
      description: 'Server down alerts from Pinger',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    
    await _localNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
    
    debugPrint('✅ 알림 채널 생성됨: pinger_default_channel');
  }

  // Foreground 메시지 처리 (앱이 열려있을 때)
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📩 Foreground 메시지 수신: ${message.notification?.title}');
    
    // TODO: 로컬 알림 표시 또는 상태 업데이트
    final status = message.data['status'];
    final instanceId = message.data['instanceId'];
    
    debugPrint('Status: $status, InstanceId: $instanceId');
  }

  // 백그라운드 메시지로 앱이 열린 경우
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('🔔 푸시 알림으로 앱 열림: ${message.notification?.title}');
    
    final instanceId = message.data['instanceId'];
    if (instanceId != null) {
      // TODO: 해당 인스턴스 상세 화면으로 이동
      debugPrint('Navigate to instance: $instanceId');
    }
  }

  // 2026-01-22 23:30:00 EST - FCM 토큰 백엔드 전송 구현
  // 백엔드에 FCM 토큰 전송
  Future<void> sendTokenToBackend(String apiUrl, String apiKey) async {
    if (_fcmToken == null) {
      debugPrint('❌ FCM 토큰이 없음');
      return;
    }

    try {
      final response = await http.put(
        Uri.parse('$apiUrl/config'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
        },
        body: jsonEncode({'fcm_token': _fcmToken}),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ FCM 토큰 백엔드 전송 성공');
      } else {
        debugPrint('❌ FCM 토큰 전송 실패: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ FCM 토큰 전송 오류: $e');
    }
  }
}

// Background/Terminated 상태에서의 메시지 핸들러 (Top-level function 필요)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('🌙 Background 메시지 수신: ${message.notification?.title}');
  
  // Background에서는 알림이 자동으로 표시됨
}
