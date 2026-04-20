class PatientProfile {
  final String name;
  final int age;
  final String patientId;
  final String cardiologist;
  final String bloodType;
  final List<String> conditions;
  final List<String> medications;
  final String emergencyContact;

  PatientProfile({
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