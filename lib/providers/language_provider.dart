import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _currentLocale = const Locale('fr');

  Locale get currentLocale => _currentLocale;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final String? langCode = prefs.getString('app_language');
    if (langCode != null && (langCode == 'fr' || langCode == 'ar')) {
      _currentLocale = Locale(langCode);
    } else {
      _currentLocale = const Locale('fr');
    }
    notifyListeners();
  }

  Future<void> setLanguage(String langCode) async {
    if (langCode == 'fr' || langCode == 'ar') {
      _currentLocale = Locale(langCode);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_language', langCode);
      notifyListeners();
    }
  }
}
