import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../../services/localization_service.dart';

class OnboardingStep1 extends StatelessWidget {
  final VoidCallback onNext;
  final AppLocale locale;

  const OnboardingStep1({
    super.key,
    required this.onNext,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations(locale);
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          // Logo
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(
              child: Text(
                'O',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            localizations.onboardingWelcomeTitle,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            localizations.onboardingWelcomeSubtitle,
            style: const TextStyle(
              fontSize: 18,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNext,
              child: Text(localizations.onboardingContinue),
            ),
          ),
        ],
      ),
    );
  }
}
