import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/network/api_client.dart';

class ProfileProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  Map<String, dynamic>? _profileData;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Getters
  Map<String, dynamic>? get profileData => _profileData;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
  }

  // جلب بيانات الطالب الشخصية كاملة من الـ API
  Future<void> fetchProfile() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.post('profile_action.php', body: {
        'action': 'get_profile',
      });

      final Map<String, dynamic> data = json.decode(response.body);

      if (data['success'] == true) {
        _profileData = data['profile'];
      } else {
        _errorMessage = data['message'] ?? 'فشل في تحميل بيانات الطالب الشخصية';
      }
    } catch (e) {
      _errorMessage = 'حدث خطأ في الاتصال بالشبكة. يرجى التحقق من اتصال الإنترنت والمحاولة لاحقاً.';
    }

    _isLoading = false;
    notifyListeners();
  }

  // تحديث البيانات ورفع المستندات (صورة الشخصية، الشهادة، البطاقة الوطنية)
  Future<bool> updateProfile({
    required Map<String, String> fields,
    String? photoPath,
    String? certPhotoPath,
    String? idPhotoPath,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final List<MultipartFileParam> files = [];

      if (photoPath != null) {
        files.add(MultipartFileParam(
          key: 'photo',
          filePath: photoPath,
          filename: 'photo.jpg',
        ));
      }
      if (certPhotoPath != null) {
        files.add(MultipartFileParam(
          key: 'cert_photo',
          filePath: certPhotoPath,
          filename: 'cert.jpg',
        ));
      }
      if (idPhotoPath != null) {
        files.add(MultipartFileParam(
          key: 'id_photo',
          filePath: idPhotoPath,
          filename: 'id.jpg',
        ));
      }

      fields['action'] = 'update_profile';

      final streamedResponse = await _apiClient.postMultipart(
        'profile_action.php',
        fields: fields,
        files: files.isNotEmpty ? files : null,
      );

      final response = await http.Response.fromStream(streamedResponse);
      final Map<String, dynamic> data = json.decode(response.body);

      if (data['success'] == true) {
        _successMessage = data['message'] ?? 'تم تحديث الملف الشخصي بنجاح';
        
        // إعادة جلب الملف الشخصي لتحديث البيانات المعروضة في الشاشة
        await fetchProfile();
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['message'] ?? 'فشل في تحديث ملف الطالب';
      }
    } catch (e) {
      _errorMessage = 'حدث خطأ في الاتصال بالشبكة. يرجى التحقق من اتصال الإنترنت والمحاولة لاحقاً.';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // تحديث بيانات الأمان (البريد الإلكتروني وكلمة المرور)
  Future<bool> updateSecurity({
    String? email,
    String? password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final Map<String, String> body = {
        'action': 'update_security',
      };
      if (email != null && email.isNotEmpty) {
        body['email'] = email;
      }
      if (password != null && password.isNotEmpty) {
        body['password'] = password;
      }

      final response = await _apiClient.post('profile_action.php', body: body);
      final Map<String, dynamic> data = json.decode(response.body);

      if (data['success'] == true) {
        _successMessage = data['message'] ?? 'تم تحديث بيانات الأمان بنجاح';
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['message'] ?? 'فشل في تحديث بيانات الأمان';
      }
    } catch (e) {
      _errorMessage = 'حدث خطأ في الاتصال بالشبكة. يرجى التحقق من اتصال الإنترنت والمحاولة لاحقاً.';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }
}
