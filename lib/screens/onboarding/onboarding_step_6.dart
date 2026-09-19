import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';
import '../../services/localization_service.dart';

class OnboardingStep6 extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final Function(String) onWakeUpTimeChanged;
  final Function(String) onSleepTimeChanged;
  final String initialWakeUpTime;
  final String initialSleepTime;
  final AppLocale locale;

  const OnboardingStep6({
    super.key,
    required this.onNext,
    required this.onPrevious,
    required this.onWakeUpTimeChanged,
    required this.onSleepTimeChanged,
    this.initialWakeUpTime = '08:00',
    this.initialSleepTime = '22:00',
    required this.locale,
  });

  @override
  State<OnboardingStep6> createState() => _OnboardingStep6State();
}

class _OnboardingStep6State extends State<OnboardingStep6> {
  late String _wakeUpTime;
  late String _sleepTime;

  @override
  void initState() {
    super.initState();
    _wakeUpTime = widget.initialWakeUpTime;
    _sleepTime = widget.initialSleepTime;
  }

  Future<void> _selectTime(BuildContext context, bool isWakeUp) async {
    final timeString = isWakeUp ? _wakeUpTime : _sleepTime;
    final parts = timeString.split(':');
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
    );

    if (picked != null) {
      setState(() {
        final time = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
        if (isWakeUp) {
          _wakeUpTime = time;
          widget.onWakeUpTimeChanged(time);
        } else {
          _sleepTime = time;
          widget.onSleepTimeChanged(time);
        }
      });
    }
  }

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
            localizations.onboardingWakeTime,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            localizations.onboardingWakeTimeSubtitle,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          _TimeSelector(
            label: localizations.onboardingWakeUp,
            time: _wakeUpTime,
            onTap: () => _selectTime(context, true),
          ),
          const SizedBox(height: 24),
          _TimeSelector(
            label: localizations.onboardingSleep,
            time: _sleepTime,
            onTap: () => _selectTime(context, false),
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
                  onPressed: widget.onNext,
                  child: Text(localizations.onboardingContinue),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeSelector extends StatelessWidget {
  final String label;
  final String time;
  final VoidCallback onTap;

  const _TimeSelector({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          border: Border.all(color: AppTheme.dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.access_time,
              color: AppTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}
