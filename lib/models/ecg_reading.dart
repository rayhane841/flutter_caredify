enum HealthStatus { normal, suspect, critical }

class EcgReading {
  final String id;
  final DateTime timestamp;
  final int heartRate;
  final HealthStatus status;
  final int riskScore;
  final int durationSeconds;
  final String? notes;

  EcgReading({
    required this.id,
    required this.timestamp,
    required this.heartRate,
    required this.status,
    required this.riskScore,
    required this.durationSeconds,
    this.notes,
  });

  String get statusLabel {
    switch (status) {
      case HealthStatus.normal:
        return 'Normal';
      case HealthStatus.suspect:
        return 'Suspect';
      case HealthStatus.critical:
        return 'Critique';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'heartRate': heartRate,
        'status': status.name,
        'riskScore': riskScore,
        'durationSeconds': durationSeconds,
        'notes': notes,
      };

  factory EcgReading.fromJson(Map<String, dynamic> json) => EcgReading(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        heartRate: json['heartRate'] as int,
        status: HealthStatus.values.firstWhere((e) => e.name == json['status']),
        riskScore: json['riskScore'] as int,
        durationSeconds: json['durationSeconds'] as int,
        notes: json['notes'] as String?,
      );
}
//stocke les résultats de chaque mesure ECG
//Représente une mesure ECG enregistrée