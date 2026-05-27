import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../providers/theme_provider.dart';
import '../providers/app_provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_localizations.dart';
import '../utils/theme_helper.dart';
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
  bool _locationEnabled = true;
  String _measureInterval = '1h';
  double _alertThreshold = 65;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final app = Provider.of<AppProvider>(context, listen: false);
        setState(() {
          _locationEnabled = app.locationEnabled;
        });
      }
    });
  }

  Color _getColor(Color light, Color dark) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  // ── Toggle localisation ───────────────────────────────────────────────────
  Future<void> _toggleLocation(bool value) async {
    final app = Provider.of<AppProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context);

    if (value) {
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.t('gps_disabled_error')),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
          setState(() => _locationEnabled = false);
          return;
        }

        LocationPermission permission = await Geolocator.checkPermission();

        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.t('gps_permission_denied')),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
            setState(() => _locationEnabled = false);
            return;
          }
        }

        if (permission == LocationPermission.deniedForever) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.t('gps_permission_forever')),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          setState(() => _locationEnabled = false);
          return;
        }

        await app.enableLocation(true);
        if (mounted) {
          setState(() => _locationEnabled = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.t('location_enabled')),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${l10n.t('error_prefix')}$e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
          setState(() => _locationEnabled = false);
        }
      }
    } else {
      // ── L'utilisateur désactive la localisation ──────────────────────
      await app.enableLocation(false);
      if (mounted) {
        setState(() => _locationEnabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.t('location_disabled')),
            backgroundColor: Colors.grey,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildLanguageCard({
    required BuildContext context,
    required String langCode,
    required String label,
    required String flag,
    required bool isSelected,
  }) {
    final surface = ThemeHelper.surface(context);
    final border = isSelected ? ThemeHelper.primary : ThemeHelper.border(context);
    final textPrimary = ThemeHelper.textPrimary(context);

    return GestureDetector(
      onTap: () {
        context.read<LanguageProvider>().setLanguage(langCode);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? ThemeHelper.primary.withOpacity(0.08) : surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: border,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    flag,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: ThemeHelper.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAr = l10n.isArabic;

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
    const primary = AppColors.primary;
    final warning = _getColor(AppColors.warning, AppColors.darkWarning);
    final normal = _getColor(AppColors.normal, AppColors.darkNormal);
    final critical = _getColor(AppColors.critical, AppColors.darkCritical);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text(l10n.t('settings_title')),
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
                        l10n.t('app_version_academic_prototype'),
                        style: TextStyle(
                            fontSize: 13, color: primary, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section Langue / Language
              _SettingsSection(
                title: l10n.t('language'),
                icon: Icons.language_rounded,
                color: primary,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildLanguageCard(
                            context: context,
                            langCode: 'fr',
                            label: l10n.t('french'),
                            flag: '🇫🇷',
                            isSelected: !isAr,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildLanguageCard(
                            context: context,
                            langCode: 'ar',
                            label: l10n.t('arabic'),
                            flag: '🇸🇦',
                            isSelected: isAr,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _SettingsSection(
                title: l10n.t('monitoring'),
                icon: Icons.monitor_heart_rounded,
                color: primary,
                children: [
                  _ToggleTile(
                    title: l10n.t('ecg_auto'),
                    subtitle: l10n.t('ecg_auto_subtitle'),
                    value: _ecgAutoRecord,
                    onChanged: (v) => setState(() => _ecgAutoRecord = v),
                  ),
                  _DropdownTile(
                    title: l10n.t('measure_frequency'),
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
                    title: l10n.t('ia_alert_threshold'),
                    subtitle: l10n.t('ia_alert_threshold_subtitle'),
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
                title: l10n.t('notifications'),
                icon: Icons.notifications_rounded,
                color: warning,
                children: [
                  _ToggleTile(
                    title: l10n.t('notifications'),
                    subtitle: l10n.t('notifications'),
                    value: _notificationsEnabled,
                    onChanged: (v) => setState(() => _notificationsEnabled = v),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _SettingsSection(
                title: l10n.t('confidentiality'),
                icon: Icons.lock_rounded,
                color: normal,
                children: [
                  _ToggleTile(
                    title: l10n.t('share_with_cardiologist'),
                    subtitle: l10n.t('share_with_cardiologist_subtitle'),
                    value: _shareDataCardiologist,
                    onChanged: (v) =>
                        setState(() => _shareDataCardiologist = v),
                  ),
                  // ── Toggle GPS — désactiver ici bloque la carte ─────────
                  _ToggleTile(
                    title: l10n.t('gps_location'),
                    subtitle: _locationEnabled
                        ? l10n.t('gps_location_subtitle_enabled')
                        : l10n.t('gps_location_subtitle_disabled'),
                    value: _locationEnabled,
                    onChanged: _toggleLocation,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _SettingsSection(
                title: l10n.t('appearance'),
                icon: Icons.palette_rounded,
                color: const Color(0xFF6A1B9A),
                children: [
                  _ToggleTile(
                    title: l10n.t('dark_theme'),
                    subtitle: l10n.t('dark_theme_subtitle'),
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
                title: l10n.t('data'),
                icon: Icons.storage_rounded,
                color: textSecondary,
                children: [
                  _ActionTile(
                    title: l10n.t('export_history'),
                    subtitle: l10n.t('export_history_subtitle'),
                    icon: Icons.download_rounded,
                    color: primary,
                    onTap: () => _exportHistory(context),
                  ),
                  _ActionTile(
                    title: l10n.t('share_with_doctor'),
                    subtitle: l10n.t('share_with_doctor_subtitle'),
                    icon: Icons.share_rounded,
                    color: primary,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(l10n.t('feature_to_implement'))),
                      );
                    },
                  ),
                  _ActionTile(
                    title: l10n.t('clear_history'),
                    subtitle: l10n.t('clear_history_subtitle'),
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

  // ── Export PDF ────────────────────────────────────────────────────────────
  Future<void> _exportHistory(BuildContext context) async {
    final app = Provider.of<AppProvider>(context, listen: false);
    final history = app.history;
    final l10n = AppLocalizations.of(context);

    if (history.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('no_records_to_export')),
          backgroundColor: const Color.fromARGB(255, 238, 162, 20),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Text(l10n.t('generating_pdf')),
          ],
        ),
        duration: const Duration(seconds: 3),
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
                pw.Text('${l10n.t('patient')} : ${app.profile.name}',
                    style: const pw.TextStyle(fontSize: 12)),
                pw.Text('${l10n.t('patient_id')} : ${app.profile.patientId}',
                    style: const pw.TextStyle(fontSize: 12)),
                pw.Text(
                    '${l10n.t('generated_on')} : ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 20),
                pw.Header(level: 1, child: pw.Text(l10n.t('summary'))),
                pw.TableHelper.fromTextArray(
                  headers: [l10n.t('status'), l10n.t('count'), l10n.t('percentage')],
                  data: [
                    [
                      '✅ ${l10n.t('yes')}',
                      '$normalCount',
                      '${((normalCount / history.length) * 100).toInt()}%'
                    ],
                    [
                      '⚠️ ${l10n.t('optional')}',
                      '$suspectCount',
                      '${((suspectCount / history.length) * 100).toInt()}%'
                    ],
                    [
                      '❌ ${l10n.t('error')}',
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
                pw.Text('${l10n.t('average_bpm')} : $avgBpm',
                    style: pw.TextStyle(
                        fontSize: 11, fontStyle: pw.FontStyle.italic)),
                pw.SizedBox(height: 20),
                pw.Header(
                    level: 1, child: pw.Text(l10n.t('readings_detail'))),
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
                              '📊 ${l10n.t('status')}: ${_getStatusText(reading.status, l10n)}',
                              style: pw.TextStyle(
                                  fontSize: 10,
                                  color: _getPdfStatusColor(reading.status))),
                          pw.Divider(),
                        ],
                      ),
                    )),
                pw.SizedBox(height: 20),
                pw.Center(
                  child: pw.Text(
                    l10n.t('academic_prototype_disclaimer'),
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
          SnackBar(
            content: Text(l10n.t('pdf_generated_success')),
            backgroundColor: const Color.fromARGB(255, 81, 196, 85),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.t('export_error')}$e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _getStatusText(HealthStatus status, AppLocalizations l10n) {
    switch (status) {
      case HealthStatus.normal:
        return l10n.t('yes');
      case HealthStatus.suspect:
        return l10n.t('optional');
      case HealthStatus.critical:
        return l10n.t('error');
    }
  }

  PdfColor _getPdfStatusColor(HealthStatus status) {
    switch (status) {
      case HealthStatus.normal:
        return PdfColors.green;
      case HealthStatus.suspect:
        return PdfColors.orange;
      case HealthStatus.critical:
        return PdfColors.red;
    }
  }

  // ── Effacer l'historique ──────────────────────────────────────────────────
  void _confirmDelete(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
        ? l10n.t('history_already_empty')
        : l10n.t('confirm_delete_content').replaceAll('{count}', '$count');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: background,
        title:
            Text(l10n.t('clear_history'), style: TextStyle(color: textPrimary)),
        content: Text(contentMessage, style: TextStyle(color: textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.t('cancel'), style: TextStyle(color: textPrimary))),
          TextButton(
            onPressed: () {
              app.clearAllHistory();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(wasEmpty
                      ? l10n.t('history_deleted_empty')
                      : '$count ${l10n.t('records_deleted')}'),
                  backgroundColor: wasEmpty ? Colors.grey : Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: critical),
            child: Text(l10n.t('delete')),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WIDGETS INTERNES
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
  final ValueChanged<bool>? onChanged;
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
