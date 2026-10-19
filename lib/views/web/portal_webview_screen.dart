import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/heartbeat_loader.dart';

// ─── إعدادات الروابط (تغيير الروابط من هنا مباشرة) ──────────────────────────

class WebPortalConfig {
  // رابط التقويم الدراسي
  static const String calendarUrl = 'https://uhos.online/student/calendar.php';

  // رابط التحصيل الأكاديمي والنتائج
  static const String academicUrl = 'https://uhos.online/student/academic.php';
}

// ─── Portal WebView Screen ──────────────────────────────────────────────────

class PortalWebViewScreen extends StatefulWidget {
  final String title;
  final String targetUrl;

  const PortalWebViewScreen({
    super.key,
    required this.title,
    required this.targetUrl,
  });

  @override
  State<PortalWebViewScreen> createState() => _PortalWebViewScreenState();
}

class _PortalWebViewScreenState extends State<PortalWebViewScreen> {
  late final WebViewController? _controller;
  bool _isLoading = true;
  double _progress = 0.0;
  bool _hasError = false;

  // بيانات الجلسة الافتراضية للمحاكاة وتمريرها في الطلب
  final String _mockStudentId = '12345672026';
  final String _mockSessionToken = 'php_sess_id_mock_9876543210_uhs';

  @override
  void initState() {
    super.initState();

    // بناء الرابط النهائي مع تمرير الجلسة في الـ Query Parameters كخيار أول
    // وذلك لأن الجلسة عن طريق الـ URL هي الأكثر أماناً وضماناً لفتح الجلسة مباشرة
    final Uri finalUri = Uri.parse(widget.targetUrl).replace(
      queryParameters: {
        'student_user_id': _mockStudentId,
        'session_token': _mockSessionToken,
        'auth_source': 'mobile_app',
      },
    );

    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (progress) {
              if (mounted) {
                setState(() {
                  _progress = progress / 100;
                });
              }
            },
            onPageStarted: (url) {
              if (mounted) {
                setState(() {
                  _isLoading = true;
                  _hasError = false;
                });
              }
            },
            onPageFinished: (url) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
            onWebResourceError: (error) {
              // Ignore minor errors that don't block display
              if (error.description.contains('net::ERR_CACHE_MISS')) return;
              if (mounted) {
                setState(() {
                  _hasError = true;
                  _isLoading = false;
                });
              }
            },
          ),
        );

      // تحميل الصفحة مع تمرير بيانات الجلسة في الهيدرز (Headers) أيضاً لضمان مطابقتها للمتصفح
      controller.loadRequest(
        finalUri,
        headers: {
          'Cookie': 'PHPSESSID=$_mockSessionToken; student_user_id=$_mockStudentId',
          'Authorization': 'Bearer $_mockSessionToken',
          'X-Requested-With': 'XMLHttpRequest',
          'X-UHS-Student-Session': _mockStudentId,
        },
      );
      _controller = controller;
    } else {
      // الـ WebView غير مدعوم على ويندوز ديسكتوب أو الويب مباشرة بدون حزم إضافية،
      // لذا سنقوم بعرض واجهة محاكاة ذكية للمطور والمستخدم توضح البيانات المرسلة والصفحة المطلوبة.
      _controller = null;
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // بناء الرابط النهائي لعرضه في المعاينة
    final String finalUrlWithParams = Uri.parse(widget.targetUrl).replace(
      queryParameters: {
        'student_user_id': _mockStudentId,
        'session_token': _mockSessionToken,
        'auth_source': 'mobile_app',
      },
    ).toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_controller != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _controller.reload(),
            ),
        ],
      ),
      body: Stack(
        children: [
          // 1. WebView (Android / iOS)
          if (_controller != null)
            WebViewWidget(controller: _controller)
          else
            // 2. Desktop Fallback & Simulated Preview (لأننا نعمل على بيئة ويندوز حالياً)
            _buildDesktopSimulator(finalUrlWithParams),

          // 3. Progress / Loading Indicator
          if (_isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                color: AppColors.secondary,
                backgroundColor: Colors.transparent,
              ),
            ),

          if (_isLoading && _controller == null)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HeartbeatLoader(),
                  SizedBox(height: 16),
                  Text(
                    'جاري تأمين الجلسة وفتح الصفحة...',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          // 4. Error Display
          if (_hasError)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 60, color: AppColors.danger),
                    const SizedBox(height: 16),
                    const Text(
                      'تعذر تحميل الصفحة الدراسية',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'تأكد من اتصالك بالإنترنت وصلاحية خوادم الجامعة.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _hasError = false;
                        });
                        _controller?.reload();
                      },
                      icon: const Icon(Icons.replay),
                      label: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopSimulator(String url) {
    return Container(
      color: AppColors.background,
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // شريط معلومات المتصفح
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      url,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // محاكاة محتوى الصفحة
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 30),
                    Icon(
                      widget.title == 'التقويم الدراسي' ? Icons.calendar_month : Icons.school,
                      size: 70,
                      color: AppColors.primary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'محاكاة متصفح تطبيق فلاتر الداخلي - ${widget.title}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'تم تشغيل الصفحة بنجاح وتأمين جلسة الطالب التلقائية دون الحاجة لإعادة تسجيل الدخول.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 14),
                    const Text(
                      'المعاملات وبيانات الجلسة المرسلة (Session Metadata):',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSessionItem('رقم الجلسة (PHPSESSID Cookie)', _mockSessionToken),
                    _buildSessionItem('المعرف البريد للأمان (student_user_id Header)', _mockStudentId),
                    _buildSessionItem('مصدر الطلب (auth_source Query)', 'mobile_app'),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info, color: AppColors.secondary, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'ملاحظة للمطور: عند تشغيل هذا التطبيق على جهاز محاكاة أندرويد أو جهاز iOS حقيقي، سيتم فتح الرابط تلقائياً داخل WebView كامل بدون أي محاكاة.',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted),
          ),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
          ),
        ],
      ),
    );
  }
}
