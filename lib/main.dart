import 'package:flutter/material.dart';

import 'services/firebase_google_auth_service.dart';
import 'style/theme.dart';
import 'ui/splash_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseGoogleAuthService.initialize();
  runApp(const EconoMarketApp());
}

class EconoMarketApp extends StatelessWidget {
  const EconoMarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EconoMarket',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
