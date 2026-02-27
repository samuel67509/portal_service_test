import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferenceHelper {
  // User information keys
  static const String _userIdKey = "USER_ID";
  static const String _userFirstNameKey = "USER_FIRST_NAME";
  static const String _userLastNameKey = "USER_LAST_NAME";
  static const String _userFullNameKey = "USER_FULL_NAME";
  static const String _userEmailKey = "USER_EMAIL";
  static const String _userPhoneKey = "USER_PHONE";
  static const String _userProfilePicKey = "USER_PROFILE_PIC";
  
  // Church information keys
  static const String _churchIdKey = "CHURCH_ID";
  static const String _churchNameKey = "CHURCH_NAME";
  static const String _churchAddressKey = "CHURCH_ADDRESS";
  static const String _churchPhoneKey = "CHURCH_PHONE";
  static const String _churchEmailKey = "CHURCH_EMAIL";
  
  // User role and permissions
  static const String _userRoleKey = "USER_ROLE";
  static const String _userPermissionsKey = "USER_PERMISSIONS";
  static const String _isAdminKey = "IS_ADMIN";
  
  // App preferences
  static const String _themeModeKey = "THEME_MODE";
  static const String _notificationsEnabledKey = "NOTIFICATIONS_ENABLED";
  static const String _lastLoginKey = "LAST_LOGIN";
  static const String _firstLaunchKey = "FIRST_LAUNCH";
  
  // Login credentials (use with caution - consider security implications)
  static const String _rememberMeKey = "REMEMBER_ME";
  static const String _savedEmailKey = "SAVED_EMAIL";
  static const String _savedPasswordKey = "SAVED_PASSWORD";
  
  // ============ USER METHODS ============
  
  /// Save complete user data
  Future<bool> saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    
    try {
      // Basic user info
      if (userData['id'] != null) {
        await prefs.setString(_userIdKey, userData['id']);
      }
      if (userData['firstName'] != null) {
        await prefs.setString(_userFirstNameKey, userData['firstName']);
      }
      if (userData['lastName'] != null) {
        await prefs.setString(_userLastNameKey, userData['lastName']);
      }
      if (userData['fullName'] != null) {
        await prefs.setString(_userFullNameKey, userData['fullName']);
      }
      if (userData['email'] != null) {
        await prefs.setString(_userEmailKey, userData['email']);
      }
      if (userData['phone'] != null) {
        await prefs.setString(_userPhoneKey, userData['phone']);
      }
      if (userData['profilePic'] != null) {
        await prefs.setString(_userProfilePicKey, userData['profilePic']);
      }
      
      // Role and permissions
      if (userData['role'] != null) {
        await prefs.setString(_userRoleKey, userData['role']);
      }
      if (userData['isAdmin'] != null) {
        await prefs.setBool(_isAdminKey, userData['isAdmin']);
      }
      if (userData['permissions'] != null) {
        final permissions = List<String>.from(userData['permissions']);
        await prefs.setStringList(_userPermissionsKey, permissions);
      }
      
      // Church info
      if (userData['churchId'] != null) {
        await prefs.setString(_churchIdKey, userData['churchId']);
      }
      if (userData['churchName'] != null) {
        await prefs.setString(_churchNameKey, userData['churchName']);
      }
      
      return true;
    } catch (e) {
      print('Error saving user data: $e');
      return false;
    }
  }
  
  /// Get complete user data
  Future<Map<String, dynamic>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    
    return {
      'id': prefs.getString(_userIdKey),
      'firstName': prefs.getString(_userFirstNameKey),
      'lastName': prefs.getString(_userLastNameKey),
      'fullName': prefs.getString(_userFullNameKey),
      'email': prefs.getString(_userEmailKey),
      'phone': prefs.getString(_userPhoneKey),
      'profilePic': prefs.getString(_userProfilePicKey),
      'role': prefs.getString(_userRoleKey),
      'isAdmin': prefs.getBool(_isAdminKey) ?? false,
      'permissions': prefs.getStringList(_userPermissionsKey) ?? [],
      'churchId': prefs.getString(_churchIdKey),
      'churchName': prefs.getString(_churchNameKey),
    };
  }
  
  // ============ CHURCH METHODS ============
  
  /// Save church data
  Future<bool> saveChurchData(Map<String, dynamic> churchData) async {
    final prefs = await SharedPreferences.getInstance();
    
    try {
      if (churchData['id'] != null) {
        await prefs.setString(_churchIdKey, churchData['id']);
      }
      if (churchData['name'] != null) {
        await prefs.setString(_churchNameKey, churchData['name']);
      }
      if (churchData['address'] != null) {
        await prefs.setString(_churchAddressKey, churchData['address']);
      }
      if (churchData['phone'] != null) {
        await prefs.setString(_churchPhoneKey, churchData['phone']);
      }
      if (churchData['email'] != null) {
        await prefs.setString(_churchEmailKey, churchData['email']);
      }
      
      return true;
    } catch (e) {
      print('Error saving church data: $e');
      return false;
    }
  }
  
  /// Get church data
  Future<Map<String, dynamic>> getChurchData() async {
    final prefs = await SharedPreferences.getInstance();
    
    return {
      'id': prefs.getString(_churchIdKey),
      'name': prefs.getString(_churchNameKey),
      'address': prefs.getString(_churchAddressKey),
      'phone': prefs.getString(_churchPhoneKey),
      'email': prefs.getString(_churchEmailKey),
    };
  }
  
  // ============ APP PREFERENCES ============
  
  /// Save theme preference
  Future<bool> saveThemeMode(String themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_themeModeKey, themeMode);
  }
  
  /// Get theme preference
  Future<String?> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeModeKey);
  }
  
  /// Save notifications preference
  Future<bool> saveNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setBool(_notificationsEnabledKey, enabled);
  }
  
  /// Get notifications preference
  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabledKey) ?? true;
  }
  
  /// Save last login timestamp
  Future<bool> saveLastLogin(DateTime dateTime) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(_lastLoginKey, dateTime.toIso8601String());
  }
  
  /// Get last login timestamp
  Future<DateTime?> getLastLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final dateString = prefs.getString(_lastLoginKey);
    if (dateString != null) {
      try {
        return DateTime.parse(dateString);
      } catch (e) {
        return null;
      }
    }
    return null;
  }
  
  /// Check if first launch
  Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_firstLaunchKey) ?? true;
  }
  
  /// Mark first launch as completed
  Future<bool> markFirstLaunchCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setBool(_firstLaunchKey, false);
  }
  
  // ============ LOGIN CREDENTIALS ============
  
  /// Save remember me credentials (use with caution)
  Future<bool> saveRememberMeCredentials({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (rememberMe) {
      await prefs.setBool(_rememberMeKey, true);
      await prefs.setString(_savedEmailKey, email);
      // Note: Storing passwords is insecure. Consider using secure storage.
      await prefs.setString(_savedPasswordKey, password);
    } else {
      await clearRememberMeCredentials();
    }
    
    return true;
  }
  
  /// Get saved email
  Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_savedEmailKey);
  }
  
  /// Get saved password
  Future<String?> getSavedPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_savedPasswordKey);
  }
  
  /// Check if remember me is enabled
  Future<bool> isRememberMeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? false;
  }
  
  /// Clear remember me credentials
  Future<void> clearRememberMeCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_savedEmailKey);
    await prefs.remove(_savedPasswordKey);
    await prefs.setBool(_rememberMeKey, false);
  }
  
  // ============ ROLE AND PERMISSION CHECKERS ============
  
  /// Check if user is admin
  Future<bool> isAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isAdminKey) ?? false;
  }
  
  /// Check user role
  Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userRoleKey);
  }
  
  /// Check if user has specific permission
  Future<bool> hasPermission(String permission) async {
    final prefs = await SharedPreferences.getInstance();
    final permissions = prefs.getStringList(_userPermissionsKey) ?? [];
    return permissions.contains(permission) || permissions.contains('all');
  }
  
  // ============ HELPER METHODS ============
  
  /// Clear all user data (logout)
  Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Clear user data
    await prefs.remove(_userIdKey);
    await prefs.remove(_userFirstNameKey);
    await prefs.remove(_userLastNameKey);
    await prefs.remove(_userFullNameKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userPhoneKey);
    await prefs.remove(_userProfilePicKey);
    await prefs.remove(_userRoleKey);
    await prefs.remove(_userPermissionsKey);
    await prefs.remove(_isAdminKey);
    
    // Note: Don't clear church data if multiple users use same church
    // Don't clear app preferences (theme, notifications, etc.)
    // Don't clear remember me credentials if user wants to stay logged in
  }
  
  /// Clear all app data (factory reset)
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
  
  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_userIdKey);
    return userId != null && userId.isNotEmpty;
  }
  
  /// Get user full name
  Future<String?> getUserFullName() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Try full name first
    String? fullName = prefs.getString(_userFullNameKey);
    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }
    
    // Construct from first and last name
    final firstName = prefs.getString(_userFirstNameKey);
    final lastName = prefs.getString(_userLastNameKey);
    
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (firstName != null) {
      return firstName;
    } else if (lastName != null) {
      return lastName;
    }
    
    return null;
  }
  
  /// Get church name
  Future<String?> getChurchName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_churchNameKey);
  }
  
  /// Get user email
  Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }
}