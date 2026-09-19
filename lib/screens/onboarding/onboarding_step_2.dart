import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../../models/language.dart';
import '../../services/localization_service.dart';

class OnboardingStep2 extends StatelessWidget {
  final VoidCallback onNext;
  final Function(Language) onLanguageSelected;
  final Language? selectedLanguage;
  final AppLocale locale;

  const OnboardingStep2({
    super.key,
    required this.onNext,
    required this.onLanguageSelected,
    this.selectedLanguage,
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
            localizations.onboardingNativeLanguage,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            localizations.onboardingNativeLanguageSubtitle,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          ...Language.values.map((language) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _LanguageOption(
                language: language,
                isSelected: selectedLanguage == language,
                onTap: () {
                  onLanguageSelected(language);
                },
                locale: locale,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final Language language;
  final bool isSelected;
  final VoidCallback onTap;
  final AppLocale locale;

  const _LanguageOption({
    required this.language,
    required this.isSelected,
    required this.onTap,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations(locale);
    final displayName = language == Language.english 
        ? localizations.langEnglish
        : language == Language.russian 
            ? localizations.langRussian
            : localizations.langKazakh;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.1) : AppTheme.cardBackground,
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                displayName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppTheme.primaryColor,
              ),
          ],
        ),
      ),
    );
  }
}
