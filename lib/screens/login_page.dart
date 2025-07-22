// lib/screens/login_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_button.dart';
import '../utils/constants.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.colorScheme.primary.withOpacity(0.8), theme.colorScheme.primaryContainer],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  // App Logo / Title
                  FlutterLogo(size: 80),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.appName,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Email Field
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: theme.colorScheme.onPrimary),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.email),
                      labelText: 'Email',
                      labelStyle: TextStyle(color: theme.colorScheme.onPrimary.withOpacity(0.8)),
                      filled: true,
                      fillColor: theme.colorScheme.primary.withOpacity(0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextField(
                    controller: _password,
                    obscureText: true,
                    style: TextStyle(color: theme.colorScheme.onPrimary),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock),
                      labelText: 'Password',
                      labelStyle: TextStyle(color: theme.colorScheme.onPrimary.withOpacity(0.8)),
                      filled: true,
                      fillColor: theme.colorScheme.primary.withOpacity(0.2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Error Text
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _error!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Login Button
                  _isLoading
                      ? CircularProgressIndicator(color: theme.colorScheme.onPrimary)
                      : CustomButton(
                          label: 'Login',
                          icon: Icons.login,
                          color: theme.colorScheme.onPrimary,
                          onPressed: () async {
                            setState(() => _isLoading = true);
                            try {
                              await authProvider.signIn(
                                _email.text.trim(),
                                _password.text.trim(),
                              );
                              Navigator.pop(context);
                            } catch (_) {
                              setState(() => _error = 'Login failed. Check credentials.');
                            }
                            setState(() => _isLoading = false);
                          },
                        ),

                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      // TODO: Forgot password logic
                    },
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(color: theme.colorScheme.onPrimary.withOpacity(0.8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
