import 'package:flutter/material.dart';
import '../core/services/connectivity_service.dart';

/// شريط صغير يظهر في أعلى الشاشة عند انقطاع/عودة الإنترنت
class ConnectivityBanner extends StatefulWidget {
  final Widget child;
  const ConnectivityBanner({super.key, required this.child});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner>
    with SingleTickerProviderStateMixin {
  final ConnectivityService _service = ConnectivityService();
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  bool _isConnected = true;
  bool _showBanner = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _slideAnimation = Tween<double>(begin: -60, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _isConnected = _service.isConnected;

    _service.connectionStream.listen((connected) {
      if (!mounted) return;
      setState(() {
        _isConnected = connected;
        _showBanner = true;
      });

      if (!connected) {
        _animationController.forward();
      } else {
        // عند عودة الاتصال: اعرض البانر الأخضر ثم اخفيه بعد ثانيتين
        _animationController.forward();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _animationController.reverse().then((_) {
              if (mounted) setState(() => _showBanner = false);
            });
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showBanner)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: child,
              ),
              child: _buildBanner(),
            ),
          ),
      ],
    );
  }

  Widget _buildBanner() {
    return Material(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isConnected
                ? [const Color(0xFF2ECC71), const Color(0xFF27AE60)]
                : [const Color(0xFFE74C3C), const Color(0xFFC0392B)],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isConnected ? Icons.wifi : Icons.wifi_off,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                _isConnected
                    ? 'تم استعادة الاتصال بالإنترنت ✓'
                    : 'لا يوجد اتصال بالإنترنت',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// مؤشر صغير دائري يُعرض في أي مكان لإظهار حالة الاتصال الحالية
class ConnectivityIndicator extends StatefulWidget {
  const ConnectivityIndicator({super.key});

  @override
  State<ConnectivityIndicator> createState() => _ConnectivityIndicatorState();
}

class _ConnectivityIndicatorState extends State<ConnectivityIndicator> {
  final ConnectivityService _service = ConnectivityService();
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    _isConnected = _service.isConnected;
    _service.connectionStream.listen((connected) {
      if (mounted) setState(() => _isConnected = connected);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _isConnected ? 'متصل بالإنترنت' : 'غير متصل بالإنترنت',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isConnected ? Colors.greenAccent : Colors.redAccent,
          boxShadow: [
            BoxShadow(
              color: (_isConnected ? Colors.greenAccent : Colors.redAccent)
                  .withValues(alpha: 0.6),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}
