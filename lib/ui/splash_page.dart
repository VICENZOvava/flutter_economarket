import 'dart:async';
import 'package:flutter/material.dart';
import '../style/colors.dart';
import '../services/api_client.dart';
import '../widgets/ecomarket_logo.dart';
import 'login_screen.dart';
import 'main_navigation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _openApp();
  }

  Future<void> _openApp() async {
    final results = await Future.wait<Object?>([
      ApiClient.instance.restoreSession(),
      Future<void>.delayed(const Duration(milliseconds: 900)),
    ]);
    if (!mounted) return;
    final signedIn = results.first is UserProfile;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => signedIn ? const MainNavigation() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.green,
      body: SafeArea(
        child: Center(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Column(
              children: [
                const Spacer(flex: 4),
                Container(
                  width: 106,
                  height: 106,
                  decoration: BoxDecoration(
                    color: AppColors.greenLight,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.green.withValues(alpha: .18),
                        blurRadius: 25,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shopping_basket_outlined,
                    color: Colors.white,
                    size: 62,
                  ),
                ),
                const SizedBox(height: 26),
                const EcoMarketLogo(iconSize: 0, textSize: 36),
                const SizedBox(height: 12),
                const Text(
                  'Compare preços. Economize mais.',
                  style: TextStyle(
                    color: Color(0xFF777777),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(flex: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [_dot(true), _dot(false), _dot(false)],
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dot(bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: active ? 26 : 8,
      height: 8,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: active ? AppColors.green : const Color(0xFFE0E0E0),
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
