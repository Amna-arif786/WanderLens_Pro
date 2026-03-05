import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wanderlens/theme.dart';
import 'package:wanderlens/screens/auth/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:wanderlens/services/theme_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeService(),
      child: const WanderLensApp(),
    ),
  );
}

class WanderLensApp extends StatelessWidget {
  const WanderLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Accessing the theme service to listen for changes..
    final themeService = Provider.of<ThemeService>(context);

    return MaterialApp(
      title: 'WanderLens - Travel Social Media',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      // Switching between Light and Dark modes based on user preference..
      themeMode: themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}
