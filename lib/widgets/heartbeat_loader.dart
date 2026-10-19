import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class HeartbeatLoader extends StatefulWidget {
  final Color? color;
  final double width;
  final double height;

  const HeartbeatLoader({
    super.key,
    this.color,
    this.width = 150.0,
    this.height = 60.0,
  });

  @override
  State<HeartbeatLoader> createState() => _HeartbeatLoaderState();
}

class _HeartbeatLoaderState extends State<HeartbeatLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _HeartbeatPainter(
              progress: _controller.value,
              color: widget.color ?? AppColors.primary,
            ),
          );
        },
      ),
    );
  }
}

class _HeartbeatPainter extends CustomPainter {
  final double progress;
  final Color color;

  _HeartbeatPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final w = size.width;
    final h = size.height;
    final centerY = h / 2;

    // ECG / Heartbeat Path
    path.moveTo(0, centerY);
    path.lineTo(w * 0.2, centerY);
    path.lineTo(w * 0.3, centerY - h * 0.3);
    path.lineTo(w * 0.4, centerY + h * 0.4);
    path.lineTo(w * 0.5, centerY - h * 0.8);
    path.lineTo(w * 0.6, centerY + h * 0.5);
    path.lineTo(w * 0.7, centerY - h * 0.2);
    path.lineTo(w * 0.8, centerY);
    path.lineTo(w, centerY);

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics[0];
    final totalLength = metric.length;

    // Draw fading background line
    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, bgPaint);

    // Draw the moving pulse
    final currentLength = totalLength * progress;
    final tailLength = totalLength * 0.3;

    final start = (currentLength - tailLength).clamp(0.0, totalLength);
    final end = currentLength;

    final extractPath = metric.extractPath(start, end);
    canvas.drawPath(extractPath, paint);
  }

  @override
  bool shouldRepaint(covariant _HeartbeatPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
