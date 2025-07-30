import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:krishidoc/locale/app_localizations.dart';
import 'package:krishidoc/utils/colors.dart';
import 'package:provider/provider.dart';
import 'package:nb_utils/nb_utils.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/disease_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/settings_provider.dart';

// Screens
import 'screens/home_page.dart';
import 'screens/disease_result_page.dart';
import 'screens/llm_chat_page.dart';
import 'screens/history_page.dart';
import 'screens/login_page.dart';
import 'screens/settings_page.dart';

// Utils
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initialize(); // Initialize nb_utils
  await Firebase.initializeApp(); // Uncomment if using Firebase
  runApp(const KrishiDocApp());
}

class KrishiDocApp extends StatelessWidget {
  const KrishiDocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DiseaseProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return MaterialApp(
            title: AppStrings.appName,
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primaryColor: primaryColor,
              colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
              useMaterial3: true,
              fontFamily: 'Roboto',
            ),
            locale: Locale(settings.language, ''),
            localizationsDelegates: const [
              AppLocalizations(), // Only custom delegate
            ],
            supportedLocales: const [
              Locale('en', ''),
              Locale('np', ''),
              Locale('hi', ''),
              Locale('ar', ''),
              Locale('fr', ''),
              Locale('de', ''),
            ],
            initialRoute: '/',
            routes: {
              '/': (_) => const HomePage(),
              '/diseaseResult': (_) => const DiseaseResultPage(),
              '/llmChat': (context) => const LlmChatPage(),
              '/history': (context) => const HistoryPage(),
              '/login': (context) => const LoginPage(),
              '/settings': (context) => const SettingsPage(),
            },
          );
        },
      ),
    );
  }
}
