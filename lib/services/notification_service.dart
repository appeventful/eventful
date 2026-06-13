import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import '../screens/event_detail_screen.dart';
import '../screens/profile_screen.dart';
import '../main.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // 1. Request permission (iOS and Android 13+)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Notification permission granted ✅');
    }

    // 2. Local Notification Settings & Channel
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
    
    // Android 13+ için Local Notifications izni iste
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _handleNotificationClick(response.payload);
      },
    );

    // Yüksek öncelikli bir bildirim kanalı oluştur (Zorunludur)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'event_channel', // id
      'Event Notifications', // title
      description: 'Etkinlik ve mesaj bildirimleri', // description
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Token yenilendiğinde veritabanına kaydet
    _messaging.onTokenRefresh.listen(_saveTokenToDatabase);

    // Eğer kullanıcı giriş yapmışsa token'ı kaydet ve genel duyuru kanalına abone yap
    if (FirebaseAuth.instance.currentUser != null) {
      _saveTokenToDatabase();
      subscribeToTopic('all_users');
    }

    // 3. App opened from terminated state via notification
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleRemoteMessage(initialMessage);
    }

    // 4. App in background opened via notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteMessage);

    // 5. Handle foreground notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("Foreground message received: ${message.notification?.title}");
      _showLocalNotification(message);
    });
  }

  static void _handleRemoteMessage(RemoteMessage message) {
    final type = message.data['type'];
    final eventId = message.data['eventId'];

    if (type == 'friend_request' || type == 'friend_accepted') {
      _navigateToProfile(message.data['senderId']);
    } else if (type == 'message' || type == 'mention') {
      _navigateToChat(message.data['chatId']);
    } else if (type == 'device_reset_request') {
      _navigateToAdminPanel();
    } else if (type == 'chat_mention' || type == 'chat_mention_all' || type == 'chat_reply') {
      if (eventId != null) {
        _navigateToEvent(eventId, code: message.data['code']);
      }
    } else if (eventId != null) {
      _navigateToEvent(
        eventId,
        code: message.data['code'],
      );
    }
  }

  static void _handleNotificationClick(String? payload) {
    if (payload != null && payload.isNotEmpty) {
      try {
        final Map<String, dynamic> data = Uri.splitQueryString(payload);
        final type = data['type'];
        final eventId = data['eventId'];

        if (type == 'friend_request' || type == 'friend_accepted') {
          _navigateToProfile(data['senderId']);
        } else if (type == 'message' || type == 'mention') {
          _navigateToChat(data['chatId']);
        } else if (type == 'device_reset_request') {
          _navigateToAdminPanel();
        } else if (type == 'chat_mention' || type == 'chat_mention_all' || type == 'chat_reply') {
          if (eventId != null) {
            _navigateToEvent(eventId, code: data['code']);
          }
        } else if (eventId != null) {
          _navigateToEvent(eventId, code: data['code']);
        }
      } catch (e) {
        // Fallback for old simple payload format if necessary
        if (payload.contains('|')) {
          final parts = payload.split('|');
          _navigateToEvent(parts[0], code: parts[1]);
        } else {
          _navigateToEvent(payload);
        }
      }
    }
  }

  static void _navigateToAdminPanel() {
    navigatorKey.currentState?.pushNamed('/admin_panel');
  }

  static void _navigateToProfile(String? userId) {
    if (userId == null) return;
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => ProfileScreen(otherUserId: userId)),
    );
  }

  static void _navigateToChat(String? chatId) {
    if (chatId != null && chatId.isNotEmpty) {
      navigatorKey.currentState?.pushNamed('/chat', arguments: chatId);
    } else {
      navigatorKey.currentState?.pushNamed('/messages');
    }
  }

  static void _navigateToEvent(String eventId, {String? code}) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => EventDetailScreen(eventId: eventId, initialCode: code)),
    );
  }

  static void _showLocalNotification(RemoteMessage message) {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'event_channel',
      'Event Notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: 'notification_icon', // Custom icon
      color: Color(0xFFFF9800), // Match manifest color
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    // Create a query-string style payload to pass all data
    final Map<String, String> payloadData = {};
    message.data.forEach((key, value) {
      payloadData[key] = value.toString();
    });
    
    // Ensure essential fields are there even if not in data
    if (message.data['eventId'] != null) payloadData['eventId'] = message.data['eventId'];
    if (message.data['code'] != null) payloadData['code'] = message.data['code'];
    if (message.data['type'] != null) payloadData['type'] = message.data['type'];
    if (message.data['senderId'] != null) payloadData['senderId'] = message.data['senderId'];
    if (message.data['chatId'] != null) payloadData['chatId'] = message.data['chatId'];

    final String payload = Uri(queryParameters: payloadData).query;

    _localNotifications.show(
      id: message.hashCode,
      title: message.notification?.title,
      body: message.notification?.body,
      notificationDetails: details,
      payload: payload,
    );
  }

  static Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  static Future<void> sendNotification({
    required String recipientId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // 1. ÖNCE OKUMA YAP (READ) - Bağımsız Firestore instance'ı kullanıyoruz
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(recipientId).get();
      final userData = userDoc.data();
      if (userData == null) return;

      final fcmToken = userData['fcmToken'];
      final settings = userData['notificationSettings'] != null 
          ? Map<String, dynamic>.from(userData['notificationSettings']) 
          : null;

      // 2. MANTIKSEL KONTROLLER
      String? notificationType = data?['type'];
      bool isAllowed = true;
      if (settings != null) {
        if (notificationType == 'message') isAllowed = settings['new_message'] ?? true;
        else if (notificationType == 'friend_request') isAllowed = settings['friend_request'] ?? true;
        else if (notificationType == 'event_approval') isAllowed = settings['event_approval'] ?? true;
        else if (notificationType == 'mention' || notificationType == 'chat_mention') isAllowed = settings['mentions'] ?? true;
      }

      // 3. ŞİMDİ YAZMALARI YAP (WRITE)
      final Map<String, dynamic> notificationData = {
        'title': title,
        'content': body,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      };
      if (data != null) notificationData.addAll(data);

      // Uygulama içi bildirim merkezine kaydet
      await FirebaseFirestore.instance
          .collection('users')
          .doc(recipientId)
          .collection('notifications')
          .add(notificationData);

      // Push bildirim tetikleyicisi oluştur
      if (fcmToken != null && isAllowed) {
        debugPrint('FCM: Sending notification to token: $fcmToken');
        await FirebaseFirestore.instance.collection('push_notifications').add({
          'to': fcmToken,
          'recipientId': recipientId,
          'notification': {
            'title': title,
            'body': body,
          },
          'data': (data ?? {}).map((key, value) => MapEntry(key, value.toString())),
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'fcmVersion': 'v1',
        });
        debugPrint('FCM V1 bildirim isteği başarıyla oluşturuldu.');
      }
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  static Future<void> _saveTokenToDatabase([String? token]) async {
    try {
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      String? fcmToken = token ?? await _messaging.getToken();
      if (fcmToken == null) return;

      // SADECE döküman varsa güncelle (Adsız kullanıcı oluşmasını engellemek için)
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      
      if (userDoc.exists) {
        final currentData = userDoc.data() as Map<String, dynamic>?;
        if (currentData?['fcmToken'] != fcmToken) {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'fcmToken': fcmToken,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          });
          debugPrint('FCM: Token updated in DB');
          subscribeToTopic('all_users');
        }
      } else {
        debugPrint('FCM: User document does not exist yet, skipping token save');
      }
    } catch (e) {
      debugPrint('FCM Error saving token: $e');
    }
  }
}
