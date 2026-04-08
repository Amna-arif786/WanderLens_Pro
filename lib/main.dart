import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:wanderlens/screens/auth/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:wanderlens/services/theme_service.dart';
import 'package:wanderlens/services/fcm_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file before anything else
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Google Sign-In singleton (must be called exactly once).
  await GoogleSignIn.instance.initialize();

  // Initialise push notifications: requests permission, saves FCM token,
  // registers background/terminated message handlers.
  await FCMService.initialize();

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
      themeMode: themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal, // primary color
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      home: const SplashScreen(),
    );
  }
}
