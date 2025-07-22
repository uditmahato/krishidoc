import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  // await Firebase.initializeApp();
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
      child: MaterialApp(
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: AppColors.primary,
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        initialRoute: '/',
        routes: {
  '/': (_) => const HomePage(),
  '/classifying': (_) => throw UnimplementedError(), // not used if you push via MaterialPageRoute
  '/diseaseResult': (_) => const DiseaseResultPage(),
          '/llmChat': (context) => const LlmChatPage(),
          '/history': (context) => const HistoryPage(),
          '/login': (context) => const LoginPage(),
          '/settings': (context) => const SettingsPage(),
        },
      ),
    );
  }
}
