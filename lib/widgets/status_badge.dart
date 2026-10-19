import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color textColor;

  const StatusBadge({
    super.key,
    required this.text,
    required this.backgroundColor,
    required this.textColor,
  });

  factory StatusBadge.success(String text) {
    return StatusBadge(
      text: text,
      backgroundColor: const Color(0xFFe8f5e9),
      textColor: const Color(0xFF2e7d32),
    );
  }

  factory StatusBadge.warning(String text) {
    return StatusBadge(
      text: text,
      backgroundColor: const Color(0xFFfff3e0),
      textColor: const Color(0xFFef6c00),
    );
  }

  factory StatusBadge.danger(String text) {
    return StatusBadge(
      text: text,
      backgroundColor: const Color(0xFFffebee),
      textColor: const Color(0xFFc62828),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          fontFamily: 'Cairo',
        ),
      ),
    );
  }
}
