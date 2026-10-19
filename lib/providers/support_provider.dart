import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/network/api_client.dart';

class SupportProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<dynamic> _tickets = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Getters
  List<dynamic> get tickets => _tickets;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
  }

  // جلب جميع تذاكر الدعم الفني الخاصة بالطالب
  Future<void> fetchTickets() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.get('get_support_tickets.php');
      final Map<String, dynamic> data = json.decode(response.body);

      if (data['success'] == true) {
        _tickets = data['data'] ?? [];
      } else {
        _errorMessage = data['message'] ?? 'فشل في جلب تذاكر الدعم الفني';
      }
    } catch (e) {
      _errorMessage = 'حدث خطأ في الاتصال بالشبكة. يرجى التحقق من اتصال الإنترنت والمحاولة لاحقاً.';
    }

    _isLoading = false;
    notifyListeners();
  }

  // إنشاء تذكرة دعم فني جديدة أو إعادة إرسال تذكرة معدلة
  Future<bool> createTicket({
    required String title,
    required String description,
    String? attachmentPath,
    int? editId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final List<MultipartFileParam> files = [];

      if (attachmentPath != null) {
        files.add(MultipartFileParam(
          key: 'attachment',
          filePath: attachmentPath,
          filename: 'attachment_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));
      }

      final Map<String, String> fields = {
        'title': title,
        'desc': description,
      };

      if (editId != null) {
        fields['edit_id'] = editId.toString();
      }

      final streamedResponse = await _apiClient.postMultipart(
        'save_support_ticket.php',
        fields: fields,
        files: files.isNotEmpty ? files : null,
      );

      final response = await http.Response.fromStream(streamedResponse);
      final Map<String, dynamic> data = json.decode(response.body);

      if (data['success'] == true) {
        _successMessage = data['message'] ?? 'تم إرسال تذكرة الدعم الفني بنجاح';
        
        // جلب قائمة التذاكر مجدداً لتحديث القائمة المعروضة
        await fetchTickets();
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['message'] ?? 'فشل في إرسال تذكرة الدعم الفني';
      }
    } catch (e) {
      _errorMessage = 'حدث خطأ في الاتصال بالشبكة. يرجى التحقق من اتصال الإنترنت والمحاولة لاحقاً.';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }
}
