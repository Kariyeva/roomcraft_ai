import 'package:flutter/material.dart';

import 'screens/01_splash.dart';
import 'screens/02_login.dart';
import 'screens/03_mode_select.dart';
import 'screens/04_ai_create.dart';
import 'screens/05_result.dart';
import 'screens/06_editor.dart';

class RoomCraftApp extends StatelessWidget {
  const RoomCraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RoomCraft AI',
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/mode': (context) => const ModeSelectScreen(),
        '/ai_create': (context) => const AiCreateScreen(),
        '/result': (context) => const ResultScreen(),
        '/editor': (context) => const EditorScreen(),
      },
    );
  }
}
