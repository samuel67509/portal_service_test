

import 'package:flutter/material.dart';
import 'package:portal_service_test/providers/auth_providers.dart';
import 'package:portal_service_test/screens/forgot_password_screen.dart';
import 'package:portal_service_test/screens/sign_up.dart';
import 'package:portal_service_test/screens/theme_setting_screen.dart';
import 'package:portal_service_test/theme/theme_provider.dart';
import 'package:portal_service_test/widgets/responsive_layout.dart';
import 'package:provider/provider.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
  final authProvider = context.read<AuthProvider>();
  final prefsHelper = authProvider.prefsHelper;

  if (await prefsHelper.isRememberMeEnabled()) {
    final savedEmail = await prefsHelper.getSavedEmail();
    final savedPassword = await prefsHelper.getSavedPassword();

    if (savedEmail != null) _emailController.text = savedEmail;
    if (savedPassword != null) {
      _passwordController.text = savedPassword;
      _rememberMe = true;
    }
  }
}


  Future<void> _handleLogin(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await authProvider.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        rememberMe: _rememberMe,
      );

      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.error ?? 'Login failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleQuickLogin(String email, String password) {
    _emailController.text = email;
    _passwordController.text = password;
    _handleLogin(context);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      body: ResponsiveLayout(
        mobile: _buildMobileLogin(context, themeProvider, authProvider),
        tablet: _buildTabletLogin(context, themeProvider, authProvider),
        desktop: _buildDesktopLogin(context, themeProvider, authProvider),
      ),
    );
  }

  Widget _buildMobileLogin(BuildContext context, ThemeProvider themeProvider, AuthProvider authProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _buildLoginContent(context, themeProvider, authProvider, true),
    );
  }

  Widget _buildTabletLogin(BuildContext context, ThemeProvider themeProvider, AuthProvider authProvider) {
    return Row(
      children: [
        Expanded(
          child: Container(
            color: Theme.of(context).primaryColor,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.church, size: 80, color: Colors.white),
                  const SizedBox(height: 20),
                  Text('Church Connect',
                      style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text('Welcome Team Portal',
                      style: TextStyle(fontSize: 16, color: Colors.white70)),
                  const SizedBox(height: 40),
                  IconButton(
                    icon: Icon(themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode, 
                              color: Colors.white70, size: 30),
                    onPressed: () => themeProvider.toggleDarkMode(),
                    tooltip: 'Toggle dark mode',
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: _buildLoginContent(context, themeProvider, authProvider, false),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLogin(BuildContext context, ThemeProvider themeProvider, AuthProvider authProvider) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.8),
                ],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.church, size: 100, color: Colors.white),
                  const SizedBox(height: 30),
                  Text('Church Connect',
                      style: TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text('Welcome Team Portal',
                      style: TextStyle(fontSize: 18, color: Colors.white70)),
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.security, size: 40, color: Colors.white),
                        const SizedBox(height: 10),
                        Text('Secure Login',
                            style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Text('Your church data is securely protected',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Colors.white70)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  IconButton(
                    icon: Icon(themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode, 
                              color: Colors.white70, size: 30),
                    onPressed: () => themeProvider.toggleDarkMode(),
                    tooltip: 'Toggle dark mode',
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(60),
            child: _buildLoginContent(context, themeProvider, authProvider, false),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginContent(BuildContext context, ThemeProvider themeProvider, AuthProvider authProvider, bool isMobile) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        if (!isMobile) ...[
          Text('Login', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text('Access your church management dashboard',
              style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 30),
        ] else ...[
          Icon(Icons.church, size: 60, color: Theme.of(context).primaryColor),
          const SizedBox(height: 20),
          Text('Church Connect', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text('Welcome Team Portal', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
        ],
        
        Form(
          key: _formKey,
          child: Column(
            children: [
              // Email field
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Password field
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              
              // Remember me & Forgot password
              Row(
                children: [
                  Checkbox(
                    value: _rememberMe,
                    onChanged: (value) {
                      setState(() {
                        _rememberMe = value ?? false;
                      });
                    },
                  ),
                  const Text('Remember me'),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: const Text('Forgot Password?'),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Error message
        if (authProvider.error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    authProvider.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        
        if (authProvider.error != null)
          const SizedBox(height: 16),
        
        // Login button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading || authProvider.isLoading
                ? null
                : () => _handleLogin(context),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading || authProvider.isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Login', style: TextStyle(fontSize: 16)),
          ),
        ),
                
        const SizedBox(height: 30),
        
        // Sign up link
        Center(
          child: TextButton(
            onPressed: _isLoading ? null : () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SignUp()));
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('Don\'t have an account? Sign Up'),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 16),
              ],
            ),
          ),
        ),
        
        if (!isMobile) ...[
          const Divider(height: 40),
          TextButton.icon(
            icon: const Icon(Icons.palette),
            label: const Text('Theme Settings'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ThemeSettingsScreen()),
              );
            },
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}