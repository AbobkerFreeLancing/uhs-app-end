import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/api_client.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  // نسخة التطبيق الحالية
  static const String appVersion = '1.0.0';

  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _errorMessage;

  // حالة تحديث التطبيق الإجباري
  bool _forceUpdate = false;
  String? _updateUrl;

  // بيانات الطالب النشط
  String? _studentId;
  String? _studentName;
  String? _seatNumber;
  String? _photoPath;
  String? _batchCode;
  bool _needsProfileCompletion = false;

  // Getters
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get forceUpdate => _forceUpdate;
  String? get updateUrl => _updateUrl;
  
  String? get studentId => _studentId;
  String? get studentName => _studentName;
  String? get seatNumber => _seatNumber;
  String? get photoPath => _photoPath;
  String? get batchCode => _batchCode;
  bool get needsProfileCompletion => _needsProfileCompletion;

  // فحص حالة تسجيل الدخول المخزنة عند تشغيل التطبيق
  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    await _apiClient.init();
    final prefs = await SharedPreferences.getInstance();
    
    final savedUserId = prefs.getString('user_id');
    final savedCookie = prefs.getString('session_cookie');

    if (savedUserId != null && savedCookie != null) {
      _isLoggedIn = true;
      _studentId = prefs.getString('student_id');
      _studentName = prefs.getString('student_name');
      _seatNumber = prefs.getString('seat_number');
      _photoPath = prefs.getString('photo_path');
      _batchCode = prefs.getString('batch_code');
      _needsProfileCompletion = prefs.getBool('needs_profile_completion') ?? false;
    } else {
      _isLoggedIn = false;
      await _apiClient.clearSession();
    }

    _isLoading = false;
    notifyListeners();
  }

  // تسجيل الدخول
  Future<bool> login(String studentId, String password) async {
    _isLoading = true;
    _errorMessage = null;
    _forceUpdate = false;
    _updateUrl = null;
    notifyListeners();

    try {
      final response = await _apiClient.post('auth.php', body: {
        'action': 'login',
        'student_id': studentId,
        'password': password,
        'app_version': appVersion,
      });

      final Map<String, dynamic> data = json.decode(response.body);

      if (data['success'] == true) {
        // بعد تسجيل الدخول الناجح في PHP، الجلسة تكون قد بدأت وتم تخزين الـ Cookie تلقائياً في الـ ApiClient.
        // الآن نقوم بجلب بيانات الملف الشخصي لتخزينها محلياً للتطبيق
        final profileResponse = await _apiClient.post('profile_action.php', body: {
          'action': 'get_profile',
        });

        final Map<String, dynamic> profileData = json.decode(profileResponse.body);

        if (profileData['success'] == true) {
          final profile = profileData['profile'];
          _studentId = profile['id'].toString();
          _studentName = profile['full_name'];
          _seatNumber = profile['seat_number'];
          _photoPath = profile['photo_path'];
          _batchCode = profile['batch_code']; // قد يكون null في البداية
          
          // تحديد إن كان يحتاج لإكمال الملف
          _needsProfileCompletion = (profile['student_phone'] == '0000000000' || profile['birth_date'] == '2000-01-01');

          // حفظ البيانات في SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_id', profile['user_id'].toString());
          await prefs.setString('student_id', _studentId!);
          await prefs.setString('student_name', _studentName!);
          await prefs.setString('seat_number', _seatNumber!);
          if (_photoPath != null) await prefs.setString('photo_path', _photoPath!);
          if (_batchCode != null) await prefs.setString('batch_code', _batchCode!);
          await prefs.setBool('needs_profile_completion', _needsProfileCompletion);

          _isLoggedIn = true;
          _isLoading = false;
          notifyListeners();
          return true;
        } else {
          _errorMessage = profileData['message'] ?? 'فشل في تحميل بيانات الملف الشخصي بعد تسجيل الدخول';
        }
      } else {
        _errorMessage = data['message'] ?? 'الرقم الجامعي أو كلمة المرور غير صحيحة';
        if (data['force_update'] == true) {
          _forceUpdate = true;
          _updateUrl = data['update_url'];
        }
      }
    } catch (e) {
      _errorMessage = 'حدث خطأ في الاتصال بالشبكة. يرجى التحقق من اتصال الإنترنت والمحاولة لاحقاً.';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // إنشاء حساب جديد
  Future<bool> register({
    required String fullName,
    required String studentId,
    required String nationalId,
    required int stateId,
    required int programId,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.post('auth.php', body: {
        'action': 'register',
        'full_name': fullName,
        'student_id': studentId,
        'national_id': nationalId,
        'state': stateId.toString(),
        'program': programId.toString(),
        'password': password,
      });

      final Map<String, dynamic> data = json.decode(response.body);

      if (data['success'] == true) {
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['message'] ?? 'فشل في إنشاء الحساب';
      }
    } catch (e) {
      _errorMessage = 'حدث خطأ في الاتصال بالشبكة. يرجى التحقق من اتصال الإنترنت والمحاولة لاحقاً.';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // جلب قائمة التخصصات/البرامج لولاية معينة
  Future<List<Map<String, dynamic>>> getPrograms(int stateId) async {
    try {
      final response = await _apiClient.post('auth.php', body: {
        'action': 'get_programs',
        'state_id': stateId.toString(),
      });
      final data = json.decode(response.body);
      if (data['success'] == true && data['programs'] != null) {
        return List<Map<String, dynamic>>.from(data['programs']);
      }
    } catch (e) {
      debugPrint('Error getting programs: $e');
    }
    return [];
  }

  // جلب قائمة الولايات الفعّالة من قاعدة البيانات ديناميكياً
  Future<List<Map<String, dynamic>>> getStates() async {
    try {
      final response = await _apiClient.post('auth.php', body: {
        'action': 'get_states',
      });
      final data = json.decode(response.body);
      if (data['success'] == true && data['states'] != null) {
        return List<Map<String, dynamic>>.from(data['states']);
      }
    } catch (e) {
      debugPrint('Error getting states: $e');
    }
    return [];
  }

  // تحديث الصورة الشخصية محلياً عند تغييرها من شاشة الحساب
  void updateLocalPhoto(String? path) async {
    _photoPath = path;
    final prefs = await SharedPreferences.getInstance();
    if (path != null) {
      await prefs.setString('photo_path', path);
    } else {
      await prefs.remove('photo_path');
    }
    notifyListeners();
  }

  // تحديث حالة إكمال الحساب محلياً
  void markProfileCompleted() async {
    _needsProfileCompletion = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('needs_profile_completion', false);
    notifyListeners();
  }

  // تسجيل الخروج
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      // إرسال طلب تسجيل الخروج للخادم لإلغاء الجلسة هناك
      await _apiClient.post('../logout.php');
    } catch (e) {
      debugPrint('Error logging out from server: $e');
    }

    // مسح الجلسة محلياً بالكامل مع الحفاظ على الرقم الجامعي
    await _apiClient.clearSession();
    final prefs = await SharedPreferences.getInstance();
    final String? savedStudentId = prefs.getString('saved_student_id');
    await prefs.clear();
    if (savedStudentId != null) {
      await prefs.setString('saved_student_id', savedStudentId);
    }

    _isLoggedIn = false;
    _studentId = null;
    _studentName = null;
    _seatNumber = null;
    _photoPath = null;
    _batchCode = null;
    _needsProfileCompletion = false;
    
    _isLoading = false;
    notifyListeners();
  }
}
