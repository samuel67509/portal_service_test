import 'package:flutter/material.dart';
import 'theme_manager.dart';

class ThemeProvider extends ChangeNotifier {
  final ThemeManager _themeManager = ThemeManager();
  
  // Getters that match what your LoginScreen expects
  ThemeData get currentTheme => _themeManager.themeData;
  ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      // Customize dark theme as needed
      
    );
  }
  bool get isDarkMode => _themeManager.currentTheme == ThemeManager.DARK_THEME;
  
  // Additional getters for the MaterialApp
  ThemeMode get themeMode {
    return isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }
  
  List<String> get availableThemes => _themeManager.availableThemes;
  String get currentThemeName => _themeManager.currentTheme;
  
  // Methods
  void setTheme(String themeName) {
    _themeManager.setTheme(themeName);
    notifyListeners();
  }
  
  void toggleDarkMode() {
    _themeManager.toggleDarkMode();
    notifyListeners();
  }
  
  ThemeData getThemeForRole(String role) {
    return _themeManager.getThemeForRole(role);
  }
}