import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SensorIndicator extends StatelessWidget {
  final bool connected;

  const SensorIndicator({super.key, required this.connected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: connected ? AppColors.normalLight : AppColors.criticalLight,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: connected
              ? AppColors.normal.withOpacity(0.3)
              : AppColors.critical.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingDot(color: connected ? AppColors.normal : AppColors.critical),
          const SizedBox(width: 6),
          Text(
            connected ? 'Capteur connecté' : 'Capteur déconnecté',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: connected ? AppColors.normal : AppColors.critical,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color.withOpacity(_animation.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
