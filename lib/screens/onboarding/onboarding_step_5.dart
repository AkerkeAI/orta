import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../../models/user_profile.dart';
import '../../services/localization_service.dart';

class OnboardingStep5 extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final Function(LanguageLevel) onLevelSelected;
  final LanguageLevel selectedLevel;
  final AppLocale locale;

  const OnboardingStep5({
    super.key,
    required this.onNext,
    required this.onPrevious,
    required this.onLevelSelected,
    this.selectedLevel = LanguageLevel.unknown,
    required this.locale,
  });

  @override
  State<OnboardingStep5> createState() => _OnboardingStep5State();
}

class _OnboardingStep5State extends State<OnboardingStep5> {
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations(widget.locale);
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Text(
            localizations.onboardingLevel,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            localizations.onboardingLevelSubtitle,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          ...LanguageLevel.values.map((level) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _LevelOption(
                level: level,
                isSelected: widget.selectedLevel == level,
                onTap: () {
                  widget.onLevelSelected(level);
                  if (level == LanguageLevel.unknown) {
                    // Show dialog and continue
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(localizations.onboardingAiAssessment),
                        content: Text(localizations.onboardingAiAssessmentPlaceholder),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(localizations.onboardingOk),
                          ),
                        ],
                      ),
                    );
                  } else {
                    widget.onNext();
                  }
                },
                locale: widget.locale,
              ),
            );
          }),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onPrevious,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(localizations.onboardingBack),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LevelOption extends StatelessWidget {
  final LanguageLevel level;
  final bool isSelected;
  final VoidCallback onTap;
  final AppLocale locale;

  const _LevelOption({
    required this.level,
    required this.isSelected,
    required this.onTap,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations(locale);
    final displayName = _getLevelDisplayName(level, localizations);
    
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
