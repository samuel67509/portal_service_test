import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:portal_service_test/firebase_options.dart';
import 'package:portal_service_test/providers/auth_providers.dart';
import 'package:portal_service_test/screens/auth/auth_wrapper.dart';
import 'package:portal_service_test/theme/theme_provider.dart';
import 'package:provider/provider.dart';

void main() async {
 WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
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
