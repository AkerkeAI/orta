import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../services/localization_service.dart';
import 'home_screen.dart';
import '../ai_chat/ai_chat_screen.dart';
import '../library/library_screen.dart';
import '../settings/settings_screen.dart';

class MainScreen extends StatefulWidget {
  final UserProfile userProfile;
  final VoidCallback onResetOnboarding;
  final AppLocale currentLocale;

  const MainScreen({
    super.key,
    required this.userProfile,
    required this.onResetOnboarding,
    required this.currentLocale,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late AppLocale _currentLocale;
  final List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _currentLocale = widget.currentLocale;
    _initializeScreens();
  }

  void _initializeScreens() {
    _screens.clear();
    _screens.addAll([
      HomeScreen(
        userProfile: widget.userProfile,
        currentLocale: _currentLocale,
        onNavigateToAi: _navigateToAiWithTask,
      ),
      AiChatScreen(
        currentLocale: _currentLocale,
        userProfile: widget.userProfile,
      ),
      LibraryScreen(currentLocale: _currentLocale),
      SettingsScreen(
        userProfile: widget.userProfile,
        onResetOnboarding: widget.onResetOnboarding,
        currentLocale: _currentLocale,
      ),
    ]);
  }

  void _navigateToAiWithTask(String task) {
    setState(() {
      _currentIndex = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations(_currentLocale);
    
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: localizations.navHome,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.chat_bubble_outline),
            activeIcon: const Icon(Icons.chat_bubble),
            label: localizations.navAi,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.library_books_outlined),
            activeIcon: const Icon(Icons.library_books),
            label: localizations.navLibrary,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings_outlined),
            activeIcon: const Icon(Icons.settings),
            label: localizations.navSettings,
          ),
        ],
      ),
    );
  }
}
