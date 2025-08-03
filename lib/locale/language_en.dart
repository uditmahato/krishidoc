import 'package:krishidoc/locale/base_language_key.dart';

class LanguageEn extends BaseLanguage {
  @override
  String get appName => 'KrishiDoc';

  @override
  String get welcome => 'Welcome to KrishiDoc!';

  @override
  String get welcomeSubtitle =>
      'Diagnose plant disease instantly and get expert advice in your language.';

  @override
  String get diagnoseButton => 'Diagnose Plant Disease';

  @override
  String get askButton => 'Ask AgriBot';

  @override
  String get history => 'History';

  @override
  String get settings => 'Settings';

  @override
  String get login => 'Login';

  @override
  String get logout => 'Logout';

  @override
  String get language => 'Language';

  @override
  String get voiceOutput => 'Voice Output';

  @override
  String get capturePhoto => 'Capture Photo';

  @override
  String get selectFromGallery => 'Select from Gallery';

  @override
  String get chatTitle => 'AgriBot Chat';

  @override
  String get chatInputHint => 'Ask about crop, disease, etc.';

  @override
  String get loginPrompt => 'Login to view your history.';

  @override
  String get noHistory => 'No history yet.';

  // 🔽 Newly added
  @override String get diagnosisResult => 'Diagnosis Result';
@override String get confidence => 'Confidence';
@override String get symptoms => 'Symptoms';
@override String get treatment => 'Treatment';
@override String get backToHome => 'Back to Home';
@override String get ofDiagnosis => 'of Diagnosis';
@override String get ok => 'OK';

@override String get symptomPrompt => 'Provide a concise list of 5–10 common and significant symptoms of {disease}.';
@override String get symptomInstruction => 'List only the symptom descriptions (one per line).';

@override String get treatmentPrompt => 'Provide 5–10 effective treatment plans for {disease}.';
@override String get treatmentInstruction => 'Tailored to local farming conditions. List each plan on its own line.';

 @override String get classifyingDisease => 'Classifying disease...';
@override String get pleaseWait => 'Please wait...';
@override String get treatments => 'Treatments';


@override
  String get emailLabel => 'Email';
  @override
  String get passwordLabel => 'Password';
  @override
  String get loginButton => 'Login';
  @override
  String get forgotPassword => 'Forgot Password?';
  @override
  String get loginFailed => 'Login failed. Check credentials.';
  @override
  String get forgotPasswordNotImplemented => 'Forgot Password feature is not implemented yet.';

 
  @override
  String get signupButton => 'Sign Up';
  @override
  String get nameLabel => 'Name';
  @override
  String get confirmPasswordLabel => 'Confirm Password';
  @override
  String get invalidEmail => 'Invalid email address. Must contain @ and a domain.';
  @override
  String get invalidPassword => 'Password must be at least 8 characters, with uppercase, lowercase, numbers, and special characters.';
  @override
  String get passwordsDoNotMatch => 'Passwords do not match.';
  @override
  String get signupFailed => 'Sign up failed. Please check your details.';
  @override
  String get signupSuccess => 'Sign up successful! Please log in.';
  @override
  String get alreadyHaveAccount => 'Already have an account? Login';
  @override
  String get resetPasswordButton => 'Reset Password';
  @override
  String get verificationCodeLabel => 'Verification Code';
  @override
  String get newPasswordLabel => 'New Password';
  @override
  String get passwordResetSuccess => 'Password reset successful! Please log in.';
  @override
  String get invalidVerificationCode => 'Invalid verification code.';
  @override
  String get dontHaveAccount => 'Don\'t have an account? Sign up';
}
