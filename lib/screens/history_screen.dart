import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/ecg_reading.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, app, _) {
        // Calculer la moyenne BPM
        final avgBpm = app.history.isNotEmpty
            ? (app.history.fold<int>(0, (sum, r) => sum + r.heartRate) /
                    app.history.length)
                .round()
            : 0;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: const Color(0xFF1976D2),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Historique ECG',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '7 derniers jours',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.download_rounded, color: Colors.white),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Exportation à implémenter')),
                  );
                },
              ),
            ],
          ),
          // ✅ SOLUTION ULTIME : ClipRect pour couper tout débordement
          body: ClipRect(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ SECTION 1 : Pills statistiques
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 16),
                      color: Colors.white,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.favorite,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Moy: $avgBpm bpm',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.analytics_rounded,
                                    size: 16,
                                    color: AppColors.normal,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '${app.history.length} mesures',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.normal,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ✅ SECTION 2 : Récapitulatif - VERSION ULTRA-SÉCURISÉE
                    Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Récapitulatif',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF424242),
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.trending_up_rounded,
                                size: 14,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // ✅ SOLUTION: GridView pour éviter tout overflow
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
                                    .where(
                                        (r) => r.status == HealthStatus.normal)
                                    .length,
                                label: 'Normal',
                                color: AppColors.normal,
                              ),
                              Container(
                                width: 1,
                                height: 30,
                                color: Colors.grey[200],
                              ),
                              _CompactRecapColumn(
                                count: app.history
                                    .where(
                                        (r) => r.status == HealthStatus.suspect)
                                    .length,
                                label: 'Suspect',
                                color: AppColors.warning,
                              ),
                              Container(
                                width: 1,
                                height: 30,
                                color: Colors.grey[200],
                              ),
                              _CompactRecapColumn(
                                count: app.history
                                    .where((r) =>
                                        r.status == HealthStatus.critical)
                                    .length,
                                label: 'Critique',
                                color: AppColors.critical,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ✅ SECTION 3 : Titre "ENREGISTREMENTS"
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'ENREGISTREMENTS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                              letterSpacing: 0.5,
                            ),
                          ),
                          // ✅ Bouton "Tout supprimer"
                          TextButton.icon(
                            icon: const Icon(Icons.delete_outline, size: 16),
                            label: const Text('Tout effacer',
                                style: TextStyle(fontSize: 11)),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed: app.history.isEmpty
                                ? null
                                : () => _showClearAllDialog(context, app),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ✅ SECTION 4 : Liste des enregistrements
                    app.history.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.history_rounded,
                                    size: 64, color: Colors.grey[300]),
                                const SizedBox(height: 12),
                                Text(
                                  'Aucun historique',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: app.history.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) =>
                                _CompactEcgHistoryItem(
                                    reading: app.history[index],
                                    onDelete: () => _showDeleteDialog(
                                        context, app, app.history[index].id)),
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

  // ✅✅✅ DIALOGUE DE CONFIRMATION : Supprimer un enregistrement ✅✅✅
  void _showDeleteDialog(
      BuildContext context, AppProvider app, String readingId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text('Supprimer'),
          ],
        ),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer cet enregistrement ECG ?\n\nCette action est irréversible.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              app.deleteHistoryItem(
                  readingId); // ✅ Appel de la méthode de suppression
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Enregistrement supprimé'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  // ✅✅✅ DIALOGUE DE CONFIRMATION : Tout supprimer ✅✅✅
  void _showClearAllDialog(BuildContext context, AppProvider app) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Tout effacer'),
          ],
        ),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer TOUT l\'historique ?\n\n${app.history.length} enregistrement(s) seront perdus définitivement.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              app.clearAllHistory(); // ✅ Appel de la méthode de suppression totale
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Historique vidé'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tout supprimer'),
          ),
        ],
      ),
    );
  }
}

// ==================== WIDGET: Colonne Récapitulative Compacte ====================

class _CompactRecapColumn extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _CompactRecapColumn({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: color,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ==================== WIDGET: Item Historique ECG Compact AVEC SUPPRESSION ✅✅✅ ====================

class _CompactEcgHistoryItem extends StatelessWidget {
  final EcgReading reading;
  final VoidCallback? onDelete; // ✅ AJOUT : Callback pour la suppression

  const _CompactEcgHistoryItem({
    required this.reading,
    this.onDelete, // ✅ Optionnel
  });

  Color _getStatusColor() {
    switch (reading.status) {
      case HealthStatus.normal:
        return AppColors.normal;
      case HealthStatus.suspect:
        return AppColors.warning;
      case HealthStatus.critical:
        return AppColors.critical;
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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ligne 1: Statut + Titre + Graphique ECG + Bouton supprimer
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  _getStatusIcon(),
                  size: 16,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getStatusText(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getTitle(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF424242),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              // ✅ Bouton supprimer (🗑️)
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 18, color: Colors.grey),
                  onPressed: onDelete,
                  tooltip: 'Supprimer cet enregistrement',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              SizedBox(
                width: 50,
                height: 24,
                child: CustomPaint(
                  painter: _WaveformPainter(color: statusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Ligne 2: BPM + Date + Durée
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite_rounded,
                      size: 14,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        '${reading.heartRate} bpm',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${reading.durationSeconds}s',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== WIDGET: Mini Graphique ECG ====================

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
