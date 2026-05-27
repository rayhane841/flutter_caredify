import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'sign_up_screen.dart';
import '../../main.dart';
import '../../services/auth_service.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/theme_helper.dart';
import '../../l10n/app_localizations.dart';

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

  String? _validateEmail(String? value, AppLocalizations l10n) {
    if (value == null || value.isEmpty) return l10n.t('email_required');
    if (!value.contains('@') || !value.contains('.')) {
      return l10n.t('email_invalid');
    }
    final parts = value.split('@');
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
      return l10n.t('email_invalid');
    }
    return null;
  }

  Future<void> _signIn() async {
    final l10n = AppLocalizations.of(context);
    if (!_emailController.text.contains('@') ||
        !_emailController.text.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.t('email_invalid')),
          backgroundColor: Colors.red));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final appProvider = Provider.of<AppProvider>(context, listen: false);

    setState(() => _isLoading = true);

    try {
      final result = await _authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final userId = _authService.currentUser?.id;
        if (userId != null) {
          final userData = await _authService.getPatientData(userId);
          if (!mounted) return;
          if (userData != null) {
            appProvider.updateProfileFromMap(userData);
          }
        }

        await appProvider.initializeAfterAuth();
        if (!mounted) return;

        navigator.pushReplacement(
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
        messenger.showSnackBar(SnackBar(
            content: Text(result['error'] ?? l10n.t('login_error')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5)));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      messenger.showSnackBar(
          SnackBar(content: Text('${l10n.t('error_prefix')}$e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
            const SizedBox(height: 48),
            Column(children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.monitor_heart_rounded,
                    size: 38, color: Color(0xFF1A47C0)),
              ),
              const SizedBox(height: 16),
              const Text('CAREDIFY',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2.5)),
              const SizedBox(height: 4),
              Text(l10n.t('cardiac_telesurveillance_system'),
                  style: const TextStyle(fontSize: 13, color: Colors.white70)),
            ]),
            const SizedBox(height: 36),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 10))
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.t('hello'),
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(l10n.t('login_to_continue'),
                        style: TextStyle(fontSize: 13, color: textSecondary)),
                    const SizedBox(height: 24),

                    // Email
                    Text(l10n.t('email'),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textPrimary)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: textPrimary),
                      decoration: _inputDecoration(
                          hint: 'patient@exemple.fr',
                          icon: Icons.email_outlined,
                          textHint: textHint,
                          inputFill: inputFill,
                          inputBorder: inputBorder),
                      validator: (v) => _validateEmail(v, l10n),
                    ),
                    const SizedBox(height: 18),

                    // Mot de passe
                    Text(l10n.t('password'),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: textPrimary)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: TextStyle(color: textPrimary),
                      decoration: _inputDecoration(
                        hint: '••••••••',
                        icon: Icons.lock_outline_rounded,
                        textHint: textHint,
                        inputFill: inputFill,
                        inputBorder: inputBorder,
                        suffixIcon: IconButton(
                          icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: textSecondary,
                              size: 20),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return l10n.t('password_required');
                        }
                        if (v.length < 6) return l10n.t('password_min_length');
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Remember me + Forgot password
                    Row(children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: _rememberMe,
                          onChanged: (v) =>
                              setState(() => _rememberMe = v ?? false),
                          activeColor: ThemeHelper.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(l10n.t('remember_me'),
                              style: TextStyle(fontSize: 9, color: textPrimary),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1)),
                      const Spacer(),
                      Flexible(
                        child: GestureDetector(
                          onTap: () => ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(
                                  content:
                                      Text(l10n.t('feature_to_implement')))),
                          child: Text(l10n.t('forgot_password'),
                              style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A47C0)),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              textAlign: TextAlign.end),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 22),

                    // Bouton connexion
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeHelper.primary,
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
                            : Text(l10n.t('sign_in'),
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Divider
                    Row(children: [
                      Expanded(child: Divider(color: border)),
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(l10n.t('or_continue_with'),
                              style: TextStyle(
                                  fontSize: 12, color: textSecondary))),
                      Expanded(child: Divider(color: border)),
                    ]),
                    const SizedBox(height: 16),

                    // Google
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(
                                content: Text(l10n.t('feature_to_implement')))),
                        icon: const _GoogleLogo(),
                        label: Text(l10n.t('continue_with_google'),
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textPrimary)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: inputBorder),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Lien inscription
                    Center(
                      child: Column(children: [
                        Text(l10n.t('dont_have_account'),
                            style:
                                TextStyle(fontSize: 13, color: textSecondary)),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const SignUpScreen())),
                          child: Text(l10n.t('create_account'),
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A47C0))),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ]),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required Color textHint,
    required Color inputFill,
    required Color inputBorder,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: textHint, fontSize: 14),
      prefixIcon: Icon(icon, size: 18, color: textHint),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: inputBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: inputBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1A47C0), width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE53935))),
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
      decoration:
          const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE8EAED)),
      child: const Center(
          child: Text('G',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4285F4)))),
    );
  }
}
