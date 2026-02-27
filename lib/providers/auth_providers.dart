import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:portal_service_test/auth_service.dart';
import 'package:portal_service_test/helpers/database_methods.dart';
import 'package:portal_service_test/helpers/shared_pref.dart';
import 'package:portal_service_test/models/user_model.dart' as AppModel;
import 'package:portal_service_test/screens/admin_dashboard.dart';
import 'package:portal_service_test/screens/email_verification_screen.dart';
import 'package:portal_service_test/screens/front_desk_screen.dart';
import 'package:portal_service_test/screens/pastoral_counselor_screen.dart';


class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final SharedPreferenceHelper _prefsHelper = SharedPreferenceHelper();
  final DatabaseMethods _databaseMethods = DatabaseMethods();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AppModel.AppUser? _currentUser;
  bool _isLoading = false;
  bool _isCheckingVerification = false;
  String? _error;
  
  Timer? _verificationCheckTimer;
  int _verificationCheckCount = 0;
  static const int _maxVerificationChecks = 60; // 5 minutes at 5-second intervals

  // Getters
  AppModel.AppUser? get currentUser => _currentUser;
 // bool get isAuthenticated => _currentUser != null; 
  bool get isLoading => _isLoading;
  bool get isCheckingVerification => _isCheckingVerification;
  String? get error => _error;
 bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.role == 'admin';
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;
  SharedPreferenceHelper get prefsHelper => _authService.prefsHelper;

  /// Initialize authentication state
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Check if there's a Firebase user
      final isAuthenticated = await _authService.checkAuthState();
      
      if (isAuthenticated) {
        // Validate the session with Firestore
        final isValidSession = await _authService.validateSession();
        
        if (isValidSession) {
          // Get stored user data
          final stored = await _authService.getStoredUser();
          
          if (stored != null) {
            _currentUser = AppModel.AppUser(
              id: stored['id'] ?? '',
              firstName: stored['firstName'] ?? '',
              lastName: stored['lastName'] ?? '',
              email: stored['email'] ?? '',
              churchName: stored['churchName'] ?? '',
              churchId: stored['churchId'] ?? '',
              role: stored['role'] ?? '',
              phone: stored['phone'] ?? '',
              createdAt: DateTime.parse(stored['createdAt'] ?? DateTime.now().toIso8601String()),
              isActive: stored['isActive'] ?? true,
              lastLogin: DateTime.parse(stored['lastLogin'] ?? DateTime.now().toIso8601String()),
              permissions: List<String>.from(stored['permissions'] ?? []),
              emailVerified: stored['emailVerified'] ?? false,
            );
            
            // Check if email needs verification
            if ( _auth.currentUser != null) {
              await _auth.currentUser!.reload();
              _currentUser = _currentUser!.copyWith(
                emailVerified: _auth.currentUser!.emailVerified, lastLogin: DateTime.now(), churchId: '', churchName: '', role: null, isActive: null, permissions: [],
              );
            }
          } else {
            // No stored data, try to fetch from Firestore
            await _fetchCurrentUserFromFirestore();
          }
        } else {
          // Invalid session, clear everything
          await _authService.logout();
          _currentUser = null;
        }
      } else {
        // Not authenticated, clear user
        _currentUser = null;
      }
    } catch (e) {
      _error = 'Failed to initialize authentication: $e';
      print('Auth initialization error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch user from Firestore
  Future<void> _fetchCurrentUserFromFirestore() async {
    try {
      final User? firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) return;
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        
        _currentUser = AppModel.AppUser(
          id: firebaseUser.uid,
          firstName: userData['firstName'] ?? '',
          lastName: userData['lastName'] ?? '',
          email: userData['email'] ?? '',
          churchName: userData['churchName'] ?? '',
          churchId: userData['churchId'] ?? '',
          role: userData['role'] ?? '',
          phone: userData['phone'] ?? '',
          createdAt: (userData['createdAt'] as Timestamp).toDate(),
          isActive: userData['isActive'] ?? true,
          lastLogin: DateTime.now(),
          permissions: List<String>.from(userData['permissions'] ?? []),
          emailVerified: userData['emailVerified'] ?? false,
        );
        
        // Save to preferences
        await _authService.prefsHelper.saveUserData({
          'id': firebaseUser.uid,
          'firstName': userData['firstName'],
          'lastName': userData['lastName'],
          'email': userData['email'],
          'phone': userData['phone'],
          'churchName': userData['churchName'],
          'churchId': userData['churchId'],
          'role': userData['role'],
          'isAdmin': userData['role'] == 'admin',
          'permissions': userData['permissions'] ?? [],
          'emailVerified': userData['emailVerified'] ?? false,
          'createdAt': _currentUser!.createdAt.toString(),
          'lastLogin': _currentUser!.lastLogin.toString(),
        });
      }
    } catch (e) {
      print('Error fetching user from Firestore: $e');
    }
  }

  /// Register with email and password
  Future<bool> registerWithEmailAndPassword({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String phone,
    required String churchName,
    String? churchId,
    String role = 'front_desk',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // Create Firebase user
      final UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        _error = 'Failed to create user account';
        return false;
      }

      // Update display name
      await user.updateDisplayName('$firstName $lastName');

      // Send verification email
      await user.sendEmailVerification();

      // Church lookup/creation
      String finalChurchId = '';
      String finalChurchName = churchName.trim();

      if (churchId != null && churchId.isNotEmpty) {
        finalChurchId = churchId;
        // Fetch church name if only ID provided
        final churchDoc = await _firestore.collection('churches').doc(churchId).get();
        if (churchDoc.exists) {
          finalChurchName = churchDoc.data()?['churchName'] ?? churchName;
        }
      } else {
        // Search for existing church
        final query = await _firestore
            .collection('churches')
            .where('churchName', isEqualTo: finalChurchName)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          finalChurchId = query.docs.first.id;
        } else {
          // Create new church
          final churchDoc = _firestore.collection('churches').doc();
          finalChurchId = churchDoc.id;
          await churchDoc.set({
            'id': churchDoc.id,
            'churchName': finalChurchName,
            'createdAt': Timestamp.now(),
            'createdBy': user.uid,
            'userName': firstName,
            'userEmail': email,
            'role': role,
            'memberCount': 1,
          });
        }
      }

      // Create user document in Firestore
      final appUser = AppModel.AppUser(
        id: user.uid,
        firstName: firstName,
        lastName: lastName,
        email: email,
        churchName: finalChurchName,
        churchId: finalChurchId,
        role: role,
        phone: phone,
        createdAt: DateTime.now(),
        isActive: true,
        lastLogin: DateTime.now(),
        permissions: _getDefaultPermissions(role),
        emailVerified: false,
      );

      // Save to Firestore
      await _firestore.collection('users').doc(user.uid).set({
        'id': user.uid,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'churchName': finalChurchName,
        'churchId': finalChurchId,
        'role': role,
        'phone': phone,
        'createdAt': Timestamp.now(),
        'isActive': true,
        'lastLogin': Timestamp.now(),
        'permissions': _getDefaultPermissions(role),
        'emailVerified': false,
        'verificationSentAt': Timestamp.now(),
      });

      // Save to preferences
      await _prefsHelper.saveUserData({
        'id': user.uid,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'role': role,
        'isAdmin': role == 'admin',
        'churchId': finalChurchId,
        'churchName': finalChurchName,
        'permissions': _getDefaultPermissions(role),
        'emailVerified': false,
        'createdAt': appUser.createdAt.toString(),
        'lastLogin': appUser.lastLogin.toString(),
      });

      // Set current user
      _currentUser = appUser;
      
      _isLoading = false;
      notifyListeners();
      return true;

    } catch (e) {
       print(' $e');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      
      // Clean up if Firebase user was created but Firestore failed
      try {
        await _auth.currentUser?.delete();
      } catch (_) {}
      
      return false;
    }
  }

  /// Login with email and password
  Future<bool> login({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final user = await _authService.loginWithEmailAndPassword(
        email: email,
        password: password,
        rememberMe: rememberMe,
      );
      
      if (user != null) {
        _currentUser = user;
        
        // Update last login in Firestore
        await _updateLastLogin();
        
        _isLoading = false;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update last login timestamp
  Future<void> _updateLastLogin() async {
    try {
      if (_currentUser == null) return;
      
      final now = DateTime.now();
      _currentUser = _currentUser!.copyWith(lastLogin: now, emailVerified: true, churchId: '', churchName: '', role: null, isActive: null, permissions: []);
      
      // Update Firestore
      await _firestore.collection('users').doc(_currentUser!.id).update({
        'lastLogin': Timestamp.now(),
      });
      
      // Update local storage
      await _prefsHelper.saveUserData({
        'lastLogin': now.toIso8601String(),
      });
    } catch (e) {
      print('Error updating last login: $e');
    }
  }

  /// Logout user
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Cancel any verification timers
      _stopVerificationCheckTimer();
      
      await _authService.logout();
      _currentUser = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Send email verification
  Future<bool> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      
      await user.sendEmailVerification();
      
      // Update verification sent timestamp in Firestore
      if (_currentUser != null) {
        await _firestore.collection('users').doc(_currentUser!.id).update({
          'verificationSentAt': Timestamp.now(),
        });
      }
      
      return true;
    } catch (e) {
      _error = 'Failed to send verification email: $e';
      notifyListeners();
      return false;
    }
  }

  /// Check email verification status
  Future<bool> checkEmailVerification() async {
    _isCheckingVerification = true;
    notifyListeners();
    
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      
      await user.reload();
      final isVerified = user.emailVerified;
      
      if (isVerified && _currentUser != null) {
        // Update user in Firestore
        await _firestore.collection('users').doc(_currentUser!.id).update({
          'emailVerified': true,
          'verifiedAt': Timestamp.now(),
        });
        
        // Update local user
        _currentUser = _currentUser!.copyWith(emailVerified: true, lastLogin: DateTime.now(), churchId: '', churchName: '', role: null, isActive: null, permissions: []);
        
        // Update preferences
        await _prefsHelper.saveUserData({
          'emailVerified': true,
        });
        
        // Stop verification timer
        _stopVerificationCheckTimer();
      }
      
      _isCheckingVerification = false;
      notifyListeners();
      return isVerified;
    } catch (e) {
      _isCheckingVerification = false;
      notifyListeners();
      return false;
    }
  }

  /// Start periodic verification check
  void startVerificationCheckTimer() {
    _stopVerificationCheckTimer(); // Clear existing timer
    
    _verificationCheckCount = 0;
    _verificationCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_verificationCheckCount >= _maxVerificationChecks) {
        timer.cancel();
        return;
      }
      
      _verificationCheckCount++;
      await checkEmailVerification();
      
      // If verified, timer will be stopped in checkEmailVerification()
    });
  }

  /// Stop verification check timer
  void _stopVerificationCheckTimer() {
    _verificationCheckTimer?.cancel();
    _verificationCheckTimer = null;
  }

  Future<void> navigateToRoleScreen(BuildContext context) async {
    if (_currentUser == null) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      return;
    }

    // Check if email is verified
    if (!isEmailVerified) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => EmailVerificationScreen(
            userRole: _currentUser!.role,
            userEmail: _currentUser!.email,
            userId: _currentUser!.id,
          ),
        ),
        (route) => false,
      );
      
      // Start verification check timer
      startVerificationCheckTimer();
      return;
    }

    // Navigate to appropriate screen based on role
    Widget screen;
    
    switch (_currentUser!.role.toLowerCase()) {
      case 'admin':
        screen = const AdminDashboard(adminChurchName: '', adminEmail: '',);
        break;
      case 'front_desk':
        screen = const FrontDeskScreen(churchName: '', userName: '', userEmail: '',);
        break;
      case 'pastor':
      case 'deacon':
      case 'elder':
        // All these roles go to Pastoral Counseling Screen
        screen = PastoralCounselorScreen(userRole: _currentUser!.role, churchName: '', counselorEmail: '', role: '',);
        break;
      default:
        // Fallback to FrontDeskScreen
        screen = const FrontDeskScreen(churchName: '', userName: '', userEmail: '',);
    }
    
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => screen),
      (route) => false,
    );
  }

  /// Get the appropriate screen widget for a role
  Widget getRoleScreen(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return const AdminDashboard(adminChurchName: '', adminEmail: '',);
      case 'front_desk':
        return const FrontDeskScreen(churchName: '', userName: '', userEmail: '',);
      case 'pastor':
      case 'deacon':
      case 'elder':
        return PastoralCounselorScreen(userRole: role, churchName: '', counselorEmail: '', role: '',);
      default:
        return const FrontDeskScreen(churchName: '', userName: '', userEmail: '',);
    }
  }

  /// Get role display name
  String getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'Administrator';
      case 'front_desk':
        return 'Front Desk';
      case 'pastor':
        return 'Pastor';
      case 'deacon':
        return 'Deacon';
      case 'elder':
        return 'Elder';
      default:
        return role;
    }
  }

  /// Reset password
  Future<bool> resetPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _authService.sendPasswordResetEmail(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  /// Update profile
  Future<bool> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
    String? churchName,
    String? churchId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await _authService.updateProfile(
        firstName: firstName,
        lastName: lastName,
        phone: phone,
      );

      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(
          firstName: firstName ?? _currentUser!.firstName,
          lastName: lastName ?? _currentUser!.lastName,
          phone: phone ?? _currentUser!.phone,
          churchName: churchName ?? _currentUser!.churchName,
          churchId: churchId ?? _currentUser!.churchId, 
          emailVerified: true,
           lastLogin: DateTime.now(),
            role: null,
             isActive: null,
              permissions: [],
        );
        
        // Update Firestore
        final updates = <String, dynamic>{};
        if (firstName != null) updates['firstName'] = firstName;
        if (lastName != null) updates['lastName'] = lastName;
        if (phone != null) updates['phone'] = phone;
        if (churchName != null) updates['churchName'] = churchName;
        if (churchId != null) updates['churchId'] = churchId;
        
        if (updates.isNotEmpty) {
          await _firestore.collection('users').doc(_currentUser!.id).update(updates);
          
          // Update preferences
          final prefData = <String, dynamic>{};
          if (firstName != null) prefData['firstName'] = firstName;
          if (lastName != null) prefData['lastName'] = lastName;
          if (phone != null) prefData['phone'] = phone;
          if (churchName != null) prefData['churchName'] = churchName;
          if (churchId != null) prefData['churchId'] = churchId;
          
          await _prefsHelper.saveUserData(prefData);
        }
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Change password
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _error = 'No user logged in';
        return false;
      }
      
      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      
      await user.reauthenticateWithCredential(credential);
      
      // Update password
      await user.updatePassword(newPassword);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Delete account
  Future<bool> deleteAccount({
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _error = 'No user logged in';
        return false;
      }
      
      // Re-authenticate
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      
      // Delete from Firestore
      await _firestore.collection('users').doc(user.uid).delete();
      
      // Delete from Firebase Auth
      await user.delete();
      
      // Clear local data
      await _prefsHelper.clearUserData();
      _currentUser = null;
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Get default permissions based on role
  List<String> _getDefaultPermissions(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return [
          'all',
          'manage_users',
          'manage_churches',
          'manage_roles',
          'view_reports',
          'export_data',
        ];
      case 'pastor':
        return [
          'manage_members',
          'manage_groups',
          'view_reports',
          'manage_services',
          'manage_giving',
          'manage_prayer',
        ];
      case 'front_desk':
        return [
          'view_members',
          'add_visitors',
          'check_in',
          'view_services',
          'print_labels',
        ];
      case 'deacon':
        return [
          'view_members',
          'manage_groups',
          'view_reports',
          'manage_community',
        ];
      case 'elder':
        return [
          'view_members',
          'view_reports',
          'manage_prayer',
          'manage_counseling',
        ];
      default:
        return ['view_members'];
    }
  }

  /// Check if user has specific permission
  bool hasPermission(String permission) {
    if (_currentUser == null) return false;
    
    if (_currentUser!.permissions.contains('all')) {
      return true;
    }
    
    return _currentUser!.permissions.contains(permission);
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Refresh user data from Firestore
  Future<void> refreshUserData() async {
    try {
      if (_currentUser == null) return;
      
      final userDoc = await _firestore
          .collection('users')
          .doc(_currentUser!.id)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        
        _currentUser = _currentUser!.copyWith(
          firstName: userData['firstName'] ?? _currentUser!.firstName,
          lastName: userData['lastName'] ?? _currentUser!.lastName,
          churchName: userData['churchName'] ?? _currentUser!.churchName,
          churchId: userData['churchId'] ?? _currentUser!.churchId,
          role: userData['role'] ?? _currentUser!.role,
          phone: userData['phone'] ?? _currentUser!.phone,
          isActive: userData['isActive'] ?? _currentUser!.isActive,
          permissions: List<String>.from(userData['permissions'] ?? _currentUser!.permissions),
          emailVerified: userData['emailVerified'] ?? _currentUser!.emailVerified,
           lastLogin: DateTime.now(),
        );
        
        notifyListeners();
      }
    } catch (e) {
      print('Error refreshing user data: $e');
    }
  }

  /// Check if user exists by email
  Future<bool> checkUserExists(String email) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();
      
      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get all users for current church (admin only)
  Future<List<AppModel.AppUser>> getChurchUsers() async {
    try {
      if (_currentUser == null || _currentUser!.churchId.isEmpty) {
        return [];
      }
      
      final query = await _firestore
          .collection('users')
          .where('churchId', isEqualTo: _currentUser!.churchId)
          .get();
      
      return query.docs.map((doc) {
        final data = doc.data();
        return AppModel.AppUser(
          id: doc.id,
          firstName: data['firstName'] ?? '',
          lastName: data['lastName'] ?? '',
          email: data['email'] ?? '',
          churchName: data['churchName'] ?? '',
          churchId: data['churchId'] ?? '',
          role: data['role'] ?? '',
          phone: data['phone'] ?? '',
          createdAt: (data['createdAt'] as Timestamp).toDate(),
          isActive: data['isActive'] ?? true,
          lastLogin: DateTime.now(),
          permissions: List<String>.from(data['permissions'] ?? []),
          emailVerified: data['emailVerified'] ?? false,
        );
      }).toList();
    } catch (e) {
      print('Error getting church users: $e');
      return [];
    }
  }

  /// Update user role (admin only)
  Future<bool> updateUserRole({
    required String userId,
    required String newRole,
  }) async {
    try {
      if (!isAdmin) {
        _error = 'Only admins can update user roles';
        return false;
      }
      
      await _firestore.collection('users').doc(userId).update({
        'role': newRole,
        'permissions': _getDefaultPermissions(newRole),
        'updatedAt': Timestamp.now(),
        'updatedBy': _currentUser!.id,
      });
      
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  /// Deactivate user account (admin only)
  Future<bool> deactivateUser(String userId) async {
    try {
      if (!isAdmin) {
        _error = 'Only admins can deactivate users';
        return false;
      }
      
      await _firestore.collection('users').doc(userId).update({
        'isActive': false,
        'deactivatedAt': Timestamp.now(),
        'deactivatedBy': _currentUser!.id,
      });
      
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  /// Reactivate user account (admin only)
  Future<bool> reactivateUser(String userId) async {
    try {
      if (!isAdmin) {
        _error = 'Only admins can reactivate users';
        return false;
      }
      
      await _firestore.collection('users').doc(userId).update({
        'isActive': true,
        'reactivatedAt': Timestamp.now(),
        'reactivatedBy': _currentUser!.id,
      });
      
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  @override
  void dispose() {
    _stopVerificationCheckTimer();
    super.dispose();
  }
}