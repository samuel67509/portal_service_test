import 'package:flutter/material.dart';

class ThemeManager {
  static const String LIGHT_THEME = 'light';
  static const String DARK_THEME = 'dark';
  static const String BLUE_THEME = 'blue';
  static const String PURPLE_THEME = 'purple';
  static const String GREEN_THEME = 'green';

  String _currentTheme = LIGHT_THEME;
  
  
  static final ThemeManager _instance = ThemeManager._internal();
  factory ThemeManager() => _instance;
  ThemeManager._internal();
 Map<String, ThemeData> get themes => Map.from(_themes); 
  String get currentTheme => _currentTheme;
  
  final Map<String, ThemeData> _themes = {
    LIGHT_THEME: ThemeData(
      brightness: Brightness.light,
      primaryColor: Colors.deepPurple,
      colorScheme: ColorScheme.light(
        primary: Colors.deepPurple,
        secondary: Colors.orange,
        background: Colors.white,
        surface: Colors.white,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
      ),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      useMaterial3: true,
    ),
    
    DARK_THEME: ThemeData(
      brightness: Brightness.dark,
      primaryColor: Colors.deepPurple[300],
      colorScheme: ColorScheme.dark(
        primary: Colors.deepPurple[300]!,
        secondary: Colors.orange[300]!,
        background: Colors.grey[900]!,
        surface: Colors.grey[800]!,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
      ),
      scaffoldBackgroundColor: Colors.grey[900],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.grey[900],
        elevation: 2,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.grey[800],
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple[300],
          foregroundColor: Colors.black,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.grey[800],
      ),
      useMaterial3: true,
    ),
    
    BLUE_THEME: ThemeData(
      brightness: Brightness.light,
      primaryColor: Colors.blue[700],
      colorScheme: ColorScheme.light(
        primary: Colors.blue[700]!,
        secondary: Colors.teal[300]!,
        background: Colors.blue[50]!,
        surface: Colors.white,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
      ),
      scaffoldBackgroundColor: Colors.blue[50],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[700],
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      useMaterial3: true,
    ),
    
    PURPLE_THEME: ThemeData(
      brightness: Brightness.light,
      primaryColor: Colors.purple[800],
      colorScheme: ColorScheme.light(
        primary: Colors.purple[800]!,
        secondary: Colors.pink[300]!,
        background: Colors.purple[50]!,
        surface: Colors.white,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
      ),
      scaffoldBackgroundColor: Colors.purple[50],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.purple[800],
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple[800],
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      useMaterial3: true,
    ),
    
    GREEN_THEME: ThemeData(
      brightness: Brightness.light,
      primaryColor: Colors.green[700],
      colorScheme: ColorScheme.light(
        primary: Colors.green[700]!,
        secondary: Colors.lightGreen[300]!,
        background: Colors.green[50]!,
        surface: Colors.white,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
      ),
      scaffoldBackgroundColor: Colors.green[50],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      useMaterial3: true,
    ),
  };

  ThemeData get themeData => _themes[_currentTheme] ?? _themes[LIGHT_THEME]!;
  
  List<String> get availableThemes => _themes.keys.toList();

  
  void setTheme(String themeName) {
    if (_themes.containsKey(themeName)) {
      _currentTheme = themeName;
    }
  }
  
  void toggleDarkMode() {
    _currentTheme = _currentTheme == LIGHT_THEME ? DARK_THEME : LIGHT_THEME;
  }
  
  ThemeData getAdminTheme() {
    return _currentTheme == DARK_THEME 
      ? _themes[DARK_THEME]!.copyWith(
          primaryColor: Colors.purple[300],
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.grey[900],
            foregroundColor: Colors.white,
          ),
        )
      : _themes[PURPLE_THEME]!;
  }
  
  ThemeData getFrontDeskTheme() {
    return _currentTheme == DARK_THEME
      ? _themes[DARK_THEME]!.copyWith(
          primaryColor: Colors.blue[300],
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.grey[900],
            foregroundColor: Colors.white,
          ),
        )
      : _themes[BLUE_THEME]!;
  }
  
  ThemeData getElderTheme() {
    return _currentTheme == DARK_THEME
      ? _themes[DARK_THEME]!.copyWith(
          primaryColor: Colors.green[300],
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.grey[900],
            foregroundColor: Colors.white,
          ),
        )
      : _themes[GREEN_THEME]!;
  }
  
  ThemeData getThemeForRole(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return getAdminTheme();
      case 'frontdesk':
        return getFrontDeskTheme();
      case 'elder':
        return getElderTheme();
      default:
        return themeData;
    }
  }
  
}