import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // ✅ AJOUTÉ : Pour Provider.of
import 'sign_up_screen.dart';
import '../../main.dart';
import '../../services/auth_service.dart';
import '../../providers/app_provider.dart'; // ✅ AJOUTÉ : Pour AppProvider

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ✅ VALIDATION EMAIL avec @ requis
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email requis';
    }
    if (!value.contains('@') || !value.contains('.')) {
      return 'Email invalide - doit contenir @ et .';
    }
    final parts = value.split('@');
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
      return 'Email invalide';
    }
    return null;
  }

  // ✅✅✅ MÉTHODE DE CONNEXION CORRIGÉE - Avec synchronisation AppProvider ✅✅✅
  void _signIn() async {
    print('🔹🔹🔹 _signIn() APPELÉE');

    // Validation locale de l'email
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

    if (!_formKey.currentState!.validate()) {
      print('❌ Formulaire invalide');
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('🔹 Appel de AuthService.signIn...');
      print('🔹 Email: ${_emailController.text}');

      // ✅ APPEL À AuthService.signIn()
      final result = await _authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      print('🔹 Résultat: $result');

      if (mounted) {
        if (result['success'] == true) {
          print('✅ Connexion réussie!');

          // ✅✅✅ AJOUT : Synchroniser AppProvider avec les données Supabase ✅✅✅
          final userId = _authService.currentUser?.id;
          if (userId != null) {
            print('🔹 Fetching patient data for userId: $userId');

            final userData = await _authService.getPatientData(userId);

            if (userData != null && mounted) {
              print('✅ Patient data fetched: ${userData['name']}');

              // ✅ Mettre à jour AppProvider pour synchroniser Dashboard
              Provider.of<AppProvider>(context, listen: false)
                  .updateProfileFromMap(userData);
            } else {
              print('⚠️ No patient data found for userId: $userId');
            }
          }

          // Message de succès
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Connexion réussie!'),
              backgroundColor: Colors.green,
            ),
          );

          // Redirection vers Dashboard
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainShell()),
          );
        } else {
          print('❌ Erreur: ${result['error']}');

          // Message d'erreur spécifique
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Erreur de connexion'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );

          setState(() => _isLoading = false);
        }
      }
    } catch (e, stackTrace) {
      print('💥 Exception: $e');
      print('📋 Stack: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
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
              const SizedBox(height: 48),
              Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.monitor_heart_rounded,
                      size: 38,
                      color: Color(0xFF1A47C0),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                    'Système de télésurveillance cardiaque',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 36),

              // White card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(28),
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      const Text(
                        'Bon retour',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0D1B2A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Connectez-vous pour continuer',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7A8D),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Email
                      const Text(
                        'E-mail',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0D1B2A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _inputDecoration(
                          hint: 'patient@exemple.fr',
                          icon: Icons.email_outlined,
                        ),
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 18),

                      // Password - ✅ Ajout validation longueur
                      const Text(
                        'Mot de passe',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0D1B2A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: _inputDecoration(
                          hint: '••••••••',
                          icon: Icons.lock_outline_rounded,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: const Color(0xFF6B7A8D),
                              size: 20,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Mot de passe requis';
                          }
                          if (v.length < 6) {
                            return 'Minimum 6 caractères';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Remember me + Forgot
                      Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: Checkbox(
                              value: _rememberMe,
                              onChanged: (v) =>
                                  setState(() => _rememberMe = v ?? false),
                              activeColor: const Color(0xFF1A47C0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Se souvenir de moi',
                              style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFF0D1B2A),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const Spacer(),
                          Flexible(
                            child: GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Fonctionnalité à implémenter'),
                                  ),
                                );
                              },
                              child: const Text(
                                'Mot de passe oublié ?',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A47C0),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // Sign In button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _signIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A47C0),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Se connecter',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Divider
                      const Row(
                        children: [
                          Expanded(child: Divider(color: Color(0xFFE0E0E0))),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Ou continuer avec',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7A8D),
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: Color(0xFFE0E0E0))),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Google button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Fonctionnalité à implémenter'),
                              ),
                            );
                          },
                          icon: const _GoogleLogo(),
                          label: const Text(
                            'Continuer avec Google',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0D1B2A),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFD6E0EE)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Sign up link
                      Center(
                        child: Column(
                          children: [
                            const Text(
                              'Vous n\'avez pas de compte ?',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7A8D),
                              ),
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const SignUpScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                'Créer un compte',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A47C0),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 14),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF9EADC0)),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF7F9FC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD6E0EE)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD6E0EE)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF1A47C0), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE53935)),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFE8EAED),
      ),
      child: const Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4285F4),
          ),
        ),
      ),
    );
  }
}
