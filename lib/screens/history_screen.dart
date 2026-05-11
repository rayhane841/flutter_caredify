import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/theme_helper.dart';
import '../models/ecg_reading.dart';
import 'ecg_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, app, _) {
        final bg = ThemeHelper.background(context);
        final surface = ThemeHelper.surface(context);
        final border = ThemeHelper.border(context);
        final textPrimary = ThemeHelper.textPrimary(context);
        final textSecondary = ThemeHelper.textSecondary(context);
        final primary = ThemeHelper.primary;
        final normal = ThemeHelper.normal(context);
        final warning = ThemeHelper.warning(context);
        final critical = ThemeHelper.critical(context);

        final avgBpm = app.history.isNotEmpty
            ? (app.history.fold<int>(0, (sum, r) => sum + r.heartRate) /
                    app.history.length)
                .round()
            : 0;

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context)),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Historique ECG',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                Text('7 derniers jours',
                    style: TextStyle(
                        fontSize: 13, color: Colors.white.withOpacity(0.8))),
              ],
            ),
            actions: [
              // ✅ BOUTON EXPORT PDF FONCTIONNEL
              IconButton(
                  icon: const Icon(Icons.download_rounded, color: Colors.white),
                  onPressed: () => _exportHistory(context, app)),
            ],
          ),
          body: ClipRect(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pills statistiques
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                      color: surface,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                              child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                      color: normal.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20)),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.favorite,
                                            size: 16, color: normal),
                                        const SizedBox(width: 4),
                                        Flexible(
                                            child: Text('Moy: $avgBpm bpm',
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: normal),
                                                overflow:
                                                    TextOverflow.ellipsis))
                                      ]))),
                          const SizedBox(width: 8),
                          Flexible(
                              child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                      color: primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20)),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.analytics_rounded,
                                            size: 16, color: primary),
                                        const SizedBox(width: 4),
                                        Flexible(
                                            child: Text(
                                                '${app.history.length} mesures',
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: primary),
                                                overflow:
                                                    TextOverflow.ellipsis))
                                      ]))),
                        ],
                      ),
                    ),
                    // Récapitulatif
                    Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2))
                          ]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text('Récapitulatif',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary)),
                            const Spacer(),
                            Icon(Icons.trending_up_rounded,
                                size: 14, color: primary)
                          ]),
                          const SizedBox(height: 12),
                          GridView.count(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisCount: 3,
                              mainAxisSpacing: 0,
                              crossAxisSpacing: 4,
                              childAspectRatio: 1.5,
                              children: [
                                _CompactRecapColumn(
                                    count: app.history
                                        .where((r) =>
                                            r.status == HealthStatus.normal)
                                        .length,
                                    label: 'Normal',
                                    color: normal,
                                    textSecondary: textSecondary),
                                Container(width: 1, height: 30, color: border),
                                _CompactRecapColumn(
                                    count: app.history
                                        .where((r) =>
                                            r.status == HealthStatus.suspect)
                                        .length,
                                    label: 'Suspect',
                                    color: warning,
                                    textSecondary: textSecondary),
                                Container(width: 1, height: 30, color: border),
                                _CompactRecapColumn(
                                    count: app.history
                                        .where((r) =>
                                            r.status == HealthStatus.critical)
                                        .length,
                                    label: 'Critique',
                                    color: critical,
                                    textSecondary: textSecondary),
                              ]),
                        ],
                      ),
                    ),
                    // Titre ENREGISTREMENTS
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('ENREGISTREMENTS',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: textSecondary,
                                  letterSpacing: 0.5)),
                          TextButton.icon(
                              icon: const Icon(Icons.delete_outline, size: 16),
                              label: const Text('Tout effacer',
                                  style: TextStyle(fontSize: 11)),
                              style: TextButton.styleFrom(
                                  foregroundColor: critical,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8)),
                              onPressed: app.history.isEmpty
                                  ? null
                                  : () => _showClearAllDialog(context, app,
                                      critical, surface, textPrimary)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Liste des enregistrements
                    app.history.isEmpty
                        ? Center(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                Icon(Icons.history_rounded,
                                    size: 64, color: textSecondary),
                                const SizedBox(height: 12),
                                Text('Aucun historique',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: textSecondary))
                              ]))
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: app.history.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final reading = app.history[index];
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          EcgDetailScreen(reading: reading),
                                    ),
                                  );
                                },
                                child: _CompactEcgHistoryItem(
                                    reading: reading,
                                    onDelete: () => _showDeleteDialog(
                                        context,
                                        app,
                                        reading.id,
                                        critical,
                                        surface,
                                        textPrimary),
                                    surface: surface,
                                    border: border,
                                    textPrimary: textPrimary,
                                    textSecondary: textSecondary,
                                    normal: normal,
                                    warning: warning,
                                    critical: critical),
                              );
                            },
                          ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ✅✅✅ MÉTHODE : Exporter l'historique en PDF (identique à SettingsScreen) ✅✅✅
  Future<void> _exportHistory(BuildContext context, AppProvider app) async {
    final history = app.history;

    // ✅ Gérer le cas où l'historique est vide
    if (history.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun enregistrement à exporter'),
          backgroundColor: Color.fromARGB(255, 230, 158, 25),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // ✅ Afficher un indicateur de chargement
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
      // ✅ Créer le document PDF
      final pdf = pw.Document();
      final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');

      // Calculer les statistiques
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
                // En-tête
                pw.Header(
                  level: 0,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('CAREDIFY',
                          style: pw.TextStyle(
                              fontSize: 24, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Rapport ECG', style: const pw.TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
                pw.Divider(),

                // Informations patient
                pw.Text('Patient : ${app.profile.name}',
                    style: const pw.TextStyle(fontSize: 12)),
                pw.Text('ID Patient : ${app.profile.patientId}',
                    style: const pw.TextStyle(fontSize: 12)),
                pw.Text(
                    'Généré le : ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 20),

                // Statistiques
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
                    2: pw.Alignment.center,
                  },
                ),
                pw.SizedBox(height: 10),
                pw.Text('Moyenne BPM : $avgBpm',
                    style: pw.TextStyle(
                        fontSize: 11, fontStyle: pw.FontStyle.italic)),
                pw.SizedBox(height: 20),

                // Historique détaillé
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

                // Pied de page
                pw.SizedBox(height: 20),
                pw.Center(
                  child: pw.Text(
                    'Document généré par CAREDIFY — Prototype académique\nAucune valeur diagnostique',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            );
          },
        ),
      );

      // ✅ Afficher le PDF ou le partager
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name:
            'CAREDIFY_Historique_ECG_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );

      // ✅ Message de succès
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(' PDF généré avec succès !'),
            backgroundColor: Color.fromARGB(255, 82, 192, 86),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // ✅ Gestion d'erreur
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(' Erreur lors de l\'export : $e'),
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

  void _showDeleteDialog(BuildContext context, AppProvider app,
      String readingId, Color critical, Color surface, Color textPrimary) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surface,
        title: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
          const SizedBox(width: 8),
          Text('Supprimer', style: TextStyle(color: textPrimary))
        ]),
        content: Text(
            'Êtes-vous sûr de vouloir supprimer cet enregistrement ECG ?\n\nCette action est irréversible.',
            style: TextStyle(color: textPrimary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler', style: TextStyle(color: textPrimary))),
          ElevatedButton(
              onPressed: () {
                app.deleteHistoryItem(readingId);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Enregistrement supprimé'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2)));
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: critical, foregroundColor: Colors.white),
              child: const Text('Supprimer')),
        ],
      ),
    );
  }

  void _showClearAllDialog(BuildContext context, AppProvider app,
      Color critical, Color surface, Color textPrimary) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surface,
        title: Row(children: [
          Icon(Icons.delete_forever_rounded, color: critical, size: 24),
          const SizedBox(width: 8),
          Text('Tout effacer', style: TextStyle(color: textPrimary))
        ]),
        content: Text(
            'Êtes-vous sûr de vouloir supprimer TOUT l\'historique ?\n\n${app.history.length} enregistrement(s) seront perdus définitivement.',
            style: TextStyle(color: textPrimary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler', style: TextStyle(color: textPrimary))),
          ElevatedButton(
              onPressed: () {
                app.clearAllHistory();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Historique vidé'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2)));
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: critical, foregroundColor: Colors.white),
              child: const Text('Tout supprimer')),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🆕 NOUVEAU : Écran de détail ECG
// ═══════════════════════════════════════════════════════════
class EcgDetailScreen extends StatelessWidget {
  final EcgReading reading;
  const EcgDetailScreen({super.key, required this.reading});

  @override
  Widget build(BuildContext context) {
    final bg = ThemeHelper.background(context);
    final surface = ThemeHelper.surface(context);
    final border = ThemeHelper.border(context);
    final textPrimary = ThemeHelper.textPrimary(context);
    final textSecondary = ThemeHelper.textSecondary(context);
    final primary = ThemeHelper.primary;
    final statusColor = reading.status == HealthStatus.normal
        ? ThemeHelper.normal(context)
        : reading.status == HealthStatus.suspect
            ? ThemeHelper.warning(context)
            : ThemeHelper.critical(context);

    // Formatage de la date complète
    final dateFormat = DateFormat('EEEE d MMMM yyyy', 'fr_FR');
    final timeFormat = DateFormat('HH:mm', 'fr_FR');
    final fullDate =
        '${dateFormat.format(reading.timestamp)} à ${timeFormat.format(reading.timestamp)}';

    // Diagnostic et conseils selon le statut
    final diagnosis = _getDiagnosis(reading.status);
    final advice = _getCardiologistAdvice(reading.status);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Détail ECG'),
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
              // 📅 Date complète
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        color: primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Date de l\'enregistrement',
                              style: TextStyle(
                                  fontSize: 12, color: textSecondary)),
                          const SizedBox(height: 4),
                          Text(fullDate,
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 📊 Graphique ECG agrandi
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.ecgBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.show_chart_rounded,
                            color: AppColors.ecgGreen, size: 18),
                        SizedBox(width: 8),
                        Text('Signal ECG - Dérivation I',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ecgGreen)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 180,
                      child: CustomPaint(
                        painter: _DetailedEcgPainter(color: AppColors.ecgGreen),
                        size: const Size(double.infinity, 180),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _MiniStat(
                            label: 'Durée',
                            value: '${reading.durationSeconds}s',
                            color: AppColors.ecgGreen),
                        _MiniStat(
                            label: 'Fréquence',
                            value: '${reading.heartRate} bpm',
                            color: AppColors.ecgGreen),
                        const _MiniStat(
                            label: 'Qualité',
                            value: '94%',
                            color: AppColors.ecgGreen),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 🩺 Diagnostic IA
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          reading.status == HealthStatus.normal
                              ? Icons.check_circle_rounded
                              : reading.status == HealthStatus.suspect
                                  ? Icons.warning_rounded
                                  : Icons.error_rounded,
                          color: statusColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text('Diagnostic',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: statusColor)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(diagnosis,
                        style: TextStyle(
                            fontSize: 14, height: 1.5, color: textPrimary)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 💡 Conseils du cardiologue
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.favorite,
                              color: Color(0xFF1A47C0), size: 16),
                        ),
                        const SizedBox(width: 8),
                        Text('Conseils du Dr. Lefebvre',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...advice.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(top: 6),
                                decoration: BoxDecoration(
                                  color: primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(item,
                                    style: TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        color: textPrimary)),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              //  BOUTON : Nouvel enregistrement ECG (Navigation vers EcgScreen)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    //  Navigation vers EcgScreen pour un nouvel enregistrement
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const EcgScreen()),
                    );
                  },
                  // Icône changée : monitor_heart_rounded (plus pertinente que refresh)
                  icon: const Icon(Icons.monitor_heart_rounded, size: 15),
                  label: const Text('Nouvel enregistrement ECG',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 25),
            ],
          ),
        ),
      ),
    );
  }

  String _getDiagnosis(HealthStatus status) {
    switch (status) {
      case HealthStatus.normal:
        return 'Rythme sinusal normal détecté. Aucune anomalie significative observée sur le signal ECG. Les intervalles PR, QRS et QT sont dans les limites normales.';
      case HealthStatus.suspect:
        return 'Anomalie mineure détectée : légère variation du segment ST ou irrégularité du rythme. Une surveillance rapprochée est recommandée. Consultez votre cardiologue pour interprétation.';
      case HealthStatus.critical:
        return 'Anomalie significative détectée : possible ischémie, arythmie ou autre pathologie cardiaque. Une évaluation médicale urgente est recommandée.';
    }
  }

  List<String> _getCardiologistAdvice(HealthStatus status) {
    switch (status) {
      case HealthStatus.normal:
        return [
          'Continuez votre activité physique régulière adaptée à votre condition',
          'Maintenez votre traitement actuel sans modification',
          'Effectuez un contrôle ECG de routine dans 6 mois',
          'Signalez tout symptôme nouveau (palpitations, essoufflement, douleur thoracique)',
        ];
      case HealthStatus.suspect:
        return [
          'Évitez les efforts physiques intenses jusqu\'à nouvel ordre',
          'Surveillez l\'apparition de symptômes : douleur thoracique, vertiges, palpitations',
          'Prenez vos médicaments selon la prescription actuelle',
          'Planifiez une consultation avec votre cardiologue dans les 7 jours',
        ];
      case HealthStatus.critical:
        return [
          'Restez au repos et évitez tout effort physique',
          'Si douleur thoracique persistante > 5 min : appelez le 15 immédiatement',
          'Ne modifiez pas votre traitement sans avis médical',
          'Consultez en urgence ou rendez-vous aux urgences les plus proches',
        ];
    }
  }
}

