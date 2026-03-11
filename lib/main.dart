import 'package:flutter/material.dart';
import 'package:studybuddy_client/theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:studybuddy_client/screens/login_screen.dart';
import 'package:studybuddy_client/screens/upload_screen.dart';

import 'package:studybuddy_client/services/auth_service.dart';
import 'package:studybuddy_client/services/theme_service.dart';
import 'package:studybuddy_client/widgets/animated_background.dart';
import 'package:studybuddy_client/firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint("Main: Starting application initialization...");

  try {
    await dotenv.load(fileName: ".env");
    debugPrint("Main: .env loaded.");

    // Initialize Firebase with the generated configurations for the current platform
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("Main: Firebase initialized.");

    // Ensure Google Sign-In is initialized before the UI builds (avoids "Bad state" on Web)
    // On Windows/Linux, AuthService.initialize() now handles skipping unsupported sign-in.
    await AuthService().initialize();
    debugPrint("Main: AuthService initialized.");
  } catch (e) {
    debugPrint("Main: Critical error during initialization: $e");
    // We continue so the app at least opens, though some features might fail.
  }

  runApp(const StudyBuddyApp());
}

class StudyBuddyApp extends StatelessWidget {
  const StudyBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService(),
      builder: (context, _) {
        return MaterialApp(
          title: 'StudyBuddy AI',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeService().themeMode,
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            return AnimatedGradientBackground(child: child!);
          },
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasData) {
                return const UploadScreen();
              }
              return const LoginScreen();
            },
          ),
        );
      },
    );
  }
}
