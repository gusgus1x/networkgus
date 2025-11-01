
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

import '../firebase_options.dart';
import '../screens/chat_screen.dart';
import '../screens/user_profile_screen.dart';
import '../screens/post_detail_screen.dart';

// Top-level background handler (required by firebase_messaging)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Ensure Firebase is initialized in background isolate
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}
  // For notification payloads, Android shows notifications automatically.
  // Keep as lightweight as possible here.
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  GlobalKey<NavigatorState>? _navigatorKey;

  static const AndroidNotificationChannel _defaultAndroidChannel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
    playSound: true,
  );

  Future<void> init({required GlobalKey<NavigatorState> navigatorKey}) async {
    _navigatorKey = navigatorKey;

    // iOS/macOS notification presentation while app is foreground
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Initialize local notifications
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _local.initialize(initSettings, onDidReceiveNotificationResponse: (res) {
      // Tapping local notification
      final payload = res.payload;
      if (payload != null && payload.isNotEmpty) {
        _navigateFromPayloadString(payload);
      }
    });

    // Android notification channel
    if (!kIsWeb) {
      final androidPlugin = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(_defaultAndroidChannel);
      // Android 13+ runtime permission for notifications
      await androidPlugin?.requestNotificationsPermission();
    }

    // iOS permission request
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // Register background handler once
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Foreground messages -> show local notification
    FirebaseMessaging.onMessage.listen((message) async {
      await _showForegroundNotification(message);
    });

    // App opened from a terminated state via notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNavigation(initialMessage);
    }

    // App opened from background via notification
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNavigation(message);
    });

    // Sync token if already signed in
    await syncToken();
    // Listen for token refresh
    _messaging.onTokenRefresh.listen((_) => syncToken());
  }

  Future<void> syncToken() async {
    try {
      final user = fb_auth.FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final token = await _messaging.getToken();
      if (token == null) return;
      final users = FirebaseFirestore.instance.collection('users');
      await users.doc(user.uid).set({
        'fcmTokens': FieldValue.arrayUnion([token]),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('FCM token sync error: $e');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final type = message.data['type'];
    String title = notification?.title ?? message.data['title'] ?? 'New notification';
    String body = notification?.body ?? message.data['body'] ?? '';
    if ((notification == null || (notification.title == null && notification.body == null)) && type is String) {
      switch (type) {
        case 'follow':
          title = 'New follower';
          body = message.data['senderName'] != null
              ? '${message.data['senderName']} started following you'
              : 'Someone started following you';
          break;
        case 'like':
          title = 'New like';
          body = message.data['senderName'] != null
              ? '${message.data['senderName']} liked your post'
              : 'Someone liked your post';
          break;
      }
    }

    final androidDetails = AndroidNotificationDetails(
      _defaultAndroidChannel.id,
      _defaultAndroidChannel.name,
      channelDescription: _defaultAndroidChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final payload = _encodePayload(message.data);
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  void _handleNavigation(RemoteMessage message) {
    _navigateFromPayload(message.data);
  }

  void _navigateFromPayload(Map<String, dynamic> data) {
    try {
      final nav = _navigatorKey?.currentState;
      if (nav == null) return;
      final type = data['type'] as String?; // chat | follow | like
      if (type == 'chat') {
        final conversationId = data['conversationId'] as String?;
        if (conversationId == null || conversationId.isEmpty) return;
        final conversationName = data['conversationName'] as String? ?? 'Chat';
        nav.push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: conversationId,
              conversationName: conversationName,
            ),
          ),
        );
      } else if (type == 'follow') {
        final userId = data['userId'] as String?; // follower id
        nav.push(
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(userId: userId),
          ),
        );
      } else if (type == 'like') {
        final postId = data['postId'] as String?;
        if (postId != null && postId.isNotEmpty) {
          nav.push(
            MaterialPageRoute(
              builder: (_) => PostDetailScreen(postId: postId),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Navigation from notification error: $e');
    }
  }

  void _navigateFromPayloadString(String payload) {
    // Payload is a simple serialized map: key1=value1;key2=value2
    final map = <String, String>{};
    for (final part in payload.split(';')) {
      final kv = part.split('=');
      if (kv.length == 2) map[kv[0]] = kv[1];
    }
    _navigateFromPayload(map);
  }

  String _encodePayload(Map<String, dynamic> data) {
    if (data.isEmpty) return '';
    final entries = data.entries.map((e) => '${e.key}=${e.value}');
    return entries.join(';');
  }
}
