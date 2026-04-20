import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ecg_reading.dart';
import '../models/patient_profile.dart';

enum EmergencyState { none, pending, confirmed }

class AppProvider extends ChangeNotifier {
  int _heartRate = 72;
  int _riskScore = 18;
  HealthStatus _healthStatus = HealthStatus.normal;
  bool _isMonitoring = false;
  EmergencyState _emergencyState = EmergencyState.none;
  int _emergencyCountdown = 600;
  bool _sensorConnected = true;
  PatientProfile _profile = PatientProfile.defaultProfile;
  List<EcgReading> _history = [];
  EcgReading? _lastReading;

  Timer? _monitoringTimer;
  Timer? _countdownTimer;
  double _phase = 0;
  final Random _random = Random();

  // ✅ GETTERS
  int get heartRate => _heartRate;
  int get riskScore => _riskScore;
  HealthStatus get healthStatus => _healthStatus;
  bool get isMonitoring => _isMonitoring;
  EmergencyState get emergencyState => _emergencyState;
  int get emergencyCountdown => _emergencyCountdown;
  bool get sensorConnected => _sensorConnected;
  PatientProfile get profile => _profile;
  List<EcgReading> get history => _history;
  EcgReading? get lastReading => _lastReading;

  String get emergencyCountdownFormatted {
    final minutes = _emergencyCountdown ~/ 60;
    final seconds = _emergencyCountdown % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  AppProvider() {
    _loadData();
  }

  // ✅ t3mel mise a jour le profile m3a il donnees il jdod min  supabase
  void updateProfileFromMap(Map<String, dynamic> data) {
    print('🔹 [PROVIDER] === updateProfileFromMap START ===');
    print('🔹 [PROVIDER] Timestamp: ${DateTime.now().millisecond}ms');
    print('🔹 [PROVIDER] Input data keys: ${data.keys.toList()}');
    print(
        '🔹 [PROVIDER] Input name: ${data['name']} (type: ${data['name']?.runtimeType})');
    print(
        '🔹 [PROVIDER] Input patientId: ${data['patient_id']} (type: ${data['patient_id']?.runtimeType})');
    print('🔹 [PROVIDER] Current _profile.name BEFORE: "${_profile.name}"');

    _profile = PatientProfile(
      //t3awed t3mel creation d'objet  mt3 les donnees ili mawjoudin fi il profile bi donnees jdod mt3 l'utilisateur
      name: _safeString(data['name'], 'Utilisateur'),
      age: data['age'] ?? 0,
      bloodType: _safeString(data['blood_type'], '?'),
      patientId: _safeString(data['patient_id'], '---'),
      cardiologist: _safeString(data['cardiologist'], ''),
      emergencyContact: _safeString(data['emergency_contact'], ''),
      conditions: _safeStringList(data['conditions']),
      medications: _safeStringList(data['medications']),
    );

    print('🔹 [PROVIDER] _profile.name AFTER update: "${_profile.name}"');
    print(
        '🔹 [PROVIDER] _profile.patientId AFTER update: "${_profile.patientId}"');
    print('🔹 [PROVIDER] _profile.age AFTER update: ${_profile.age}');
    print('🔹 [PROVIDER] Calling notifyListeners()...');

    // yinformi il l'application inou donnees tbadelet
    notifyListeners();

    print('✅ [PROVIDER] notifyListeners() completed');
    print('✅ [PROVIDER] === updateProfileFromMap END ===');
  }

  // ✅ t3awen pour sécuriser les strings depuis Supabase ke fema des donnees nulles ne provquent pas des erreurs
  String _safeString(dynamic value, String defaultValue) {
    if (value == null) {
      print(
          '⚠️ [PROVIDER] _safeString: value is null, returning default: "$defaultValue"');
      return defaultValue;
    }
    final str = value.toString().trim();
    if (str.isEmpty) {
      print(
          '⚠️ [PROVIDER] _safeString: value is empty, returning default: "$defaultValue"');
      return defaultValue;
    }
    return str;
  }

  //  t3awen bech tbadel liste dynamique par une liste en text
  List<String> _safeStringList(dynamic value) {
    if (value == null) {
      print(
          '⚠️ [PROVIDER] _safeStringList: value is null, returning empty list');
      return [];
    }
    if (value is List) {
      //thabet inou list w lee
      final result =
          value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
      print(
          '✅ [PROVIDER] _safeStringList: converted ${value.length} items to ${result.length} strings');
      return result;
    }
    print(
        '⚠️ [PROVIDER] _safeStringList: value is not a List, returning empty list');
    return [];
  }

  //Sauvegarde le profil actuel dans la mémoire du téléphone
  Future<void> _saveProfileToPrefs() async {
    try {
      print('🔹 [PROVIDER] _saveProfileToPrefs: Saving profile...');
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_profile.toJson());
      print('🔹 [PROVIDER] _saveProfileToPrefs: JSON length = ${json.length}');
      await prefs.setString('caredify_profile', json);
      print('✅ [PROVIDER] _saveProfileToPrefs: Profile saved successfully');
    } catch (e) {
      print('❌ [PROVIDER] _saveProfileToPrefs: Error saving profile: $e');
    }
  }

