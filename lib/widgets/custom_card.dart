import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double marginBottom;
  final Color? borderColor;
  final BoxBorder? border;

  const CustomCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20.0),
    this.marginBottom = 15.0,
    this.borderColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: marginBottom),
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(15),
        border: border ?? Border.all(
          color: borderColor ?? const Color(0xFFeef2f6),
          width: borderColor != null ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
