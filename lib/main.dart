//inicia o Flutter e abre a tela de splash

import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter/material.dart';

import 'services/api_client.dart';
import 'services/firebase_google_auth_service.dart';
import 'style/theme.dart';
import 'ui/login_screen.dart';
import 'ui/main_navigation.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await FirebaseGoogleAuthService.initialize();
  final user = await ApiClient.instance.restoreSession();
  runApp(EconoMarketApp(isAuthenticated: user != null));
  FlutterNativeSplash.remove();
}

class EconoMarketApp extends StatelessWidget {
  final bool isAuthenticated;

  const EconoMarketApp({super.key, required this.isAuthenticated});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EconoMarket',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: isAuthenticated ? const MainNavigation() : const LoginScreen(),
    );
  }
}
