import 'package:flutter/material.dart';

import '../models/scheduling_preferences.dart';
import '../services/life_repository.dart';
import '../services/planning_strings.dart';

class SchedulingPreferencesDialog extends StatefulWidget {
  final LifeRepository repository;
  const SchedulingPreferencesDialog({super.key, required this.repository});
  @override
  State<SchedulingPreferencesDialog> createState() =>
      _SchedulingPreferencesDialogState();
}

class _SchedulingPreferencesDialogState
    extends State<SchedulingPreferencesDialog> {
  late final Map<String, TextEditingController> fields;
  late String intensity;
  bool saving = false;
  String? error;
  String t(String key) =>
      planningText(widget.repository.data.life.interfaceLanguage, key);
  @override
  void initState() {
    super.initState();
    final p = widget.repository.data.scheduling;
    final j = p.toJson();
    fields = {
      for (final key in [
        'timezone',
        'studyStart',
        'studyEnd',
        'workStart',
        'workEnd',
        'weekdays',
        'daysOff',
        'maxDailyMinutes',
        'breakMinutes',
        'sessionMinutes',
        'notAfter',
        'unavailable',
      ])
        key: TextEditingController(
          text: key == 'weekdays'
              ? (p.weekdays.isEmpty ? '1,2,3,4,5' : p.weekdays.join(','))
              : key == 'daysOff'
              ? p.daysOff.join(',')
              : key == 'unavailable'
              ? p.unavailable
                    .map(
                      (r) => '${r['date']} ${r['startTime']}-${r['endTime']}',
                    )
                    .join('\n')
              : key == 'timezone' && p.timezone.isEmpty
              ? widget.repository.data.life.preferences['timezone'] ?? ''
              : j[key].toString(),
        ),
    };
    intensity = p.intensity;
  }

  Future<void> save() async {
    if (saving) return;
    SchedulingPreferences next;
    try {
      List<int> days(String key) => fields[key]!.text.trim().isEmpty
          ? []
          : fields[key]!.text
                .split(',')
                .map((v) => int.parse(v.trim()))
                .toList();
      final unavailable = <Map<String, String>>[];
      for (final line
          in fields['unavailable']!.text
              .split('\n')
              .where((s) => s.trim().isNotEmpty)) {
        final match = RegExp(
          r'^(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2})-(\d{2}:\d{2})$',
        ).firstMatch(line.trim());
        if (match == null) throw const FormatException();
        unavailable.add({
          'date': match[1]!,
          'startTime': match[2]!,
          'endTime': match[3]!,
        });
      }
      next = SchedulingPreferences(
        timezone: fields['timezone']!.text.trim(),
        studyStart: fields['studyStart']!.text.trim(),
        studyEnd: fields['studyEnd']!.text.trim(),
        workStart: fields['workStart']!.text.trim(),
        workEnd: fields['workEnd']!.text.trim(),
        weekdays: days('weekdays'),
        daysOff: days('daysOff'),
        maxDailyMinutes: int.parse(fields['maxDailyMinutes']!.text),
        breakMinutes: int.parse(fields['breakMinutes']!.text),
        sessionMinutes: int.parse(fields['sessionMinutes']!.text),
        notAfter: fields['notAfter']!.text.trim(),
        intensity: intensity,
        unavailable: unavailable,
      );
      next.validate();
      if (next.timezone.isEmpty) throw const FormatException();
    } catch (_) {
      setState(() => error = t('invalidPreferences'));
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.repository.saveSchedulingPreferences(next);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = t('saveFailed');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(t('preferences')),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final key in fields.keys)
            TextField(
              controller: fields[key],
              enabled: !saving,
              maxLines: key == 'unavailable' ? 3 : 1,
              decoration: InputDecoration(labelText: t(key)),
            ),
          DropdownButtonFormField<String>(
            initialValue: intensity,
            decoration: InputDecoration(labelText: t('intensity')),
            items: ['light', 'regular', 'intensive']
                .map((v) => DropdownMenuItem(value: v, child: Text(t(v))))
                .toList(),
            onChanged: saving
                ? null
                : (value) => setState(() => intensity = value!),
          ),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: Text(t('cancel')),
      ),
      ElevatedButton(onPressed: saving ? null : save, child: Text(t('save'))),
    ],
  );
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }
}
