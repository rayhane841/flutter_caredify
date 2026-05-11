import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ThemeHelper {
  // ✅ Retourne la couleur adaptée au thème actif
  static Color getColor(BuildContext context, Color light, Color dark) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  // ✅ Couleurs principales (adaptatives)
  static Color background(BuildContext context) =>
      getColor(context, AppColors.background, AppColors.darkBackground);
  static Color surface(BuildContext context) =>
      getColor(context, AppColors.surface, AppColors.darkSurface);
  static Color surfaceVariant(BuildContext context) =>
      getColor(context, AppColors.surfaceVariant, AppColors.darkSurfaceVariant);
  static Color border(BuildContext context) =>
      getColor(context, AppColors.border, AppColors.darkBorder);
  static Color textPrimary(BuildContext context) =>
      getColor(context, AppColors.textPrimary, AppColors.darkTextPrimary);
  static Color textSecondary(BuildContext context) =>
      getColor(context, AppColors.textSecondary, AppColors.darkTextSecondary);
  static Color textHint(BuildContext context) =>
      getColor(context, AppColors.textHint, AppColors.darkTextHint);

  // ✅ Couleurs sémantiques (adaptatives)
  static Color normal(BuildContext context) =>
      getColor(context, AppColors.normal, AppColors.darkNormal);
  static Color warning(BuildContext context) =>
      getColor(context, AppColors.warning, AppColors.darkWarning);
  static Color critical(BuildContext context) =>
      getColor(context, AppColors.critical, AppColors.darkCritical);
  static Color emergency(BuildContext context) =>
      getColor(context, AppColors.emergency, AppColors.darkEmergency);

  // ✅ Couleurs fixes (identiques dans les deux thèmes)
  static Color primary = AppColors.primary;
  static Color ecgGreen = AppColors.ecgGreen;
  static Color ecgBackground = AppColors.ecgBackground;
}
