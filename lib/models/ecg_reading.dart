enum HealthStatus {
  normal,
  suspect,
  critical
} //enum pour reprsenter les differents etats de sante d'une mesures ecg

class EcgReading {
  //classe pour reprsenter une mesures mt3 ecg avec ses differentes proprietes comme l'id ,dateTime ,mesure de coeur ...
  final String id; //	Identifiant unique de la mesure
  final DateTime timestamp; //Quand la mesure a été prise
  final int heartRate; //Fréquence cardiaque en bpm
  final HealthStatus status; //Normal / Suspect / Critique
  final int riskScore; //Score de risque (0 à 100)
  final int durationSeconds; //Durée de l'enregistrement en secondes
  final String? notes; //Remarques du médecin(texte)

  EcgReading({
    //constructeur de la classe ecgreading qui prend en parametre les differents proprietes de la classe pour creer une instance de ecgreading
    required this.id,
    required this.timestamp,
    required this.heartRate,
    required this.status,
    required this.riskScore,
    required this.durationSeconds,
    this.notes,
  });

  String get statusLabel {
    //une methode pour convertir l'etat de sante de la mesure ecg en une chaines de caracteres pour l'affichage fi dasboard
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
        //une methode pour convertir une instance de ecgreading en json pour pouvoir le sauvegarder dans shared prefernces (wela transmettre a une api)
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'heartRate': heartRate,
        'status': status.name,
        'riskScore': riskScore,
        'durationSeconds': durationSeconds,
        'notes': notes,
      };

  factory EcgReading.fromJson(Map<String, dynamic> json) => EcgReading(
        //une factory pour creer une instance de ecgreading a partir d'un json (lorsque on recupere les mesures sauvegarder dans shared prefernces ou dans l'api)
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
