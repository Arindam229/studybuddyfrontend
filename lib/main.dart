import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:studybuddy_client/screens/chat_screen.dart';
import 'package:studybuddy_client/screens/login_screen.dart';
import 'package:studybuddy_client/screens/upload_screen.dart';

import 'package:studybuddy_client/services/auth_service.dart';
import 'package:studybuddy_client/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase with the generated configurations for the current platform
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Ensure Google Sign-In is initialized before the UI builds (avoids "Bad state" on Web)
  await AuthService().initialize();

  runApp(const StudyBuddyApp());
}

class StudyBuddyApp extends StatelessWidget {
  const StudyBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StudyBuddy AI',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[50],
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
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
  }
}
