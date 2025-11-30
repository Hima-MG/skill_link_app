import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:skill_link_app/screens/Splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const SKillLink());
}

class SKillLink extends StatelessWidget {
  const SKillLink({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: SplashScreen());
  }
}