// ═══════════════════════════════════════════════════════════
//  Painter pour ECG détaillé (plus de points, plus fluide)
// ═══════════════════════════════════════════════════════════
class _DetailedEcgPainter extends CustomPainter {
  final Color color;
  _DetailedEcgPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final height = size.height;
    final width = size.width;
    final baseline = height / 2;

    // Génération d'un signal ECG réaliste avec onde P, QRS, onde T
    path.moveTo(0, baseline);

    // Segment isoélectrique initial
    path.lineTo(width * 0.08, baseline);

    // Onde P
    _addSmoothWave(path, width * 0.08, baseline, width * 0.12, -height * 0.15);
    path.lineTo(width * 0.20, baseline);

    // Segment PR
    path.lineTo(width * 0.28, baseline);

    // Complexe QRS (plus prononcé)
    path.lineTo(width * 0.30, baseline - height * 0.05); // Q
    path.lineTo(width * 0.33, baseline + height * 0.35); // R (pic)
    path.lineTo(width * 0.36, baseline - height * 0.10); // S
    path.lineTo(width * 0.40, baseline);

    // Segment ST
    path.lineTo(width * 0.52, baseline);

    // Onde T
    _addSmoothWave(path, width * 0.52, baseline, width * 0.68, -height * 0.20);
    path.lineTo(width * 0.75, baseline);

