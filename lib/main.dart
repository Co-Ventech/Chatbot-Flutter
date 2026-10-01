import 'package:flutter/material.dart';
import 'package:chatbotapp/constants/constants.dart';
import 'package:chatbotapp/themes/my_theme.dart';
import 'package:chatbotapp/providers/ai_config_provider.dart';
import 'package:chatbotapp/providers/chat_provider.dart';
import 'package:chatbotapp/providers/settings_provider.dart';
import 'package:chatbotapp/providers/user_profile_provider.dart';
import 'package:chatbotapp/providers/voice_input_provider.dart';
import 'package:chatbotapp/screens/home_screen.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ChatProvider.initHive();

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (context) => ChatProvider()),
      ChangeNotifierProvider(
        create: (context) => SettingsProvider()..getSavedSettings(),
      ),
      ChangeNotifierProvider(
        create: (context) => UserProfileProvider()..loadUser(),
      ),
      ChangeNotifierProvider(create: (context) => VoiceInputProvider()),
      ChangeNotifierProvider(create: (context) => AiConfigProvider()),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();

    return MaterialApp(
      title: Constants.appTitle,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: settingsProvider.themeMode,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
