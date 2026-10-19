import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_colors.dart';
import 'core/services/notification_service.dart';
import 'core/services/connectivity_service.dart';
import 'providers/auth_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/finance_provider.dart';
import 'providers/support_provider.dart';
import 'providers/guidance_provider.dart';
import 'views/auth/login_screen.dart';
import 'views/dashboard/dashboard_screen.dart';
import 'views/finance/finance_screen.dart';
import 'views/profile/profile_screen.dart';
import 'views/support/support_screen.dart';
import 'views/guidance/guidance_screen.dart';
import 'views/web/portal_webview_screen.dart';
import 'widgets/connectivity_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة Firebase بالطريقة الحديثة
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // تسجيل معالج إشعارات الخلفية لـ FCM
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  // تهيئة الإشعارات المحلية على مستوى نظام التشغيل
  await NotificationService.init();

  // بدء مراقبة حالة الاتصال بالإنترنت
  ConnectivityService().startMonitoring();
  
  // قفل اتجاه الشاشة على الوضع الطولي
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // تهيئة مزود المصادقة وفحص الجلسة السابقة
  final authProvider = AuthProvider();
  await authProvider.checkAuthStatus();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => FinanceProvider()),
        ChangeNotifierProvider(create: (_) => SupportProvider()),
        ChangeNotifierProvider(create: (_) => GuidanceProvider()),
      ],
      child: UHSStudentApp(isLoggedIn: authProvider.isLoggedIn),
    ),
  );
}

class UHSStudentApp extends StatelessWidget {
  final bool isLoggedIn;
  const UHSStudentApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'جامعة العلوم الصحية',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        fontFamily: 'Cairo',
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      builder: (context, child) {
        return ConnectivityBanner(child: child ?? const SizedBox());
      },
      initialRoute: isLoggedIn ? '/dashboard' : '/login',
      routes: {
        '/login':     (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/finance':   (context) => const FinanceScreen(),
        '/profile':   (context) => const ProfileScreen(),
        '/support':   (context) => const SupportScreen(),
        '/guidance':  (context) => const GuidanceScreen(),
        '/web_portal': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, String>;
          return PortalWebViewScreen(
            title: args['title']!,
            targetUrl: args['url']!,
          );
        },
      },
    );
  }
}