  // ✅✅✅ MÉTHODE _loadData() CORRIGÉE - Ne pas écraser un profil déjà mis à jour ✅✅✅
  Future<void> _loadData() async {
    print('🔹 [PROVIDER] _loadData: Starting...');
    final prefs = await SharedPreferences.getInstance();

    // y3mel il autorisation mt3 l'historique (dima mawjoud)
    final historyJson = prefs.getString('caredify_history');
    if (historyJson != null) {
      print('🔹 [PROVIDER] _loadData: Found history in SharedPreferences');
      final list = jsonDecode(historyJson) as List;
      _history = list
          .map((e) => EcgReading.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      print(
          '🔹 [PROVIDER] _loadData: No history found, generating sample data');
      _history = _generateSampleHistory();
      _saveHistory();
    }

    // ✅✅✅ CHARGEMENT DU PROFIL - Avec vérification pour ne pas écraser une mise à jour récente ✅✅✅
    final profileJson = prefs.getString('caredify_profile');
    if (profileJson != null) {
      // ✅ Vérifier si _profile a déjà été mis à jour (n'est pas la valeur par défaut)
      final isProfileAlreadySet = _profile.name != 'Utilisateur' &&
          _profile.name != 'Chargement...' &&
          _profile.name.isNotEmpty &&
          _profile.patientId != '---';

      if (!isProfileAlreadySet) {
        // ✅ Le profil n'a pas encore été mis à jour → charger depuis SharedPreferences
        print(
            '🔹 [PROVIDER] _loadData: Loading profile from SharedPreferences...');
        print(
            '🔹 [PROVIDER] _loadData: Profile JSON preview: ${profileJson.substring(0, min(100, profileJson.length))}...');
        _profile = PatientProfile.fromJson(
            jsonDecode(profileJson) as Map<String, dynamic>);
        print(
            '🔹 [PROVIDER] _loadData: _profile.name loaded: "${_profile.name}"');
      } else {
        // ✅ Le profil a déjà été mis à jour → NE PAS écraser avec l'ancienne valeur
        print(
            '✅ [PROVIDER] _loadData: Profile already set, skipping SharedPreferences load');
        print(
            '✅ [PROVIDER] _loadData: Keeping current _profile.name: "${_profile.name}"');
      }
    } else {
      print(
          '🔹 [PROVIDER] _loadData: No profile found in SharedPreferences, using default');
    }

    print('✅ [PROVIDER] _loadData: Completed, calling notifyListeners()');
    notifyListeners();
  }

  List<EcgReading> _generateSampleHistory() {
    final statuses = [
      HealthStatus.normal,
      HealthStatus.normal,
      HealthStatus.suspect,
      HealthStatus.normal,
      HealthStatus.normal,
      HealthStatus.critical,
      HealthStatus.normal,
      HealthStatus.normal,
    ];
    final now = DateTime.now();
    return statuses.asMap().entries.map((e) {
      final i = e.key;
      final status = e.value;
      final date = now.subtract(Duration(hours: i * 3 + _random.nextInt(2)));
      final hr = status == HealthStatus.normal
          ? 65 + _random.nextInt(20)
          : status == HealthStatus.suspect
              ? 95 + _random.nextInt(20)
              : 145 + _random.nextInt(30);
      final risk = status == HealthStatus.normal
          ? 10 + _random.nextInt(20)
          : status == HealthStatus.suspect
              ? 45 + _random.nextInt(20)
              : 78 + _random.nextInt(15);
      return EcgReading(
        id: '${now.millisecondsSinceEpoch}-$i',
        timestamp: date,
        heartRate: hr,
        status: status,
        riskScore: risk,
        durationSeconds: 30 + _random.nextInt(60),
      );
    }).toList();
  }

//yebda lancement mt3 il monotoring cardiaque
  void startMonitoring() {
    _isMonitoring = true; //active l'etat de la lecture
    _phase = 0; //initialise la phase pour la simulation du rythme cardiaque
    notifyListeners(); //t5ali fema mise à jour lil interface (affiche le graph)
    _monitoringTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      //bech t3melha kol 0.8s
      _phase +=
          0.3; //avance de la phase pour simuler les variation du rythme cardiaque
      final baseHR = 72; //hedha il rythme cardiaque de base pour la simulation
      final variance = sin(_phase) * 8 +
          (_random.nextDouble() - 0.5) *
              6; //calcule une variance bech n5alou il rythme cardiaque plus realiste
      _heartRate = (baseHR + variance).round().clamp(40,
          200); //n3amlou mise a jour lil rythme cardiaque en respectant des limites realistes (bech maykounech fema des valeurs trop extremes)

      final baseRisk =
          18; //hedhi il risque de base pour la simulation(lil lecteur normal)
      final riskVariance = sin(_phase * 0.7) * 5 +
          (_random.nextDouble() - 0.5) *
              3; //calcul une variance pour le risque bech n5alou il rythme cardiaque plus realiste
      _riskScore = (baseRisk + riskVariance).round().clamp(5,
          95); //n3mlou mise a jour lil risque en respectant des limites realistes (ib des valeurs irrealistes)

      _healthStatus = _riskScore <
              35 //ken il risk score a9el min 35 n7otouh normal, ken a9el min 65 n7otouh suspect ,sinon n7otouh critique
          ? HealthStatus.normal
          : _riskScore < 65
              ? HealthStatus.suspect
              : HealthStatus.critical;

      notifyListeners(); //t5ali fema dima mise a jour lil interface pour afficher les nouvelles valeurs du rythme cardiaque,du risque w 7ata l'etat de santé
    });
  }

  void stopMonitoring() {
    //hna l'arret du monitoring cardiaque
    _isMonitoring = false; //desactive l'etat de la lecture
    _monitoringTimer
        ?.cancel(); //arret le timer de la simulation du rythme cardiaque
    _monitoringTimer =
        null; // nathfou l'objettimer pour eviter les fuites de memoire

    final reading = EcgReading(
      //wa9et man7bsou il monitoring ,on cree un nouvel enregistrement ECG avec les valeurs actuelles du rythme caridiaque,de l'etat de sante wela risque
      id: '${DateTime.now().millisecondsSinceEpoch}', //n7otou id unique basé sur le timestamp actuel bech nejmou le supprimer plus tard si on besoin
      timestamp: DateTime.now(), //wa9et enregistrement actuel
      heartRate: _heartRate, //valeur actuelle lil rythme cardiaque
      status: _healthStatus, //kifkif lil etat de santé actuel
      riskScore: _riskScore, //zeda il risque actuelle
      durationSeconds:
          45, // n7oto une dureé fixe pour la simulation nejmou roudouha dynamique minba3ed
    );
    _lastReading =
        reading; //n7outou l'enregistrement dans la variables _lastReading pour pouvoir l'afficher dans le dashboard
    _history = [reading, ..._history]
        .take(50)
        .toList(); //on ajoute le nouvel enregistrement au debut de l'historique et on garde que les 50 derniers pour eviter d'avoir une liste trop longue
    _saveHistory(); //on sauvegarde l'historique n3mlou mis a jour lil interface pour afficher le nouvel enregistrement fi l'historique meme si apres la fermuture de l'application
    notifyListeners(); //nefsha t5ali fema mise a jour lil interface pour afficher le nouvel enregistrement dans le dashboard
  }

  void triggerEmergency() {
    //hna ken il lecteur ydetecte une anomalie critique ,on declenche l'etat d'urgence
    _emergencyState = EmergencyState
        .pending; //n5alou l'etat d'urgence en attente pour donner une chance a l'utilisateur de confirmer ou annulr l'urgence (hne en fait 5idmet il cardiologue)
    notifyListeners(); //jil 3ada t3mel il mise a jour lil interface pour afficher l'etat d'urgence
  }

  void confirmEmergency() {
    //hna ken l'utilisateur yconfirmi l'uregence ,on passe par l'etat confirme et on lance un compte a rebours de 10 minutes pour donner le temps aux secours
    _emergencyState = EmergencyState
        .confirmed; //n5alou l'etat d'urgence confirme pour indiquer inou les secours sont en routes
    _emergencyCountdown =
        600; // n7outou bil compteur de 600 secondes(10minutes)
    _countdownTimer
        ?.cancel(); //arret le timer prcedent s'il existe bech evite les conflicts de timer
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      //lance un timer qui se declenche chaque secondes
      if (_emergencyCountdown > 0) {
        _emergencyCountdown--; //on decremente le compteur en 1s
        notifyListeners();
      } else {
        _countdownTimer?.cancel();
      }
    });
    notifyListeners(); //t5ali fema mise a jour lil interface pour afficher le changement d'etat d'urgence et le lancement de compteur
  }

  void cancelEmergency() {
    _emergencyState = EmergencyState
        .none; //n5alou l'etat d'urgence m3al9a bech ken y7ib annuler l'urgence
    _emergencyCountdown =
        600; //n7outou le compteur bi il valeur de base lil urgence jeya 10 minutes
    _countdownTimer
        ?.cancel(); //arret le timer de compteur precedent s'il existe bech yeviti li conflicts de timer
    _countdownTimer =
        null; //nathfou l'objet timer pour eviter les fuites de memoire
    notifyListeners(); // na3mlou mise a jour lil interface pour afficher l'annulation de l'urgence w le reste du compteur
  }

  // ✅✅✅ MÉTHODE : Supprimer un enregistrement par ID ✅✅✅
  void deleteHistoryItem(String readingId) {
    //hna ken l'utilisateur y7ib yna7i un enregistrement de l'historique
    print('🔹 [PROVIDER] Deleting history item: $readingId'); //
    _history = _history
        .where((r) => r.id != readingId)
        .toList(); //on filtre l'historique pour garder que l'enregistrement qui n'a pas l'id correspondant a celui qu'on veut suprimer
    _saveHistory(); // ✅ Sauvegarde dans SharedPreferences
    notifyListeners(); //na3mlou mis a jour lil interface pour afficher l'historique mis a jour sans l'enregistrement supprimé
    print(
        '✅ [PROVIDER] History item deleted successfully'); //y2ked enou c bon supprimer
  }

