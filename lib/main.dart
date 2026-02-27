import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:portal_service_test/firebase_options.dart';
import 'package:portal_service_test/models/user_model.dart' as AppModel;
import 'package:portal_service_test/providers/auth_providers.dart';
import 'package:portal_service_test/screens/admin_dashboard.dart';
import 'package:portal_service_test/screens/email_verification_screen.dart';
import 'package:portal_service_test/screens/front_desk_screen.dart';
import 'package:portal_service_test/screens/loading_screen.dart';
import 'package:portal_service_test/screens/pastoral_counselor_screen.dart';
import 'package:portal_service_test/screens/sign_up.dart';
import 'package:portal_service_test/theme/theme_provider.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
          lazy: false,
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeProvider(),
          lazy: false,
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Church Connect',
            theme: themeProvider.currentTheme, // This will use the selected theme
            darkTheme: themeProvider.darkTheme, // Always use the dark theme variant
            themeMode: themeProvider.themeMode, // Auto-switch based on isDarkMode
            home: const AuthWrapper(),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}
class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Initialize auth provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.initialize();
    });
  }

 @override
Widget build(BuildContext context) {
  final authProvider = Provider.of<AuthProvider>(context);

  if (authProvider.isLoading) {
    return const LoadingScreen();
  }

  // Check if user is authenticated (handle nullable)
  final isAuthenticated = authProvider.isAuthenticated;
  if (isAuthenticated != true) { // Fixed line 96
    return const SignUp(); // Or LoginScreen if you have one
  }

  // User is authenticated - check email verification
  final user = authProvider.currentUser;
  if (user == null) {
    return const SignUp();
  }

  // Check if email is verified - Fixed line 104
  if (user.emailVerified != true) {
    return EmailVerificationScreen(
      userRole: user.role,
      userEmail: user.email,
      userId: user.id,
    );
  }

  // Email is verified - navigate based on user role
  return _getRoleScreen(user);
}

  Widget _getRoleScreen(AppModel.AppUser user) {
    switch (user.role.toLowerCase()) {
      case 'admin':
        return AdminDashboard(
          adminChurchName: user.churchName,
          adminEmail: user.email,
        );
      case 'front_desk':
        return FrontDeskScreen(
          churchName: user.churchName,
          userEmail: user.email,
          userName: '${user.firstName} ${user.lastName}',
        );
      case 'pastor':
      case 'deacon':
      case 'elder':
        return PastoralCounselorScreen(
          churchName: user.churchName,
          counselorEmail: user.email,
          role: user.role,
          userRole: user.role,
        );
      default:
        // Default to front desk for unknown roles
        return FrontDeskScreen(
          churchName: user.churchName,
          userEmail: user.email,
          userName: '${user.firstName} ${user.lastName}',
        );
    }
  }
}