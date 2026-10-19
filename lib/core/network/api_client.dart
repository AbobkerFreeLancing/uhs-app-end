import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  // عنوان الخادم الأساسي للـ APIs (قابل للتخصيص)
  String _baseUrl = 'https://uhos.online/student/api';
  
  // معرّف الجلسة المخزن مؤقتاً
  String? _cookie;

  String get baseUrl => _baseUrl;

  void setBaseUrl(String newUrl) {
    _baseUrl = newUrl;
  }

  // تهيئة واستعادة معرّف الجلسة من التخزين المحلي
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _cookie = prefs.getString('session_cookie');
    
    // للاتصال المباشر بسيرفر الإنتاج، لا نقوم بتحويل العنوان في المحاكي
    /*
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _baseUrl = 'http://10.0.2.2/uohs/student/api';
    }
    */
  }

  // حفظ معرّف الجلسة
  Future<void> saveCookie(String rawCookie) async {
    // استخراج PHPSESSID فقط من الـ Set-Cookie header
    final index = rawCookie.indexOf('PHPSESSID=');
    if (index != -1) {
      final endIndex = rawCookie.indexOf(';', index);
      final cookie = endIndex == -1 ? rawCookie.substring(index) : rawCookie.substring(index, endIndex);
      _cookie = cookie;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_cookie', cookie);
    }
  }

  // مسح بيانات الجلسة (تسجيل الخروج)
  Future<void> clearSession() async {
    _cookie = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_cookie');
  }

  // دمج الترويسات الافتراضية مع الترويسات المخصصة
  Map<String, String> _getHeaders(Map<String, String>? customHeaders) {
    final Map<String, String> headers = {
      'Accept': 'application/json',
      'X-Requested-With': 'XMLHttpRequest',
    };
    if (_cookie != null) {
      headers['Cookie'] = _cookie!;
    }
    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }
    return headers;
  }

  // تنفيذ طلب POST اعتيادي
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

    return response;
  }

  // تنفيذ طلب GET اعتيادي (على سبيل المثال لجلب شات الدعم)
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

  // تنفيذ طلب POST يحتوي على ملفات (Multipart Request)
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

// معلمة الملف لطلبات الـ Multipart
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