// ✅✅✅ MÉTHODE : Tout supprimer l'historique ✅✅✅
  void clearAllHistory() {
    //hne ken l'utilisateur y7ib yfas5 tous les enregistrement
    print('🔹 [PROVIDER] Clearing all history...');
    _history = []; //on vide toute la liste
    _saveHistory(); // ✅ Sauvegarde dans SharedPreferences
    notifyListeners(); //na3mlou mis a jou lil interface pour afficher l'historique vide
    print('✅ [PROVIDER] All history cleared successfully');
  }

  // ✅✅✅ NOUVELLE MÉTHODE : Pour naviguer entre les tabs du MainShell ✅✅✅
  VoidCallback? onNavigateToTab;

  void navigateToDashboard() {
    //hne ken y7ib l'utilisateur yarj3 lil dasboard apres avoir consulter le profile
    if (onNavigateToTab != null) {
      //ken la fonction mt3 navigation mawjouda fi le provider
      onNavigateToTab!(); //on l'appelle pour naviguer vers le dasboard
    }
  }

  // ✅ MÉTHODE EXISTANTE updateProfile - Gardée pour compatibilité
  void updateProfile(PatientProfile profile) async {
    //hne il methode updateProfile bech ta5ou un objet Patientprofile complet w ta3melou mise a jour lil profile actuelle il mawjpud fi le provider
    print('🔹 [PROVIDER] updateProfile called'); //
    _profile = profile;//on met a jour le profile avec le nouveau profile fourni 
    await _saveProfileToPrefs();//on sauvgarde le nouveau profile dans shared preferences pour le garder meme apres la fermeture de l'application 
    notifyListeners();//ki l3ada ta3mel il mise a jour lil interface pour afficher les nouvelles informations du profile dans le dashboard w 7atta le profile
    print('✅ [PROVIDER] updateProfile completed');//c bon hne l'update du profile et dashboard est terminé
  }

  Future<void> _saveHistory() async {//hna ken y7ib nsavegarder l'historique mis a jour dans la memoire du telephone bech yb9a meme ki nsakrou telephone 
    final prefs = await SharedPreferences.getInstance();//on recupere l'instance de shared prefernces pour pouvoir y accceder et y savugarder des données
    await prefs.setString('caredify_history',//on sauvegarde l'historique dans shared preferces en le convertissant d'aboard en json pour pouvoir le stocker sous forme de string 
        jsonEncode(_history.map((e) => e.toJson()).toList()));//on convertit chaque enregistrement de l'historique en json puis on les mets dans une liste avant de les encoder en json pour les sauvegarder dans shared preferences sous la clé 'caredify_history'
  }

  @override
  void dispose() {//ken l'application ferme ou le providerest detruit ,on arret les timers pour eviter les fuites de memoires et on appelle super.dispose() pour faire  le nettoyage de base du provider 
    _monitoringTimer?.cancel();//arret de monitoring timer s'il existe
    _countdownTimer?.cancel();//arret du countdown timer s'il existe 
    super.dispose();//appel de la methode dispose de la classe parente pour faire le nettoyage de base du provider 
  }
}
