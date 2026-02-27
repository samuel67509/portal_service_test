import 'package:flutter/material.dart';
import 'package:portal_service_test/providers/auth_providers.dart';
import 'package:portal_service_test/screens/email_verification_screen.dart';
import 'package:portal_service_test/screens/login_screen.dart';
import 'package:portal_service_test/widgets/responsive_layout.dart';
import 'package:provider/provider.dart';


class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _churchNameController = TextEditingController(); // Changed from phoneController
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  String? _selectedRole;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;

  // Define available roles and their navigation targets
 final Map<String, Map<String, dynamic>> _roles = {
    'admin': {
      'name': 'Admin',
      'icon': Icons.admin_panel_settings,
      'color': Colors.purple,
  
    },
    'front_desk': {
      'name': 'Front Desk',
      'icon': Icons.desk,
      'color': Colors.blue,
     
    },
    'pastor': {
      'name': 'Pastor',
      'icon': Icons.people,
      'color': Colors.green,
     
    },
    'deacon': {
      'name': 'Deacon',
      'icon': Icons.handshake,
      'color': Colors.orange,
    
    },
    'elder': {
      'name': 'Elder',
      'icon': Icons.leaderboard,
      'color': Colors.indigo,
    
    },
  };

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _churchNameController.dispose(); // Updated controller name
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // In your SignUp screen, update the _submitForm method:
/// In your SignUp widget, update the _submitForm method
Future<void> _submitForm() async {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  
  if (!_formKey.currentState!.validate()) return;
  
  if (_selectedRole == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please select a role'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }
  
  if (!_agreeToTerms) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please agree to the Terms of Service and Privacy Policy'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  if (_passwordController.text != _confirmPasswordController.text) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Passwords do not match'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    final success = await authProvider.registerWithEmailAndPassword(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      churchName: _churchNameController.text.trim(),
      role: _selectedRole!,
      phone: '', // or collect phone number if needed
    );

    if (success) {
      // Navigate to verification screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => EmailVerificationScreen(
            userRole: _selectedRole!,
            userEmail: _emailController.text.trim(),
            userId: authProvider.currentUser?.id,
          ),
        ),
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration successful! Check your email for verification link.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: ${authProvider.error}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ResponsiveLayout(
        mobile: _buildMobileSignUp(context),
        tablet: _buildTabletSignUp(context),
        desktop: _buildDesktopSignUp(context),
      ),
    );
  }

  Widget _buildMobileSignUp(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _buildSignUpContent(context, true),
    );
  }

  Widget _buildTabletSignUp(BuildContext context) {
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
                  Text('Welcome Team Portal',
                      style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text('Multi-Church Staff Registration',
                      style: TextStyle(fontSize: 16, color: Colors.white70)),
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
                        Icon(Icons.group_add, size: 40, color: Colors.white),
                        const SizedBox(height: 10),
                        Text('Join Your Church Team',
                            style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Text('Register as a staff member to access church management tools and resources',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: _buildSignUpContent(context, false),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopSignUp(BuildContext context) {
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
                  Text('Church Welcome Team Portal',
                      style: TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text('Multi-Church Registration System',
                      style: TextStyle(fontSize: 18, color: Colors.white70)),
                  const SizedBox(height: 50),
                  Container(
                    padding: const EdgeInsets.all(30),
                    margin: const EdgeInsets.symmetric(horizontal: 60),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.group_add, size: 60, color: Colors.white),
                        const SizedBox(height: 20),
                        Text('Join Your Welcome Team',
                            style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),
                        Text('Register to access specialized tools and resources for church management, counseling, and ministry operations.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.white70)),
                      ],
                    ),
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
            child: _buildSignUpContent(context, false),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpContent(BuildContext context, bool isMobile) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        if (!isMobile) ...[
          Text('Create Account', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 30),
        ] else ...[
          Icon(Icons.church, size: 60, color: Theme.of(context).primaryColor),
          const SizedBox(height: 20),
          Text('Church Welcome Team Portal', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text('Multi-Church Registration System', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
        ],

        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name fields
              if (isMobile)
                Column(
                  children: [
                    TextFormField(
                      controller: _firstNameController,
                      decoration: InputDecoration(
                        labelText: 'First Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your first name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: InputDecoration(
                        labelText: 'Last Name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your last name';
                        }
                        return null;
                      },
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameController,
                        decoration: InputDecoration(
                          labelText: 'First Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your first name';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameController,
                        decoration: InputDecoration(
                          labelText: 'Last Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your last name';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),

              // Email
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
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

              // Church Name (replaced Phone)
              TextFormField(
                controller: _churchNameController,
                decoration: InputDecoration(
                  labelText: 'Church Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.church),
                  hintText: 'Enter your church name',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your church name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Role Selection Dropdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Your Role',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButtonFormField<String>(
                        value: _selectedRole,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                        hint: const Row(
                          children: [
                            Icon(Icons.person_outline, color: Colors.grey),
                            SizedBox(width: 12),
                            Text('Choose your role'),
                          ],
                        ),
                        items: _roles.entries.map((entry) {
                          final roleData = entry.value;
                          return DropdownMenuItem<String>(
                            value: entry.key,
                            child: Row(
                              children: [
                                Icon(
                                  roleData['icon'],
                                  color: roleData['color'],
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        roleData['name'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                          
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedRole = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a role';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Passwords
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
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
                    return 'Please enter a password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please confirm your password';
                  }
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Terms Agreement
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _agreeToTerms,
                    onChanged: (value) {
                      setState(() {
                        _agreeToTerms = value ?? false;
                      });
                    },
                  ),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        text: 'I agree to the ',
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                        children: [
                          TextSpan(
                            text: 'Terms of Service',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const TextSpan(text: ' of the Welcome Team Portal'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // Back to Login
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => LoginScreen()));
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.arrow_back),
                      SizedBox(width: 8),
                      Text('Already have an account? Sign In'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}