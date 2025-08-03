
import 'package:flutter/material.dart';
import 'package:krishidoc/utils/colors.dart';
import '../widgets/custom_button.dart';
import '../locale/base_language_key.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();
  bool _isLoading = false;
  String? _error;

  // Basic email validation (checks for @ and domain)
  bool _isValidEmail(String email) {
    return email.contains('@') && email.contains('.') && email.length > 5;
  }

  // Password validation (8+ chars, uppercase, lowercase, number, special char)
  bool _isValidPassword(String password) {
    final regex = RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$');
    return regex.hasMatch(password);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final BaseLanguage lang = BaseLanguage.of(context);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Card(
              color: cardColor,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: borderColor, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // App Logo
                    Image.asset(
                      'assets/icons/krishi_logo.png',
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      lang.appName,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Name Field
                    TextField(
                      controller: _name,
                      keyboardType: TextInputType.name,
                      style: TextStyle(color: textPrimaryLightColor),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.person, color: iconColor),
                        labelText: lang.nameLabel,
                        labelStyle: TextStyle(color: textSecondaryLightColor),
                        filled: true,
                        fillColor: primaryColor.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Email Field
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      style: TextStyle(color: textPrimaryLightColor),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.email, color: iconColor),
                        labelText: lang.emailLabel,
                        labelStyle: TextStyle(color: textSecondaryLightColor),
                        filled: true,
                        fillColor: primaryColor.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    TextField(
                      controller: _password,
                      obscureText: true,
                      style: TextStyle(color: textPrimaryLightColor),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.lock, color: iconColor),
                        labelText: lang.passwordLabel,
                        labelStyle: TextStyle(color: textSecondaryLightColor),
                        filled: true,
                        fillColor: primaryColor.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Confirm Password Field
                    TextField(
                      controller: _confirmPassword,
                      obscureText: true,
                      style: TextStyle(color: textPrimaryLightColor),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.lock, color: iconColor),
                        labelText: lang.confirmPasswordLabel,
                        labelStyle: TextStyle(color: textSecondaryLightColor),
                        filled: true,
                        fillColor: primaryColor.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: primaryColor, width: 2),
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
                            color: errorBackGroundColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: errorTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Sign Up Button
                    _isLoading
                        ? CircularProgressIndicator(color: progressIndicatorColor)
                        : CustomButton(
                            label: lang.signupButton,
                            icon: Icons.person_add,
                            color: primaryColor,
                            textColor: textPrimaryDarkColor,
                            onPressed: () {
                              setState(() {
                                _error = null;
                                _isLoading = true;
                              });

                              if (_name.text.trim().isEmpty) {
                                setState(() {
                                  _error = lang.nameLabel + ' is required.';
                                  _isLoading = false;
                                });
                                return;
                              }

                              if (!_isValidEmail(_email.text.trim())) {
                                setState(() {
                                  _error = lang.invalidEmail;
                                  _isLoading = false;
                                });
                                return;
                              }

                              if (!_isValidPassword(_password.text.trim())) {
                                setState(() {
                                  _error = lang.invalidPassword;
                                  _isLoading = false;
                                });
                                return;
                              }

                              if (_password.text.trim() != _confirmPassword.text.trim()) {
                                setState(() {
                                  _error = lang.passwordsDoNotMatch;
                                  _isLoading = false;
                                });
                                return;
                              }

                              // Simulate signup success (no actual authorization)
                              setState(() => _isLoading = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    lang.signupSuccess,
                                    style: TextStyle(color: textPrimaryDarkColor),
                                  ),
                                  backgroundColor: accent,
                                ),
                              );
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                          ),

                    const SizedBox(height: 16),

                    // Login Link
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/login');
                      },
                      child: Text(
                        lang.alreadyHaveAccount,
                        style: TextStyle(
                          color: accent,
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
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }
}
