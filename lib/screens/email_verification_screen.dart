import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:portal_service_test/providers/auth_providers.dart';
import 'package:portal_service_test/screens/admin_dashboard.dart';
import 'package:portal_service_test/screens/front_desk_screen.dart';
import 'package:portal_service_test/screens/pastoral_counselor_screen.dart';
import 'package:portal_service_test/screens/sign_up.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String userRole;
  final String userEmail;
  final String? userId;

  const EmailVerificationScreen({
    super.key,
    required this.userRole,
    required this.userEmail,
    this.userId,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  AuthProvider? _authProvider;
  Timer? _verificationTimer;
  bool _isResending = false;
  int _resendCooldown = 0;
  bool _hasStartedTimer = false;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    // Initialize immediately in initState
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    _startInitialVerificationCheck();
  }

  void _startInitialVerificationCheck() {
    // Check verification status immediately
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkVerificationStatus();
      // Start periodic checks
      _startVerificationTimer();
      
      if (!_hasStartedTimer) {
        _authProvider?.startVerificationCheckTimer();
        _hasStartedTimer = true;
      }
    });
  }

  void _startVerificationTimer() {
    _verificationTimer?.cancel();
    _verificationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkVerificationStatus();
    });
  }

  Future<void> _checkVerificationStatus() async {
    if (_isChecking || _authProvider == null) return;
    
    _isChecking = true;
    final isVerified = await _authProvider!.checkEmailVerification();
    _isChecking = false;
    
    if (isVerified && mounted) {
      _verificationTimer?.cancel();
      _navigateToRoleScreen();
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_resendCooldown > 0 || _authProvider == null) return;
    
    setState(() => _isResending = true);
    
    final success = await _authProvider!.sendEmailVerification();
    
    if (mounted) {
      setState(() => _isResending = false);
      
      if (success) {
        setState(() => _resendCooldown = 60);
        _startResendCooldown();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent! Check your inbox.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: ${_authProvider!.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startResendCooldown() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _resendCooldown--);
        if (_resendCooldown <= 0) timer.cancel();
      }
    });
  }

  void _navigateToRoleScreen() {
    if (_authProvider != null && mounted) {
      _authProvider!.notifyListeners();
    }
  }

  void _logout() async {
    await _authProvider?.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SignUp()),
        (route) => false,
      );
    }
  }

  Widget _buildRoleScreen() {
    if (_authProvider == null) return const SignUp();
    
    final user = _authProvider!.currentUser;
    if (user == null) return const SignUp();

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
        return FrontDeskScreen(
          churchName: user.churchName,
          userEmail: user.email,
          userName: '${user.firstName} ${user.lastName}',
        );
    }
  }

  @override
  void dispose() {
    _verificationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use Provider.of directly or check if _authProvider is initialized
    final authProvider = _authProvider ?? Provider.of<AuthProvider>(context);
    final isVerified = authProvider.isEmailVerified;
    
    // If verified while screen is open, navigate immediately
    if (isVerified) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => _buildRoleScreen()),
            (route) => false,
          );
        }
      });
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Verification'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: isVerified ? Colors.green.shade50 : Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isVerified ? Icons.verified : Icons.mark_email_unread,
                  size: 80,
                  color: isVerified ? Colors.green : Theme.of(context).primaryColor,
                ),
              ),
              
              const SizedBox(height: 32),
              
              Text(
                isVerified ? 'Email Verified!' : 'Verify Your Email',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 16),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  isVerified
                      ? 'Your email has been successfully verified. Redirecting...'
                      : 'We sent a verification link to:',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              
              if (!isVerified) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        widget.userEmail,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Chip(
                        label: Text(
                          _getRoleDisplayName(widget.userRole),
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                        ),
                        backgroundColor: _getRoleColor(widget.userRole),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '📧 Verification Steps:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildInstruction('1. Open your email app'),
                        _buildInstruction('2. Find email from Church Connect'),
                        _buildInstruction('3. Click the verification link'),
                        _buildInstruction('4. Return to this app'),
                        const SizedBox(height: 12),
                        Text(
                          'The app will automatically redirect you once verified.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                if (_isChecking)
                  const Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Checking verification status...'),
                    ],
                  )
                else
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _resendCooldown > 0 || _isResending ? null : _resendVerificationEmail,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isResending
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(_resendCooldown > 0
                                  ? 'Resend in $_resendCooldown seconds'
                                  : 'Resend Verification Email'),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      TextButton(
                        onPressed: _logout,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout, size: 18),
                            SizedBox(width: 8),
                            Text('Use different email'),
                          ],
                        ),
                      ),
                    ],
                  ),
              ] else ...[
                const SizedBox(height: 32),
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Redirecting to your dashboard...'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstruction(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.circle, size: 8, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  // Helper method to get role display name
  String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'ADMINISTRATOR';
      case 'front_desk':
        return 'FRONT DESK';
      case 'pastor':
        return 'PASTOR';
      case 'deacon':
        return 'DEACON';
      case 'elder':
        return 'ELDER';
      default:
        return role.toUpperCase();
    }
  }

  // Helper method to get role color
  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.purple;
      case 'front_desk':
        return Colors.blue;
      case 'pastor':
        return Colors.green;
      case 'deacon':
        return Colors.orange;
      case 'elder':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }
}