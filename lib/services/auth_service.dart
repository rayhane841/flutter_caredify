import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ✅ GET CURRENT USER
  User? get currentUser => _supabase.auth.currentUser;

  // ✅ STREAM AUTH STATE
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // ✅ SIGN UP (INSCRIPTION) - VERSION CORRIGÉE
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
  }) async {
    try {
      // 🔹 ÉTAPE 1: Créer le compte via Supabase Auth
      print('🔹 Starting signUp for: $email');

      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        print('❌ Auth response user is null');
        return {'success': false, 'error': 'Échec de création du compte'};
      }

      final userId = authResponse.user!.id;
      print('✅ User created in Auth: ${authResponse.user?.email}');
      print('✅ User ID: $userId');

      // 🔹 ÉTAPE 2: Attendre que la session soit prête + se connecter automatiquement
      // Ceci résout le problème RLS qui bloque l'insertion juste après signUp
      print('🔹 Waiting for session to be ready...');
      await Future.delayed(const Duration(seconds: 2));

      // Se connecter automatiquement après l'inscription pour activer la session
      final signInResponse = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (signInResponse.user == null) {
        print('❌ Auto sign-in failed');
        return {'success': false, 'error': 'Échec de connexion automatique'};
      }

      print('✅ Session established: ${signInResponse.user?.email}');

      // 🔹 ÉTAPE 3: Préparer les données pour insertion
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
        'patient_id': 'PAT-${userId.toString().substring(0, 8).toUpperCase()}',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'cardiologist': '',
        'emergency_contact': '',
      };

      print('🔹 Inserting patient data into database...');

      // 🔹 ÉTAPE 4: Insérer les données dans PostgreSQL
      final result = await _supabase.from('patients').insert(patientData);

      // 🔹 ÉTAPE 5: Vérifier le résultat de l'insertion
      print('✅ Insert result: $result');

      // Vérifier s'il y a une erreur dans la réponse
      if (result is PostgrestException) {
        print('❌ PostgrestException: ${result.message}');
        return {
          'success': false,
          'error': 'Erreur base de données: ${result.message}'
        };
      }

      print('✅ Patient data saved successfully!');

      return {
        'success': true,
        'user': authResponse.user,
        'userId': userId,
      };
    } on AuthException catch (e) {
      print('❌ AuthException: ${e.message}');
      return {'success': false, 'error': _getAuthErrorMessage(e.message)};
    } on PostgrestException catch (e) {
      print('❌ PostgrestException: ${e.message}');
      print('❌ Details: ${e.details}');
      print('❌ Hint: ${e.hint}');
      return {
        'success': false,
        'error': 'Erreur base de données: ${e.message}'
      };
    } catch (e, stackTrace) {
      print('❌ Unexpected Exception: $e');
      print('❌ Stack trace: $stackTrace');
      return {'success': false, 'error': 'Erreur inattendue: $e'};
    }
  }

  // ✅ SIGN IN (CONNEXION)
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      print('🔹 Signing in: $email');

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        print('❌ Sign in response user is null');
        return {'success': false, 'error': 'Échec de connexion'};
      }

      print('✅ User signed in: ${response.user?.email}');

      return {
        'success': true,
        'user': response.user,
        'userId': response.user!.id,
      };
    } on AuthException catch (e) {
      print('❌ AuthException during sign in: ${e.message}');
      return {'success': false, 'error': _getAuthErrorMessage(e.message)};
    } catch (e) {
      print('❌ Exception during sign in: $e');
      return {'success': false, 'error': 'Erreur: $e'};
    }
  }

  // ✅ SIGN OUT (DÉCONNEXION)
  Future<void> signOut() async {
    print('🔹 Signing out user...');
    await _supabase.auth.signOut();
    print('✅ User signed out');
  }

  // ✅ GET PATIENT DATA
  Future<Map<String, dynamic>?> getPatientData(String userId) async {
    try {
      print('🔹 Fetching patient data for: $userId');

      final response = await _supabase
          .from('patients')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        print('⚠️ No patient data found for: $userId');
      } else {
        print('✅ Patient data fetched successfully');
      }

      return response;
    } catch (e) {
      print('❌ Error fetching patient data: $e');
      return null;
    }
  }

  // ✅ SAVE ECG DATA
  Future<void> saveEcgData({
    required String patientId,
    required List<double> ecgValues,
    required int heartRate,
    required String status,
    required DateTime timestamp,
  }) async {
    try {
      print('🔹 Saving ECG data for patient: $patientId');

      await _supabase.from('ecg_readings').insert({
        'patient_id': patientId,
        'ecg_values': ecgValues,
        'heart_rate': heartRate,
        'status': status,
        'timestamp': timestamp.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });

      print('✅ ECG data saved successfully');
    } catch (e) {
      print('❌ Error saving ECG data: $e');
      rethrow;
    }
  }

  // ✅ GET ECG READINGS (STREAM)
  Stream<List<Map<String, dynamic>>> getEcgReadings(String patientId) {
    return _supabase
        .from('ecg_readings')
        .stream(primaryKey: ['id'])
        .eq('patient_id', patientId)
        .order('timestamp', ascending: false)
        .limit(50)
        .map((rows) => rows.toList());
  }

  // ✅ UPDATE PATIENT PROFILE
  Future<bool> updateProfile({
    required String userId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      print('🔹 Updating profile for: $userId');

      updates['updated_at'] = DateTime.now().toIso8601String();

      final result =
          await _supabase.from('patients').update(updates).eq('id', userId);

      print('✅ Profile update result: $result');
      return true;
    } catch (e) {
      print('❌ Error updating profile: $e');
      return false;
    }
  }

  // ✅ CALCULATE AGE FROM BIRTH DATE
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

  // ✅ ERROR MESSAGES (adaptés pour Supabase)
  String _getAuthErrorMessage(String message) {
    print('🔹 Auth error message: $message');

    if (message.contains('Invalid login credentials') ||
        message.contains('Invalid credentials')) {
      return 'Email ou mot de passe incorrect';
    }
    if (message.contains('User already registered') ||
        message.contains('duplicate key')) {
      return 'Cet email est déjà utilisé';
    }
    if (message.contains('Password should be at least')) {
      return 'Mot de passe trop court (6 caractères min)';
    }
    if (message.contains('Email not confirmed')) {
      return 'Veuillez confirmer votre email';
    }
    if (message.contains('new row violates row-level security')) {
      return 'Erreur de permission - veuillez réessayer ou contacter le support';
    }
    if (message.contains('relation "patients" does not exist')) {
      return 'Table patients non trouvée - contactez le support';
    }
    return 'Erreur d\'authentification: $message';
  }
}
