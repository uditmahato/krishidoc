
import 'package:flutter/material.dart';
import 'package:krishidoc/utils/colors.dart';
import '../widgets/custom_button.dart';
import '../locale/base_language_key.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _verificationCode = TextEditingController();
  final TextEditingController _newPassword = TextEditingController();
  final TextEditingController _confirmNewPassword = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _isCodeSent = false;

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

                    // Email Field
                    if (!_isCodeSent)
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

                    // Verification Code Field
                    if (_isCodeSent)
                      TextField(
                        controller: _verificationCode,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: textPrimaryLightColor),
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.vpn_key, color: iconColor),
                          labelText: lang.verificationCodeLabel,
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
                    if (_isCodeSent) const SizedBox(height: 16),

                    // New Password Field
                    if (_isCodeSent)
                      TextField(
                        controller: _newPassword,
                        obscureText: true,
                        style: TextStyle(color: textPrimaryLightColor),
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.lock, color: iconColor),
                          labelText: lang.newPasswordLabel,
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
                    if (_isCodeSent) const SizedBox(height: 16),

                    // Confirm New Password Field
                    if (_isCodeSent)
                      TextField(
                        controller: _confirmNewPassword,
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

                    // Action Button
                    _isLoading
                        ? CircularProgressIndicator(color: progressIndicatorColor)
                        : CustomButton(
                            label: _isCodeSent ? lang.resetPasswordButton : lang.forgotPassword,
                            icon: _isCodeSent ? Icons.lock_open : Icons.send,
                            color: primaryColor,
                            textColor: textPrimaryDarkColor,
                            onPressed: () {
                              setState(() {
                                _error = null;
                                _isLoading = true;
                              });

                              if (!_isCodeSent) {
                                // Validate email and simulate sending code
                                if (!_isValidEmail(_email.text.trim())) {
                                  setState(() {
                                    _error = lang.invalidEmail;
                                    _isLoading = false;
                                  });
                                  return;
                                }
                                setState(() {
                                  _isCodeSent = true;
                                  _isLoading = false;
                                });
                              } else {
                                // Validate verification code and passwords
                                if (_verificationCode.text.trim() != '123456') { // Dummy code
                                  setState(() {
                                    _error = lang.invalidVerificationCode;
                                    _isLoading = false;
                                  });
                                  return;
                                }

                                if (!_isValidPassword(_newPassword.text.trim())) {
                                  setState(() {
                                    _error = lang.invalidPassword;
                                    _isLoading = false;
                                  });
                                  return;
                                }

                                if (_newPassword.text.trim() != _confirmNewPassword.text.trim()) {
                                  setState(() {
                                    _error = lang.passwordsDoNotMatch;
                                    _isLoading = false;
                                  });
                                  return;
                                }

                                // Simulate password reset success
                                setState(() => _isLoading = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      lang.passwordResetSuccess,
                                      style: TextStyle(color: textPrimaryDarkColor),
                                    ),
                                    backgroundColor: accent,
                                  ),
                                );
                                Navigator.pushReplacementNamed(context, '/login');
                              }
                            },
                          ),

                    const SizedBox(height: 16),

                    // Back to Login Link
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/login');
                      },
                      child: Text(
                        lang.loginButton,
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
    _email.dispose();
    _verificationCode.dispose();
    _newPassword.dispose();
    _confirmNewPassword.dispose();
    super.dispose();
  }
}
