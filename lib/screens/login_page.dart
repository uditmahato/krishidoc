import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:krishidoc/utils/colors.dart';
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
      backgroundColor: background, // Use background from colors.dart
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Card(
              color: cardColor, // Use cardColor from colors.dart
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: borderColor,
                  width: 1,
                ), // Use borderColor
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // App Logo
                    Image.asset(
                      'assets/icons/krishi_logo.png', // Consistent with home_page.dart
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppStrings.appName,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color:
                            primaryColor, // Use primaryColor from colors.dart
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Email Field
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(
                        color: textPrimaryLightColor,
                      ), // Use textPrimaryLightColor
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          Icons.email,
                          color: iconColor,
                        ), // Use iconColor
                        labelText: 'Email',
                        labelStyle: TextStyle(
                          color: textSecondaryLightColor,
                        ), // Use textSecondaryLightColor
                        filled: true,
                        fillColor: primaryColor.withOpacity(
                          0.1,
                        ), // Use primaryColor
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: borderColor,
                          ), // Use borderColor
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: borderColor,
                          ), // Use borderColor
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: primaryColor,
                            width: 2,
                          ), // Use primaryColor
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    TextField(
                      controller: _password,
                      obscureText: true,
                      style: TextStyle(
                        color: textPrimaryLightColor,
                      ), // Use textPrimaryLightColor
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          Icons.lock,
                          color: iconColor,
                        ), // Use iconColor
                        labelText: 'Password',
                        labelStyle: TextStyle(
                          color: textSecondaryLightColor,
                        ), // Use textSecondaryLightColor
                        filled: true,
                        fillColor: primaryColor.withOpacity(
                          0.1,
                        ), // Use primaryColor
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: borderColor,
                          ), // Use borderColor
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: borderColor,
                          ), // Use borderColor
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: primaryColor,
                            width: 2,
                          ), // Use primaryColor
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Error Text
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                errorBackGroundColor, // Use errorBackGroundColor
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: errorTextColor, // Use errorTextColor
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Login Button
                    _isLoading
                        ? CircularProgressIndicator(
                            color: progressIndicatorColor,
                          ) // Use progressIndicatorColor
                        : CustomButton(
                            label: 'Login',
                            icon: Icons.login,
                            color: primaryColor, // Use primaryColor
                            textColor: textPrimaryDarkColor, // White text/icon
                            onPressed: () async {
                              setState(() => _isLoading = true);
                              try {
                                await authProvider.signIn(
                                  _email.text.trim(),
                                  _password.text.trim(),
                                );
                                Navigator.pop(context);
                              } catch (_) {
                                setState(
                                  () => _error =
                                      'Login failed. Check credentials.',
                                );
                              }
                              setState(() => _isLoading = false);
                            },
                          ),

                    const SizedBox(height: 16),

                    // Forgot Password Button
                    TextButton(
                      onPressed: () {
                        // TODO: Implement forgot password logic
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Forgot Password feature is not implemented yet.',
                              style: TextStyle(color: textPrimaryDarkColor),
                            ),
                            backgroundColor: accent, // Use accent
                          ),
                        );
                      },
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: accent, // Use accent
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }
}
