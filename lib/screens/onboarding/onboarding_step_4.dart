import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../../services/localization_service.dart';

class OnboardingStep4 extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final Function(String) onNameChanged;
  final String initialName;
  final AppLocale locale;

  const OnboardingStep4({
    super.key,
    required this.onNext,
    required this.onPrevious,
    required this.onNameChanged,
    this.initialName = '',
    required this.locale,
  });

  @override
  State<OnboardingStep4> createState() => _OnboardingStep4State();
}

class _OnboardingStep4State extends State<OnboardingStep4> {
  late TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleNext() {
    if (_formKey.currentState!.validate()) {
      widget.onNameChanged(_controller.text.trim());
      widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations(widget.locale);
    
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            Text(
              localizations.onboardingName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              localizations.onboardingNameSubtitle,
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: localizations.onboardingNameHint,
              ),
              textCapitalization: TextCapitalization.words,
              // No input formatters - allow any Unicode characters
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return localizations.onboardingNameError;
                }
                return null;
              },
              onFieldSubmitted: (_) => _handleNext(),
            ),
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
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _handleNext,
                    child: Text(localizations.onboardingContinue),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
