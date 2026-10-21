import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../style/colors.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/ecomarket_logo.dart';
import '../widgets/green_button.dart';
import 'main_navigation.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showMessage('Preencha nome, e-mail e senha.');
      return;
    }
    if (password.length < 6) {
      _showMessage('A senha deve ter pelo menos 6 caracteres.');
      return;
    }
    if (password != _confirmationController.text) {
      _showMessage('As senhas não coincidem.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ApiClient.instance.register(
        name: name,
        email: email,
        password: password,
      );
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
              const EcoMarketLogo(iconSize: 40, textSize: 24),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                label: const Text(
                  'Voltar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.text,
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 34),
              const Text(
                'Criar conta 🌿',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.7,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Junte-se a milhares que economizam todo mês',
                style: TextStyle(color: Color(0xFF777777), fontSize: 15),
              ),
              const SizedBox(height: 34),
              const _Label('Nome completo'),
              const SizedBox(height: 9),
              CustomTextField(
                controller: _nameController,
                hint: 'Ana Paula Silva',
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 19),
              const _Label('E-mail'),
              const SizedBox(height: 9),
              CustomTextField(
                controller: _emailController,
                hint: 'ana@email.com',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 19),
              const _Label('Senha'),
              const SizedBox(height: 9),
              CustomTextField(
                controller: _passwordController,
                hint: '•••••••••',
                obscureText: true,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 19),
              const _Label('Confirmar senha'),
              const SizedBox(height: 9),
              CustomTextField(
                controller: _confirmationController,
                hint: '•••••••••',
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _register(),
              ),
              const SizedBox(height: 24),
              GreenButton(
                text: _isLoading ? 'Criando conta...' : 'Criar conta',
                onPressed: _isLoading ? null : _register,
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
