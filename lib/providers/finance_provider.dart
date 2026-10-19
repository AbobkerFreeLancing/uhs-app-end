import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/network/api_client.dart';
import '../core/services/notification_service.dart';
import '../core/database/database_helper.dart';

// ─── Local Notification Model ───────────────────────────────────────────────

class LocalNotification {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  bool isRead;

  LocalNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
      };

  factory LocalNotification.fromJson(Map<String, dynamic> json) => LocalNotification(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        message: json['message'] ?? '',
        timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
        isRead: json['isRead'] ?? false,
      );
}

// ─── Finance Provider ────────────────────────────────────────────────────────

class FinanceProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<dynamic> _invoices = [];
  List<dynamic> _installments = [];
  List<dynamic> _banks = [];
  Map<String, dynamic> _summary = {
    'required': '0.00',
    'paid': '0.00',
    'in_progress': '0.00'
  };

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // الإشعارات المحلية واللحظية
  List<LocalNotification> _notifications = [];
  bool _notifsLoaded = false;

  // Getters
  List<dynamic> get invoices => _invoices;
  List<dynamic> get installments => _installments;
  List<dynamic> get banks => _banks;
  Map<String, dynamic> get summary => _summary;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  List<LocalNotification> get notifications {
    if (!_notifsLoaded) {
      _loadCachedNotifications();
    }
    return _notifications;
  }
  int get unreadNotificationsCount {
    if (!_notifsLoaded) {
      _loadCachedNotifications();
    }
    return _notifications.where((n) => !n.isRead).length;
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
  }

  // تحميل الإشعارات المخزنة محلياً
  Future<void> _loadCachedNotifications() async {
    _notifsLoaded = true;
    try {
      final dbHelper = DatabaseHelper();
      final List<Map<String, dynamic>> maps = await dbHelper.getNotifications();
      _notifications = maps.map((item) => LocalNotification(
        id: item['id'] ?? '',
        title: item['title'] ?? '',
        message: item['message'] ?? '',
        timestamp: DateTime.tryParse(item['timestamp'] ?? '') ?? DateTime.now(),
        isRead: item['is_read'] == 1,
      )).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading cached notifications: $e');
    }
  }

  // تحميل البيانات المالية المخزنة محلياً عند بدء تشغيل التطبيق دون إنترنت
  Future<void> loadCachedFinancials() async {
    try {
      final dbHelper = DatabaseHelper();
      final cachedInvoices = await dbHelper.getInvoices();
      if (cachedInvoices.isNotEmpty) {
        _invoices = cachedInvoices.map((inv) => {
          'id': inv['id'],
          'invoice_number': inv['invoice_number'],
          'title': inv['title'],
          'total_amount': inv['total_amount']?.toString(),
          'status': inv['status'],
          'rejection_note': inv['rejection_note'],
          'created_at': inv['created_at'],
        }).toList();
      }

      final cachedSummaryStr = await dbHelper.getCache('financial_summary');
      if (cachedSummaryStr != null) {
        _summary = json.decode(cachedSummaryStr);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading cached financials: $e');
    }
  }

  // تحديد كل الإشعارات كمقروءة
  Future<void> markAllNotificationsAsRead() async {
    try {
      final dbHelper = DatabaseHelper();
      await dbHelper.markAllNotificationsAsRead();
      for (var n in _notifications) {
        n.isRead = true;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  // تحديد إشعار معين كمقروء
  Future<void> markNotificationAsRead(String id) async {
    try {
      final dbHelper = DatabaseHelper();
      await dbHelper.markNotificationAsRead(id);
      final idx = _notifications.indexWhere((n) => n.id == id);
      if (idx != -1) {
        _notifications[idx].isRead = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  // مسح جميع الإشعارات
  Future<void> clearNotifications() async {
    try {
      final dbHelper = DatabaseHelper();
      await dbHelper.clearNotifications();
      _notifications.clear();
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
    }
  }

  // مقارنة البيانات الحالية بالسابقة لتوليد إشعارات لحظية محلياً
  Future<void> _checkAndGenerateNotifications(List<dynamic> newInvoices) async {
    try {
      final dbHelper = DatabaseHelper();
      final cachedInvoices = await dbHelper.getInvoices();
      
      Map<String, dynamic> cachedMap = {};
      if (cachedInvoices.isNotEmpty) {
        for (var row in cachedInvoices) {
          cachedMap[row['id'].toString()] = {
            'status': row['status'],
            'rejection_note': row['rejection_note'],
            'total_amount': row['total_amount'],
            'invoice_number': row['invoice_number'],
            'title': row['title'],
          };
        }
      }

      final List<LocalNotification> newGeneratedNotifications = [];

      for (var inv in newInvoices) {
        final String id = inv['id'].toString();
        final String invoiceNum = inv['invoice_number'] ?? '';
        final String status = inv['status'] ?? 'unpaid';
        final String rejectionNote = inv['rejection_note'] ?? '';
        final double amount = double.tryParse(inv['total_amount']?.toString() ?? '0') ?? 0.0;
        final String title = inv['title'] ?? 'فاتورة رسوم دراسية';

        // نولد إشعاراً فقط إذا كانت هناك بيانات سابقة مخزنة (لتجنب إشعار أول تشغيل بالبيانات القديمة)
        if (cachedMap.isNotEmpty) {
          if (!cachedMap.containsKey(id)) {
            // فاتورة جديدة تمت إضافتها
            final titleMsg = 'فاتورة جديدة';
            final bodyMsg = 'تم إصدار فاتورة جديدة رقم #$invoiceNum بقيمة ${amount.toStringAsFixed(0)} ج.س للـ: $title';
            final notifId = 'add_${id}_${DateTime.now().millisecondsSinceEpoch}';

            await dbHelper.insertNotification({
              'id': notifId,
              'title': titleMsg,
              'message': bodyMsg,
              'timestamp': DateTime.now().toIso8601String(),
              'is_read': 0,
              'is_received': 1,
              'type': 'invoice',
            });

            newGeneratedNotifications.add(LocalNotification(
              id: notifId,
              title: titleMsg,
              message: bodyMsg,
              timestamp: DateTime.now(),
            ));
            
            // إظهار إشعار في الستارة العلوية للجهاز كرسالة النظام
            NotificationService.showSystemNotification(
              id: int.tryParse(id) ?? DateTime.now().millisecondsSinceEpoch,
              title: titleMsg,
              body: bodyMsg,
            );
          } else {
            final oldInv = cachedMap[id];
            final oldStatus = oldInv['status'];
            final oldRejection = oldInv['rejection_note'];

            // 1. تغيير حالة الفاتورة
            if (oldStatus != status) {
              String statusAr = status;
              if (status == 'paid') statusAr = 'مسددة';
              else if (status == 'unpaid') statusAr = 'معلقة';
              else if (status == 'payment_requests' || status == 'In progress') statusAr = 'قيد المراجعة والتدقيق';
              else if (status == 'partial') statusAr = 'مسددة جزئياً';

              final titleMsg = 'تحديث حالة الفاتورة';
              final bodyMsg = 'تم تحديث حالة الفاتورة رقم #$invoiceNum إلى: $statusAr';
              final notifId = 'status_${id}_${DateTime.now().millisecondsSinceEpoch}';

              await dbHelper.insertNotification({
                'id': notifId,
                'title': titleMsg,
                'message': bodyMsg,
                'timestamp': DateTime.now().toIso8601String(),
                'is_read': 0,
                'is_received': 1,
                'type': 'invoice',
              });

              newGeneratedNotifications.add(LocalNotification(
                id: notifId,
                title: titleMsg,
                message: bodyMsg,
                timestamp: DateTime.now(),
              ));

              // إظهار إشعار في الستارة العلوية للجهاز كرسالة النظام
              NotificationService.showSystemNotification(
                id: (int.tryParse(id) ?? DateTime.now().millisecondsSinceEpoch) + 100000,
                title: titleMsg,
                body: bodyMsg,
              );
            }

            // 2. تغيير أو إضافة ملاحظة رفض
            if (rejectionNote.isNotEmpty && oldRejection != rejectionNote) {
              final titleMsg = 'تنبيه بخصوص الفاتورة';
              final bodyMsg = 'تنبيه للفاتورة رقم #$invoiceNum: $rejectionNote';
              final notifId = 'note_${id}_${DateTime.now().millisecondsSinceEpoch}';

              await dbHelper.insertNotification({
                'id': notifId,
                'title': titleMsg,
                'message': bodyMsg,
                'timestamp': DateTime.now().toIso8601String(),
                'is_read': 0,
                'is_received': 1,
                'type': 'invoice',
              });

              newGeneratedNotifications.add(LocalNotification(
                id: notifId,
                title: titleMsg,
                message: bodyMsg,
                timestamp: DateTime.now(),
              ));

              // إظهار إشعار في الستارة العلوية للجهاز كرسالة النظام
              NotificationService.showSystemNotification(
                id: (int.tryParse(id) ?? DateTime.now().millisecondsSinceEpoch) + 200000,
                title: titleMsg,
                body: bodyMsg,
              );
            }
          }
        }
      }

      // حفظ الحالة الجديدة للفواتير لتكون المرجع المستقبلي في SQLite
      await dbHelper.saveInvoices(newInvoices);

      if (newGeneratedNotifications.isNotEmpty) {
        if (!_notifsLoaded) {
          await _loadCachedNotifications();
        }
        _notifications.insertAll(0, newGeneratedNotifications);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error checking notifications: $e');
    }
  }

  // جلب الفواتير والأقساط والبنوك والملخص المالي من الـ API
  Future<void> fetchFinancials() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.post('finance_action.php', body: {
        'action': 'get_financials',
      });

      final Map<String, dynamic> data = json.decode(response.body);

      if (data['success'] == true) {
        final List<dynamic> fetchedInvoices = data['invoices'] ?? [];
        _invoices = fetchedInvoices;
        _installments = data['installments'] ?? [];
        _banks = data['banks'] ?? [];
        if (data['summary'] != null) {
          _summary = Map<String, dynamic>.from(data['summary']);
        }
        
        // حفظ الملخص في قاعدة البيانات المحلية SQLite
        final dbHelper = DatabaseHelper();
        await dbHelper.saveCache('financial_summary', json.encode(_summary));
        
        // التحقق وتوليد الإشعارات محلياً
        await _checkAndGenerateNotifications(fetchedInvoices);
      } else {
        _errorMessage = data['message'] ?? 'فشل في جلب البيانات المالية للمستفيد';
      }
    } catch (e) {
      _errorMessage = 'حدث خطأ في الاتصال بالشبكة. يرجى التحقق من اتصال الإنترنت والمحاولة لاحقاً.';
    }

    _isLoading = false;
    notifyListeners();
  }

  // إرسال إشعار تحويل بنكي جديد أو تحديث طلب دفع مرفوض
  Future<bool> uploadReceipt({
    required int invoiceId,
    required String transactionNumber,
    required String bankName,
    String? receiptFilePath, // قد يكون null في حال تحديث الرقم والبنك بدون تغيير الصورة
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final List<MultipartFileParam> files = [];

      if (receiptFilePath != null) {
        files.add(MultipartFileParam(
          key: 'receipt',
          filePath: receiptFilePath,
          filename: 'receipt.jpg',
        ));
      }

      final Map<String, String> fields = {
        'action': 'upload_receipt',
        'invoice_id': invoiceId.toString(),
        'transaction_number': transactionNumber,
        'bank_name': bankName,
      };

      final streamedResponse = await _apiClient.postMultipart(
        'finance_action.php',
        fields: fields,
        files: files.isNotEmpty ? files : null,
      );

      final response = await http.Response.fromStream(streamedResponse);
      final Map<String, dynamic> data = json.decode(response.body);

      if (data['success'] == true) {
        _successMessage = data['message'] ?? 'تم إرسال إيصال السداد بنجاح';
        
        // جلب البيانات مجدداً لتحديث قائمة الفواتير والملخص في الشاشة
        await fetchFinancials();
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['message'] ?? 'فشل في رفع إيصال السداد';
      }
    } catch (e) {
      _errorMessage = 'حدث خطأ في الاتصال بالشبكة. يرجى التحقق من اتصال الإنترنت والمحاولة لاحقاً.';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }
}
