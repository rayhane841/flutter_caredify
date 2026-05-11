import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // ← ✅ Ajouté pour AppProvider
import '../theme/app_theme.dart';
import '../utils/theme_helper.dart';
import '../services/auth_service.dart';
import '../providers/app_provider.dart'; // ← ✅ Ajouté
import 'notification_screen.dart';
import 'settings_screen.dart';

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

  Future<void> _loadPatientData() async {
    setState(() => _isLoading = true);
    final userId = _authService.currentUser?.id;
    if (userId != null) {
      final data = await _authService.getPatientData(userId);
      if (mounted) {
        if (data != null) {
          setState(() {
            _patientData = data;
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  String _getSafeString(dynamic value) {
    if (value == null) return 'Non renseigné';
    final str = value.toString().trim();
    return str.isEmpty ? 'Non renseigné' : str;
  }

  String? _validateTunisianPhone(String? value) {
    if (value == null || value.isEmpty) return 'Numéro requis';
    final cleanValue =
        value.replaceAll(RegExp(r'[\s+-]'), '').replaceAll('+216', '');
    final phoneRegex = RegExp(r'^[0-9]{8}$');
    if (!phoneRegex.hasMatch(cleanValue)) {
      return 'Numéro invalide (8 chiffres requis)';
    }
    return null;
  }

  void _showEditProfileDialog(BuildContext context) {
    if (_patientData == null) return;
    final nameController =
        TextEditingController(text: _patientData?['name'] ?? '');
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
        builder: (context, setDialogState) {
          final surface = ThemeHelper.surface(context);
          final border = ThemeHelper.border(context);
          final textPrimary = ThemeHelper.textPrimary(context);
          final textSecondary = ThemeHelper.textSecondary(context);
          return AlertDialog(
            backgroundColor: surface,
            title: Text('Modifier le profil',
                style: TextStyle(color: textPrimary)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                          labelText: 'Nom complet',
                          border: const OutlineInputBorder(),
                          labelStyle: TextStyle(color: textSecondary),
                          enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: border)),
                          focusedBorder: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: ThemeHelper.primary)))),
                  const SizedBox(height: 12),
                  const Text('Téléphone',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                            color: surfaceVariant(context),
                            borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(10),
                                bottomLeft: Radius.circular(10)),
                            border: Border.all(color: border)),
                        child: const Text('+216',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600))),
                    Expanded(
                        child: TextFormField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            maxLength: 8,
                            decoration: InputDecoration(
                                hintText: 'XX XXX XXX',
                                hintStyle: TextStyle(
                                    color: textSecondary, fontSize: 14),
                                filled: true,
                                fillColor: surfaceVariant(context),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                border: const OutlineInputBorder(
                                    borderRadius: BorderRadius.only(
                                        topRight: Radius.circular(10),
                                        bottomRight: Radius.circular(10)),
                                    borderSide:
                                        BorderSide(color: AppColors.border)),
                                enabledBorder: const OutlineInputBorder(
                                    borderRadius: BorderRadius.only(
                                        topRight: Radius.circular(10),
                                        bottomRight: Radius.circular(10)),
                                    borderSide:
                                        BorderSide(color: AppColors.border)),
                                focusedBorder: const OutlineInputBorder(
                                    borderRadius: BorderRadius.only(
                                        topRight: Radius.circular(10),
                                        bottomRight: Radius.circular(10)),
                                    borderSide: BorderSide(
                                        color: Color(0xFF1A47C0), width: 1.5)),
                                counterText: ''),
                            validator: _validateTunisianPhone))
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                      controller: bloodTypeController,
                      decoration: InputDecoration(
                          labelText: 'Groupe sanguin',
                          border: const OutlineInputBorder(),
                          labelStyle: TextStyle(color: textSecondary))),
                  const SizedBox(height: 12),
                  TextField(
                      controller: cardiologistController,
                      decoration: InputDecoration(
                          labelText: 'Cardiologue',
                          border: const OutlineInputBorder(),
                          labelStyle: TextStyle(color: textSecondary))),
                  const SizedBox(height: 12),
                  TextField(
                      controller: weightController,
                      decoration: InputDecoration(
                          labelText: 'Poids (kg)',
                          border: const OutlineInputBorder(),
                          labelStyle: TextStyle(color: textSecondary)),
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  TextField(
                      controller: heightController,
                      decoration: InputDecoration(
                          labelText: 'Taille (cm)',
                          border: const OutlineInputBorder(),
                          labelStyle: TextStyle(color: textSecondary)),
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  TextField(
                      controller: medicalHistoryController,
                      decoration: InputDecoration(
                          labelText: 'Antécédents médicaux',
                          border: const OutlineInputBorder(),
                          alignLabelWithHint: true,
                          labelStyle: TextStyle(color: textSecondary)),
                      maxLines: 2),
                  const SizedBox(height: 12),
                  TextField(
                      controller: allergiesController,
                      decoration: InputDecoration(
                          labelText: 'Allergies',
                          border: const OutlineInputBorder(),
                          alignLabelWithHint: true,
                          labelStyle: TextStyle(color: textSecondary)),
                      maxLines: 2),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Annuler', style: TextStyle(color: textPrimary))),
              ElevatedButton(
                  onPressed: () async {
                    final phoneError =
                        _validateTunisianPhone(phoneController.text);
                    if (phoneError != null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(phoneError),
                          backgroundColor: Colors.red));
                      return;
                    }
                    final userId = _authService.currentUser?.id;
                    if (userId != null) {
                      final cleanPhone =
                          phoneController.text.replaceAll(RegExp(r'[\s-]'), '');
                      final success = await _authService
                          .updateProfile(userId: userId, updates: {
                        'name': nameController.text.trim(),
                        'phone': cleanPhone,
                        'blood_type': bloodTypeController.text.trim(),
                        'cardiologist': cardiologistController.text.trim(),
                        'weight':
                            double.tryParse(weightController.text) ?? 70.0,
                        'height':
                            double.tryParse(heightController.text) ?? 170.0,
                        'medical_history': medicalHistoryController.text.trim(),
                        'allergies': allergiesController.text.trim()
                      });
                      if (success && mounted) {
                        Navigator.pop(context);
                        _loadPatientData();
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Profil mis à jour avec succès')));
                      }
                    }
                  },
                  child: const Text('Enregistrer')),
            ],
          );
        },
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final surface = ThemeHelper.surface(context);
    final textPrimary = ThemeHelper.textPrimary(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surface,
        title: Text('Déconnexion', style: TextStyle(color: textPrimary)),
        content: Text('Êtes-vous sûr de vouloir vous déconnecter ?',
            style: TextStyle(color: textPrimary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler', style: TextStyle(color: textPrimary))),
          ElevatedButton(
              onPressed: () async {
                // ✅✅✅ NOUVEAU : Nettoyer l'état persistant AVANT déconnexion
                final app = Provider.of<AppProvider>(context, listen: false);
                await app.onLogout();
                
                // Déconnecter de Supabase
                await _authService.signOut();
                
                if (context.mounted) {
                  Navigator.pop(context);
                  // Supprimer TOUTES les routes et aller à SignIn
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/signin', (route) => false);
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Déconnexion')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = ThemeHelper.background(context);
    final surface = ThemeHelper.surface(context);
    final border = ThemeHelper.border(context);
    final textPrimary = ThemeHelper.textPrimary(context);
    final textSecondary = ThemeHelper.textSecondary(context);
    final surfaceVariant = ThemeHelper.getColor(
        context, AppColors.surfaceVariant, AppColors.darkSurfaceVariant);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Mon profil'),
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: border)),
        actions: [
          TextButton(
              onPressed:
                  _isLoading ? null : () => _showEditProfileDialog(context),
              child: const Text('Modifier',
                  style: TextStyle(
                      color: Color(0xFF1A47C0), fontWeight: FontWeight.w600)))
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
                        Icon(Icons.error_outline,
                            size: 48, color: ThemeHelper.warning(context)),
                        const SizedBox(height: 16),
                        Text('Aucune donnée trouvée',
                            style: TextStyle(color: textPrimary)),
                        const SizedBox(height: 8),
                        ElevatedButton(
                            onPressed: _loadPatientData,
                            child: const Text('Réessayer'))
                      ]))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                                color: surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: border)),
                            child: Column(children: [
                              Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                      color: ThemeHelper.primary,
                                      shape: BoxShape.circle),
                                  child: Center(
                                      child: Text((() {
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
                                              color: Colors.white)))),
                              const SizedBox(height: 14),
                              Text(_patientData?['name'] ?? 'Nom non défini',
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: textPrimary)),
                              const SizedBox(height: 4),
                              Text(
                                  '${_patientData?['age'] ?? '?'} ans · ${_patientData?['blood_type'] ?? '?'}',
                                  style: TextStyle(
                                      fontSize: 15, color: textSecondary)),
                              const SizedBox(height: 12),
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                      color: surfaceVariant,
                                      borderRadius: BorderRadius.circular(100)),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.badge_rounded,
                                            size: 16, color: Color(0xFF1A47C0)),
                                        const SizedBox(width: 6),
                                        Text(
                                            _patientData?['patient_id'] ??
                                                'PAT-????',
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF1A47C0)))
                                      ]))
                            ])),
                        const SizedBox(height: 16),
                        _SectionCard(
                            title: 'Informations personnelles',
                            icon: Icons.person_outline_rounded,
                            color: ThemeHelper.primary,
                            surface: surface,
                            border: border,
                            children: [
                              _InfoRow(
                                  label: 'Nom complet',
                                  value: _getSafeString(_patientData?['name']),
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary),
                              _InfoRow(
                                  label: 'Email',
                                  value: _getSafeString(_patientData?['email']),
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary),
                              _InfoRow(
                                  label: 'Téléphone',
                                  value: _getSafeString(_patientData?['phone']),
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary),
                              _InfoRow(
                                  label: 'Date de naissance',
                                  value: _getSafeString(
                                      _patientData?['birth_date']),
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary),
                              _InfoRow(
                                  label: 'Âge',
                                  value: '${_patientData?['age'] ?? '?'} ans',
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary)
                            ]),
                        const SizedBox(height: 12),
                        _SectionCard(
                            title: 'Informations médicales',
                            icon: Icons.medical_services_outlined,
                            color: ThemeHelper.critical(context),
                            surface: surface,
                            border: border,
                            children: [
                              _InfoRow(
                                  label: 'Groupe sanguin',
                                  value: _getSafeString(
                                      _patientData?['blood_type']),
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary),
                              _InfoRow(
                                  label: 'Pathologie',
                                  value: _getSafeString(
                                      _patientData?['cardiac_pathology']),
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary),
                              _InfoRow(
                                  label: 'Poids',
                                  value: '${_patientData?['weight'] ?? '?'} kg',
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary),
                              _InfoRow(
                                  label: 'Taille',
                                  value: '${_patientData?['height'] ?? '?'} cm',
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary),
                              _InfoRow(
                                  label: 'Antécédents',
                                  value: _getSafeString(
                                      _patientData?['medical_history']),
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary),
                              _InfoRow(
                                  label: 'Allergies',
                                  value: _getSafeString(
                                      _patientData?['allergies']),
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary)
                            ]),
                        const SizedBox(height: 12),
                        _SectionCard(
                            title: 'Mon cardiologue',
                            icon: Icons.medical_services_rounded,
                            color: ThemeHelper.primary,
                            surface: surface,
                            border: border,
                            children: [
                              _InfoRow(
                                  label: 'Nom',
                                  value: _getSafeString(
                                      _patientData?['cardiologist']),
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary),
                              _InfoRow(
                                  label: 'Suivi',
                                  value: 'Télésurveillance active',
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary),
                              _InfoRow(
                                  label: 'Prochain RDV',
                                  value: '15 avril 2026',
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary)
                            ]),
                        const SizedBox(height: 12),
                        _MenuItemCard(
                            icon: Icons.notifications_outlined,
                            title: 'Notifications',
                            subtitle: 'Configurer les alertes',
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const NotificationScreen()));
                            },
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            surface: surface,
                            border: border),
                        const SizedBox(height: 12),
                        _MenuItemCard(
                            icon: Icons.settings_outlined,
                            title: 'Paramètres',
                            subtitle: 'Capteur, compte',
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const SettingsScreen()));
                            },
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            surface: surface,
                            border: border),
                        const SizedBox(height: 24),
                        Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: ThemeHelper.critical(context)
                                        .withOpacity(0.3))),
                            child: GestureDetector(
                                onTap: () => _showLogoutDialog(context),
                                child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.logout_rounded,
                                          color: ThemeHelper.critical(context),
                                          size: 20),
                                      const SizedBox(width: 8),
                                      Text('Déconnexion',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: ThemeHelper.critical(
                                                  context)))
                                    ]))),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
      ),
    );
  }
}

