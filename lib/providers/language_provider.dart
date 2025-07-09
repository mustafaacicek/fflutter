import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _languageKey = 'selected_language';
  
  // Desteklenen diller
  final List<Locale> supportedLocales = const [
    Locale('tr'), // Türkçe
    Locale('en'), // İngilizce
    Locale('es'), // İspanyolca
  ];
  
  // Varsayılan dil
  String _currentLanguage = 'tr'; // Varsayılan olarak Türkçe
  
  // Getter
  String get currentLanguage => _currentLanguage;
  
  // Dil değiştirme
  Future<void> changeLanguage(String languageCode) async {
    if (_currentLanguage != languageCode) {
      _currentLanguage = languageCode;
      
      // Dil tercihini kaydet
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, languageCode);
      
      // UI'ı güncelle
      notifyListeners();
    }
  }
  
  // Kaydedilmiş dil ayarını yükle
  Future<void> loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString(_languageKey);
    
    if (savedLanguage != null) {
      _currentLanguage = savedLanguage;
    } else {
      // Cihaz dilini al
      final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
      final deviceLanguage = deviceLocale.languageCode;
      
      // Desteklenen bir dil mi kontrol et
      if (supportedLocales.any((locale) => locale.languageCode == deviceLanguage)) {
        _currentLanguage = deviceLanguage;
      }
      // Desteklenmeyen dil ise varsayılan dil kullanılır (tr)
    }
    
    notifyListeners();
  }
}
