import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../../models/language.dart';
import '../../models/user_profile.dart';
import '../../services/localization_service.dart';

class OnboardingStep7 extends StatelessWidget {
  final VoidCallback onComplete;
  final VoidCallback onPrevious;
  final String name;
  final Language? nativeLanguage;
  final Language? learningLanguage;
  final LanguageLevel level;
  final AppLocale locale;

  const OnboardingStep7({
    super.key,
    required this.onComplete,
    required this.onPrevious,
    required this.name,
    this.nativeLanguage,
    this.learningLanguage,
    this.level = LanguageLevel.unknown,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations(locale);
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Text(
            localizations.onboardingSummary,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            localizations.onboardingSummarySubtitle,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummaryRow(
                    label: localizations.summaryName,
                    value: name,
                  ),
                  const Divider(height: 24),
                  _SummaryRow(
                    label: localizations.summaryNativeLanguage,
                    value: _getLanguageDisplayName(nativeLanguage, localizations),
                  ),
                  const Divider(height: 24),
                  _SummaryRow(
                    label: localizations.summaryLearningLanguage,
                    value: _getLanguageDisplayName(learningLanguage, localizations),
                  ),
                  const Divider(height: 24),
                  _SummaryRow(
                    label: localizations.summaryLevel,
                    value: _getLevelDisplayName(level, localizations),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onPrevious,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(localizations.onboardingBack),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onComplete,
                  child: Text(localizations.onboardingStart),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getLanguageDisplayName(Language? language, AppLocalizations localizations) {
    if (language == null) return localizations.summaryNotSelected;
    
    switch (language) {
      case Language.english:
        return localizations.langEnglish;
      case Language.russian:
        return localizations.langRussian;
      case Language.kazakh:
        return localizations.langKazakh;
    }
  }

  String _getLevelDisplayName(LanguageLevel level, AppLocalizations localizations) {
    switch (level) {
      case LanguageLevel.a0:
        return localizations.levelA0;
      case LanguageLevel.a1:
        return localizations.levelA1;
      case LanguageLevel.a2:
        return localizations.levelA2;
      case LanguageLevel.b1:
        return localizations.levelB1;
      case LanguageLevel.b2:
        return localizations.levelB2;
      case LanguageLevel.c1:
        return localizations.levelC1;
      case LanguageLevel.c2:
        return localizations.levelC2;
      case LanguageLevel.unknown:
        return localizations.levelUnknown;
    }
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
