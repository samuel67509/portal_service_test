import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:portal_service_test/helpers/database_methods.dart';
import 'package:portal_service_test/helpers/shared_pref.dart';
import 'package:portal_service_test/models/user_model.dart';



class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SharedPreferenceHelper _prefsHelper = SharedPreferenceHelper();
  final DatabaseMethods _databaseMethods = DatabaseMethods();
   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  SharedPreferenceHelper get prefsHelper => _prefsHelper;
  
  // Current user stream
  Stream<User?> get user => _auth.authStateChanges();
  
  // Current user
  User? get currentUser => _auth.currentUser;
  
  // ============ EMAIL/PASSWORD REGISTRATION ============
  
  Future<AppUser?> registerWithEmailAndPassword({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String phone,
    required String churchName,
    String? churchId,
    String finalChurchId = '',
    String role = '', 
  }) async {
    try {
      // 1. Create Firebase user
      final UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      
      final User? user = credential.user;
      if (user == null) return null;
      // 2. Ensure church exists


if (churchId != null && churchId.isNotEmpty) {
  finalChurchId = churchId; // already provided
} else {
  // Look up church by name
  final query = await _firestore
      .collection('churches')
      .where('name', isEqualTo: churchName.trim())
      .limit(1)
      .get();

  if (query.docs.isEmpty) {
    // 🚀 FIRST USER → create church automatically
    final newChurch = _firestore.collection('churches').doc();
    await newChurch.set({
      'id': newChurch.id,
      'name': churchName.trim(),
      'createdAt': DateTime.now(),
      'createdBy': user.uid,
    });
    finalChurchId = newChurch.id;
  } else {
    finalChurchId = query.docs.first.id;
  }
}

      
      // 2. Update display name
      await user.updateDisplayName('$firstName $lastName');
      
      // 3. Create user data for database
      final appUser = AppUser(
        id: user.uid,
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        email: email.trim().toLowerCase(),
        churchName: churchName.trim(),
        churchId: churchId ?? '',
        role: role,
        phone: phone.trim(),
        createdAt: DateTime.now(),
        isActive: true,
        lastLogin: DateTime.now(),
        permissions: _getDefaultPermissions(role), emailVerified: null,
      );
      
      // 4. Save to database
      await _databaseMethods.addUser(appUser);
      
      // 5. Save to local storage
      await _prefsHelper.saveUserData({
        'id': user.uid,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'role': role,
        'isAdmin': role == 'admin',
        'permissions': _getDefaultPermissions(role),
        'churchId': churchId ?? '',
        'churchName': churchName,
      });
      
      // 6. Send email verification
      await user.sendEmailVerification();
      
      return appUser;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Registration failed: ${e.toString()}';
    }
    
  }
  
  Future<void> debugRegistrationIssue() async {
  try {
    print('=== DEBUG REGISTRATION ===');
    
    // Check churches collection
    final churches = await _firestore.collection('churches').get();
    print('Total churches in database: ${churches.docs.length}');
    
    for (var doc in churches.docs) {
      print('Church: ${doc['name']} - ID: ${doc.id}');
    }
    
    // Check current user
    final currentUser = _auth.currentUser;
    print('Current Firebase user: ${currentUser?.uid}');
    
    if (currentUser != null) {
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      print('User document exists: ${userDoc.exists}');
      if (userDoc.exists) {
        print('User data: ${userDoc.data()}');
      }
    }
    
    print('=== END DEBUG ===');
  } catch (e) {
    print('Debug error: $e');
  }
}

  // In your AuthService class, add this method:
Future<Map<String, dynamic>?> getStoredUser() async {
  try {
    final userData = await prefsHelper.getUserData();
    if (userData['id'] != null && userData['id']!.isNotEmpty) {
      return userData;
    }
    return null;
  } catch (e) {
    print('Error getting stored user: $e');
    return null;
  }
}

