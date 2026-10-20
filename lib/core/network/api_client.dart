import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// بيئات التشغيل المتاحة للنظام
enum AppEnvironment {
  /// السيرفر الإنتاجي الرسمي (Production Live)
  production,

  /// بيئة التطوير المحلية عبر خادم Laragon
  localLaragon,

  /// بيئة محاكي الأندرويد للاتصال بـ Laragon المحلي (10.0.2.2)
  androidEmulator,

  /// بيئة مخصصة (Custom IP أو شبكة محلية Wi-Fi)
  custom,
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  /// --------------------------------------------------------------------------
  /// إعدادات الروابط والبيئات
  /// قم بتغيير [activeEnvironment] للتبديل بين السيرفر المحلي والإنتاجي
  /// --------------------------------------------------------------------------
  static const AppEnvironment activeEnvironment = AppEnvironment.localLaragon;

  // الرابط الرسمي المعتمد عند النشر والرفع على السيرفر
  static const String productionUrl = 'https://reg.uhs-edu.cloud/student/api';

  // رابط Laragon المحلي (منفذ Apache في Laragon هو 8080)
  static const String localLaragonUrl = 'http://uhs-sys.test:8080/student/api';

  // رابط محاكي الأندرويد للاتصال بسيرفر Laragon المحلي
  static const String emulatorUrl = 'http://10.0.2.2:8080/student/api';

  // رابط مخصص (في حال الاختبار عبر جهاز حقيقي متصل بنفس شبكة الـ Wi-Fi)
  static String? customUrl;

  // عنوان الخادم الأساسي الفعلي
  String _baseUrl = productionUrl;

  // معرّف الجلسة (PHP Session Cookie)
  String? _cookie;

  // توكن المصادقة الرسمي (Laravel Sanctum Token)
  String? _token;

  String get baseUrl => _baseUrl;
  String? get currentToken => _token;
  String? get currentCookie => _cookie;

  void setBaseUrl(String newUrl) {
    _baseUrl = newUrl;
  }

  /// تهيئة واستعادة معرّف الجلسة والتوكن من التخزين المحلي
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _cookie = prefs.getString('session_cookie');
    _token = prefs.getString('auth_token');

    // تحديد عنوان الخادم المناسب وفق البيئة المحددة ونوع الجهاز
    switch (activeEnvironment) {
      case AppEnvironment.production:
        _baseUrl = productionUrl;
        break;

      case AppEnvironment.localLaragon:
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          // محاكي الأندرويد يحتاج 10.0.2.2 للوصول لـ localhost الخاص بالكمبيوتر
          _baseUrl = emulatorUrl;
        } else {
          _baseUrl = localLaragonUrl;
        }
        break;

      case AppEnvironment.androidEmulator:
        _baseUrl = emulatorUrl;
        break;

      case AppEnvironment.custom:
        _baseUrl = customUrl ?? localLaragonUrl;
        break;
    }

    debugPrint('UHS ApiClient Initialized with BaseUrl: $_baseUrl');
  }

  /// حفظ معرّف الجلسة (PHPSESSID)
  Future<void> saveCookie(String rawCookie) async {
    final index = rawCookie.indexOf('PHPSESSID=');
    if (index != -1) {
      final endIndex = rawCookie.indexOf(';', index);
      final cookie = endIndex == -1 ? rawCookie.substring(index) : rawCookie.substring(index, endIndex);
      _cookie = cookie;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_cookie', cookie);
    }
  }

  /// حفظ توكن Sanctum الصادر من الخادم
  Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  /// مسح بيانات الجلسة (عند تسجيل الخروج)
  Future<void> clearSession() async {
    _cookie = null;
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_cookie');
    await prefs.remove('auth_token');
  }

  /// دمج الترويسات الافتراضية مع الترويسات المخصصة
  Map<String, String> _getHeaders(Map<String, String>? customHeaders) {
    final Map<String, String> headers = {
      'Accept': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
    };

    // إرفاق توكن Sanctum في الترويسات القياسية
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }

    // إرفاق كوكي الجلسة
    if (_cookie != null && _cookie!.isNotEmpty) {
      headers['Cookie'] = _cookie!;
    }

    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }
    return headers;
  }

  /// تنفيذ طلب POST اعتيادي
  Future<http.Response> post(String endpoint, {Map<String, String>? body}) async {
    final uri = Uri.parse('$_baseUrl/$endpoint');
    final response = await http.post(
      uri,
      headers: _getHeaders(null),
      body: body,
    );

    // إذا أرجع الخادم ترويسة Set-Cookie، نقوم بحفظها
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null) {
      await saveCookie(setCookie);
    }

    // استخراج توكن Sanctum تلقائياً إن وجد في استجابة تسجيل الدخول
    try {
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) {
        if (data['token'] != null) {
          await saveToken(data['token'].toString());
        } else if (data['data'] is Map && data['data']['auth_token'] != null) {
          await saveToken(data['data']['auth_token'].toString());
        }
      }
    } catch (_) {}

    return response;
  }

  /// تنفيذ طلب GET اعتيادي
  Future<http.Response> get(String endpoint, {Map<String, String>? queryParams}) async {
    var uriString = '$_baseUrl/$endpoint';
    if (queryParams != null && queryParams.isNotEmpty) {
      final query = Uri(queryParameters: queryParams).query;
      uriString += '?$query';
    }
    final uri = Uri.parse(uriString);
    return await http.get(
      uri,
      headers: _getHeaders(null),
    );
  }

  /// تنفيذ طلب POST يحتوي على ملفات (Multipart Request)
  Future<http.StreamedResponse> postMultipart(
    String endpoint, {
    required Map<String, String> fields,
    List<MultipartFileParam>? files,
  }) async {
    final uri = Uri.parse('$_baseUrl/$endpoint');
    final request = http.MultipartRequest('POST', uri);

    request.headers.addAll(_getHeaders(null));
    request.fields.addAll(fields);

    if (files != null) {
      for (final fileParam in files) {
        if (fileParam.filePath != null) {
          final file = await http.MultipartFile.fromPath(
            fileParam.key,
            fileParam.filePath!,
            filename: fileParam.filename,
          );
          request.files.add(file);
        } else if (fileParam.bytes != null) {
          final file = http.MultipartFile.fromBytes(
            fileParam.key,
            fileParam.bytes!,
            filename: fileParam.filename,
          );
          request.files.add(file);
        }
      }
    }

    return await request.send();
  }
}

/// معلمة الملف لطلبات الـ Multipart
class MultipartFileParam {
  final String key;
  final String? filePath;
  final List<int>? bytes;
  final String filename;

  MultipartFileParam({
    required this.key,
    this.filePath,
    this.bytes,
    required this.filename,
  });
}
