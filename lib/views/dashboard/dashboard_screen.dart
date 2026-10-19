import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/finance_provider.dart';
import '../../widgets/menu_card_widget.dart';
import '../../widgets/connectivity_banner.dart';


class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // جلب البيانات المالية تلقائياً للتحقق من وجود إشعارات جديدة عند فتح لوحة التحكم
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<FinanceProvider>().fetchFinancials().then((_) {
          if (mounted) {
            final financeProv = context.read<FinanceProvider>();
            // إظهار تنبيه Snack Bar فوري إذا كانت هناك إشعارات مالية جديدة لم تقرأ
            if (financeProv.unreadNotificationsCount > 0) {
              final latestNotif = financeProv.notifications.firstWhere((n) => !n.isRead);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${latestNotif.title}: ${latestNotif.message}',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                  ),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  action: SnackBarAction(
                    label: 'عرض',
                    textColor: Colors.white,
                    onPressed: () {
                      _showNotificationsBottomSheet(context, financeProv);
                    },
                  ),
                ),
              );
            }
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, authProvider),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    _buildAnnouncements(),
                    const SizedBox(height: 25),
                    _buildGridMenu(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const ConnectivityIndicator(),
                  const SizedBox(width: 8),
                  const Text(
                    'جامعة العلوم الصحية',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Cairo',
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Consumer<FinanceProvider>(
                    builder: (context, financeProv, child) {
                      final count = financeProv.unreadNotificationsCount;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_active, color: Colors.white),
                            onPressed: () => _showNotificationsBottomSheet(context, financeProv),
                          ),
                          if (count > 0)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  '$count',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.white),
                    tooltip: 'تسجيل الخروج',
                    onPressed: () async {
                      await auth.logout();
                      if (context.mounted) {
                        Navigator.pushReplacementNamed(context, '/login');
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 38,
            backgroundColor: Colors.white24,
            backgroundImage: auth.photoPath != null && auth.photoPath!.isNotEmpty
                ? NetworkImage(auth.photoPath!)
                : null,
            child: auth.photoPath == null || auth.photoPath!.isEmpty
                ? const Icon(Icons.person, size: 40, color: Colors.white)
                : null,
          ),
          const SizedBox(height: 10),
          Text(
            auth.studentName ?? 'مرحباً بك، الطالب',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'الرقم الجامعي: ${auth.seatNumber ?? 'غير معرف'}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildBadge(FontAwesomeIcons.graduationCap, 'خدمات الطلاب الإلكترونية'),
              if (auth.batchCode != null) ...[
                const SizedBox(width: 10),
                _buildBadge(FontAwesomeIcons.userGroup, auth.batchCode!),
              ],
            ],
          )
        ],
      ),
    );
  }

  // FIX: Changed parameter type from IconData to FaIconData to match FontAwesome icons
  Widget _buildBadge(FaIconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          FaIcon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncements() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFfffbeb),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFfef3c7)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFfbbf24),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'تنبيه',
              style: TextStyle(
                color: Color(0xFF92400e),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                fontFamily: 'Cairo',
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'عزيزي الطالب، يرجى استكمال سداد القسط الثاني لتجنب الغرامات.',
              style: TextStyle(
                color: Color(0xFF92400e),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'Cairo',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildGridMenu(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 15,
      crossAxisSpacing: 15,
      childAspectRatio: 0.9,
      children: [
        MenuCardWidget(
          title: 'بيانات الطالب',
          subtitle: 'تعديل الملف والوثائق',
          icon: const FaIcon(FontAwesomeIcons.circleUser, color: Colors.white, size: 26),
          iconBackgroundColor: const Color(0xFF4f46e5),
          onTap: () => Navigator.pushNamed(context, '/profile'),
        ),
        MenuCardWidget(
          title: 'الفواتير والأقسام',
          subtitle: 'سداد الرسوم ومتابعة الأقساط',
          icon: const FaIcon(FontAwesomeIcons.fileInvoiceDollar, color: Colors.white, size: 26),
          iconBackgroundColor: const Color(0xFF059669),
          // ✅ Navigate to the completed Finance screen
          onTap: () => Navigator.pushNamed(context, '/finance'),
        ),
        MenuCardWidget(
          title: 'الدعم الفني',
          subtitle: 'حل المشاكل التقنية والتذاكر',
          icon: const FaIcon(FontAwesomeIcons.headset, color: Colors.white, size: 26),
          iconBackgroundColor: const Color(0xFFea580c),
          onTap: () => Navigator.pushNamed(context, '/support'),
        ),
        MenuCardWidget(
          title: 'الرعاية والتوجيه',
          subtitle: 'تقديم الشكاوى والدعم النفسي',
          icon: const FaIcon(FontAwesomeIcons.handshakeAngle, color: Colors.white, size: 26),
          iconBackgroundColor: const Color(0xFF8b5cf6),
          onTap: () => _showUnderDevelopmentDialog(context, 'قسم الرعاية والتوجيه'),
        ),
        MenuCardWidget(
          title: 'التقويم الدراسي',
          subtitle: 'مواعيد الامتحانات والعطلات',
          icon: const FaIcon(FontAwesomeIcons.calendarDays, color: Colors.white, size: 26),
          iconBackgroundColor: const Color(0xFFdb2777),
          onTap: () => _showUnderDevelopmentDialog(context, 'قسم التقويم الدراسي'),
        ),
        MenuCardWidget(
          title: 'التحصيل الأكاديمي',
          subtitle: 'النتائج والفصل الدراسي',
          icon: const FaIcon(FontAwesomeIcons.graduationCap, color: Colors.white, size: 26),
          iconBackgroundColor: const Color(0xFF2563eb),
          onTap: () => _showUnderDevelopmentDialog(context, 'قسم التحصيل الأكاديمي'),
        ),
      ],
    );
  }

  // ─── Notifications Bottom Sheet ───────────────────────────────────────────

  void _showNotificationsBottomSheet(BuildContext context, FinanceProvider provider) {
    // تحديد كل الإشعارات كمقروءة عند فتح شريط الإشعارات
    provider.markAllNotificationsAsRead();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'الإشعارات والتنبيهات المالية',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.textDark,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        provider.clearNotifications();
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'مسح الكل',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          color: AppColors.danger,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: provider.notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_none_outlined,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'لا توجد إشعارات جديدة حالياً',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                color: AppColors.textMuted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        itemCount: provider.notifications.length,
                        itemBuilder: (context, index) {
                          final notif = provider.notifications[index];
                          IconData notifIcon = Icons.notifications_none;
                          Color notifColor = AppColors.primary;

                          if (notif.title.contains('جديدة')) {
                            notifIcon = Icons.add_card_outlined;
                            notifColor = const Color(0xFF4f46e5);
                          } else if (notif.title.contains('حالة')) {
                            notifIcon = Icons.swap_horiz_outlined;
                            notifColor = const Color(0xFF059669);
                          } else if (notif.title.contains('تنبيه')) {
                            notifIcon = Icons.warning_amber_rounded;
                            notifColor = const Color(0xFFdc2626);
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: notif.isRead ? Colors.grey.shade50 : notifColor.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: notif.isRead ? Colors.grey.shade200 : notifColor.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: notifColor.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(notifIcon, color: notifColor, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            notif.title,
                                            style: TextStyle(
                                              fontFamily: 'Cairo',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: notifColor,
                                            ),
                                          ),
                                          Text(
                                            _formatTimestamp(notif.timestamp),
                                            style: const TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 10,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        notif.message,
                                        style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 12,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) {
      return 'الآن';
    } else if (diff.inMinutes < 60) {
      return 'منذ ${diff.inMinutes} د';
    } else if (diff.inHours < 24) {
      return 'منذ ${diff.inHours} س';
    } else {
      return '${dt.day}/${dt.month}';
    }
  }

  void _showUnderDevelopmentDialog(BuildContext context, String sectionName) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 10,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // أيقونة حركية جميلة دائرية بنمط بريميوم
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9E6), // لون خلفية أصفر دافئ
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFFE082), width: 3),
                  ),
                  child: const Icon(
                    Icons.construction_rounded,
                    color: Color(0xFFF5B041), // لون برتقالي دافئ
                    size: 45,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  sectionName,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'هذا القسم قيد التطوير والتحسين حالياً.\nنعمل جاهدين لتوفير أفضل تجربة لكم قريباً!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: AppColors.textDark,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                    ),
                    child: const Text(
                      'حسناً، فهمت',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
