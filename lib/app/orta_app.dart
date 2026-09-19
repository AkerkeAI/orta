import 'package:flutter/material.dart';

import '../models/language.dart';
import '../models/life_context.dart';
import '../services/storage_service.dart';
import '../services/localization_service.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/core/orta_shell.dart';

class OrtaApp extends StatefulWidget {
  const OrtaApp({super.key});

  @override
  State<OrtaApp> createState() => _OrtaAppState();
}

class _OrtaAppState extends State<OrtaApp> {
  final StorageService _storageService = StorageService();
  bool _isLoading = true;
  bool _onboardingCompleted = false;
  LifeContext? _lifeContext;
  AppLocale _currentLocale = AppLocale.english;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    final completed = await _storageService.isOnboardingCompleted();
    final context = await _storageService.getLifeContext();

    if (mounted) {
      setState(() {
        _onboardingCompleted = completed;
        _lifeContext = context;
        _currentLocale = context != null
            ? AppLocaleExtension.fromLanguage(context.interfaceLanguage)
            : AppLocale.english;
        _isLoading = false;
      });
    }
  }

  Future<void> _completeOnboarding(LifeContext lifeContext) async {
    await _storageService.saveLifeContext(lifeContext);
    await _storageService.setOnboardingCompleted(true);

    if (mounted) {
      setState(() {
        _onboardingCompleted = true;
        _lifeContext = lifeContext;
        _currentLocale = AppLocaleExtension.fromLanguage(
          lifeContext.interfaceLanguage,
        );
      });
    }
  }

  Future<void> _resetOnboarding() async {
    await _storageService.clearUserData();

    if (mounted) {
      setState(() {
        _onboardingCompleted = false;
        _lifeContext = null;
        _currentLocale = AppLocale.english;
      });
    }
  }

  Future<void> _updateLifeContext(LifeContext context) async {
    await _storageService.saveLifeContext(context);
    if (mounted) {
      setState(() {
        _lifeContext = context;
        _currentLocale = AppLocaleExtension.fromLanguage(
          context.interfaceLanguage,
        );
      });
    }
  }

  void _updateLocale(Language nativeLanguage) {
    setState(() {
      _currentLocale = AppLocaleExtension.fromLanguage(nativeLanguage);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_onboardingCompleted) {
      return OnboardingScreen(
        onComplete: _completeOnboarding,
        onLocaleChange: _updateLocale,
        currentLocale: _currentLocale,
      );
    }

    return OrtaShell(
      lifeContext:
          _lifeContext ??
          const LifeContext(name: 'there', interfaceLanguage: Language.english),
      onContextChanged: _updateLifeContext,
      onResetOnboarding: _resetOnboarding,
      currentLocale: _currentLocale,
    );
  }
}
