import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _locale = const Locale('ko', 'KR');
  
  Locale get locale => _locale;
  
  bool get isKorean => _locale.languageCode == 'ko';
  bool get isEnglish => _locale.languageCode == 'en';
  
  LanguageProvider() {
    _loadLanguage();
  }
  
  void toggleLanguage() {
    if (_locale.languageCode == 'ko') {
      setLanguage(const Locale('en', 'US'));
    } else {
      setLanguage(const Locale('ko', 'KR'));
    }
  }
  
  void setLanguage(Locale locale) {
    _locale = locale;
    _saveLanguage(locale.languageCode);
    notifyListeners();
  }
  
  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code') ?? 'ko';
    if (languageCode == 'en') {
      _locale = const Locale('en', 'US');
    } else {
      _locale = const Locale('ko', 'KR');
    }
    notifyListeners();
  }
  
  Future<void> _saveLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);
  }
}