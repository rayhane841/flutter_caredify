import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart'; // ← NOUVEL IMPORT
import '../theme/app_theme.dart';
import '../providers/theme_provider.dart';
import '../providers/app_provider.dart';
import '../models/ecg_reading.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _ecgAutoRecord = false;
  bool _shareDataCardiologist = true;
  bool _locationEnabled = true; // ← État local synchronisé avec AppProvider
  String _measureInterval = '1h';
  double _alertThreshold = 65;

  @override
  void initState() {
    super.initState();
    // ✅ Synchroniser l'état local avec AppProvider au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final app = Provider.of<AppProvider>(context, listen: false);
        setState(() {
          _locationEnabled = app.locationEnabled;
        });
      }
    });
  }

  // ✅ Helper : retourne la couleur appropriée selon le thème actif
  Color _getColor(Color light, Color dark) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  // ✅✅✅ MÉTHODE : Gérer le toggle de localisation ✅✅✅
  Future<void> _toggleLocation(bool value) async {
    final app = Provider.of<AppProvider>(context, listen: false);

    if (value) {
      // ✅ L'utilisateur veut ACTIVER la localisation
      try {
        // 1. Vérifier si les services de localisation sont activés
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Les services de localisation sont désactivés'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
          // Revenir à l'état précédent
          setState(() => _locationEnabled = false);
          return;
        }

        // 2. Vérifier les permissions
        LocationPermission permission = await Geolocator.checkPermission();

        if (permission == LocationPermission.denied) {
          // Demander la permission
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ Permission de localisation refusée'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
            setState(() => _locationEnabled = false);
            return;
          }
        }

        if (permission == LocationPermission.deniedForever) {
          // Permission refusée définitivement → guider vers les paramètres
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '⚠️ Permission refusée définitivement. Activez-la dans Paramètres > Applications.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
          setState(() => _locationEnabled = false);
          return;
        }

        // 3. Permission accordée → activer dans AppProvider
        await app.enableLocation(true);
        setState(() => _locationEnabled = true);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Localisation activée'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur : $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        setState(() => _locationEnabled = false);
      }
    } else {
      // ✅ L'utilisateur veut DÉSACTIVER la localisation
      await app.enableLocation(false);
      setState(() => _locationEnabled = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📍 Localisation désactivée'),
          backgroundColor: Colors.grey,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Récupération dynamique des couleurs
    final background =
        _getColor(AppColors.background, AppColors.darkBackground);
    final surface = _getColor(AppColors.surface, AppColors.darkSurface);
    final surfaceVariant =
        _getColor(AppColors.surfaceVariant, AppColors.darkSurfaceVariant);
    final border = _getColor(AppColors.border, AppColors.darkBorder);
    final textPrimary =
        _getColor(AppColors.textPrimary, AppColors.darkTextPrimary);
    final textSecondary =
        _getColor(AppColors.textSecondary, AppColors.darkTextSecondary);
    final textHint = _getColor(AppColors.textHint, AppColors.darkTextHint);
    const primary = AppColors.primary;
    final warning = _getColor(AppColors.warning, AppColors.darkWarning);
    final normal = _getColor(AppColors.normal, AppColors.darkNormal);
    final critical = _getColor(AppColors.critical, AppColors.darkCritical);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Paramètres'),
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: border),
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
                  color: surfaceVariant,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'CAREDIFY v1.0.0 — Prototype académique\nMode simulé, aucune donnée réelle transmise',
                        style: TextStyle(
                            fontSize: 13, color: primary, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _SettingsSection(
                title: 'Surveillance',
                icon: Icons.monitor_heart_rounded,
                color: primary,
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
                    options: const {
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
                color: warning,
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
                color: normal,
                children: [
                  _ToggleTile(
                    title: 'Partager avec cardiologue',
                    subtitle: 'Données ECG transmises au Dr. Lefebvre',
                    value: _shareDataCardiologist,
                    onChanged: (v) =>
                        setState(() => _shareDataCardiologist = v),
                  ),
                  // ✅✅✅ TOGGLE LOCALISATION GPS FONCTIONNEL ✅✅✅
                  _ToggleTile(
                    title: 'Localisation GPS',
                    subtitle: 'Pour les urgences et la carte',
                    value: _locationEnabled,
                    onChanged: _toggleLocation, // ← Appel de la méthode async
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
                    value: Provider.of<ThemeProvider>(context).isDarkMode,
                    onChanged: (v) {
                      Provider.of<ThemeProvider>(context, listen: false)
                          .toggleDarkMode(v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _SettingsSection(
                title: 'Données',
                icon: Icons.storage_rounded,
                color: textSecondary,
                children: [
                  _ActionTile(
                    title: 'Exporter l\'historique',
                    subtitle: 'Télécharger toutes les mesures en PDF',
                    icon: Icons.download_rounded,
                    color: primary,
                    onTap: () => _exportHistory(context),
                  ),
                  _ActionTile(
                    title: 'Partager avec médecin',
                    subtitle: 'Envoyer un rapport par email',
                    icon: Icons.share_rounded,
                    color: primary,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Fonctionnalité à implémenter')),
                      );
                    },
                  ),
                  _ActionTile(
                    title: 'Effacer l\'historique',
                    subtitle: 'Supprimer toutes les mesures locales',
                    icon: Icons.delete_rounded,
                    color: critical,
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

  // ✅✅✅ MÉTHODE : Exporter l'historique en PDF ✅✅✅
  Future<void> _exportHistory(BuildContext context) async {
    final app = Provider.of<AppProvider>(context, listen: false);
    final history = app.history;

    if (history.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Aucun enregistrement à exporter'),
          backgroundColor: Color.fromARGB(255, 238, 162, 20),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Text('Génération du PDF...'),
          ],
        ),
        duration: Duration(seconds: 3),
        backgroundColor: Colors.blue,
      ),
    );

    try {
      final pdf = pw.Document();
      final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');

      final avgBpm =
          history.fold<int>(0, (sum, r) => sum + r.heartRate) ~/ history.length;
      final normalCount =
          history.where((r) => r.status == HealthStatus.normal).length;
      final suspectCount =
          history.where((r) => r.status == HealthStatus.suspect).length;
      final criticalCount =
          history.where((r) => r.status == HealthStatus.critical).length;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('CAREDIFY',
                          style: pw.TextStyle(
                              fontSize: 24, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Rapport ECG',
                          style: const pw.TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
                pw.Divider(),
                pw.Text('Patient : ${app.profile.name}',
                    style: const pw.TextStyle(fontSize: 12)),
                pw.Text('ID Patient : ${app.profile.patientId}',
                    style: const pw.TextStyle(fontSize: 12)),
                pw.Text(
                    'Généré le : ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 20),
                pw.Header(level: 1, child: pw.Text('Récapitulatif')),
                pw.TableHelper.fromTextArray(
                  headers: ['Statut', 'Nombre', 'Pourcentage'],
                  data: [
                    [
                      '✅ Normal',
                      '$normalCount',
                      '${((normalCount / history.length) * 100).toInt()}%'
                    ],
                    [
                      '⚠️ Suspect',
                      '$suspectCount',
                      '${((suspectCount / history.length) * 100).toInt()}%'
                    ],
                    [
                      '❌ Critique',
                      '$criticalCount',
                      '${((criticalCount / history.length) * 100).toInt()}%'
                    ],
                  ],
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.center,
                    2: pw.Alignment.center
                  },
                ),
                pw.SizedBox(height: 10),
                pw.Text('Moyenne BPM : $avgBpm',
                    style: pw.TextStyle(
                        fontSize: 11, fontStyle: pw.FontStyle.italic)),
                pw.SizedBox(height: 20),
                pw.Header(
                    level: 1, child: pw.Text('Détail des enregistrements')),
                ...history.take(50).map((reading) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 8),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('📅 ${dateFormat.format(reading.timestamp)}',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 11)),
                          pw.SizedBox(height: 4),
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text('❤️ ${reading.heartRate} bpm',
                                  style: const pw.TextStyle(fontSize: 10)),
                              pw.Text('⏱️ ${reading.durationSeconds}s',
                                  style: const pw.TextStyle(fontSize: 10)),
                              pw.Text('🎯 Score: ${reading.riskScore}/100',
                                  style: const pw.TextStyle(fontSize: 10)),
                            ],
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text(
                              '📊 Statut: ${_getStatusText(reading.status)}',
                              style: pw.TextStyle(
                                fontSize: 10,
                                color: _getStatusColor(reading.status) ==
                                        HealthStatus.normal
                                    ? PdfColors.green
                                    : _getStatusColor(reading.status) ==
                                            HealthStatus.suspect
                                        ? PdfColors.orange
                                        : PdfColors.red,
                              )),
                          pw.Divider(),
                        ],
                      ),
                    )),
                pw.SizedBox(height: 20),
                pw.Center(
                  child: pw.Text(
                    'Document généré par CAREDIFY — Prototype académique\nAucune valeur diagnostique',
                    style:
                        const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name:
            'CAREDIFY_Historique_ECG_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ PDF généré avec succès !'),
            backgroundColor: Color.fromARGB(255, 81, 196, 85),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur lors de l\'export : $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ✅ Helper pour le statut texte
  String _getStatusText(HealthStatus status) {
    switch (status) {
      case HealthStatus.normal:
        return 'Normal';
      case HealthStatus.suspect:
        return 'Suspect';
      case HealthStatus.critical:
        return 'Critique';
    }
  }

  // ✅ Helper pour la couleur du statut (pour PDF)
  PdfColor _getStatusColor(HealthStatus status) {
    switch (status) {
      case HealthStatus.normal:
        return PdfColors.green;
      case HealthStatus.suspect:
        return PdfColors.orange;
      case HealthStatus.critical:
        return PdfColors.red;
    }
  }

  // ✅✅✅ MÉTHODE : Effacer l'historique via AppProvider ✅✅✅
  void _confirmDelete(BuildContext context) {
    final background = _getColor(AppColors.surface, AppColors.darkSurface);
    final textPrimary =
        _getColor(AppColors.textPrimary, AppColors.darkTextPrimary);
    final textSecondary =
        _getColor(AppColors.textSecondary, AppColors.darkTextSecondary);
    final critical = _getColor(AppColors.critical, AppColors.darkCritical);
    final app = Provider.of<AppProvider>(context, listen: false);

    final wasEmpty = app.history.isEmpty;
    final count = app.history.length;
    final contentMessage = wasEmpty
        ? 'L\'historique est déjà vide. Aucune action nécessaire.'
        : 'Cette action est irréversible. Toutes les $count mesures seront supprimées définitivement.';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: background,
        title:
            Text('Effacer l\'historique', style: TextStyle(color: textPrimary)),
        content: Text(contentMessage, style: TextStyle(color: textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: TextStyle(color: textPrimary))),
          TextButton(
            onPressed: () {
              app.clearAllHistory();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(wasEmpty
                      ? 'ℹ️ Historique déjà vide'
                      : '✅ $count enregistrement(s) supprimé(s)'),
                  backgroundColor: wasEmpty ? Colors.grey : Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: critical),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WIDGETS INTERNES (inchangés)
// ─────────────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;
  const _SettingsSection(
      {required this.title,
      required this.icon,
      required this.color,
      required this.children});
  @override
  Widget build(BuildContext context) {
    final surface =
        _getColor(context, AppColors.surface, AppColors.darkSurface);
    final border = _getColor(context, AppColors.border, AppColors.darkBorder);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(title,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.5))
      ]),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border)),
        child: Column(
            children: children.asMap().entries.map((e) {
          final isLast = e.key == children.length - 1;
          return Column(children: [
            e.value,
            if (!isLast)
              Divider(height: 1, indent: 16, endIndent: 16, color: border)
          ]);
        }).toList()),
      ),
    ]);
  }
}

