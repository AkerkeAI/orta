import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../models/language.dart';
import '../../app/theme/app_theme.dart';
import '../../services/localization_service.dart';

class SettingsScreen extends StatefulWidget {
  final UserProfile userProfile;
  final VoidCallback onResetOnboarding;
  final AppLocale currentLocale;

  const SettingsScreen({
    super.key,
    required this.userProfile,
    required this.onResetOnboarding,
    required this.currentLocale,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _notificationsEnabled;

  @override
  void initState() {
    super.initState();
    _notificationsEnabled = widget.userProfile.notificationsEnabled;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations(widget.currentLocale);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.navSettings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile section
          _SectionHeader(title: localizations.settingsProfile),
          _SettingsTile(
            icon: Icons.person,
            label: localizations.settingsName,
            value: widget.userProfile.name,
          ),
          _SettingsTile(
            icon: Icons.language,
            label: localizations.settingsNativeLanguage,
            value: _getLanguageDisplayName(widget.userProfile.nativeLanguage, localizations),
          ),
          _SettingsTile(
            icon: Icons.translate,
            label: localizations.settingsLearningLanguage,
            value: _getLanguageDisplayName(widget.userProfile.learningLanguage, localizations),
          ),
          _SettingsTile(
            icon: Icons.school,
            label: localizations.settingsCurrentLevel,
            value: widget.userProfile.level.shortName,
          ),
          const SizedBox(height: 24),
          
          // Learning section
          _SectionHeader(title: localizations.settingsLearning),
          _SettingsTile(
            icon: Icons.wb_sunny,
            label: localizations.settingsWakeUpTime,
            value: widget.userProfile.wakeUpTime,
          ),
          _SettingsTile(
            icon: Icons.bedtime,
            label: localizations.settingsSleepTime,
            value: widget.userProfile.sleepTime,
          ),
          const SizedBox(height: 24),
          
          // Notifications section
          _SectionHeader(title: localizations.settingsNotifications),
          _SwitchTile(
            icon: Icons.notifications,
            label: localizations.settingsEnableInteractions,
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
            },
          ),
          const SizedBox(height: 24),
          
          // App section
          _SectionHeader(title: localizations.settingsApp),
          _SettingsTile(
            icon: Icons.info,
            label: localizations.settingsAboutOrta,
            value: '${localizations.version} 0.1.1',
            onTap: () {
              _showAboutDialog(context, localizations);
            },
          ),
          const SizedBox(height: 24),
          
          // Reset onboarding
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.refresh,
                color: Colors.red,
              ),
              title: Text(
                localizations.settingsResetOnboarding,
                style: const TextStyle(color: Colors.red),
              ),
              subtitle: Text(localizations.settingsResetSubtitle),
              onTap: () {
                _showResetConfirmation(context, localizations);
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getLanguageDisplayName(Language language, AppLocalizations localizations) {
    switch (language) {
      case Language.english:
        return localizations.langEnglish;
      case Language.russian:
        return localizations.langRussian;
      case Language.kazakh:
        return localizations.langKazakh;
    }
  }

  void _showAboutDialog(BuildContext context, AppLocalizations localizations) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.aboutOrtaTitle),
        content: Text(localizations.aboutOrtaDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(localizations.settingsClose),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmation(BuildContext context, AppLocalizations localizations) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.settingsResetConfirmation),
        content: Text(localizations.settingsResetMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(localizations.settingsCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onResetOnboarding();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(localizations.settingsReset),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppTheme.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryColor),
        title: Text(label),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            ],
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final Function(bool) onChanged;

  const _SwitchTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primaryColor),
        title: Text(label),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: AppTheme.primaryColor.withValues(alpha: 0.5),
          activeThumbColor: AppTheme.primaryColor,
        ),
      ),
    );
  }
}