    // Segment final
    path.lineTo(width, baseline);

    canvas.drawPath(path, paint);

    // Grille de fond subtile
    final gridPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..strokeWidth = 0.5;

    // Lignes horizontales
    for (int i = 0; i <= 4; i++) {
      final y = baseline - height * 0.25 + i * height * 0.125;
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }

    // Lignes verticales
    for (int i = 0; i <= 10; i++) {
      final x = i * width * 0.1;
      canvas.drawLine(Offset(x, 0), Offset(x, height), gridPaint);
    }
  }

  void _addSmoothWave(
      Path path, double startX, double startY, double endX, double amplitude) {
    final controlX = (startX + endX) / 2;
    final controlY = startY + amplitude;
    path.quadraticBezierTo(controlX, controlY, endX, startY);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════
// Mini statistique pour le détail ECG
// ═══════════════════════════════════════════════════════════
class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.9))),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 📋 Widgets existants (inchangés sauf onTap)
// ═══════════════════════════════════════════════════════════

// ==================== _CompactRecapColumn ====================
class _CompactRecapColumn extends StatelessWidget {
  final int count;
  final String label;
  final Color color, textSecondary;
  const _CompactRecapColumn(
      {required this.count,
      required this.label,
      required this.color,
      required this.textSecondary});

  @override
  Widget build(BuildContext context) {
    return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$count',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w700, color: color),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: textSecondary),
              overflow: TextOverflow.ellipsis),
        ]);
  }
}

