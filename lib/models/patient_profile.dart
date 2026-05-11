class PatientProfile {
  //classe pour stocker les informations du patient qui seront affichees dans le dashboard et aussi dans le profile
  final String name; //nom du patient
  final int age; //age du patient
  final String patientId; //id du patient
  final String cardiologist; //nom du cardiologue qui suit le patient
  final String bloodType; //type de sang du patient
  final List<String> conditions; //liste des conditions medicales du patient
  final List<String> medications; //liste des medicaments que le patient prend
  final String emergencyContact; // contact d'urgence du patient

  PatientProfile({
    //constructeur de la classe patientprofile qui prend en parametre les differents proprietes de la classe pour creer une instance de patientprofile
    required this.name,
    required this.age,
    required this.patientId,
    required this.cardiologist,
    required this.bloodType,
    required this.conditions,
    required this.medications,
    required this.emergencyContact,
  });

  static PatientProfile get defaultProfile => PatientProfile(
        //une instance par defaut du profile du patient qui sera utilisee lors de la premiere utilisation de l'application ou lorque les données du profile sont réinitialisées
        name: 'Jean Dupont',
        age: 67,
        patientId: 'CAR-2024-00142',
        cardiologist: 'Dr. Marie Lefebvre',
        bloodType: 'A+',
        conditions: ['Fibrillation auriculaire', 'Hypertension artérielle'],
        medications: ['Warfarine 5mg', 'Métoprolol 50mg', 'Ramipril 10mg'],
        emergencyContact: '+33 6 12 34 56 78',
      );

  Map<String, dynamic> toJson() => {
        //une methode pour convertir une instance de patientprofile en json pour pouvoir le sauvegarde dans shared prefernces (wela transmettre a une api)
        'name': name,
        'age': age,
        'patientId': patientId,
        'cardiologist': cardiologist,
        'bloodType': bloodType,
        'conditions': conditions,
        'medications': medications,
        'emergencyContact': emergencyContact,
      };

  factory PatientProfile.fromJson(Map<String, dynamic> json) => PatientProfile(
        //une factory pour creer une instance de patientprofile a partir d'un json (lorsque on recupere les donneés )
        name: json['name'] as String,
        age: json['age'] as int,
        patientId: json['patientId'] as String,
        cardiologist: json['cardiologist'] as String,
        bloodType: json['bloodType'] as String,
        conditions: List<String>.from(json['conditions'] as List),
        medications: List<String>.from(json['medications'] as List),
        emergencyContact: json['emergencyContact'] as String,
      );

  PatientProfile copyWith({
    //une methode pour faire les mise a jour du profile
    String? name,
    int? age,
    String? patientId,
    String? cardiologist,
    String? bloodType,
    List<String>? conditions,
    List<String>? medications,
    String? emergencyContact,
  }) =>
      PatientProfile(
        //une methode pour faire les mise a jour du profile en creant une nouvelle instance de patientprofile avec les nouvellle valeurs si elles sont fournies ou les anciennes valeurs
        name: name ?? this.name,
        age: age ?? this.age,
        patientId: patientId ?? this.patientId,
        cardiologist: cardiologist ?? this.cardiologist,
        bloodType: bloodType ?? this.bloodType,
        conditions: conditions ?? this.conditions,
        medications: medications ?? this.medications,
        emergencyContact: emergencyContact ?? this.emergencyContact,
      );
}
//stocke les infos médicales du patient
