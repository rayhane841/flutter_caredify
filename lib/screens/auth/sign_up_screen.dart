import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'sign_in_screen.dart';
import '../../main.dart';
import '../../services/auth_service.dart';
import '../../providers/app_provider.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _pageController = PageController();
  final _authService = AuthService();
  int _currentStep = 0;

  // Étape 1 - Controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Étape 2 - Controllers
  String? _bloodType;
  String? _cardiacPathology;
  final _weightController = TextEditingController(text: '70');
  final _heightController = TextEditingController(text: '170');
  final _medicalHistoryController = TextEditingController();
  final _allergiesController = TextEditingController();

  // Étape 3 - Variables
  bool? _hadInfarctus;
  bool? _hadRhythmDisorder;
  bool? _hadHospitalization;

  // Étape 4 - Checkboxes
  bool _consentDataTreatment = false;
  bool _consentShareCardiologist = false;
  bool _consentResearch = false;

  bool _isLoading = false;

  @override
  void dispose() {
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _medicalHistoryController.dispose();
    _allergiesController.dispose();
    super.dispose();
  }

  // ✅✅✅ VALIDATION TÉLÉPHONE TUNISIE (8 chiffres) ✅✅✅
  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Numéro requis';
    }

    // Supprime les espaces et tirets pour la validation
    final cleanValue = value.replaceAll(RegExp(r'[\s-]'), '');

    // Vérifie que ce sont exactement 8 chiffres
    final phoneRegex = RegExp(r'^[0-9]{8}$');

    if (!phoneRegex.hasMatch(cleanValue)) {
      return 'Numéro invalide (8 chiffres requis)';
    }

    return null;
  }

  void _nextStep() {
    if (_currentStep < 3) {
      if (_currentStep == 0) {
        if (_firstNameController.text.isEmpty ||
            _lastNameController.text.isEmpty ||
            _emailController.text.isEmpty ||
            _phoneController.text.isEmpty ||
            _dobController.text.isEmpty ||
            _passwordController.text.isEmpty ||
            _confirmPasswordController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Veuillez remplir tous les champs obligatoires'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        if (!_emailController.text.contains('@') ||
            !_emailController.text.contains('.')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email invalide - doit contenir @ et .'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // ✅ Validation téléphone Tunisie
        final phoneError = _validatePhone(_phoneController.text);
        if (phoneError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(phoneError),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final dateRegex = RegExp(r'^\d{2}/\d{2}/\d{4}$');
        if (!dateRegex.hasMatch(_dobController.text)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Date invalide - format jj/mm/aaaa requis'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final dateParts = _dobController.text.split('/');
        if (dateParts.length == 3) {
          final day = int.tryParse(dateParts[0]);
          final month = int.tryParse(dateParts[1]);
          final year = int.tryParse(dateParts[2]);

          if (day == null || day < 1 || day > 31) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Jour invalide (1-31)'),
                  backgroundColor: Colors.red),
            );
            return;
          }
          if (month == null || month < 1 || month > 12) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Mois invalide (1-12)'),
                  backgroundColor: Colors.red),
            );
            return;
          }
          if (year == null || year < 1920 || year > 2008) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Année invalide (1920-2008)'),
                  backgroundColor: Colors.red),
            );
            return;
          }
        }

        if (_passwordController.text != _confirmPasswordController.text) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Les mots de passe ne correspondent pas'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _createAccount();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _showDatePickerDialog() async {
    int selectedDay = 1;
    int selectedMonth = 1;
    int selectedYear = 1990;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Date de naissance', textAlign: TextAlign.center),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDatePickerColumn(
                      label: 'Jour',
                      values: List.generate(31, (i) => i + 1),
                      selected: selectedDay,
                      onSelected: (value) =>
                          setDialogState(() => selectedDay = value),
                    ),
                    _buildDatePickerColumn(
                      label: 'Mois',
                      values: List.generate(12, (i) => i + 1),
                      selected: selectedMonth,
                      onSelected: (value) =>
                          setDialogState(() => selectedMonth = value),
                    ),
                    _buildDatePickerColumn(
                      label: 'Année',
                      values: List.generate(89, (i) => 2008 - i),
                      selected: selectedYear,
                      onSelected: (value) =>
                          setDialogState(() => selectedYear = value),
                    ),
                  ],
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
              onPressed: () {
                setState(() {
                  _dobController.text =
                      '${selectedDay.toString().padLeft(2, '0')}/${selectedMonth.toString().padLeft(2, '0')}/$selectedYear';
                });
                Navigator.pop(context);
              },
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePickerColumn({
    required String label,
    required List<int> values,
    required int selected,
    required ValueChanged<int> onSelected,
  }) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF1A47C0))),
        const SizedBox(height: 8),
        Container(
          height: 120,
          width: 70,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF1A47C0), width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListWheelScrollView.useDelegate(
            itemExtent: 40,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (index) => onSelected(values[index]),
            childDelegate: ListWheelChildBuilderDelegate(
              builder: (context, index) {
                final value = values[index];
                final isSelected = value == selected;
                return Center(
                  child: Text(
                    value.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: isSelected ? 20 : 16,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? const Color(0xFF1A47C0) : Colors.grey,
                    ),
                  ),
                );
              },
              childCount: values.length,
            ),
          ),
        ),
      ],
    );
  }

  // ✅✅✅ MÉTHODE _createAccount() CORRIGÉE - Avec retry logique + addPostFrameCallback ✅✅✅
  void _createAccount() async {
    print('🚨🚨🚨 _createAccount() APPELÉE ! 🚨🚨🚨');

    if (!_consentDataTreatment || !_consentShareCardiologist) {
      print('❌ Consentements non acceptés');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez accepter les consentements obligatoires'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('🔹 Appel de AuthService.signUp...');
      print('🔹 Email: ${_emailController.text}');
      print('🔹 Nom: ${_firstNameController.text} ${_lastNameController.text}');

      // ✅ Formatage du numéro pour Supabase : +216 + 8 chiffres
      final cleanPhone = _phoneController.text.replaceAll(RegExp(r'[\s-]'), '');
      final tunisianPhone = '+216$cleanPhone';

      final result = await _authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phone: tunisianPhone, // ✅ Envoie +216XXXXXXXX
        birthDate: _dobController.text,
        bloodType: _bloodType ?? 'O+',
        cardiacPathology: _cardiacPathology ?? '',
        weight: double.tryParse(_weightController.text) ?? 70.0,
        height: double.tryParse(_heightController.text) ?? 170.0,
        medicalHistory: _medicalHistoryController.text,
        allergies: _allergiesController.text,
      );

      print('🔹 Résultat de signUp: $result');

      if (mounted) {
        if (result['success'] == true) {
          print('✅ Inscription réussie!');

          // ✅✅✅ Synchroniser AppProvider avec retry logique pour Supabase ✅✅✅
          final userId = _authService.currentUser?.id;
          if (userId != null) {
            print('🔹 Fetching patient data for new user: $userId');

            // ✅ AJOUT : Retry logique pour attendre que Supabase confirme l'insertion
            Map<String, dynamic>? userData;
            int retryCount = 0;
            const maxRetries = 3;

            while (retryCount < maxRetries && userData == null) {
              // Petit délai entre chaque tentative
              await Future.delayed(const Duration(milliseconds: 300));

              userData = await _authService.getPatientData(userId);

              if (userData == null) {
                print('⚠️ Retry $retryCount: patient data not found yet...');
                retryCount++;
              }
            }

            if (userData != null && mounted) {
              print('✅ Patient data fetched: ${userData['name']}');

              // ✅ Mettre à jour AppProvider pour synchroniser Dashboard
              Provider.of<AppProvider>(context, listen: false)
                  .updateProfileFromMap(userData);
            } else {
              print(
                  '⚠️ Could not fetch patient data after $maxRetries retries');
            }
          }

          // Message de succès
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Compte créé avec succès!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // ✅✅✅ SOLUTION ULTIME : Utiliser addPostFrameCallback pour naviguer APRÈS le frame courant ✅✅✅
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const MainShell()),
                  (route) => false,
                );
              }
            });
          }
        } else {
          print('❌ Erreur: ${result['error']}');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Une erreur est survenue'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );

          setState(() => _isLoading = false);
        }
      }
    } catch (e, stackTrace) {
      print('💥 EXCEPTION dans _createAccount: $e');
      print('📋 Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A47C0),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 32),
              Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_add_rounded,
                      size: 32,
                      color: Color(0xFF1A47C0),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'CAREDIFY',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Créez votre compte patient',
                    style: TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildProgressIndicator(),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 450,
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (index) =>
                            setState(() => _currentStep = index),
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildStep1InsideCard(),
                          _buildStep2InsideCard(),
                          _buildStep3InsideCard(),
                          _buildStep4InsideCard(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Déjà un compte ? ',
                      style: TextStyle(fontSize: 14, color: Colors.white70)),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const SignInScreen()),
                      );
                    },
                    child: const Text(
                      'Se connecter',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: index <= _currentStep
                ? const Color(0xFF1A47C0)
                : Colors.grey[300],
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }

  Widget _buildBackButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: _previousStep,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: Color(0xFF1A47C0),
          ),
        ),
      ),
    );
  }

  Widget _buildStep1InsideCard() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBackButton(),
          const SizedBox(height: 8),
          const Text(
            'Informations personnelles',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0D1B2A)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Commencez votre parcours cardiaque',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7A8D)),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                  child: _buildTextField(
                      label: 'Prénom *',
                      controller: _firstNameController,
                      hint: 'Jean')),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildTextField(
                      label: 'Nom *',
                      controller: _lastNameController,
                      hint: 'Martin')),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'E-mail *',
            controller: _emailController,
            hint: 'patient@exemple.fr',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          // ✅✅✅ CHAMP TÉLÉPHONE TUNISIE (+216 + 8 chiffres) ✅✅✅
          const Text(
            'Téléphone *',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0D1B2A),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Indicatif Tunisie (+216) - non modifiable
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
              // Champ de saisie (8 chiffres)
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 8,
                  decoration: InputDecoration(
                    hintText: 'XX XXX XXX',
                    hintStyle:
                        const TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
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
                      borderSide:
                          BorderSide(color: Color(0xFF1A47C0), width: 1.5),
                    ),
                    errorBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(10),
                        bottomRight: Radius.circular(10),
                      ),
                      borderSide: BorderSide(color: Color(0xFFE53935)),
                    ),
                    counterText: '', // Cache le compteur de caractères
                  ),
                  validator: _validatePhone,
                  onChanged: (value) {
                    // Formate automatiquement : supprime les espaces/tirets
                    final cleanValue = value.replaceAll(RegExp(r'[\s-]'), '');
                    if (cleanValue.length > 8) {
                      _phoneController.text = cleanValue.substring(0, 8);
                      _phoneController.selection = TextSelection.fromPosition(
                        TextPosition(offset: 8),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Date de naissance *',
            controller: _dobController,
            hint: 'jj/mm/aaaa',
            icon: Icons.calendar_today_outlined,
            suffixIcon: IconButton(
              icon: const Icon(Icons.calendar_month_outlined,
                  size: 18, color: Color(0xFF6B7A8D)),
              onPressed: _showDatePickerDialog,
            ),
            readOnly: true,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Mot de passe *',
            controller: _passwordController,
            hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: const Color(0xFF6B7A8D)),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            label: 'Confirmer le mot de passe *',
            controller: _confirmPasswordController,
            hint: '••••••••',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscureConfirmPassword,
            suffixIcon: IconButton(
              icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: const Color(0xFF6B7A8D)),
              onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A47C0),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Suivant',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2InsideCard() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBackButton(),
          const SizedBox(height: 8),
          const Text('Dossier médical',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D1B2A))),
          const SizedBox(height: 4),
          const Text('Informations pour votre suivi personnalisé',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7A8D))),
          const SizedBox(height: 20),
          _buildDropdownField(
              label: 'Groupe sanguin',
              value: _bloodType,
              hint: 'Sélectionner...',
              items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
              onChanged: (v) => setState(() => _bloodType = v),
              icon: Icons.bloodtype_outlined),
          const SizedBox(height: 16),
          _buildDropdownField(
              label: 'Pathologie cardiaque',
              value: _cardiacPathology,
              hint: 'Sélectionner...',
              items: [
                'Hypertension',
                'Insuffisance cardiaque',
                'Trouble du rythme',
                'Maladie coronarienne',
                'Autre'
              ],
              onChanged: (v) => setState(() => _cardiacPathology = v),
              icon: Icons.favorite_outline),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _buildTextField(
                      label: 'Poids (kg)',
                      controller: _weightController,
                      hint: '70',
                      keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildTextField(
                      label: 'Taille (cm)',
                      controller: _heightController,
                      hint: '170',
                      keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(
              label: 'Antécédents médicaux',
              controller: _medicalHistoryController,
              hint: 'Ex: IDM 2019...',
              maxLines: 2),
          const SizedBox(height: 16),
          _buildTextField(
              label: 'Allergies',
              controller: _allergiesController,
              hint: 'Ex: Pénicilline...',
              maxLines: 2),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A47C0),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Suivant',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 18)
                  ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3InsideCard() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBackButton(),
          const SizedBox(height: 8),
          const Text('Antécédents cardiaques',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D1B2A))),
          const SizedBox(height: 4),
          const Text('Répondez par Oui ou Non',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7A8D))),
          const SizedBox(height: 20),
          _buildQuestion(
              number: 1,
              question: 'Avez-vous déjà eu un infarctus ?',
              value: _hadInfarctus,
              onChanged: (v) => setState(() => _hadInfarctus = v)),
          const SizedBox(height: 16),
          _buildQuestion(
              number: 2,
              question: 'Trouble du rythme cardiaque ?',
              value: _hadRhythmDisorder,
              onChanged: (v) => setState(() => _hadRhythmDisorder = v)),
          const SizedBox(height: 16),
          _buildQuestion(
              number: 3,
              question: 'Hospitalisation cardiaque ?',
              value: _hadHospitalization,
              onChanged: (v) => setState(() => _hadHospitalization = v)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A47C0),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Suivant',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 18)
                  ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4InsideCard() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBackButton(),
          const SizedBox(height: 8),
          const Text(
            'Consentement',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0D1B2A)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Lisez et acceptez les conditions',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7A8D)),
          ),
          const SizedBox(height: 20),
          _buildConsentCheckbox(
            title: 'Traitement des données *',
            description:
                "J'autorise CAREDIFY à collecter mes données de santé.",
            value: _consentDataTreatment,
            onChanged: (v) {
              setState(() => _consentDataTreatment = v!);
            },
            obligatory: true,
          ),
          const SizedBox(height: 12),
          _buildConsentCheckbox(
            title: 'Partage cardiologue *',
            description: "J'autorise la transmission à mon cardiologue.",
            value: _consentShareCardiologist,
            onChanged: (v) {
              setState(() => _consentShareCardiologist = v!);
            },
            obligatory: true,
          ),
          const SizedBox(height: 12),
          _buildConsentCheckbox(
            title: 'Recherche (optionnel)',
            description:
                "J'accepte l'utilisation anonymisée pour la recherche.",
            value: _consentResearch,
            onChanged: (v) {
              setState(() => _consentResearch = v!);
            },
            obligatory: false,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: (_consentDataTreatment &&
                      _consentShareCardiologist &&
                      !_isLoading)
                  ? _createAccount
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    (_consentDataTreatment && _consentShareCardiologist)
                        ? const Color(0xFF1A47C0)
                        : Colors.grey[400],
                foregroundColor:
                    (_consentDataTreatment && _consentShareCardiologist)
                        ? Colors.white
                        : Colors.white70,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_add_outlined,
                          size: 20,
                          color: (_consentDataTreatment &&
                                  _consentShareCardiologist)
                              ? Colors.white
                              : Colors.white70,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Créer mon compte',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: (_consentDataTreatment &&
                                    _consentShareCardiologist)
                                ? Colors.white
                                : Colors.white70,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          if (!(_consentDataTreatment && _consentShareCardiologist))
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                '⚠️ Veuillez accepter les 2 consentements obligatoires',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    Widget? suffixIcon,
    bool obscureText = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0D1B2A))),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLines: maxLines,
          readOnly: readOnly,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
            prefixIcon: icon != null
                ? Icon(icon, size: 18, color: const Color(0xFF9EADC0))
                : null,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: const Color(0xFFF7F9FC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFD6E0EE))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFD6E0EE))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: Color(0xFF1A47C0), width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0D1B2A))),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD6E0EE))),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Row(children: [
                if (icon != null)
                  Icon(icon, size: 18, color: const Color(0xFF9EADC0)),
                if (icon != null) const SizedBox(width: 8),
                Text(hint,
                    style:
                        const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13))
              ]),
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF9EADC0)),
              items: items
                  .map((item) =>
                      DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestion(
      {required int number,
      required String question,
      required bool? value,
      required ValueChanged<bool?> onChanged}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
                color: Color(0xFF1A47C0), shape: BoxShape.circle),
            child: Center(
                child: Text('$number',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)))),
        const SizedBox(width: 12),
        Expanded(
            child: Text(question,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0D1B2A))))
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
            child: GestureDetector(
                onTap: () => onChanged(true),
                child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                        color: value == true
                            ? const Color(0xFF1A47C0)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: value == true
                                ? const Color(0xFF1A47C0)
                                : Colors.grey[300]!)),
                    child: Center(
                        child: Text('Oui',
                            style: TextStyle(
                                color: value == true
                                    ? Colors.white
                                    : Colors.grey[700],
                                fontWeight: FontWeight.w600)))))),
        const SizedBox(width: 10),
        Expanded(
            child: GestureDetector(
                onTap: () => onChanged(false),
                child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                        color: value == false ? Colors.grey : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: value == false
                                ? Colors.grey
                                : Colors.grey[300]!)),
                    child: Center(
                        child: Text('Non',
                            style: TextStyle(
                                color: value == false
                                    ? Colors.white
                                    : Colors.grey[700],
                                fontWeight: FontWeight.w600))))))
      ]),
    ]);
  }

  Widget _buildConsentCheckbox(
      {required String title,
      required String description,
      required bool value,
      required ValueChanged<bool?> onChanged,
      required bool obligatory}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Transform.scale(
                scale: 1.1,
                child: Checkbox(
                  value: value,
                  onChanged: onChanged,
                  activeColor: const Color(0xFF1A47C0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0D1B2A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7A8D),
              height: 1.4,
            ),
          ),
          if (obligatory) ...[
            const SizedBox(height: 4),
            const Text(
              'Obligatoire',
              style: TextStyle(
                fontSize: 11,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