// ==================== _CompactEcgHistoryItem ====================
class _CompactEcgHistoryItem extends StatelessWidget {
  final EcgReading reading;
  final VoidCallback? onDelete;
  final Color surface,
      border,
      textPrimary,
      textSecondary,
      normal,
      warning,
      critical;

  const _CompactEcgHistoryItem(
      {required this.reading,
      this.onDelete,
      required this.surface,
      required this.border,
      required this.textPrimary,
      required this.textSecondary,
      required this.normal,
      required this.warning,
      required this.critical});

  Color _getStatusColor() {
    switch (reading.status) {
      case HealthStatus.normal:
        return normal;
      case HealthStatus.suspect:
        return warning;
      case HealthStatus.critical:
        return critical;
    }
  }

  String _getStatusText() {
    switch (reading.status) {
      case HealthStatus.normal:
        return 'Normal';
      case HealthStatus.suspect:
        return 'Suspect';
      case HealthStatus.critical:
        return 'Critique';
    }
  }

  IconData _getStatusIcon() {
    switch (reading.status) {
      case HealthStatus.normal:
        return Icons.check_circle_rounded;
      case HealthStatus.suspect:
        return Icons.warning_rounded;
      case HealthStatus.critical:
        return Icons.error_rounded;
    }
  }

  String _getTitle() {
    switch (reading.status) {
      case HealthStatus.normal:
        return 'Rythme sinusal normal';
      case HealthStatus.suspect:
        return 'Anomalie détectée';
      case HealthStatus.critical:
        return 'Urgence cardiaque';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final timeFormat = DateFormat('HH:mm');
    final isToday = DateTime.now().difference(reading.timestamp).inDays == 0;
    final dateStr = isToday
        ? 'Auj. ${timeFormat.format(reading.timestamp)}'
        : DateFormat('dd/MM HH:mm').format(reading.timestamp);
    final statusBg = reading.status == HealthStatus.normal
        ? AppColors.normalLight
        : reading.status == HealthStatus.suspect
            ? AppColors.warningLight
            : AppColors.criticalLight;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6)),
                  child: Icon(_getStatusIcon(), size: 16, color: statusColor)),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(_getStatusText(),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(_getTitle(),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textPrimary),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1),
                  ])),
              const SizedBox(width: 6),
              if (onDelete != null)
                IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    onPressed: onDelete,
                    tooltip: 'Supprimer cet enregistrement',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints()),
              SizedBox(
                  width: 50,
                  height: 24,
                  child: CustomPaint(
                      painter: _WaveformPainter(color: statusColor))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.favorite_rounded, size: 14, color: textSecondary),
                const SizedBox(width: 3),
                Flexible(
                    child: Text('${reading.heartRate} bpm',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: textPrimary),
                        overflow: TextOverflow.ellipsis))
              ])),
              const SizedBox(width: 10),
              Flexible(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.access_time_rounded, size: 14, color: textSecondary),
                const SizedBox(width: 3),
                Flexible(
                    child: Text(dateStr,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: textSecondary),
                        overflow: TextOverflow.ellipsis))
              ])),
              const Spacer(),
              Text('${reading.durationSeconds}s',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== _WaveformPainter ====================
class _WaveformPainter extends CustomPainter {
  final Color color;
  _WaveformPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path();
    path.moveTo(0, size.height / 2);
    path.lineTo(size.width * 0.1, size.height / 2);
    path.lineTo(size.width * 0.15, size.height * 0.2);
    path.lineTo(size.width * 0.2, size.height * 0.8);
    path.lineTo(size.width * 0.25, size.height / 2);
    path.lineTo(size.width * 0.4, size.height / 2);
    path.lineTo(size.width * 0.45, size.height * 0.3);
    path.lineTo(size.width * 0.5, size.height * 0.7);
    path.lineTo(size.width * 0.55, size.height / 2);
    path.lineTo(size.width * 0.7, size.height / 2);
    path.lineTo(size.width * 0.75, size.height * 0.25);
    path.lineTo(size.width * 0.8, size.height * 0.75);
    path.lineTo(size.width * 0.85, size.height / 2);
    path.lineTo(size.width, size.height / 2);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