// Helper pour surfaceVariant dynamique
Color surfaceVariant(BuildContext context) => ThemeHelper.getColor(
    context, AppColors.surfaceVariant, AppColors.darkSurfaceVariant);

// ==================== _MenuItemCard ====================
class _MenuItemCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  final Color textPrimary, textSecondary, surface, border;
  const _MenuItemCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap,
      required this.textPrimary,
      required this.textSecondary,
      required this.surface,
      required this.border});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: onTap,
        child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border)),
            child: Row(children: [
              Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: ThemeHelper.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, size: 20, color: ThemeHelper.primary)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(fontSize: 13, color: textSecondary))
                  ])),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary)
            ])));
  }
}

// ==================== _SectionCard ====================
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;
  final Color surface, border;
  const _SectionCard(
      {required this.title,
      required this.icon,
      required this.color,
      required this.children,
      required this.surface,
      required this.border});
  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, size: 18, color: color)),
                const SizedBox(width: 10),
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700))
              ])),
          const Divider(height: 1),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: children))
        ]));
  }
}

// ==================== _InfoRow ====================
class _InfoRow extends StatelessWidget {
  final String label, value;
  final Color textPrimary, textSecondary;
  const _InfoRow(
      {required this.label,
      required this.value,
      required this.textPrimary,
      required this.textSecondary});
  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 110,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      color: textSecondary,
                      fontWeight: FontWeight.w500))),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary)))
        ]));
  }
}