import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'sign_in_screen.dart';
import '../../main.dart';
import '../../services/auth_service.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/theme_helper.dart';

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

  // Étape 2 - Controllers + Cardiologue
  String? _bloodType;
  String? _cardiacPathology;
  String? _selectedCardiologistId; // ← ID du cardiologue sélectionné
  String? _selectedCardiologistLabel; // ← Label affiché dans le dropdown
  List<Map<String, dynamic>> _cardiologists = []; // ← Liste des cardiologues
  bool _isLoadingCardiologists = false; // ← État de chargement
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
  void initState() {
    super.initState();
    _loadCardiologists(); // ← Charger la liste au démarrage
  }

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

  // ✅ Charger la liste des cardiologues depuis Supabase
  Future<void> _loadCardiologists() async {
    setState(() => _isLoadingCardiologists = true);
    try {
      final list = await _authService.getCardiologists();
      if (mounted) {
        setState(() {
          _cardiologists = list;
          _isLoadingCardiologists = false;
        });
      }
    } catch (e) {
      print('❌ Error loading cardiologists: $e');
      if (mounted) {
        setState(() => _isLoadingCardiologists = false);
      }
    }
  }

  // ✅ Validation du mot de passe côté client
  bool _validatePassword(String password) {
    if (password.isEmpty) return false;
    bool hasLower = false,
        hasUpper = false,
        hasDigit = false,
        hasSpecial = false;
    const specialChars = '!@#\$%^&*()_+-=[]{};:\'"|<>,.?/`~';
    for (int i = 0; i < password.length; i++) {
      final char = password[i];
      if (char.compareTo('a') >= 0 && char.compareTo('z') <= 0) {
        hasLower = true;
      } else if (char.compareTo('A') >= 0 && char.compareTo('Z') <= 0)
        hasUpper = true;
      else if (char.compareTo('0') >= 0 && char.compareTo('9') <= 0)
        hasDigit = true;
      else if (specialChars.contains(char)) hasSpecial = true;
    }
    return hasLower && hasUpper && hasDigit && hasSpecial;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Numéro requis';
    final cleanValue = value.replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^[0-9]{8}$').hasMatch(cleanValue)) {
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Veuillez remplir tous les champs obligatoires'),
              backgroundColor: Colors.red));
          return;
        }
        if (!_emailController.text.contains('@') ||
            !_emailController.text.contains('.')) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Email invalide - doit contenir @ et .'),
              backgroundColor: Colors.red));
          return;
        }
        final String? phoneError = _validatePhone(_phoneController.text);
        if (phoneError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(phoneError), backgroundColor: Colors.red));
          return;
        }
        final dateRegex = RegExp(r'^\d{2}/\d{2}/\d{4}$');
        if (!dateRegex.hasMatch(_dobController.text)) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Date invalide - format jj/mm/aaaa requis'),
              backgroundColor: Colors.red));
          return;
        }
        if (_passwordController.text != _confirmPasswordController.text) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Les mots de passe ne correspondent pas'),
              backgroundColor: Colors.red));
          return;
        }
        final password = _passwordController.text.trim();
        if (!_validatePassword(password)) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'Mot de passe invalide : il doit contenir au moins 1 minuscule, 1 majuscule, 1 chiffre et 1 symbole spécial (!@#\$%^&*...)'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 6)));
          return;
        }
      }
      setState(() => _currentStep++);
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _createAccount();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _showDatePickerDialog() async {
    int selectedDay = 1, selectedMonth = 1, selectedYear = 1990;
    final textPrimary = ThemeHelper.textPrimary(context);
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final surface = ThemeHelper.surface(context);
          return AlertDialog(
            backgroundColor: surface,
            title: Text('Date de naissance',
                textAlign: TextAlign.center,
                style: TextStyle(color: textPrimary)),
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
                            textPrimary: textPrimary),
                        _buildDatePickerColumn(
                            label: 'Mois',
                            values: List.generate(12, (i) => i + 1),
                            selected: selectedMonth,
                            onSelected: (value) =>
                                setDialogState(() => selectedMonth = value),
                            textPrimary: textPrimary),
                        _buildDatePickerColumn(
                            label: 'Année',
                            values: List.generate(89, (i) => 2008 - i),
                            selected: selectedYear,
                            onSelected: (value) =>
                                setDialogState(() => selectedYear = value),
                            textPrimary: textPrimary),
                      ]),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Annuler', style: TextStyle(color: textPrimary))),
              ElevatedButton(
                onPressed: () {
                  setState(() => _dobController.text =
                      '${selectedDay.toString().padLeft(2, '0')}/${selectedMonth.toString().padLeft(2, '0')}/$selectedYear');
                  Navigator.pop(context);
                },
                child: const Text('Valider'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDatePickerColumn(
      {required String label,
      required List<int> values,
      required int selected,
      required ValueChanged<int> onSelected,
      required Color textPrimary}) {
    return Column(children: [
      Text(label,
          style: TextStyle(
              fontWeight: FontWeight.bold, color: ThemeHelper.primary)),
      const SizedBox(height: 8),
      Container(
        height: 120,
        width: 70,
        decoration: BoxDecoration(
            border: Border.all(color: ThemeHelper.primary, width: 2),
            borderRadius: BorderRadius.circular(10)),
        child: ListWheelScrollView.useDelegate(
          itemExtent: 40,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: (index) => onSelected(values[index]),
          childDelegate: ListWheelChildBuilderDelegate(
            builder: (context, index) {
              final value = values[index];
              final isSelected = value == selected;
              return Center(
                  child: Text(value.toString().padLeft(2, '0'),
                      style: TextStyle(
                          fontSize: isSelected ? 20 : 16,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color:
                              isSelected ? ThemeHelper.primary : textPrimary)));
            },
            childCount: values.length,
          ),
        ),
      ),
    ]);
  }

  void _createAccount() async {
    if (!_consentDataTreatment || !_consentShareCardiologist) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Veuillez accepter les consentements obligatoires'),
          backgroundColor: Colors.red));
      return;
    }
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Les mots de passe ne correspondent pas'),
          backgroundColor: Colors.red));
      return;
    }
    if (!_validatePassword(password)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Mot de passe invalide : il doit contenir au moins 1 minuscule, 1 majuscule, 1 chiffre et 1 symbole spécial'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 6)));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final cleanPhone = _phoneController.text.replaceAll(RegExp(r'[\s-]'), '');
      final tunisianPhone = '+216$cleanPhone';
      final result = await _authService.signUp(
        email: _emailController.text.trim(),
        password: password,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phone: tunisianPhone,
        birthDate: _dobController.text,
        bloodType: _bloodType ?? 'O+',
        cardiacPathology: _cardiacPathology ?? '',
        weight: double.tryParse(_weightController.text) ?? 70.0,
        height: double.tryParse(_heightController.text) ?? 170.0,
        medicalHistory: _medicalHistoryController.text,
        allergies: _allergiesController.text,
        // ✅ NOUVEAU : Passer le cardiologue sélectionné
        cardiologist: _selectedCardiologistLabel ?? '',
      );
      if (mounted) {
        if (result['success'] == true) {
          final userId = _authService.currentUser?.id;
          if (userId != null) {
            Map<String, dynamic>? userData;
            int retryCount = 0;
            while (retryCount < 3 && userData == null) {
              await Future.delayed(const Duration(milliseconds: 300));
              userData = await _authService.getPatientData(userId);
              if (userData == null) retryCount++;
            }
            if (userData != null && mounted) {
              Provider.of<AppProvider>(context, listen: false)
                  .updateProfileFromMap(userData);
            }
          }
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Compte créé avec succès!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2)));
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const MainShell()),
                    (route) => false);
              }
            });
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(result['error'] ?? 'Une erreur est survenue'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5)));
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5)));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = ThemeHelper.primary;
    final surface = ThemeHelper.surface(context);
    final border = ThemeHelper.border(context);
    final textPrimary = ThemeHelper.textPrimary(context);
    final textSecondary = ThemeHelper.textSecondary(context);
    final textHint = ThemeHelper.textHint(context);
    final inputFill = ThemeHelper.getColor(
        context, const Color(0xFFF7F9FC), AppColors.darkSurfaceVariant);
    final inputBorder = ThemeHelper.getColor(
        context, const Color(0xFFD6E0EE), AppColors.darkBorder);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(children: [
            const SizedBox(height: 32),
            Column(children: [
              Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.person_add_rounded,
                      size: 32, color: Color(0xFF1A47C0))),
              const SizedBox(height: 12),
              const Text('CAREDIFY',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2.5)),
              const SizedBox(height: 4),
              const Text('Créez votre compte patient',
                  style: TextStyle(fontSize: 13, color: Colors.white70)),
            ]),
            const SizedBox(height: 24),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 30,
                        offset: const Offset(0, 10))
                  ]),
              child: Column(children: [
                _buildProgressIndicator(textSecondary),
                const SizedBox(height: 20),
                SizedBox(
                  height: 450,
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) =>
                        setState(() => _currentStep = index),
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildStep1InsideCard(surface, border, textPrimary,
                          textSecondary, textHint, inputFill, inputBorder),
                      _buildStep2InsideCard(surface, border, textPrimary,
                          textSecondary, textHint, inputFill, inputBorder),
                      _buildStep3InsideCard(
                          surface, border, textPrimary, textSecondary),
                      _buildStep4InsideCard(
                          surface, border, textPrimary, textSecondary),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 32),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('Déjà un compte ? ',
                  style: TextStyle(fontSize: 14, color: Colors.white70)),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const SignInScreen()));
                },
                child: const Text('Se connecter',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ]),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(Color textSecondary) {
    return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
            4,
            (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: index <= _currentStep
                        ? ThemeHelper.primary
                        : textSecondary.withOpacity(0.3),
                    shape: BoxShape.circle))));
  }

  Widget _buildBackButton(Color textPrimary) {
    return Align(
        alignment: Alignment.centerLeft,
        child: GestureDetector(
            onTap: _previousStep,
            child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: ThemeHelper.getColor(context, Colors.grey[100]!,
                        AppColors.darkSurfaceVariant),
                    shape: BoxShape.circle),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: textPrimary))));
  }

  // ── Étape 1 ──
  Widget _buildStep1InsideCard(Color surface, Color border, Color textPrimary,
      Color textSecondary, Color textHint, Color inputFill, Color inputBorder) {
    return SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildBackButton(textPrimary),
      const SizedBox(height: 8),
      Text('Informations personnelles',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary)),
      const SizedBox(height: 4),
      Text('Commencez votre parcours cardiaque',
          style: TextStyle(fontSize: 13, color: textSecondary)),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(
            child: _buildTextField(
                label: 'Prénom *',
                controller: _firstNameController,
                hint: 'Jean',
                textPrimary: textPrimary,
                textHint: textHint,
                inputFill: inputFill,
                inputBorder: inputBorder)),
        const SizedBox(width: 12),
        Expanded(
            child: _buildTextField(
                label: 'Nom *',
                controller: _lastNameController,
                hint: 'Martin',
                textPrimary: textPrimary,
                textHint: textHint,
                inputFill: inputFill,
                inputBorder: inputBorder)),
      ]),
      const SizedBox(height: 16),
      _buildTextField(
          label: 'E-mail *',
          controller: _emailController,
          hint: 'patient@exemple.fr',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          textPrimary: textPrimary,
          textHint: textHint,
          inputFill: inputFill,
          inputBorder: inputBorder),
      const SizedBox(height: 16),
      Text('Téléphone *',
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
      const SizedBox(height: 8),
      Row(children: [
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
                color: inputFill,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    bottomLeft: Radius.circular(10)),
                border: Border.all(color: inputBorder)),
            child: const Text('+216',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
        Expanded(
            child: TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 8,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                    hintText: 'XX XXX XXX',
                    hintStyle: TextStyle(color: textHint, fontSize: 14),
                    prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                    filled: true,
                    fillColor: inputFill,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                        borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(10),
                            bottomRight: Radius.circular(10)),
                        borderSide: BorderSide(color: inputBorder)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(10),
                            bottomRight: Radius.circular(10)),
                        borderSide: BorderSide(color: inputBorder)),
                    focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.only(
                            topRight: Radius.circular(10),
                            bottomRight: Radius.circular(10)),
                        borderSide: BorderSide(
                            color: Color(0xFF1A47C0), width: 1.5)),
                    errorBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.only(
                            topRight: Radius.circular(10),
                            bottomRight: Radius.circular(10)),
                        borderSide: BorderSide(color: Color(0xFFE53935))),
                    counterText: ''),
                validator: _validatePhone,
                onChanged: (value) {
                  final cleanValue = value.replaceAll(RegExp(r'[\s-]'), '');
                  if (cleanValue.length > 8) {
                    _phoneController.text = cleanValue.substring(0, 8);
                    _phoneController.selection =
                        TextSelection.fromPosition(const TextPosition(offset: 8));
                  }
                })),
      ]),
      const SizedBox(height: 16),
      _buildTextField(
          label: 'Date de naissance *',
          controller: _dobController,
          hint: 'jj/mm/aaaa',
          icon: Icons.calendar_today_outlined,
          suffixIcon: IconButton(
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              onPressed: _showDatePickerDialog),
          readOnly: true,
          textPrimary: textPrimary,
          textHint: textHint,
          inputFill: inputFill,
          inputBorder: inputBorder),
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
                  size: 18),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword)),
          textPrimary: textPrimary,
          textHint: textHint,
          inputFill: inputFill,
          inputBorder: inputBorder),
      const SizedBox(height: 8),
      Text(
          'Doit contenir : minuscule, majuscule, chiffre et symbole (!@#\$%^&*)',
          style: TextStyle(
              fontSize: 11, color: textSecondary, fontStyle: FontStyle.italic)),
      const SizedBox(height: 8),
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
                  size: 18),
              onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword)),
          textPrimary: textPrimary,
          textHint: textHint,
          inputFill: inputFill,
          inputBorder: inputBorder),
      const SizedBox(height: 24),
      SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
              onPressed: _isLoading ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeHelper.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
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
                          Icon(Icons.arrow_forward, size: 18)
                        ]))),
    ]));
  }

  // ── Étape 2 — AVEC DROPDOWN CARDIOLOGUE ──
  Widget _buildStep2InsideCard(Color surface, Color border, Color textPrimary,
      Color textSecondary, Color textHint, Color inputFill, Color inputBorder) {
    return SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildBackButton(textPrimary), const SizedBox(height: 8),
      Text('Dossier médical',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary)),
      const SizedBox(height: 4),
      Text('Informations pour votre suivi personnalisé',
          style: TextStyle(fontSize: 13, color: textSecondary)),
      const SizedBox(height: 20),

      // Groupe sanguin
      _buildDropdownField(
          label: 'Groupe sanguin',
          value: _bloodType,
          hint: 'Sélectionner...',
          items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
          onChanged: (v) => setState(() => _bloodType = v),
          icon: Icons.bloodtype_outlined,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          textHint: textHint,
          inputFill: inputFill,
          inputBorder: inputBorder),
      const SizedBox(height: 16),

      // Pathologie cardiaque
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
          icon: Icons.favorite_outline,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          textHint: textHint,
          inputFill: inputFill,
          inputBorder: inputBorder),
      const SizedBox(height: 16),

      // ✅ NOUVEAU : Dropdown Cardiologue
      // ✅ NOUVEAU : Dropdown Cardiologue (CORRIGÉ)
      Text('Mon cardiologue',
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
      const SizedBox(height: 8),
      _isLoadingCardiologists
          ? Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                  color: inputFill,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: inputBorder)),
              child: Row(children: [
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Text('Chargement...', style: TextStyle(color: textSecondary))
              ]))
          : _cardiologists.isEmpty
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                      color: inputFill,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: inputBorder)),
                  child: Text('Aucun cardiologue disponible',
                      style: TextStyle(color: textSecondary, fontSize: 13)))
              : StatefulBuilder(
                  // ✅ StatefulBuilder pour mise à jour immédiate indépendante
                  builder: (context, setLocalState) {
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                                color: inputFill,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: _selectedCardiologistLabel != null
                                        ? const Color(0xFF1A47C0)
                                        : inputBorder,
                                    width: _selectedCardiologistLabel != null
                                        ? 1.5
                                        : 1.0)),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedCardiologistLabel != null &&
                                        _cardiologists.any((c) =>
                                            c['label'] ==
                                            _selectedCardiologistLabel)
                                    ? _selectedCardiologistLabel
                                    : null,
                                hint: Row(children: [
                                  Icon(Icons.medical_services_outlined,
                                      size: 18, color: textHint),
                                  const SizedBox(width: 8),
                                  Text('Sélectionner...',
                                      style: TextStyle(
                                          color: textHint, fontSize: 13)),
                                ]),
                                isExpanded: true,
                                icon: Icon(Icons.arrow_drop_down,
                                    color: textSecondary),
                                dropdownColor: inputFill,
                                // ✅ Items sans Row+Icon pour éviter l'overflow
                                items: _cardiologists.map((c) {
                                  return DropdownMenuItem<String>(
                                    value: c['label'] as String,
                                    child: Text(
                                      c['label'] as String,
                                      style: TextStyle(
                                          color: textPrimary, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? value) {
                                  if (value == null) return;
                                  // ✅ Double setState : local + global
                                  setLocalState(() {
                                    _selectedCardiologistLabel = value;
                                  });
                                  setState(() {
                                    _selectedCardiologistLabel = value;
                                    final selected = _cardiologists.firstWhere(
                                        (c) => c['label'] == value,
                                        orElse: () => <String, dynamic>{});
                                    _selectedCardiologistId =
                                        selected.isNotEmpty
                                            ? selected['id'] as String
                                            : null;
                                  });
                                },
                              ),
                            )),
                        // ✅ Confirmation visible immédiatement
                        if (_selectedCardiologistLabel != null) ...[
                          const SizedBox(height: 6),
                          Row(children: [
                            const Icon(Icons.check_circle,
                                size: 14, color: Colors.green),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text(
                              _selectedCardiologistLabel!,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            )),
                          ]),
                        ] else ...[
                          const SizedBox(height: 4),
                          Text('Optionnel — Vous pourrez changer plus tard',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: textSecondary,
                                  fontStyle: FontStyle.italic)),
                        ],
                      ]);
                }),

      const SizedBox(height: 16),

      // Poids / Taille
      Row(children: [
        Expanded(
            child: _buildTextField(
                label: 'Poids (kg)',
                controller: _weightController,
                hint: '70',
                keyboardType: TextInputType.number,
                textPrimary: textPrimary,
                textHint: textHint,
                inputFill: inputFill,
                inputBorder: inputBorder)),
        const SizedBox(width: 12),
        Expanded(
            child: _buildTextField(
                label: 'Taille (cm)',
                controller: _heightController,
                hint: '170',
                keyboardType: TextInputType.number,
                textPrimary: textPrimary,
                textHint: textHint,
                inputFill: inputFill,
                inputBorder: inputBorder)),
      ]),
      const SizedBox(height: 16),

      // Antécédents médicaux
      _buildTextField(
          label: 'Antécédents médicaux',
          controller: _medicalHistoryController,
          hint: 'Ex: IDM 2019...',
          maxLines: 2,
          textPrimary: textPrimary,
          textHint: textHint,
          inputFill: inputFill,
          inputBorder: inputBorder),
      const SizedBox(height: 16),

      // Allergies
      _buildTextField(
          label: 'Allergies',
          controller: _allergiesController,
          hint: 'Ex: Pénicilline...',
          maxLines: 2,
          textPrimary: textPrimary,
          textHint: textHint,
          inputFill: inputFill,
          inputBorder: inputBorder),
      const SizedBox(height: 24),

      // Bouton Suivant
      SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeHelper.primary,
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
                  ]))),
    ]));
  }

  // ── Étape 3 ──
  Widget _buildStep3InsideCard(
      Color surface, Color border, Color textPrimary, Color textSecondary) {
    return SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildBackButton(textPrimary),
      const SizedBox(height: 8),
      Text('Antécédents cardiaques',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary)),
      const SizedBox(height: 4),
      Text('Répondez par Oui ou Non',
          style: TextStyle(fontSize: 13, color: textSecondary)),
      const SizedBox(height: 20),
      _buildQuestion(
          number: 1,
          question: 'Avez-vous déjà eu un infarctus ?',
          value: _hadInfarctus,
          onChanged: (v) => setState(() => _hadInfarctus = v),
          textPrimary: textPrimary,
          textSecondary: textSecondary),
      const SizedBox(height: 16),
      _buildQuestion(
          number: 2,
          question: 'Trouble du rythme cardiaque ?',
          value: _hadRhythmDisorder,
          onChanged: (v) => setState(() => _hadRhythmDisorder = v),
          textPrimary: textPrimary,
          textSecondary: textSecondary),
      const SizedBox(height: 16),
      _buildQuestion(
          number: 3,
          question: 'Hospitalisation cardiaque ?',
          value: _hadHospitalization,
          onChanged: (v) => setState(() => _hadHospitalization = v),
          textPrimary: textPrimary,
          textSecondary: textSecondary),
      const SizedBox(height: 24),
      SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                  backgroundColor: ThemeHelper.primary,
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
                  ]))),
    ]));
  }

  // ── Étape 4 ──
  Widget _buildStep4InsideCard(
      Color surface, Color border, Color textPrimary, Color textSecondary) {
    return SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildBackButton(textPrimary),
      const SizedBox(height: 8),
      Text('Consentement',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary)),
      const SizedBox(height: 4),
      Text('Lisez et acceptez les conditions',
          style: TextStyle(fontSize: 13, color: textSecondary)),
      const SizedBox(height: 20),
      _buildConsentCheckbox(
          title: 'Traitement des données *',
          description: "J'autorise CAREDIFY à collecter mes données de santé.",
          value: _consentDataTreatment,
          onChanged: (v) => setState(() => _consentDataTreatment = v!),
          obligatory: true,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          surface: surface,
          border: border),
      const SizedBox(height: 12),
      _buildConsentCheckbox(
          title: 'Partage cardiologue *',
          description: "J'autorise la transmission à mon cardiologue.",
          value: _consentShareCardiologist,
          onChanged: (v) => setState(() => _consentShareCardiologist = v!),
          obligatory: true,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          surface: surface,
          border: border),
      const SizedBox(height: 12),
      _buildConsentCheckbox(
          title: 'Recherche (optionnel)',
          description: "J'accepte l'utilisation anonymisée pour la recherche.",
          value: _consentResearch,
          onChanged: (v) => setState(() => _consentResearch = v!),
          obligatory: false,
          textPrimary: textPrimary,
          textSecondary: textSecondary,
          surface: surface,
          border: border),
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
                          ? ThemeHelper.primary
                          : Colors.grey[400],
                  foregroundColor:
                      (_consentDataTreatment && _consentShareCardiologist)
                          ? Colors.white
                          : Colors.white70,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.person_add_outlined,
                          size: 20,
                          color: (_consentDataTreatment &&
                                  _consentShareCardiologist)
                              ? Colors.white
                              : Colors.white70),
                      const SizedBox(width: 8),
                      Text('Créer mon compte',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: (_consentDataTreatment &&
                                      _consentShareCardiologist)
                                  ? Colors.white
                                  : Colors.white70))
                    ]))),
      if (!(_consentDataTreatment && _consentShareCardiologist))
        const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text('⚠️ Veuillez accepter les 2 consentements obligatoires',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange,
                    fontWeight: FontWeight.w500),
                textAlign: TextAlign.center)),
    ]));
  }

  // ── Helpers ──
  Widget _buildTextField(
      {required String label,
      required TextEditingController controller,
      required String hint,
      IconData? icon,
      Widget? suffixIcon,
      bool obscureText = false,
      TextInputType? keyboardType,
      int maxLines = 1,
      bool readOnly = false,
      required Color textPrimary,
      required Color textHint,
      required Color inputFill,
      required Color inputBorder}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
      const SizedBox(height: 8),
      TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLines: maxLines,
          readOnly: readOnly,
          style: TextStyle(color: textPrimary),
          decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: textHint, fontSize: 13),
              prefixIcon:
                  icon != null ? Icon(icon, size: 18, color: textHint) : null,
              suffixIcon: suffixIcon,
              filled: true,
              fillColor: inputFill,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: inputBorder)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: inputBorder)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFF1A47C0), width: 1.5)))),
    ]);
  }

  Widget _buildDropdownField(
      {required String label,
      required String? value,
      required String hint,
      required List<String> items,
      required ValueChanged<String?> onChanged,
      IconData? icon,
      required Color textPrimary,
      required Color textSecondary,
      required Color textHint,
      required Color inputFill,
      required Color inputBorder}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
            color: inputFill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: inputBorder)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            hint: Row(children: [
              if (icon != null) Icon(icon, size: 18, color: textHint),
              if (icon != null) const SizedBox(width: 8),
              Text(hint, style: TextStyle(color: textHint, fontSize: 13))
            ]),
            isExpanded: true,
            icon: Icon(Icons.arrow_drop_down, color: textSecondary),
            items: items
                .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(item, style: TextStyle(color: textPrimary))))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    ]);
  }

  Widget _buildQuestion(
      {required int number,
      required String question,
      required bool? value,
      required ValueChanged<bool?> onChanged,
      required Color textPrimary,
      required Color textSecondary}) {
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
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary)))
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
                            ? ThemeHelper.primary
                            : ThemeHelper.getColor(context, Colors.grey[100]!,
                                AppColors.darkSurfaceVariant),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: value == true
                                ? ThemeHelper.primary
                                : ThemeHelper.border(context))),
                    child: Center(
                        child: Text('Oui',
                            style: TextStyle(
                                color:
                                    value == true ? Colors.white : textPrimary,
                                fontWeight: FontWeight.w600)))))),
        const SizedBox(width: 10),
        Expanded(
            child: GestureDetector(
                onTap: () => onChanged(false),
                child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                        color: value == false
                            ? Colors.grey
                            : ThemeHelper.getColor(context, Colors.grey[100]!,
                                AppColors.darkSurfaceVariant),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: value == false
                                ? Colors.grey
                                : ThemeHelper.border(context))),
                    child: Center(
                        child: Text('Non',
                            style: TextStyle(
                                color:
                                    value == false ? Colors.white : textPrimary,
                                fontWeight: FontWeight.w600)))))),
      ]),
    ]);
  }

  Widget _buildConsentCheckbox(
      {required String title,
      required String description,
      required bool value,
      required ValueChanged<bool?> onChanged,
      required bool obligatory,
      required Color textPrimary,
      required Color textSecondary,
      required Color surface,
      required Color border}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: ThemeHelper.getColor(
              context, Colors.grey[50]!, AppColors.darkSurfaceVariant),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Transform.scale(
              scale: 1.1,
              child: Checkbox(
                  value: value,
                  onChanged: onChanged,
                  activeColor: ThemeHelper.primary)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textPrimary)))
        ]),
        const SizedBox(height: 4),
        Text(description,
            style: TextStyle(fontSize: 12, color: textSecondary, height: 1.4)),
        if (obligatory) ...[
          const SizedBox(height: 4),
          const Text('Obligatoire',
              style: TextStyle(
                  fontSize: 11, color: Colors.red, fontWeight: FontWeight.w500))
        ],
      ]),
    );
  }
}
