import 'package:flutter/material.dart';
import 'home_backend_page.dart';
import 'lista_backend_page.dart';
import 'comparar_backend_page.dart';
import 'promocoes_backend_page.dart';
import 'perfil_backend_page.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  static const List<Widget> _pages = [
    HomeBackendPage(),
    ListaBackendPage(),
    CompararBackendPage(),
    PromocoesBackendPage(),
    PerfilBackendPage(),
  ];

  static const List<BottomNavigationBarItem> _navItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.home_outlined),
      activeIcon: Icon(Icons.home),
      label: 'Início',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.list_alt_outlined),
      activeIcon: Icon(Icons.list_alt),
      label: 'Lista',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.bar_chart_outlined),
      activeIcon: Icon(Icons.bar_chart),
      label: 'Comparar',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.local_offer_outlined),
      activeIcon: Icon(Icons.local_offer),
      label: 'Promoções',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Perfil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        items: _navItems,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