// Also add this method to validate session:
Future<bool> validateSession() async {
  try {
    final User? currentUser = _auth.currentUser;
    
    if (currentUser == null) {
      // Clear stored data if no Firebase user
      await prefsHelper.clearUserData();
      return false;
    }
    
    // Check if user exists in Firestore
    final userDoc = await _firestore
        .collection('users')
        .doc(currentUser.uid)
        .get();
    
    if (!userDoc.exists) {
      await _auth.signOut();
      await prefsHelper.clearUserData();
      return false;
    }
    
    final userData = userDoc.data()!;
    
    // Check if user is active
    if (userData['isActive'] != true) {
      await _auth.signOut();
      await prefsHelper.clearUserData();
      return false;
    }
    
    // Update local storage with latest data
    await prefsHelper.saveUserData({
      'id': currentUser.uid,
      'firstName': userData['firstName'],
      'lastName': userData['lastName'],
      'email': userData['email'],
      'phone': userData['phone'],
      'churchName': userData['churchName'],
      'churchId': userData['churchId'],
      'role': userData['role'],
      'isAdmin': userData['role'] == 'admin',
      'permissions': userData['permissions'] ?? [],
    });
    
    return true;
  } catch (e) {
    print('Error validating session: $e');
    return false;
  }
}
  // ============ EMAIL/PASSWORD LOGIN ============
  
  Future<AppUser?> loginWithEmailAndPassword({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    try {
      // 1. Sign in with Firebase
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      
      final User? user = credential.user;
      if (user == null) return null;
      
      // 2. Check if email is verified
      if (!user.emailVerified) {
        throw 'Please verify your email address before logging in.';
      }
      
      // 3. Get user data from database
      final List<AppUser> allUsers = await _databaseMethods.getAllUsers();
      final appUser = allUsers.firstWhere(
        (u) => u.id == user.uid,
        orElse: () => AppUser(
          id: user.uid,
          firstName: user.displayName?.split(' ').first ?? '',
          lastName: user.displayName?.split(' ').last ?? '',
          email: user.email ?? '',
          churchName: '',
          churchId: '',
          role: '',
          phone: '',
          createdAt: DateTime.now(),
          isActive: false,
          permissions: [], emailVerified: null,
        ),
      );
      
      // 4. Check if account is active
      if (!appUser.isActive) {
        throw 'Your account has been deactivated. Please contact your church administrator.';
      }
      
      // 5. Save to local storage
      await _prefsHelper.saveUserData({
        'id': user.uid,
        'firstName': appUser.firstName,
        'lastName': appUser.lastName,
        'email': appUser.email,
        'phone': appUser.phone,
        'role': appUser.role,
        'isAdmin': appUser.role == 'admin',
        'permissions': appUser.permissions,
        'churchId': appUser.churchId,
        'churchName': appUser.churchName,
      });
      
      // 6. Save last login
      await _databaseMethods.updateUser(user.uid, {
        'lastLogin': DateTime.now(),
      });
      
      await _prefsHelper.saveLastLogin(DateTime.now());
      
      // 7. Save remember me credentials if requested
      if (rememberMe) {
        await _prefsHelper.saveRememberMeCredentials(
          email: email,
          password: password,
          rememberMe: true,
        );
      }
      
      return appUser;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      rethrow;
    }
  }
  
  // ============ PASSWORD RESET ============
  
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }
  
  // ============ LOGOUT ============
  
  Future<void> logout() async {
    try {
      // Sign out from Firebase
      await _auth.signOut();
      
      // Clear local user data (keep app preferences)
      await _prefsHelper.clearUserData();
    } catch (e) {
      throw 'Logout failed: ${e.toString()}';
    }
  }
  
  // ============ ACCOUNT MANAGEMENT ============
  
  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) throw 'No user logged in';
      
      final updates = <String, dynamic>{};
      
      // Update Firebase display name if needed
      if (firstName != null || lastName != null) {
        final currentFirstName = await _prefsHelper.getUserData().then((data) => data['firstName']);
        final currentLastName = await _prefsHelper.getUserData().then((data) => data['lastName']);
        
        final newFirstName = firstName ?? currentFirstName;
        final newLastName = lastName ?? currentLastName;
        
        await user.updateDisplayName('$newFirstName $newLastName');
        
        updates['firstName'] = newFirstName;
        updates['lastName'] = newLastName;
      }
      
      if (phone != null) {
        updates['phone'] = phone;
      }
      
      // Update in database
      if (updates.isNotEmpty) {
        await _databaseMethods.updateUser(user.uid, updates);
        
        // Update local storage
        final currentData = await _prefsHelper.getUserData();
        await _prefsHelper.saveUserData({
          ...currentData,
          ...updates,
        });
      }
    } catch (e) {
      throw 'Profile update failed: ${e.toString()}';
    }
  }
  
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) throw 'No user logged in';
      if (user.email == null) throw 'No email associated with account';
      
      // Re-authenticate user
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      
      await user.reauthenticateWithCredential(credential);
      
      // Update password
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Password change failed: ${e.toString()}';
    }
  }
  
  Future<void> deleteAccount() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) throw 'No user logged in';
      
      // Delete from database
      await _databaseMethods.deleteUser(user.uid);
      
      // Delete from Firebase Auth
      await user.delete();
      
      // Clear local data
      await logout();
    } catch (e) {
      throw 'Account deletion failed: ${e.toString()}';
    }
  }
  
  // ============ HELPER METHODS ============
  
  List<String> _getDefaultPermissions(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return ['all'];
      case 'front_desk':
      case 'front desk':
        return ['add_visitors', 'view_visitors', 'edit_visitors'];
      case 'pastor':
        return ['view_appointments', 'counseling', 'complete_appointments', 'add_notes'];
      case 'deacon':
        return ['support_visitors', 'view_appointments', 'complete_appointments', 'add_notes'];
      case 'elder':
        return ['view_appointments', 'counseling', 'complete_appointments', 'add_notes'];
      default:
        return ['view_visitors'];
    }
  }
  
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled. Please contact support.';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'too-many-requests':
        return 'Too many failed login attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }
  
  // ============ CHECK AUTH STATE ============
  
  Future<bool> checkAuthState() async {
    final isLoggedIn = await _prefsHelper.isLoggedIn();
    if (!isLoggedIn) return false;
    
    final user = _auth.currentUser;
    if (user == null) return false;
    
    // Check if token is still valid
    try {
      await user.getIdToken(true);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  Future<void> reauthenticate() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) return;
      
      await user.getIdToken(true);
    } catch (e) {
      await logout();
    }
  }

  // ============ GET CURRENT USER FROM DATABASE ============
  
  Future<AppUser?> getCurrentAppUser() async {
    try {
      final User? firebaseUser = _auth.currentUser;
      if (firebaseUser == null) return null;
      
      final List<AppUser> allUsers = await _databaseMethods.getAllUsers();
      return allUsers.firstWhere(
        (u) => u.id == firebaseUser.uid,
        orElse: () => AppUser(
          id: firebaseUser.uid,
          firstName: firebaseUser.displayName?.split(' ').first ?? '',
          lastName: firebaseUser.displayName?.split(' ').last ?? '',
          email: firebaseUser.email ?? '',
          churchName: '',
          churchId: '',
          role: '',
          phone: '',
          createdAt: DateTime.now(),
          isActive: false,
          permissions: [], emailVerified: null,
        ),
      );
    } catch (e) {
      print('Error getting current app user: $e');
      return null;
    }
  }

  // ============ CHECK USER PERMISSIONS ============
  
  Future<bool> hasPermission(String permission) async {
    try {
      final data = await _prefsHelper.getUserData();
      final permissions = List<String>.from(data['permissions'] ?? []);
      
      // Admins have all permissions
      if (data['isAdmin'] == true || permissions.contains('all')) {
        return true;
      }
      
      return permissions.contains(permission);
    } catch (e) {
      return false;
    }
  }

  // ============ UPDATE CHURCH INFO ============
  
  Future<void> updateChurchInfo({
    required String churchId,
    required String churchName,
  }) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) throw 'No user logged in';
      
      // Update in database
      await _databaseMethods.updateUser(user.uid, {
        'churchId': churchId,
        'churchName': churchName,
      });
      
      // Update local storage
      final currentData = await _prefsHelper.getUserData();
      await _prefsHelper.saveUserData({
        ...currentData,
        'churchId': churchId,
        'churchName': churchName,
      });
    } catch (e) {
      throw 'Failed to update church info: ${e.toString()}';
    }
  }

  // ============ VERIFY EMAIL ============
  
  Future<void> sendEmailVerification() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) throw 'No user logged in';
      
      if (user.emailVerified) {
        throw 'Email is already verified';
      }
      
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Failed to send verification email: ${e.toString()}';
    }
  }

  // ============ CHECK IF EMAIL IS VERIFIED ============
  
  bool get isEmailVerified {
    return _auth.currentUser?.emailVerified ?? false;
  }

  // ============ RELOAD USER ============
  
  Future<void> reloadUser() async {
    try {
      await _auth.currentUser?.reload();
    } catch (e) {
      print('Error reloading user: $e');
    }
  }
}