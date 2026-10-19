import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/network/api_client.dart';

class GuidanceProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<dynamic> _requests = [];
  List<dynamic> _chatMessages = [];
  String _activeChatStatus = 'جديد';

  bool _isLoading = false;
  bool _isChatLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Getters
  List<dynamic> get requests => _requests;
  List<dynamic> get chatMessages => _chatMessages;
  String get activeChatStatus => _activeChatStatus;
  bool get isLoading => _isLoading;
  bool get isChatLoading => _isChatLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
  }

  // جلب جميع طلبات الرعاية والتوجيه الخاصة بالطالب
  Future<void> fetchRequests() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.get('get_affairs_requests.php');
      final Map<String, dynamic> data = json.decode(response.body);

      if (data['success'] == true) {
        _requests = data['data'] ?? [];
      } else {
        _errorMessage = data['message'] ?? 'فشل في جلب طلبات الرعاية والتوجيه';
      }
    } catch (e) {
      _errorMessage = 'حدث خطأ في الاتصال بالشبكة. يرجى التحقق من اتصال الإنترنت والمحاولة لاحقاً.';
    }

    _isLoading = false;
    notifyListeners();
  }

  // فتح طلب رعاية وتوجيه جديد
  Future<int?> createRequest({
    required String title,
    required String type,
    required String description,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.post('create_affairs_request.php', body: {
        'title': title,
        'type': type,
        'desc': description,
      });

      final Map<String, dynamic> data = json.decode(response.body);

      if (data['success'] == true) {
        _successMessage = data['message'] ?? 'تم فتح طلب الرعاية بنجاح';
        
        // إعادة جلب الطلبات لتحديث القائمة الرئيسية
        await fetchRequests();
        
        _isLoading = false;
        notifyListeners();
        return data['request_id'];
      } else {
        _errorMessage = data['message'] ?? 'فشل في فتح طلب الرعاية والتوجيه';
      }
    } catch (e) {
      _errorMessage = 'حدث خطأ في الاتصال بالشبكة. يرجى التحقق من اتصال الإنترنت والمحاولة لاحقاً.';
    }

    _isLoading = false;
    notifyListeners();
    return null;
  }

  // جلب المحادثة ورسائل الشات لطلب معين
  Future<void> fetchChatHistory(int requestId) async {
    _isChatLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.get('get_affairs_chat.php', queryParams: {
        'request_id': requestId.toString(),
      });
      final Map<String, dynamic> data = json.decode(response.body);

      if (data['success'] == true) {
        _chatMessages = data['data'] ?? [];
        _activeChatStatus = data['status'] ?? 'جديد';
      } else {
        _errorMessage = data['message'] ?? 'فشل في تحميل رسائل محادثة الرعاية';
      }
    } catch (e) {
      _errorMessage = 'حدث خطأ في الاتصال بالشبكة. يرجى التحقق من اتصال الإنترنت والمحاولة لاحقاً.';
    }

    _isChatLoading = false;
    notifyListeners();
  }

  // إرسال رسالة شات جديدة (مع إمكانية إرفاق ملف/صورة/تسجيل صوتي)
  Future<bool> sendChatMessage({
    required int requestId,
    required String message,
    String? attachmentPath,
  }) async {
    _errorMessage = null;
    _successMessage = null;
    // لا نحتاج لتعطيل الشاشة بأكملها عند إرسال رسالة (فقط تشغيل مؤشر إرسال خفيف في الشات)
    notifyListeners();

    try {
      final List<MultipartFileParam> files = [];

      if (attachmentPath != null) {
        // تحديد نوع واسم الملف المناسب عند الرفع
        final filename = attachmentPath.split('/').last;
        files.add(MultipartFileParam(
          key: 'attachment',
          filePath: attachmentPath,
          filename: filename,
        ));
      }

      final Map<String, String> fields = {
        'request_id': requestId.toString(),
        'message': message,
      };

      final streamedResponse = await _apiClient.postMultipart(
        'send_affairs_message.php',
        fields: fields,
        files: files.isNotEmpty ? files : null,
      );

      final response = await http.Response.fromStream(streamedResponse);
      final Map<String, dynamic> data = json.decode(response.body);

      if (data['success'] == true) {
        _successMessage = data['message'] ?? 'تم إرسال الرسالة بنجاح';
        
        // إعادة جلب الشات فوراً لرؤية الرسالة الجديدة ومرفقاتها
        await fetchChatHistory(requestId);
        return true;
      } else {
        _errorMessage = data['message'] ?? 'فشل في إرسال الرسالة';
      }
    } catch (e) {
      _errorMessage = 'حدث خطأ في الاتصال بالشبكة. يرجى التحقق من اتصال الإنترنت والمحاولة لاحقاً.';
    }

    notifyListeners();
    return false;
  }
}
