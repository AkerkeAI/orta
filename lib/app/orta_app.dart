import 'package:flutter/material.dart';

import '../models/language.dart';
import '../models/life_context.dart';
import '../services/storage_service.dart';
import '../services/life_repository.dart';
import '../services/localization_service.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/core/orta_shell.dart';

class OrtaApp extends StatefulWidget {
  final LifeDataStorage? storage;
  const OrtaApp({super.key, this.storage});
  @override
  State<OrtaApp> createState() => _OrtaAppState();
}

class _OrtaAppState extends State<OrtaApp> {
  LifeRepository? _repository;
  bool _loadError = false;
  bool _busy = false;
  AppLocale? _onboardingLocale;

  AppLocale get _locale => _repository?.data.onboardingCompleted == true
      ? AppLocaleExtension.fromLanguage(
          _repository!.data.life.interfaceLanguage,
        )
      : _onboardingLocale ?? AppLocalizations.of(context).locale;

  AppLocalizations get _strings => AppLocalizations(_locale);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadError = false);
    try {
      final repository = await LifeRepository.open(
        widget.storage ?? StorageService(),
      );
      if (!mounted) {
        repository.dispose();
        return;
      }
      repository.addListener(_refreshLocale);
      setState(() => _repository = repository);
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = true);
      }
    }
  }

  void _refreshLocale() {
    if (mounted) setState(() {});
  }

  Future<void> _completeOnboarding(LifeContext life) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _repository!.completeOnboarding(life);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_strings.get('data_save_error')),
            action: SnackBarAction(
              label: _strings.get('retry'),
              onPressed: () => _completeOnboarding(life),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    final previousLocale = _locale;
    try {
      await _repository!.reset();
      if (mounted) setState(() => _onboardingLocale = previousLocale);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_strings.get('data_reset_error')),
            action: SnackBarAction(
              label: _strings.get('retry'),
              onPressed: _reset,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Localizations.override(
    context: context,
    locale: Locale(_locale.languageCode),
    child: Builder(builder: _buildLocalized),
  );

  Widget _buildLocalized(BuildContext context) {
    if (_loadError) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _strings.get('data_load_error'),
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: _load,
                    child: Text(_strings.get('retry')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final repository = _repository;
    if (repository == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!repository.data.onboardingCompleted) {
      return Stack(
        children: [
          OnboardingScreen(
            onComplete: _completeOnboarding,
            onLocaleChange: (Language language) => setState(
              () =>
                  _onboardingLocale = AppLocaleExtension.fromLanguage(language),
            ),
            currentLocale: _locale,
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x55000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      );
    }
    return OrtaShell(
      repository: repository,
      onResetOnboarding: _reset,
      currentLocale: _locale,
    );
  }

  @override
  void dispose() {
    _repository?.removeListener(_refreshLocale);
    _repository?.dispose();
    super.dispose();
  }
}
