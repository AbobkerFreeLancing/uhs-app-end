import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/database/database_helper.dart';
import '../core/network/api_client.dart';

class NotificationsView extends StatefulWidget {
  @override
  _NotificationsViewState createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  List<dynamic> notifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadLocalNotifications();
    syncNotificationsWithServer();
  }

  // تحميل الإشعارات من قاعدة البيانات المحلية أولاً لعرضها فوراً
  Future<void> loadLocalNotifications() async {
    try {
      final dbHelper = DatabaseHelper();
      final localNotifs = await dbHelper.getNotifications();
      setState(() {
        notifications = localNotifs;
        isLoading = localNotifs.isEmpty; // نظهر مؤشر التحميل فقط إذا كانت البيانات فارغة محلياً
      });
    } catch (e) {
      print('Error loading local notifications: $e');
    }
  }

  // جلب وتحديث الإشعارات من السيرفر وحفظها محلياً
  Future<void> syncNotificationsWithServer() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? sessionId = prefs.getString('session_cookie') ?? prefs.getString('PHPSESSID');

    try {
      final baseUrl = ApiClient().baseUrl;
      final response = await http.post(
        Uri.parse('$baseUrl/notifications_action.php'),
        headers: {
          'Cookie': sessionId != null ? (sessionId.contains('PHPSESSID') ? sessionId : 'PHPSESSID=$sessionId') : '',
        },
        body: {
          'action': 'get_notifications',
        },
      );

      final data = json.decode(response.body);
      if (data['success'] == true) {
        final serverNotifs = data['notifications'] as List<dynamic>;
        final dbHelper = DatabaseHelper();
        
        // حفظ إشعارات السيرفر في قاعدة البيانات المحلية SQLite
        for (var notif in serverNotifs) {
          await dbHelper.insertNotification({
            'id': notif['id'].toString(),
            'title': notif['title'] ?? 'تنبيه جديد',
            'message': notif['message'] ?? '',
            'created_at': notif['created_at'] ?? DateTime.now().toIso8601String(),
            'is_read': (notif['is_read'] == 1 || notif['is_read'] == "1") ? 1 : 0,
            'is_received': (notif['is_received'] == 1 || notif['is_received'] == "1") ? 1 : 0,
            'type': notif['type'] ?? 'general',
          });
        }
        
        // إعادة تحميل البيانات محلياً لعرضها
        await loadLocalNotifications();
      }
    } catch (e) {
      print('Error syncing notifications with server: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // وضع الإشعار كـ مقروء محلياً وسيرفر
  Future<void> markAsRead(String id) async {
    // 1. التحديث محلياً أولاً للاستجابة اللحظية في الواجهة
    try {
      final dbHelper = DatabaseHelper();
      await dbHelper.markNotificationAsRead(id);
      await loadLocalNotifications();
    } catch (e) {
      print('Error marking notification as read locally: $e');
    }

    // 2. تحديث السيرفر
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? sessionId = prefs.getString('session_cookie') ?? prefs.getString('PHPSESSID');

    try {
      final baseUrl = ApiClient().baseUrl;
      await http.post(
        Uri.parse('$baseUrl/notifications_action.php'),
        headers: {
          'Cookie': sessionId != null ? (sessionId.contains('PHPSESSID') ? sessionId : 'PHPSESSID=$sessionId') : '',
        },
        body: {
          'action': 'mark_as_read',
          'notification_id': id,
        },
      );
    } catch (e) {
      print('Error marking notification as read on server: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('الإشعارات', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? Center(child: Text('لا توجد إشعارات حالياً', style: TextStyle(fontSize: 18, color: Colors.grey)))
              : ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    var notif = notifications[index];
                    bool isRead = notif['is_read'] == 1 || notif['is_read'] == "1";
                    
                    return Card(
                      color: isRead ? Colors.white : Colors.blue.shade50,
                      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        leading: Icon(
                          notif['type'] == 'invoice' ? Icons.receipt_long : Icons.notifications,
                          color: isRead ? Colors.grey : Colors.indigo,
                        ),
                        title: Text(
                          notif['title'] ?? 'بدون عنوان',
                          style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 5),
                            Text(notif['message'] ?? ''),
                            SizedBox(height: 5),
                            Text(
                              notif['created_at'] ?? '',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                        onTap: () {
                          if (!isRead) {
                            markAsRead(notif['id'].toString());
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
