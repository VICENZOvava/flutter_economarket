import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../style/colors.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/ecomarket_logo.dart';
import '../widgets/green_button.dart';
import 'main_navigation.dart';
import 'register_page.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showMessage('Informe seu e-mail e sua senha.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ApiClient.instance.login(email, password);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigation()),
        (_) => false,
      );
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const EcoMarketLogo(iconSize: 44, textSize: 27),
              const SizedBox(height: 38),
              const Text(
                'Bem-vindo de volta 👋',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.7,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Entre para comparar preços e economizar',
                style: TextStyle(color: Color(0xFF777777), fontSize: 15),
              ),
              const SizedBox(height: 38),
              const _Label('E-mail'),
              const SizedBox(height: 10),
              CustomTextField(
                controller: _emailController,
                hint: 'seu@email.com',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 20),
              const _Label('Senha'),
              const SizedBox(height: 10),
              CustomTextField(
                controller: _passwordController,
                hint: '•••••••••',
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _showMessage(
                    'A recuperação de senha não está disponível nesta API.',
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.only(top: 5),
                  ),
                  child: const Text(
                    'Esqueci minha senha',
                    style: TextStyle(
                      color: AppColors.green,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 7),
              GreenButton(
                text: _isLoading ? 'Entrando...' : 'Entrar',
                onPressed: _isLoading ? null : _login,
              ),
              const SizedBox(height: 27),
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    Text(
                      'Não tem conta? ',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 15,
                      ),
                    ),
                    GestureDetector(
                      onTap: _isLoading
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              );
                            },
                      child: const Text(
                        'Criar conta',
                        style: TextStyle(
                          color: AppColors.green,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.text,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
