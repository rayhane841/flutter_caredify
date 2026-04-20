import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'notification_screen.dart'; // ✅ AJOUT : Import pour NotificationScreen
import 'settings_screen.dart'; // ✅ Déjà présent normalement

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  bool _isLoading = true;
  Map<String, dynamic>? _patientData;

  @override
  void initState() {
    super.initState();
    _loadPatientData();
  }

  // ✅ CHARGER LES DONNÉES PATIENT DEPUIS SUPABASE
  Future<void> _loadPatientData() async {
    setState(() => _isLoading = true);

    final userId = _authService.currentUser?.id;

    if (userId != null) {
      print('🔹 Loading patient data for: $userId');

      final data = await _authService.getPatientData(userId);

      if (mounted) {
        if (data != null) {
          print('✅ Patient data loaded: ${data['name']}');
          setState(() {
            _patientData = data;
            _isLoading = false;
          });
        } else {
          print('⚠️ No patient data found');
          setState(() => _isLoading = false);
        }
      }
    } else {
      print('⚠️ No authenticated user');
      setState(() => _isLoading = false);
    }
  }

  // ✅ HELPER POUR SÉCURISER LES STRINGS
  String _getSafeString(dynamic value) {
    if (value == null) return 'Non renseigné';
    final str = value.toString().trim();
    return str.isEmpty ? 'Non renseigné' : str;
  }

  // ✅✅✅ VALIDATION TÉLÉPHONE TUNISIE (8 chiffres) ✅✅✅
  String? _validateTunisianPhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Numéro requis';
    }

    // Supprime les espaces, tirets et l'indicatif +216 pour la validation
    final cleanValue =
        value.replaceAll(RegExp(r'[\s+-]'), '').replaceAll('+216', '');

    // Vérifie que ce sont exactement 8 chiffres
    final phoneRegex = RegExp(r'^[0-9]{8}$');

    if (!phoneRegex.hasMatch(cleanValue)) {
      return 'Numéro invalide (8 chiffres requis)';
    }

    return null;
  }

  // ✅✅✅ DIALOGUE D'ÉDITION DU PROFIL - VERSION CORRIGÉE ✅✅✅
  void _showEditProfileDialog(BuildContext context) {
    if (_patientData == null) return;

    final nameController =
        TextEditingController(text: _patientData?['name'] ?? '');

    // ✅ Préparer le numéro de téléphone : supprimer +216 pour l'édition
    final rawPhone = _patientData?['phone'] ?? '';
    final cleanPhone = rawPhone
        .toString()
        .replaceAll(RegExp(r'[\s+-]'), '')
        .replaceAll('+216', '');
    final phoneController = TextEditingController(text: cleanPhone);

    final bloodTypeController =
        TextEditingController(text: _patientData?['blood_type'] ?? '');
    final cardiologistController =
        TextEditingController(text: _patientData?['cardiologist'] ?? '');

    // ✅✅✅ NOUVEAUX CHAMPS : Poids, Taille, Antécédents, Allergies ✅✅✅
    final weightController = TextEditingController(
        text: _patientData?['weight']?.toString() ?? '70');
    final heightController = TextEditingController(
        text: _patientData?['height']?.toString() ?? '170');
    final medicalHistoryController =
        TextEditingController(text: _patientData?['medical_history'] ?? '');
    final allergiesController =
        TextEditingController(text: _patientData?['allergies'] ?? '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Modifier le profil'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nom complet
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom complet',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // ✅ Téléphone Tunisie
                const Text(
                  'Téléphone',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0D1B2A),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9FC),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(10),
                          bottomLeft: Radius.circular(10),
                        ),
                        border: Border.all(color: const Color(0xFFD6E0EE)),
                      ),
                      child: const Text(
                        '+216',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0D1B2A),
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 8,
                        decoration: InputDecoration(
                          hintText: 'XX XXX XXX',
                          hintStyle: const TextStyle(
                              color: Color(0xFFB0BEC5), fontSize: 14),
                          prefixIcon: const Icon(Icons.phone_outlined,
                              size: 18, color: Color(0xFF9EADC0)),
                          filled: true,
                          fillColor: const Color(0xFFF7F9FC),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(10),
                              bottomRight: Radius.circular(10),
                            ),
                            borderSide: BorderSide(color: Color(0xFFD6E0EE)),
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(10),
                              bottomRight: Radius.circular(10),
                            ),
                            borderSide: BorderSide(color: Color(0xFFD6E0EE)),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(10),
                              bottomRight: Radius.circular(10),
                            ),
                            borderSide: BorderSide(
                                color: Color(0xFF1A47C0), width: 1.5),
                          ),
                          errorBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(10),
                              bottomRight: Radius.circular(10),
                            ),
                            borderSide: BorderSide(color: Color(0xFFE53935)),
                          ),
                          counterText: '',
                        ),
                        validator: _validateTunisianPhone,
                        onChanged: (value) {
                          final cleanValue =
                              value.replaceAll(RegExp(r'[\s-]'), '');
                          if (cleanValue.length > 8) {
                            phoneController.text = cleanValue.substring(0, 8);
                            phoneController.selection =
                                TextSelection.fromPosition(
                              TextPosition(offset: 8),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Groupe sanguin
                TextField(
                  controller: bloodTypeController,
                  decoration: const InputDecoration(
                    labelText: 'Groupe sanguin',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Cardiologue
                TextField(
                  controller: cardiologistController,
                  decoration: const InputDecoration(
                    labelText: 'Cardiologue',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // ✅✅✅ NOUVEAUX CHAMPS MÉDICAUX ✅✅✅

                // Poids (kg)
                TextField(
                  controller: weightController,
                  decoration: const InputDecoration(
                    labelText: 'Poids (kg)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),

                // Taille (cm) - ✅ heightController UTILISÉ ICI
                TextField(
                  controller: heightController, // ✅ heightController utilisé
                  decoration: const InputDecoration(
                    labelText: 'Taille (cm)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),

                // Antécédents médicaux
                TextField(
                  controller: medicalHistoryController,
                  decoration: const InputDecoration(
                    labelText: 'Antécédents médicaux',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),

                // Allergies
                TextField(
                  controller: allergiesController,
                  decoration: const InputDecoration(
                    labelText: 'Allergies',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                // ✅ Valider le téléphone avant d'enregistrer
                final phoneError = _validateTunisianPhone(phoneController.text);
                if (phoneError != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(phoneError),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final userId = _authService.currentUser?.id;
                if (userId != null) {
                  print('🔹 Updating profile...');

                  // ✅ Formatage du numéro pour Supabase : +216 + 8 chiffres
                  final cleanPhone =
                      phoneController.text.replaceAll(RegExp(r'[\s-]'), '');
                  final tunisianPhone = '$cleanPhone';

                  final success = await _authService.updateProfile(
                    userId: userId,
                    updates: {
                      'name': nameController.text.trim(),
                      'phone': tunisianPhone,
                      'blood_type': bloodTypeController.text.trim(),
                      'cardiologist': cardiologistController.text.trim(),
                      // ✅✅✅ NOUVEAUX CHAMPS UTILISÉS ✅✅✅
                      'weight': double.tryParse(weightController.text) ?? 70.0,
                      'height': double.tryParse(heightController.text) ??
                          170.0, // ✅ heightController utilisé ici
                      'medical_history': medicalHistoryController.text.trim(),
                      'allergies': allergiesController.text.trim(),
                      // ❌ 'emergency_contact' supprimé
                    },
                  );

                  if (success && mounted) {
                    Navigator.pop(context);
                    _loadPatientData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Profil mis à jour avec succès')),
                    );
                  }
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ DIALOGUE DE DÉCONNEXION
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _authService.signOut();
              if (context.mounted) {
                Navigator.pop(context);
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/signin', (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mon profil'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
        actions: [
          TextButton(
            onPressed:
                _isLoading ? null : () => _showEditProfileDialog(context),
            child: const Text(
              'Modifier',
              style: TextStyle(
                color: Color(0xFF1A47C0),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _patientData == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.orange),
                        const SizedBox(height: 16),
                        const Text('Aucune donnée trouvée'),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _loadPatientData,
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // ✅ AVATAR + INFORMATIONS PRINCIPALES
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    // ✅ CORRECTION: Fonction anonyme pour gérer le type
                                    (() {
                                      final nameStr =
                                          (_patientData?['name'] ?? '?')
                                              .toString();
                                      final nameParts = nameStr.split(' ');
                                      final initials = nameParts
                                          .where((part) => part.isNotEmpty)
                                          .map((part) =>
                                              part.isNotEmpty ? part[0] : '')
                                          .take(2)
                                          .join();
                                      return initials.isEmpty
                                          ? '?'
                                          : initials.toUpperCase();
                                    })(),
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                _patientData?['name'] ?? 'Nom non défini',
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_patientData?['age'] ?? '?'} ans · ${_patientData?['blood_type'] ?? '?'}',
                                style: const TextStyle(
                                    fontSize: 15,
                                    color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.badge_rounded,
                                        size: 16, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    Text(
                                      _patientData?['patient_id'] ?? 'PAT-????',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ✅ INFORMATIONS PERSONNELLES
                        _SectionCard(
                          title: 'Informations personnelles',
                          icon: Icons.person_outline_rounded,
                          color: AppColors.primary,
                          children: [
                            _InfoRow(
                                label: 'Nom complet',
                                value: _getSafeString(_patientData?['name'])),
                            _InfoRow(
                                label: 'Email',
                                value: _getSafeString(_patientData?['email'])),
                            _InfoRow(
                                label: 'Téléphone',
                                value: _getSafeString(_patientData?['phone'])),
                            _InfoRow(
                                label: 'Date de naissance',
                                value: _getSafeString(
                                    _patientData?['birth_date'])),
                            _InfoRow(
                                label: 'Âge',
                                value: '${_patientData?['age'] ?? '?'} ans'),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // ✅✅✅ INFORMATIONS MÉDICALES - SECTION CORRIGÉE ✅✅✅
                        _SectionCard(
                          title: 'Informations médicales',
                          icon: Icons.medical_services_outlined,
                          color: AppColors.critical,
                          children: [
                            _InfoRow(
                                label: 'Groupe sanguin',
                                value: _getSafeString(
                                    _patientData?['blood_type'])),
                            _InfoRow(
                                label: 'Pathologie',
                                value: _getSafeString(
                                    _patientData?['cardiac_pathology'])),
                            _InfoRow(
                                label: 'Poids',
                                value: '${_patientData?['weight'] ?? '?'} kg'),
                            _InfoRow(
                                label: 'Taille',
                                value: '${_patientData?['height'] ?? '?'} cm'),
                            // ✅ CORRECTION: Utiliser _getSafeString au lieu de cast direct
                            _InfoRow(
                                label: 'Antécédents',
                                value: _getSafeString(
                                    _patientData?['medical_history'])),
                            _InfoRow(
                                label: 'Allergies',
                                value:
                                    _getSafeString(_patientData?['allergies'])),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // ✅ CARDIOLOGUE - ✅ UTILISE _getSafeString
                        _SectionCard(
                          title: 'Mon cardiologue',
                          icon: Icons.medical_services_rounded,
                          color: AppColors.primary,
                          children: [
                            _InfoRow(
                                label: 'Nom',
                                value: _getSafeString(
                                    _patientData?['cardiologist'])),
                            _InfoRow(
                                label: 'Suivi',
                                value: 'Télésurveillance active'),
                            _InfoRow(
                                label: 'Prochain RDV', value: '15 avril 2026'),
                          ],
                        ),
                        const SizedBox(height: 12),

                        const SizedBox(height: 12),

                        // ✅ NOTIFICATIONS
                        _MenuItemCard(
                          icon: Icons.notifications_outlined,
                          title: 'Notifications',
                          subtitle: 'Configurer les alertes',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const NotificationScreen()),
                            );
                          },
                        ),
                        const SizedBox(height: 12),

                        // ✅ PARAMÈTRES
                        _MenuItemCard(
                          icon: Icons.settings_outlined,
                          title: 'Paramètres',
                          subtitle: 'Capteur, compte',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SettingsScreen()),
                            );
                          },
                        ),
                        const SizedBox(height: 24),

                        // ✅ DÉCONNEXION
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: GestureDetector(
                            onTap: () => _showLogoutDialog(context),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.logout_rounded,
                                    color: Colors.red, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Déconnexion',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
      ),
    );
  }
}

// ==================== _MenuItemCard ====================
class _MenuItemCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuItemCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== _SectionCard ====================
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

// ==================== _InfoRow ====================
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
