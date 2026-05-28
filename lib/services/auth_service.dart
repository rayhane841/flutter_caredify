import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // ════════════════════════════════════════════════════════
  // ✅ Cardiologues actifs — via RPC + filtre status='active'
  // ════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getCardiologists() async {
    try {
      print('🔹 [AUTH] Fetching active cardiologists via RPC...');

      final response = await _supabase.rpc('get_cardiologist_profiles');

      if (response == null || (response as List).isEmpty) {
        print('⚠️ [AUTH] 0 cardiologists found');
        return [];
      }

      // ✅ Filtrer uniquement les cardiologues avec status = 'active'
      final activeCardiologists = (response as List).where((c) {
        final status = (c['status'] ?? '').toString().toLowerCase().trim();
        return status == 'active';
      }).toList();

      print(
          '✅ [AUTH] ${activeCardiologists.length} active cardiologists (out of ${(response as List).length} total)');

      final cardiologists = activeCardiologists.map((c) {
        final fullName = (c['full_name'] ?? 'Inconnu').toString().trim();
        final specialty = (c['specialty'] ?? '').toString().trim();
        final label = specialty.isNotEmpty && specialty != 'null'
            ? 'Dr. $fullName - $specialty'
            : 'Dr. $fullName';
        return {
          'id': c['id'].toString(),
          'name': fullName,
          'label': label,
        };
      }).toList();

      print('✅ [AUTH] ${cardiologists.length} cardiologists ready');
      return cardiologists;
    } catch (e, stack) {
      print('❌ [AUTH] Error fetching cardiologists: $e');
      print('❌ [AUTH] Stack: $stack');
      return [];
    }
  }

  // ════════════════════════════════════════════════════════
  // ✅ Résoudre cardiologist_id depuis label — via RPC (actifs uniquement)
  // ════════════════════════════════════════════════════════
  Future<String?> _resolveCardiologistId(String cardiologistLabel) async {
    if (cardiologistLabel.isEmpty) return null;
    try {
      String searchName = cardiologistLabel.trim();
      if (searchName.startsWith('Dr. '))
        searchName = searchName.substring(4).trim();
      if (searchName.contains(' - '))
        searchName = searchName.split(' - ')[0].trim();

      print('🔍 [AUTH] Recherche cardiologue: "$searchName"');

      final response = await _supabase.rpc('get_cardiologist_profiles');
      if (response == null) return null;

      // ✅ Filtrer les actifs avant de chercher
      final list = (response as List).where((c) {
        final status = (c['status'] ?? '').toString().toLowerCase().trim();
        return status == 'active';
      }).toList();

      final found = list.firstWhere(
        (c) => (c['full_name'] as String? ?? '')
            .toLowerCase()
            .contains(searchName.toLowerCase()),
        orElse: () => null,
      );

      if (found != null) {
        print(
            '✅ [AUTH] Cardiologue trouvé: ${found['full_name']} → ${found['id']}');
        return found['id'] as String?;
      }

      print('⚠️ [AUTH] Cardiologue non trouvé pour: "$searchName"');
      return null;
    } catch (e) {
      print('❌ [AUTH] Erreur résolution cardiologue: $e');
      return null;
    }
  }

  // ════════════════════════════════════════════════════════
  // SIGN UP — ✅ Ajout family_phone
  // ════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required String birthDate,
    required String bloodType,
    required String cardiacPathology,
    required double weight,
    required double height,
    required String medicalHistory,
    required String allergies,
    String cardiologist = '',
    String? familyPhone, // ✅ NOUVEAU
    // ✅ Antécédents cardiaques — step 3
    bool? antecedentInfarctus,
    bool? antecedentTroubleRythme,
    bool? antecedentHospitalisation,
  }) async {
    try {
      print('🔹 [AUTH] Starting signUp for: $email');

      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        print('❌ [AUTH] Auth response user is null');
        return {'success': false, 'error': 'Échec de création du compte'};
      }

      final userId = authResponse.user!.id;
      print('✅ [AUTH] User created: $userId');

      await Future.delayed(const Duration(seconds: 1));

      final signInResponse = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (signInResponse.session == null) {
        print('❌ [AUTH] Session not established');
        return {'success': false, 'error': "Échec d'activation de session"};
      }

      print('✅ [AUTH] Session active');
      await Future.delayed(const Duration(milliseconds: 500));

      final cardiologistId = await _resolveCardiologistId(cardiologist);
      print('✅ [AUTH] cardiologist_id résolu: $cardiologistId');

      // ✅ Formater family_phone avec préfixe +216 si fourni
      String? formattedFamilyPhone;
      if (familyPhone != null && familyPhone.trim().isNotEmpty) {
        final cleanFamilyPhone =
            familyPhone.replaceAll(RegExp(r'[\s-]'), '').trim();
        formattedFamilyPhone = '+216$cleanFamilyPhone';
      }

      final patientData = {
        'id': userId,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'name': '$firstName $lastName',
        'phone': phone,
        'birth_date': birthDate,
        'age': _calculateAge(birthDate),
        'blood_type': bloodType,
        'cardiac_pathology': cardiacPathology,
        'weight': weight,
        'height': height,
        'medical_history': medicalHistory,
        'allergies': allergies,
        'patient_id': 'PAT-${userId.substring(0, 8).toUpperCase()}',
        'cardiologist': cardiologist,
        'cardiologist_id': cardiologistId,
        'emergency_contact': '',
        'family_phone': formattedFamilyPhone, // ✅ NOUVEAU
        // ✅ Antécédents cardiaques — noms de colonnes Supabase en français
        'antecedent_infarctus': antecedentInfarctus,
        'antecedent_trouble_rythme': antecedentTroubleRythme,
        'antecedent_hospitalisation': antecedentHospitalisation,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      print('🔹 [AUTH] Inserting patient data...');
      await _supabase.from('patients').insert(patientData);
      print('✅ [AUTH] Patient data saved successfully');

      return {
        'success': true,
        'user': authResponse.user,
        'userId': userId,
      };
    } on AuthException catch (e) {
      print('❌ [AUTH] AuthException: ${e.message}');
      if (e.message.contains('Database error') ||
          e.message.contains('unexpected_failure')) {
        return await _retryAfterDatabaseError(
          email: email,
          password: password,
          firstName: firstName,
          lastName: lastName,
          phone: phone,
          birthDate: birthDate,
          bloodType: bloodType,
          cardiacPathology: cardiacPathology,
          weight: weight,
          height: height,
          medicalHistory: medicalHistory,
          allergies: allergies,
          cardiologist: cardiologist,
          familyPhone: familyPhone, // ✅ NOUVEAU
          antecedentInfarctus: antecedentInfarctus,
          antecedentTroubleRythme: antecedentTroubleRythme,
          antecedentHospitalisation: antecedentHospitalisation,
        );
      }
      return {'success': false, 'error': _getAuthErrorMessage(e.message)};
    } on PostgrestException catch (e) {
      print('❌ [AUTH] PostgrestException: ${e.message} | code: ${e.code}');
      final detailsStr = e.details?.toString() ?? '';
      if (e.code == '23505') {
        if (detailsStr.contains('email'))
          return {'success': false, 'error': 'Cet email est déjà utilisé'};
        if (detailsStr.contains('patient_id'))
          return {
            'success': false,
            'error': 'ID patient déjà existant - réessayez'
          };
        return {'success': false, 'error': 'Donnée déjà existante'};
      }
      if (e.code == '42501')
        return {'success': false, 'error': 'Erreur de permission RLS'};
      if (e.code == '23502')
        return {
          'success': false,
          'error': 'Champ obligatoire manquant: ${e.details}'
        };
      return {
        'success': false,
        'error': 'Erreur base de données: ${e.message}'
      };
    } catch (e, stackTrace) {
      print('❌ [AUTH] Unexpected: $e');
      print('❌ [AUTH] Stack: $stackTrace');
      return {'success': false, 'error': 'Erreur inattendue: $e'};
    }
  }

  // ════════════════════════════════════════════════════════
  // RETRY — ✅ Ajout family_phone
  // ════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> _retryAfterDatabaseError({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required String birthDate,
    required String bloodType,
    required String cardiacPathology,
    required double weight,
    required double height,
    required String medicalHistory,
    required String allergies,
    String cardiologist = '',
    String? familyPhone, // ✅ NOUVEAU
    bool? antecedentInfarctus,
    bool? antecedentTroubleRythme,
    bool? antecedentHospitalisation,
  }) async {
    try {
      print('🔄 [AUTH] Retry after database error...');
      await Future.delayed(const Duration(seconds: 2));

      final signIn = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (signIn.user == null) {
        return {
          'success': false,
          'error': 'Compte créé mais connexion impossible.'
        };
      }

      final userId = signIn.user!.id;
      print('✅ [AUTH] Retry: connected as $userId');

      final existing = await _supabase
          .from('patients')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (existing != null) {
        print('✅ [AUTH] Patient already exists');
        return {'success': true, 'user': signIn.user, 'userId': userId};
      }

      final cardiologistId = await _resolveCardiologistId(cardiologist);

      // ✅ Formater family_phone avec préfixe +216 si fourni
      String? formattedFamilyPhone;
      if (familyPhone != null && familyPhone.trim().isNotEmpty) {
        final cleanFamilyPhone =
            familyPhone.replaceAll(RegExp(r'[\s-]'), '').trim();
        formattedFamilyPhone = '+216$cleanFamilyPhone';
      }

      final patientData = {
        'id': userId,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'name': '$firstName $lastName',
        'phone': phone,
        'birth_date': birthDate,
        'age': _calculateAge(birthDate),
        'blood_type': bloodType,
        'cardiac_pathology': cardiacPathology,
        'weight': weight,
        'height': height,
        'medical_history': medicalHistory,
        'allergies': allergies,
        'patient_id': 'PAT-${userId.substring(0, 8).toUpperCase()}',
        'cardiologist': cardiologist,
        'cardiologist_id': cardiologistId,
        'emergency_contact': '',
        'family_phone': formattedFamilyPhone, // ✅ NOUVEAU
        'antecedent_infarctus': antecedentInfarctus,
        'antecedent_trouble_rythme': antecedentTroubleRythme,
        'antecedent_hospitalisation': antecedentHospitalisation,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _supabase.from('patients').insert(patientData);
      print('✅ [AUTH] Retry: patient saved');

      return {'success': true, 'user': signIn.user, 'userId': userId};
    } catch (e) {
      print('❌ [AUTH] Retry failed: $e');
      return {
        'success': false,
        'error':
            'Erreur lors de la création. Essayez de vous connecter directement.',
      };
    }
  }

  // ════════════════════════════════════════════════════════
  // SIGN IN
  // ════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      print('🔹 [AUTH] Signing in: $email');
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user == null) {
        return {'success': false, 'error': 'Échec de connexion'};
      }
      print('✅ [AUTH] Signed in: ${response.user?.email}');
      return {
        'success': true,
        'user': response.user,
        'userId': response.user!.id,
      };
    } on AuthException catch (e) {
      return {'success': false, 'error': _getAuthErrorMessage(e.message)};
    } catch (e) {
      return {'success': false, 'error': 'Erreur: $e'};
    }
  }

  // ════════════════════════════════════════════════════════
  // SIGN OUT
  // ════════════════════════════════════════════════════════
  Future<void> signOut() async {
    await _supabase.auth.signOut();
    print('✅ [AUTH] Signed out');
  }

  // ════════════════════════════════════════════════════════
  // GET PATIENT DATA
  // ════════════════════════════════════════════════════════
  Future<Map<String, dynamic>?> getPatientData(String userId) async {
    try {
      print('🔹 [AUTH] Fetching patient data for: $userId');
      final response = await _supabase
          .from('patients')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (response == null) {
        print('⚠️ [AUTH] No patient found for: $userId');
      } else {
        print('✅ [AUTH] Patient data fetched');
      }
      return response;
    } catch (e) {
      print('❌ [AUTH] Error fetching patient: $e');
      return null;
    }
  }

  // ════════════════════════════════════════════════════════
  // SAVE ECG DATA
  // ════════════════════════════════════════════════════════
  Future<void> saveEcgData({
    required String patientId,
    required List<double> ecgValues,
    required int heartRate,
    required String status,
    required DateTime timestamp,
  }) async {
    try {
      print('🔹 [AUTH] Saving ECG for patient: $patientId');
      await _supabase.from('ecg_readings').insert({
        'patient_id': patientId,
        'ecg_values': ecgValues,
        'heart_rate': heartRate,
        'status': status,
        'timestamp': timestamp.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });
      print('✅ [AUTH] ECG saved');
    } catch (e) {
      print('❌ [AUTH] Error saving ECG: $e');
      rethrow;
    }
  }

  // ════════════════════════════════════════════════════════
  // GET ECG READINGS (stream)
  // ════════════════════════════════════════════════════════
  Stream<List<Map<String, dynamic>>> getEcgReadings(String patientId) {
    return _supabase
        .from('ecg_readings')
        .stream(primaryKey: ['id'])
        .eq('patient_id', patientId)
        .order('timestamp', ascending: false)
        .limit(50)
        .map((rows) => rows.toList());
  }

  // ════════════════════════════════════════════════════════
  // UPDATE PROFILE
  // ════════════════════════════════════════════════════════
  Future<bool> updateProfile({
    required String userId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      print('🔹 [AUTH] Updating profile for: $userId');
      updates['updated_at'] = DateTime.now().toIso8601String();
      await _supabase.from('patients').update(updates).eq('id', userId);
      print('✅ [AUTH] Profile updated');
      return true;
    } catch (e) {
      print('❌ [AUTH] Error updating profile: $e');
      return false;
    }
  }

  // ════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════
  int _calculateAge(String birthDate) {
    try {
      final parts = birthDate.split('/');
      if (parts.length != 3) return 0;
      final birthYear = int.parse(parts[2]);
      return DateTime.now().year - birthYear;
    } catch (e) {
      return 0;
    }
  }

  String _getAuthErrorMessage(String message) {
    if (message.contains('Invalid login credentials') ||
        message.contains('Invalid credentials'))
      return 'Email ou mot de passe incorrect';
    if (message.contains('User already registered') ||
        message.contains('duplicate key')) return 'Cet email est déjà utilisé';
    if (message.contains('Password should be at least'))
      return 'Mot de passe trop court (6 caractères min)';
    if (message.contains('Email not confirmed'))
      return 'Veuillez confirmer votre email';
    if (message.contains('new row violates row-level security'))
      return 'Erreur de permission - réessayez';
    return 'Erreur: $message';
  }
}
