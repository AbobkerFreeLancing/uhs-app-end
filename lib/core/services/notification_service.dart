import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../network/api_client.dart';

// معالج إشعارات الخلفية لـ Firebase Cloud Messaging
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // حفظ الإشعار وتأكيد الاستلام وإظهاره في الستارة العلوية
  await NotificationService.handleIncomingNotification(message);
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // تهيئة نظام الإشعارات المحلي وتكامل Firebase
  static Future<void> init() async {
    // 1. طلب صلاحيات الإشعارات من المستخدم
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted notifications permission');
    }

    // 2. تهيئة الإشعارات المحلية للأندرويد والآي أو إس
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // عند نقر المستخدم على الإشعار من الستارة العلوية للذهاب للتطبيق
        debugPrint('Notification clicked: ${response.payload}');
      },
    );

    // طلب صلاحيات الإشعارات لأجهزة أندرويد 13 فما فوق
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // 3. جلب الـ FCM Token الحالي وتحديثه على السيرفر
    String? token = await _fcm.getToken();
    if (token != null) {
      debugPrint('FCM Token: $token');
      await updateTokenOnServer(token);
    }

    // 4. الاستماع لتجديد الـ Token وتحديثه تلقائياً
    _fcm.onTokenRefresh.listen((newToken) {
      updateTokenOnServer(newToken);
    });

    // 5. الاستماع للإشعارات في الوضع الأمامي (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Received foreground message: ${message.messageId}');
      handleIncomingNotification(message);
    });

    // 6. الاستماع للنقر على الإشعار وفتح التطبيق
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('App opened from notification: ${message.messageId}');
    });
  }

  // معالجة الإشعار الوارد: حفظه محلياً في SQLite، إرسال تأكيد استلام للسيرفر، وإظهاره للنظام
  static Future<void> handleIncomingNotification(RemoteMessage message) async {
    final String title = message.notification?.title ?? message.data['title'] ?? 'تنبيه جديد';
    final String body = message.notification?.body ?? message.data['body'] ?? 'تم تحديث بياناتك في النظام';
    final String type = message.data['type'] ?? 'general';
    final String id = message.data['id'] ?? message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString();

    debugPrint('Processing incoming notification: id=$id, title=$title');

    // 1. حفظ الإشعار في قاعدة البيانات المحلية SQLite
    final dbHelper = DatabaseHelper();
    await dbHelper.insertNotification({
      'id': id,
      'title': title,
      'message': body,
      'created_at': DateTime.now().toIso8601String(),
      'is_read': 0,
      'is_received': 1,
      'type': type,
    });

    // 2. إرسال تأكيد استلام للسيرفر (Mark as Received)
    await markAsReceivedOnServer(id);

    // 3. إظهار الإشعار في شريط التنبيهات
    await showSystemNotification(
      id: id.hashCode,
      title: title,
      body: body,
    );
  }

  // إرسال تأكيد الاستلام للسيرفر
  static Future<void> markAsReceivedOnServer(String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    final String? sessionCookie = prefs.getString('session_cookie');
    
    if (sessionCookie == null) {
      debugPrint('Cannot confirm receipt: Session cookie is null');
      return;
    }

    final String baseUrl = ApiClient().baseUrl;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/notifications_action.php'),
        headers: {
          'Cookie': sessionCookie,
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
        },
        body: {
          'action': 'mark_as_received',
          'notification_id': notificationId,
        },
      );
      debugPrint('Confirm receipt response: ${response.body}');
    } catch (e) {
      debugPrint('Error confirming receipt: $e');
    }
  }

  // تحديث الـ Token الخاص بـ FCM في جدول الطلاب بالسيرفر
  static Future<void> updateTokenOnServer(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final String? sessionCookie = prefs.getString('session_cookie');

    if (sessionCookie == null) {
      debugPrint('Cannot update FCM Token: Session cookie is null');
      return;
    }

    final String baseUrl = ApiClient().baseUrl;
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/notifications_action.php'),
        headers: {
          'Cookie': sessionCookie,
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
        },
        body: {
          'action': 'update_fcm_token',
          'fcm_token': token,
        },
      );
      debugPrint('Token update response: ${response.body}');
    } catch (e) {
      debugPrint('Error updating FCM Token on server: $e');
    }
  }

  // إظهار إشعار في الستارة العلوية للجهاز كرسالة نظام
  static Future<void> showSystemNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'uohs_finance_channel_id',
      'تنبيهات الفواتير والمالية',
      channelDescription: 'تنبيهات إشعار الفواتير وتعديلات الحساب المالي للطالب',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      showWhen: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}
