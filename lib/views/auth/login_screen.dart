import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/heartbeat_loader.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LoginView();
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  _LoginViewState createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> with SingleTickerProviderStateMixin {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _rememberMe = true;
  
  // متحكمات الحركة (Animations)
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadSavedStudentId();
    
    // إعداد تأثيرات الدخول الحركية (Fade & Slide)
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _animationController.forward();
  }

  // تحميل الرقم الجامعي المحفوظ مسبقاً
  Future<void> _loadSavedStudentId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString('saved_student_id');
      if (savedId != null && mounted) {
        setState(() {
          _idController.text = savedId;
        });
      }
    } catch (e) {
      debugPrint('Error loading saved student ID: $e');
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _submitLogin() async {
    final id = _idController.text.trim();
    final pass = _passwordController.text;

    if (id.isEmpty || pass.isEmpty) {
      _showSnackBar('الرجاء إدخال الرقم الجامعي وكلمة المرور');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(id, pass);

    if (success && mounted) {
      // حفظ أو إزالة الرقم الجامعي بناءً على حالة تذكرني
      try {
        final prefs = await SharedPreferences.getInstance();
        if (_rememberMe) {
          await prefs.setString('saved_student_id', id);
        } else {
          await prefs.remove('saved_student_id');
        }
      } catch (e) {
        debugPrint('Error saving student ID preferences: $e');
      }
      
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else if (mounted) {
      if (authProvider.forceUpdate) {
        _showUpdateDialog(
          context,
          authProvider.errorMessage ?? 'تحديث مطلوب للاستمرار.',
          authProvider.updateUrl ?? 'https://uhos.online',
        );
      } else {
        _showSnackBar(authProvider.errorMessage ?? 'فشل تسجيل الدخول');
      }
    }
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showUpdateDialog(BuildContext context, String message, String updateUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PopScope(
          canPop: false, // منع زر الرجوع في أندرويد
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.system_update_alt, color: AppColors.primary, size: 28),
                SizedBox(width: 10),
                Text(
                  'تحديث مطلوب',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            content: Text(
              message,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                height: 1.5,
              ),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: () async {
                  final Uri url = Uri.parse(updateUrl);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'عذراً، تعذر فتح رابط التحديث تلقائياً.',
                          style: TextStyle(fontFamily: 'Cairo'),
                        ),
                      ),
                    );
                  }
                },
                child: const Text(
                  'تحديث الآن',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            // تطبيق تأثير الحركات (Fade & Slide)
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // الهيدر واللوجو للجامعة
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(35),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5)),
                        ]
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.health_and_safety, size: 75, color: Colors.white),
                          SizedBox(height: 15),
                          Text(
                            'جامعة العلوم الصحية',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          Text(
                            'بوابة الخدمات الإلكترونية للمستفيدين',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // حاوية نموذج تسجيل الدخول
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(30),
                          bottomRight: Radius.circular(30),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // عنوان التبويب
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: AppColors.primary,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'تسجيل الدخول',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ),
                          ),
                          
                          // نموذج الدخول
                          Padding(
                            padding: const EdgeInsets.all(30.0),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              child: authProvider.isLoading
                                  ? const Column(
                                      key: ValueKey('loading'),
                                      children: [
                                        SizedBox(height: 30),
                                        HeartbeatLoader(),
                                        SizedBox(height: 25),
                                        Text(
                                          'جاري التحقق من الجلسة والهوية...',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontFamily: 'Cairo',
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 30),
                                      ],
                                    )
                                  : Column(
                                      key: const ValueKey('login_form'),
                                      children: [
                                        CustomTextField(
                                          label: 'الرقم الجامعي',
                                          hint: 'مثال: 12345672026',
                                          controller: _idController,
                                          keyboardType: TextInputType.number,
                                        ),
                                        const SizedBox(height: 15),
                                        CustomTextField(
                                          label: 'كلمة المرور',
                                          hint: '******',
                                          isPassword: true,
                                          controller: _passwordController,
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Checkbox(
                                                  value: _rememberMe,
                                                  onChanged: (v) {
                                                    setState(() {
                                                      _rememberMe = v ?? false;
                                                    });
                                                  },
                                                  activeColor: AppColors.primary,
                                                ),
                                                const Text('تذكرني لاحقاً', style: TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                                              ],
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                _showSnackBar('يرجى التواصل مع الدعم الفني بالجامعة لاستعادة كلمة المرور');
                                              },
                                              child: const Text(
                                                'نسيت كلمة المرور؟',
                                                style: TextStyle(color: AppColors.primary, fontFamily: 'Cairo', fontSize: 13),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 25),
                                        CustomButton(
                                          text: 'دخول إلى حسابي',
                                          onPressed: _submitLogin,
                                        ),
                                      ],
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
        ),
      ),
    );
  }
}
