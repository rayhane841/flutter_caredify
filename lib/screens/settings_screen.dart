import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _ecgAutoRecord = false;
  bool _shareDataCardiologist = true;
  bool _locationEnabled = true;
  bool _darkMode = false;
  String _measureInterval = '1h';
  double _alertThreshold = 65;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Paramètres'),
        backgroundColor: AppColors.surface,
        elevation: 0,
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
              // App version
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 20, color: AppColors.primary),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'CAREDIFY v1.0.0 — Prototype académique\nMode simulé, aucune donnée réelle transmise',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _SettingsSection(
                title: 'Surveillance',
                icon: Icons.monitor_heart_rounded,
                color: AppColors.primary,
                children: [
                  _ToggleTile(
                    title: 'ECG automatique',
                    subtitle: 'Enregistrement périodique automatique',
                    value: _ecgAutoRecord,
                    onChanged: (v) => setState(() => _ecgAutoRecord = v),
                  ),
                  _DropdownTile(
                    title: 'Fréquence de mesure',
                    value: _measureInterval,
                    options: {
                      '30min': '30 minutes',
                      '1h': '1 heure',
                      '2h': '2 heures',
                      '6h': '6 heures'
                    },
                    onChanged: (v) => setState(() => _measureInterval = v!),
                  ),
                  _SliderTile(
                    title: 'Seuil d\'alerte IA',
                    subtitle: 'Score de risque déclenchant l\'alerte',
                    value: _alertThreshold,
                    min: 40,
                    max: 90,
                    label: '${_alertThreshold.round()}/100',
                    onChanged: (v) => setState(() => _alertThreshold = v),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _SettingsSection(
                title: 'Notifications',
                icon: Icons.notifications_rounded,
                color: AppColors.warning,
                children: [
                  _ToggleTile(
                    title: 'Notifications activées',
                    subtitle: 'Alertes et résultats ECG',
                    value: _notificationsEnabled,
                    onChanged: (v) => setState(() => _notificationsEnabled = v),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _SettingsSection(
                title: 'Confidentialité',
                icon: Icons.lock_rounded,
                color: AppColors.normal,
                children: [
                  _ToggleTile(
                    title: 'Partager avec cardiologue',
                    subtitle: 'Données ECG transmises au Dr. Lefebvre',
                    value: _shareDataCardiologist,
                    onChanged: (v) =>
                        setState(() => _shareDataCardiologist = v),
                  ),
                  _ToggleTile(
                    title: 'Localisation GPS',
                    subtitle: 'Pour les urgences et la carte',
                    value: _locationEnabled,
                    onChanged: (v) => setState(() => _locationEnabled = v),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _SettingsSection(
                title: 'Apparence',
                icon: Icons.palette_rounded,
                color: const Color(0xFF6A1B9A),
                children: [
                  _ToggleTile(
                    title: 'Mode sombre',
                    subtitle: 'Thème sombre de l\'application',
                    value: _darkMode,
                    onChanged: (v) => setState(() => _darkMode = v),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _SettingsSection(
                title: 'Données',
                icon: Icons.storage_rounded,
                color: AppColors.textSecondary,
                children: [
                  _ActionTile(
                    title: 'Exporter l\'historique',
                    subtitle: 'Télécharger toutes les mesures en PDF',
                    icon: Icons.download_rounded,
                    onTap: () {},
                  ),
                  _ActionTile(
                    title: 'Partager avec médecin',
                    subtitle: 'Envoyer un rapport par email',
                    icon: Icons.share_rounded,
                    onTap: () {},
                  ),
                  _ActionTile(
                    title: 'Effacer l\'historique',
                    subtitle: 'Supprimer toutes les mesures locales',
                    icon: Icons.delete_rounded,
                    color: AppColors.critical,
                    onTap: () => _confirmDelete(context),
                  ),
                ],
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Effacer l\'historique'),
        content: const Text(
            'Cette action est irréversible. Toutes les mesures seront supprimées.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(foregroundColor: AppColors.critical),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: children.asMap().entries.map((e) {
              final isLast = e.key == children.length - 1;
              return Column(
                children: [
                  e.value,
                  if (!isLast)
                    const Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: AppColors.border),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

class _DropdownTile extends StatelessWidget {
  final String title;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String?> onChanged;

  const _DropdownTile({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        items: options.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: onChanged,
        style: const TextStyle(
            fontSize: 14,
            color: AppColors.primary,
            fontWeight: FontWeight.w600),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

class _SliderTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final String label;
  final ValueChanged<double> onChanged;

  const _SliderTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
            ],
          ),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          Slider(
            value: value,
            min: min,
            max: max,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.border,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(title,
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, color: color)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: Icon(Icons.chevron_right_rounded,
          color: AppColors.textHint, size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
