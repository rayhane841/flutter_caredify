import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'theme/app_theme.dart';
import 'providers/app_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/ecg_screen.dart';
import 'screens/emergency_screen.dart';
import 'screens/map_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/results_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/auth/sign_in_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ INITIALISATION SUPABASE
  await Supabase.initialize(
    url: 'https://sjwehettourojokbuahr.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNqd2VoZXR0b3Vyb2pva2J1YWhyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU2NTcwNDksImV4cCI6MjA5MTIzMzA0OX0.VPEcRhTf_FwRVuYbP0uNA3pEe-VAPS-2DxQGyP9h5Sc',
  );

  await initializeDateFormatting('fr_FR', null);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const CaredifyApp());
}

class CaredifyApp extends StatelessWidget {
  const CaredifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: MaterialApp(
        title: 'CAREDIFY',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: const SplashScreen(),
        routes: {
          '/results': (_) => const ResultsScreen(),
          '/history': (_) => const HistoryScreen(),
          '/settings': (_) => const SettingsScreen(),
          '/signin': (_) => const SignInScreen(),
        },
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // ✅✅✅ AJOUT : initState pour connecter le callback de navigation ✅✅✅
  @override
  void initState() {
    super.initState();
    // Attendre que le widget soit monté pour accéder au Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final app = Provider.of<AppProvider>(context, listen: false);
      // ✅ Connecter le callback pour permettre le retour depuis EmergencyScreen
      app.onNavigateToTab = () {
        setState(() {
          _currentIndex = 0; // Retour au Dashboard (index 0)
        });
      };
    });
  }

  // ✅✅✅ AJOUT : dispose pour nettoyer le callback ✅✅✅
  @override
  void dispose() {
    // Nettoyer le callback pour éviter les fuites mémoire
    if (mounted) {
      final app = Provider.of<AppProvider>(context, listen: false);
      app.onNavigateToTab = null;
    }
    super.dispose();
  }

  // ✅✅✅ LISTE DES ÉCRANS - Simple, sans callback ✅✅✅
  List<Widget> get _screens => [
        const DashboardScreen(),
        const EcgScreen(),
        const EmergencyScreen(), // ← showBackButton = false (par défaut)
        const MapScreen(), // ← showBackButton = false (par défaut)
        const ProfileScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, app, _) {
        final isEmergencyActive = app.emergencyState != EmergencyState.none;
        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border:
                  Border(top: BorderSide(color: AppColors.border, width: 1)),
              boxShadow: [
                BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 12,
                    offset: Offset(0, -4)),
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
                    ),
                    _NavItem(
                      icon: Icons.show_chart_rounded,
                      label: 'ECG',
                      selected: _currentIndex == 1,
                      onTap: () => setState(() => _currentIndex = 1),
                    ),
                    // Emergency center button
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _currentIndex = 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: isEmergencyActive
                                    ? AppColors.emergency
                                    : _currentIndex == 2
                                        ? AppColors.emergency
                                        : AppColors.criticalLight,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        AppColors.emergency.withOpacity(0.35),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.emergency_rounded,
                                size: 26,
                                color: _currentIndex == 2 || isEmergencyActive
                                    ? Colors.white
                                    : AppColors.emergency,
                              ),
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
                    ),
                    _NavItem(
                      icon: Icons.person_rounded,
                      label: 'Profil',
                      selected: _currentIndex == 4,
                      onTap: () => setState(() => _currentIndex = 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
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
                color: selected ? AppColors.surfaceVariant : Colors.transparent,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Icon(
                icon,
                size: 24,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
