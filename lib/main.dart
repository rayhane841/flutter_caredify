import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

// ✅ Providers
import 'providers/app_provider.dart';
import 'providers/theme_provider.dart';

// ✅ Thème & Utils
import 'theme/app_theme.dart';
import 'utils/theme_helper.dart';

// ✅ Screens
import 'screens/splash_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/ecg_screen.dart';
import 'screens/emergency_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/map_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/results_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/auth/sign_in_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://sjwehettourojokbuahr.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNqd2VoZXR0b3Vyb2pva2J1YWhyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU2NTcwNDksImV4cCI6MjA5MTIzMzA0OX0.VPEcRhTf_FwRVuYbP0uNA3pEe-VAPS-2DxQGyP9h5Sc',
  );

  await initializeDateFormatting('fr_FR', null);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const CaredifyApp());
}

// ═══════════════════════════════════════════════════════════
// WIDGET RACINE
// ═══════════════════════════════════════════════════════════
class CaredifyApp extends StatelessWidget {
  const CaredifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'CAREDIFY',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const SplashScreen(),
            routes: {
              '/results': (_) => const ResultsScreen(),
              '/history': (_) => const HistoryScreen(),
              '/settings': (_) => const SettingsScreen(),
              '/signin': (_) => const SignInScreen(),
            },
            builder: (context, child) {
              final brightness = Theme.of(context).brightness;
              SystemChrome.setSystemUIOverlayStyle(
                SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: brightness == Brightness.dark
                      ? Brightness.light
                      : Brightness.dark,
                  statusBarBrightness: brightness,
                  systemNavigationBarColor: brightness == Brightness.dark
                      ? AppColors.darkBackground
                      : AppColors.background,
                  systemNavigationBarIconBrightness:
                      brightness == Brightness.dark
                          ? Brightness.light
                          : Brightness.dark,
                ),
              );
              return child!;
            },
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SHELL PRINCIPAL — Navigation par onglets avec protection retour
// ═══════════════════════════════════════════════════════════
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final app = Provider.of<AppProvider>(context, listen: false);

      // ✅ Callback navigation vers Dashboard
      app.onNavigateToTab = () {
        if (mounted) setState(() => _currentIndex = 0);
      };

      // ✅ Écoute Supabase real-time pour confirmation cardiologue
      _listenToCardiologistConfirmation(app);
    });
  }

  /// Écoute les alertes confirmées par le cardiologue depuis Supabase
  void _listenToCardiologistConfirmation(AppProvider app) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    Supabase.instance.client
        .from('alerts')
        .stream(primaryKey: ['id'])
        .eq('patient_id', userId)
        .listen((data) {
          if (!mounted) return;
          if (data.isEmpty) return;

          for (final alert in data) {
            final status = alert['status'] as String?;
            if (status == 'confirmed') {
              app.onCardiologistConfirmed();
              if (mounted) setState(() => _currentIndex = 2);
              break;
            } else if (status == 'dismissed') {
              app.onCardiologistDismissed();
              break;
            }
          }
        });
  }

  @override
  void dispose() {
    if (mounted) {
      final app = Provider.of<AppProvider>(context, listen: false);
      app.onNavigateToTab = null;
    }
    super.dispose();
  }

  // ✅ Écrans
  List<Widget> get _screens => [
        const DashboardScreen(),    // 0
        const EcgScreen(),          // 1
        const MessagesScreen(),     // 2
        const MapScreen(),          // 3
        const ProfileScreen(),      // 4
      ];

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, app, _) {
        final surface = ThemeHelper.surface(context);
        final border = ThemeHelper.border(context);
        final textPri = ThemeHelper.textPrimary(context);
        final textSec = ThemeHelper.textSecondary(context);
        final primary = ThemeHelper.primary;
        final emergency = ThemeHelper.emergency(context);
        final criticalLight = ThemeHelper.getColor(
          context,
          AppColors.criticalLight,
          AppColors.darkSurfaceVariant,
        );

        final showEmergencyOverlay =
            app.emergencyState == EmergencyState.confirmed &&
                app.cardiologistConfirmed;

        return Stack(
          children: [
            // ── App principale avec protection retour (WillPopScope) ─────────
            WillPopScope(
              onWillPop: () async {
                // ✅ Empêcher le retour arrière vers SignIn
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Utilisez le bouton Déconnexion dans Profil pour quitter'),
                    duration: Duration(seconds: 2),
                  ),
                );
                return false; // ← Bloque le retour arrière
              },
              child: Scaffold(
                body: IndexedStack(
                  index: _currentIndex,
                  children: _screens,
                ),
                bottomNavigationBar: _buildNavBar(
                  app: app,
                  surface: surface,
                  border: border,
                  textPri: textPri,
                  textSec: textSec,
                  primary: primary,
                  emergency: emergency,
                  criticalLight: criticalLight,
                ),
              ),
            ),

            // ── Overlay Emergency si cardiologue confirme ──
            if (showEmergencyOverlay)
              const EmergencyScreen(showBackButton: true),
          ],
        );
      },
    );
  }

  Widget _buildNavBar({
    required AppProvider app,
    required Color surface,
    required Color border,
    required Color textPri,
    required Color textSec,
    required Color primary,
    required Color emergency,
    required Color criticalLight,
  }) {
    final hasAlert = app.emergencyState != EmergencyState.none;
    final hasUnreadMessages = app.aiAlertPending;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Accueil',
                selected: _currentIndex == 0,
                onTap: () => setState(() => _currentIndex = 0),
                textPrimary: textPri,
                textSecondary: textSec,
                primary: primary,
              ),
              _NavItem(
                icon: Icons.show_chart_rounded,
                label: 'ECG',
                selected: _currentIndex == 1,
                onTap: () => setState(() => _currentIndex = 1),
                textPrimary: textPri,
                textSecondary: textSec,
                primary: primary,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _currentIndex = 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: hasAlert
                                  ? emergency
                                  : _currentIndex == 2
                                      ? primary
                                      : criticalLight,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (hasAlert ? emergency : primary)
                                      .withOpacity(0.35),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              hasAlert
                                  ? Icons.emergency_rounded
                                  : Icons.message_rounded,
                              size: 26,
                              color: _currentIndex == 2 || hasAlert
                                  ? Colors.white
                                  : primary,
                            ),
                          ),
                          if (hasUnreadMessages)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: emergency,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: surface,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              _NavItem(
                icon: Icons.map_rounded,
                label: 'Carte',
                selected: _currentIndex == 3,
                onTap: () => setState(() => _currentIndex = 3),
                textPrimary: textPri,
                textSecondary: textSec,
                primary: primary,
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: 'Profil',
                selected: _currentIndex == 4,
                onTap: () => setState(() => _currentIndex = 4),
                textPrimary: textPri,
                textSecondary: textSec,
                primary: primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// NAV ITEM
// ═══════════════════════════════════════════════════════════
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color textPrimary;
  final Color textSecondary;
  final Color primary;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.textPrimary,
    required this.textSecondary,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? ThemeHelper.getColor(
                        context,
                        AppColors.surfaceVariant,
                        AppColors.darkSurfaceVariant,
                      )
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Icon(
                icon,
                size: 24,
                color: selected ? primary : textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? primary : textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}