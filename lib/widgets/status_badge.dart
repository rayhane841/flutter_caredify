import 'package:flutter/material.dart';
import '../models/ecg_reading.dart';
import '../theme/app_theme.dart';

class StatusBadge extends StatelessWidget {
  final HealthStatus status;
  final bool large;

  const StatusBadge({super.key, required this.status, this.large = false});

  Color get _color {
    switch (status) {
      case HealthStatus.normal:
        return AppColors.normal;
      case HealthStatus.suspect:
        return AppColors.warning;
      case HealthStatus.critical:
        return AppColors.critical;
    }
  }

  Color get _bgColor {
    switch (status) {
      case HealthStatus.normal:
        return AppColors.normalLight;
      case HealthStatus.suspect:
        return AppColors.warningLight;
      case HealthStatus.critical:
        return AppColors.criticalLight;
    }
  }

  String get _label {
    switch (status) {
      case HealthStatus.normal:
        return 'Normal';
      case HealthStatus.suspect:
        return 'Suspect';
      case HealthStatus.critical:
        return 'Critique';
    }
  }

  IconData get _icon {
    switch (status) {
      case HealthStatus.normal:
        return Icons.check_circle_rounded;
      case HealthStatus.suspect:
        return Icons.warning_rounded;
      case HealthStatus.critical:
        return Icons.dangerous_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = large ? 16.0 : 12.0;
    final iconSize = large ? 18.0 : 14.0;
    final padding = large
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 6);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: iconSize, color: _color),
          const SizedBox(width: 6),
          Text(
            _label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}
