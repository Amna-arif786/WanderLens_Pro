import 'package:flutter/material.dart';
import 'package:wanderlens/screens/auth/google_complete_profile_screen.dart';
import 'package:wanderlens/screens/auth/register_screen.dart';
import 'package:wanderlens/screens/auth/forget_password.dart';
import 'package:wanderlens/screens/main_navigation.dart';
import 'package:wanderlens/services/auth_service.dart';
import 'package:wanderlens/services/user_service.dart';

import '../../responsive/constrained_scaffold.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await UserService.login(
          _emailController.text.trim(), _passwordController.text);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainNavigation()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Login failed. Please check your email and password.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);

    try {
      final result = await AuthService.signInWithGoogle();

      // User cancelled the account picker
      if (result == null) return;

      if (!mounted) return;

      final bool isNewUser = result['isNewUser'] as bool;

      if (isNewUser) {
        // First time login → go to profile setup
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => GoogleCompleteProfileScreen(
              tempUserData:
                  Map<String, dynamic>.from(result['tempUserData'] as Map),
            ),
          ),
        );
      } else {
        // Existing user → go straight to the app
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainNavigation()),
        );
      }
    } catch (e) {
      if (mounted) {
        final message = _friendlyGoogleError(e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  /// Converts raw exception messages into user-friendly strings.
  String _friendlyGoogleError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('network') || lower.contains('socket')) {
      return 'No internet connection. Please try again.';
    }
    if (lower.contains('cancel')) {
      return 'Google sign-in was cancelled.';
    }
    if (lower.contains('account-exists-with-different-credential')) {
      return 'An account already exists with a different sign-in method for this email.';
    }
    if (lower.contains('id token') || lower.contains('idtoken')) {
      return 'Could not get Google credentials. Please try again.';
    }
    // Show the real message so it is easier to debug.
    final msg = raw.replaceAll('Exception: ', '');
    return msg.isNotEmpty ? msg : 'Google sign-in failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.travel_explore,
                        size: 40,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Welcome Back',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to continue your journey',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined,
                            color: Theme.of(context).colorScheme.primary),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) =>
                          (value == null || value.isEmpty)
                              ? 'Please enter your email'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline,
                            color: Theme.of(context).colorScheme.primary),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) =>
                          (value == null || value.isEmpty)
                              ? 'Please enter your password'
                              : null,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) =>
                                    const ForgetPasswordScreen())),
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            (_isLoading || _isGoogleLoading) ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Sign In',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Google Sign-In button ───────────────────────────────────────
              InkWell(
                onTap: (_isLoading || _isGoogleLoading)
                    ? null
                    : _signInWithGoogle,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: Colors.grey.shade300, width: 1.5),
                  ),
                  child: Center(
                    child: _isGoogleLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black54),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Image.asset('assets/google_Icon.png',
                                  height: 20.0, width: 20.0),
                              const SizedBox(width: 12),
                              const Text(
                                'Continue with Google',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black87),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Don\'t have an account? '),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (context) => const RegisterScreen())),
                    child: Text(
                      'Sign Up',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
