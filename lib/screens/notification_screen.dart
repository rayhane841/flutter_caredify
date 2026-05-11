import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/theme_helper.dart'; // ← NOUVEL IMPORT

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});
  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool _alertesRythme = true,
      _alertesUrgence = true,
      _rappelsMedicaments = false,
      _rapportsHebdomadaires = true,
      _notificationsPush = true,
      _notificationsEmail = false,
      _notificationsSMS = false;

  @override
  Widget build(BuildContext context) {
    final bg = ThemeHelper.background(context);
    final surface = ThemeHelper.surface(context);
    final border = ThemeHelper.border(context);
    final textPrimary = ThemeHelper.textPrimary(context);
    final textSecondary = ThemeHelper.textSecondary(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        leading: IconButton(
            icon: Icon(Icons.arrow_back, color: textPrimary),
            onPressed: () => Navigator.pop(context)),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: border)),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle(
                  title: 'Alertes médicales',
                  icon: Icons.health_and_safety_rounded,
                  textPrimary: textPrimary),
              const SizedBox(height: 8),
              _SwitchTile(
                  title: 'Alertes rythme cardiaque',
                  subtitle:
                      'Recevoir une notification en cas d\'anomalie détectée',
                  value: _alertesRythme,
                  onChanged: (v) => setState(() => _alertesRythme = v),
                  icon: Icons.favorite_rounded,
                  iconColor: ThemeHelper.critical(context),
                  surface: surface,
                  border: border,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary),
              _SwitchTile(
                  title: 'Alertes d\'urgence',
                  subtitle:
                      'Notifications prioritaires en cas de situation critique',
                  value: _alertesUrgence,
                  onChanged: (v) => setState(() => _alertesUrgence = v),
                  icon: Icons.emergency_rounded,
                  iconColor: ThemeHelper.emergency(context),
                  surface: surface,
                  border: border,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary),
              _SwitchTile(
                  title: 'Rappels de médicaments',
                  subtitle: 'Rappel pour la prise de vos traitements',
                  value: _rappelsMedicaments,
                  onChanged: (v) => setState(() => _rappelsMedicaments = v),
                  icon: Icons.medication_rounded,
                  iconColor: ThemeHelper.warning(context),
                  surface: surface,
                  border: border,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary),
              _SwitchTile(
                  title: 'Rapports hebdomadaires',
                  subtitle: 'Résumé de votre activité cardiaque chaque semaine',
                  value: _rapportsHebdomadaires,
                  onChanged: (v) => setState(() => _rapportsHebdomadaires = v),
                  icon: Icons.summarize_rounded,
                  iconColor: ThemeHelper.primary,
                  surface: surface,
                  border: border,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary),
              const SizedBox(height: 24),
              _SectionTitle(
                  title: 'Canaux de notification',
                  icon: Icons.campaign_rounded,
                  textPrimary: textPrimary),
              const SizedBox(height: 8),
              _SwitchTile(
                  title: 'Notifications push',
                  subtitle: 'Alertes sur votre appareil mobile',
                  value: _notificationsPush,
                  onChanged: (v) => setState(() => _notificationsPush = v),
                  icon: Icons.notifications_active_rounded,
                  iconColor: ThemeHelper.primary,
                  surface: surface,
                  border: border,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary),
              _SwitchTile(
                  title: 'Notifications email',
                  subtitle: 'Résumés et rapports par email',
                  value: _notificationsEmail,
                  onChanged: (v) => setState(() => _notificationsEmail = v),
                  icon: Icons.email_rounded,
                  iconColor: Colors.blue,
                  surface: surface,
                  border: border,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary),
              _SwitchTile(
                  title: 'Notifications SMS',
                  subtitle: 'Alertes critiques par SMS (frais possibles)',
                  value: _notificationsSMS,
                  onChanged: (v) => setState(() => _notificationsSMS = v),
                  icon: Icons.sms_rounded,
                  iconColor: Colors.green,
                  surface: surface,
                  border: border,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary),
              const SizedBox(height: 24),
              _SectionTitle(
                  title: 'Son et vibration',
                  icon: Icons.volume_up_rounded,
                  textPrimary: textPrimary),
              const SizedBox(height: 8),
              Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border)),
                  child: Column(children: [
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Son des alertes',
                              style:
                                  TextStyle(fontSize: 14, color: textPrimary)),
                          DropdownButton<String>(
                              value: 'Moyen',
                              items: ['Silencieux', 'Faible', 'Moyen', 'Fort']
                                  .map((s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s,
                                          style:
                                              TextStyle(color: textPrimary))))
                                  .toList(),
                              onChanged: (v) {},
                              underline: const SizedBox())
                        ]),
                    const Divider(height: 24),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Vibration',
                              style:
                                  TextStyle(fontSize: 14, color: textPrimary)),
                          Switch(
                              value: true,
                              onChanged: (v) {},
                              activeThumbColor: ThemeHelper.primary)
                        ])
                  ])),
              const SizedBox(height: 32),
              SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Notification de test envoyée !'),
                                backgroundColor: Color(0xFF1A47C0),
                                duration: Duration(seconds: 2)));
                      },
                      icon: const Icon(Icons.notifications_active_rounded),
                      label: const Text('Tester une notification'),
                      style: ElevatedButton.styleFrom(
                          textStyle: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                          backgroundColor: ThemeHelper.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))))),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== _SectionTitle ====================
class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color textPrimary;
  const _SectionTitle(
      {required this.title, required this.icon, required this.textPrimary});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: ThemeHelper.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 16, color: ThemeHelper.primary)),
      const SizedBox(width: 8),
      Text(title,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary))
    ]);
  }
}

// ==================== _SwitchTile ====================
class _SwitchTile extends StatelessWidget {
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData icon;
  final Color iconColor, surface, border, textPrimary, textSecondary;
  const _SwitchTile(
      {required this.title,
      required this.subtitle,
      required this.value,
      required this.onChanged,
      required this.icon,
      required this.iconColor,
      required this.surface,
      required this.border,
      required this.textPrimary,
      required this.textSecondary});
  @override
  Widget build(BuildContext context) {
    return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border)),
        child: Row(children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 20, color: iconColor)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(fontSize: 12, color: textSecondary))
              ])),
          Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: ThemeHelper.primary)
        ]));
  }
}