class _ToggleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged; // ← Nullable pour gérer async
  const _ToggleTile(
      {required this.title,
      required this.subtitle,
      required this.value,
      this.onChanged});
  @override
  Widget build(BuildContext context) {
    final textPrimary =
        _getColor(context, AppColors.textPrimary, AppColors.darkTextPrimary);
    final textSecondary = _getColor(
        context, AppColors.textSecondary, AppColors.darkTextSecondary);
    const primary = AppColors.primary;
    final textHint =
        _getColor(context, AppColors.textHint, AppColors.darkTextHint);
    final border = _getColor(context, AppColors.border, AppColors.darkBorder);
    return ListTile(
      title: Text(title,
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary)),
      subtitle:
          Text(subtitle, style: TextStyle(fontSize: 12, color: textSecondary)),
      trailing: Switch(
        value: value,
        onChanged: onChanged != null ? (v) => onChanged!(v) : null,
        activeThumbColor: primary,
        inactiveThumbColor: textHint,
        inactiveTrackColor: border,
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
  const _DropdownTile(
      {required this.title,
      required this.value,
      required this.options,
      required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final textPrimary =
        _getColor(context, AppColors.textPrimary, AppColors.darkTextPrimary);
    const primary = AppColors.primary;
    final surface =
        _getColor(context, AppColors.surface, AppColors.darkSurface);
    return ListTile(
      title: Text(title,
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary)),
      trailing: DropdownButton<String>(
        value: value,
        underline: const SizedBox(),
        dropdownColor: surface,
        items: options.entries
            .map((e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value, style: TextStyle(color: textPrimary))))
            .toList(),
        onChanged: onChanged,
        style: TextStyle(
            fontSize: 14, color: primary, fontWeight: FontWeight.w600),
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
  const _SliderTile(
      {required this.title,
      required this.subtitle,
      required this.value,
      required this.min,
      required this.max,
      required this.label,
      required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final textPrimary =
        _getColor(context, AppColors.textPrimary, AppColors.darkTextPrimary);
    final textSecondary = _getColor(
        context, AppColors.textSecondary, AppColors.darkTextSecondary);
    const primary = AppColors.primary;
    final border = _getColor(context, AppColors.border, AppColors.darkBorder);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(title,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textPrimary)),
          Text(label,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: primary)),
        ]),
        Text(subtitle, style: TextStyle(fontSize: 12, color: textSecondary)),
        Slider(
            value: value,
            min: min,
            max: max,
            activeColor: primary,
            inactiveColor: border,
            onChanged: onChanged),
      ]),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  const _ActionTile(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.onTap,
      this.color = AppColors.primary});
  @override
  Widget build(BuildContext context) {
    final textSecondary = _getColor(
        context, AppColors.textSecondary, AppColors.darkTextSecondary);
    final textHint =
        _getColor(context, AppColors.textHint, AppColors.darkTextHint);
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(title,
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600, color: color)),
      subtitle:
          Text(subtitle, style: TextStyle(fontSize: 12, color: textSecondary)),
      trailing: Icon(Icons.chevron_right_rounded, color: textHint, size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HELPER STATIQUE
// ─────────────────────────────────────────────────────────────
Color _getColor(BuildContext context, Color light, Color dark) {
  return Theme.of(context).brightness == Brightness.dark ? dark : light;
}
