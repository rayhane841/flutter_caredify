import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  // ✅ États des notifications
  bool _alertesRythme = true;
  bool _alertesUrgence = true;
  bool _rappelsMedicaments = false;
  bool _rapportsHebdomadaires = true;
  bool _notificationsPush = true;
  bool _notificationsEmail = false;
  bool _notificationsSMS = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ SECTION : Alertes médicales
              _SectionTitle(
                  title: 'Alertes médicales',
                  icon: Icons.health_and_safety_rounded),
              const SizedBox(height: 8),
              _SwitchTile(
                title: 'Alertes rythme cardiaque',
                subtitle:
                    'Recevoir une notification en cas d\'anomalie détectée',
                value: _alertesRythme,
                onChanged: (v) => setState(() => _alertesRythme = v),
                icon: Icons.favorite_rounded,
                iconColor: AppColors.critical,
              ),
              _SwitchTile(
                title: 'Alertes d\'urgence',
                subtitle:
                    'Notifications prioritaires en cas de situation critique',
                value: _alertesUrgence,
                onChanged: (v) => setState(() => _alertesUrgence = v),
                icon: Icons.emergency_rounded,
                iconColor: AppColors.emergency,
              ),
              _SwitchTile(
                title: 'Rappels de médicaments',
                subtitle: 'Rappel pour la prise de vos traitements',
                value: _rappelsMedicaments,
                onChanged: (v) => setState(() => _rappelsMedicaments = v),
                icon: Icons.medication_rounded,
                iconColor: AppColors.warning,
              ),
              _SwitchTile(
                title: 'Rapports hebdomadaires',
                subtitle: 'Résumé de votre activité cardiaque chaque semaine',
                value: _rapportsHebdomadaires,
                onChanged: (v) => setState(() => _rapportsHebdomadaires = v),
                icon: Icons.summarize_rounded,
                iconColor: AppColors.primary,
              ),

              const SizedBox(height: 24),

              // ✅ SECTION : Canaux de notification
              _SectionTitle(
                  title: 'Canaux de notification',
                  icon: Icons.campaign_rounded),
              const SizedBox(height: 8),
              _SwitchTile(
                title: 'Notifications push',
                subtitle: 'Alertes sur votre appareil mobile',
                value: _notificationsPush,
                onChanged: (v) => setState(() => _notificationsPush = v),
                icon: Icons.notifications_active_rounded,
                iconColor: AppColors.primary,
              ),
              _SwitchTile(
                title: 'Notifications email',
                subtitle: 'Résumés et rapports par email',
                value: _notificationsEmail,
                onChanged: (v) => setState(() => _notificationsEmail = v),
                icon: Icons.email_rounded,
                iconColor: Colors.blue,
              ),
              _SwitchTile(
                title: 'Notifications SMS',
                subtitle: 'Alertes critiques par SMS (frais possibles)',
                value: _notificationsSMS,
                onChanged: (v) => setState(() => _notificationsSMS = v),
                icon: Icons.sms_rounded,
                iconColor: Colors.green,
              ),

              const SizedBox(height: 24),

              // ✅ SECTION : Son et vibration
              _SectionTitle(
                  title: 'Son et vibration', icon: Icons.volume_up_rounded),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Son des alertes',
                            style: TextStyle(fontSize: 14)),
                        DropdownButton<String>(
                          value: 'Moyen',
                          items: ['Silencieux', 'Faible', 'Moyen', 'Fort']
                              .map((s) =>
                                  DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (v) {},
                          underline: const SizedBox(),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Vibration', style: TextStyle(fontSize: 14)),
                        Switch(
                          value: true,
                          onChanged: (v) {},
                          activeColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ✅ BOUTON : Tester une notification
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🔔 Notification de test envoyée !'),
                        backgroundColor: AppColors.primary,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.notifications_active_rounded),
                  label: const Text('Tester une notification'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
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

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ==================== _SwitchTile ====================
class _SwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData icon;
  final Color iconColor;

  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
