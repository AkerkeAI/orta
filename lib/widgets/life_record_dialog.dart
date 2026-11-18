import 'package:flutter/material.dart';

import '../models/life_context.dart';
import '../models/language.dart';
import '../services/localization_service.dart';
import '../services/orta_localization.dart';
import '../services/planning_strings.dart';
import '../services/scheduling_engine.dart';
import '../models/life_data.dart';
import '../models/orta_models.dart';
import '../services/life_repository.dart';
import '../services/life_data_strings.dart';

class LifeRecordDialog extends StatefulWidget {
  final LifeRepository repository;
  final String initialType;
  const LifeRecordDialog({
    super.key,
    required this.repository,
    this.initialType = 'exam',
  });
  @override
  State<LifeRecordDialog> createState() => _LifeRecordDialogState();
}

class _LifeRecordDialogState extends State<LifeRecordDialog> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _date = TextEditingController();
  final _start = TextEditingController();
  final _end = TextEditingController();
  late String _type = widget.initialType;
  String? _projectId, _goalId, _examId;
  bool _saving = false;
  bool _allDay = false;
  String? _error;
  String t(String key) =>
      lifeDataText(widget.repository.data.life.interfaceLanguage, key);

  String get _dateLabel {
    if (_type != 'event') return t('date');
    const labels = {
      Language.english: 'Date (YYYY-MM-DD, required)',
      Language.russian: 'Дата (ГГГГ-ММ-ДД, обязательно)',
      Language.kazakh: 'Күні (ЖЖЖЖ-АА-КК, міндетті)',
    };
    return labels[widget.repository.data.life.interfaceLanguage]!;
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (_type == 'event') {
      final candidate = CalendarEvent(
        id: 'manual_conflict_preview',
        title: _title.text.trim(),
        date: _date.text.trim(),
        startTime: _allDay ? '' : _start.text.trim(),
        endTime: _allDay ? '' : _end.text.trim(),
        category: 'Event',
        isAllDay: _allDay,
        timezone: widget.repository.data.scheduling.timezone,
      );
      final engine = SchedulingEngine(
        widget.repository.data.copyWith(
          events: [...widget.repository.data.events, candidate],
        ),
      );
      final conflicts =
          SchedulingEngine.dates(
                SchedulingEngine.shift(candidate.date, -2),
                SchedulingEngine.shift(candidate.date, 2),
              )
              .expand(engine.conflicts)
              .where((pair) => pair.any((o) => o.event.id == candidate.id))
              .toList();
      if (conflicts.isNotEmpty) {
        final language = widget.repository.data.life.interfaceLanguage;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(planningText(language, 'conflict')),
            content: Text(
              '${conflicts.map((pair) => pair.map((o) => o.event.title).join(' / ')).join('\n')}\n${planningText(language, 'keepBoth')}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(planningText(language, 'cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(planningText(language, 'save')),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final id = newLifeId(_type);
    final title = _title.text.trim();
    final date = _date.text.trim();
    try {
      switch (_type) {
        case 'goal':
          await widget.repository.saveGoal(
            GoalContext(id: id, titleKey: title, areaKey: 'personalGoals'),
          );
        case 'exam':
          await widget.repository.saveExam(
            ExamContext(id: id, name: title, date: date.isEmpty ? null : date),
          );
        case 'project':
          await widget.repository.saveProject(
            ProjectContext(id: id, name: title),
          );
        case 'task':
          await widget.repository.saveTask(
            Task(
              id: id,
              title: title,
              category: 'Task',
              dueDate: date.isEmpty ? null : date,
              projectId: _projectId,
              goalId: _goalId,
              examId: _examId,
              domain: _projectId == null
                  ? LifeDomain.personalGoals
                  : LifeDomain.projects,
            ),
          );
        case 'event':
          await widget.repository.saveEvent(
            CalendarEvent(
              id: id,
              title: title,
              date: date,
              startTime: _allDay ? '' : _start.text.trim(),
              endTime: _allDay ? '' : _end.text.trim(),
              isAllDay: _allDay,
              timezone: widget.repository.data.scheduling.timezone,
              category: 'Event',
              projectId: _projectId,
              goalId: _goalId,
              examId: _examId,
            ),
          );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = t('error');
          _saving = false;
        });
      }
    }
  }

  Widget _link(
    String kind,
    List<DropdownMenuItem<String>> records,
    String? value,
    ValueChanged<String?> change,
  ) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(labelText: t(kind)),
    items: [
      DropdownMenuItem<String>(value: null, child: Text(t('none'))),
      ...records,
    ],
    onChanged: change,
  );

  @override
  Widget build(BuildContext context) {
    final life = widget.repository.data.life;
    final strings = AppLocalizations(
      AppLocaleExtension.fromLanguage(life.interfaceLanguage),
    );
    return AlertDialog(
      title: Text(t('add')),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _type,
                items: ['goal', 'exam', 'project', 'task', 'event']
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(t(type))),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (type) => setState(() => _type = type!),
              ),
              TextFormField(
                controller: _title,
                decoration: InputDecoration(labelText: t('title')),
                validator: (value) => value == null || value.trim().isEmpty
                    ? t('required')
                    : null,
              ),
              if (['exam', 'task', 'event'].contains(_type))
                TextFormField(
                  controller: _date,
                  decoration: InputDecoration(labelText: _dateLabel),
                  validator: (value) =>
                      (value?.trim().isEmpty ?? true) && _type != 'event'
                      ? null
                      : isLifeDate(value!.trim())
                      ? null
                      : t('invalidDate'),
                ),
              if (_type == 'event')
                CheckboxListTile(
                  value: _allDay,
                  onChanged: (v) => setState(() => _allDay = v ?? false),
                  title: Text(
                    planningText(
                      widget.repository.data.life.interfaceLanguage,
                      'allDay',
                    ),
                  ),
                ),
              if (_type == 'event' && !_allDay) ...[
                TextFormField(
                  controller: _start,
                  decoration: InputDecoration(labelText: t('start')),
                  validator: (value) =>
                      RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$')
                          .hasMatch(value?.trim() ?? '')
                      ? null
                      : t('invalidTime'),
                ),
                TextFormField(
                  controller: _end,
                  decoration: InputDecoration(labelText: t('end')),
                  validator: (value) =>
                      RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$')
                              .hasMatch(value?.trim() ?? '') &&
                          _start.text.trim().compareTo(value!.trim()) < 0
                      ? null
                      : t('invalidTime'),
                ),
              ],
              if (['task', 'event'].contains(_type)) ...[
                if (life.projects.isNotEmpty)
                  _link(
                    'project',
                    life.projects
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name),
                          ),
                        )
                        .toList(),
                    _projectId,
                    (id) => setState(() => _projectId = id),
                  ),
                if (life.goals.isNotEmpty)
                  _link(
                    'goal',
                    life.goals
                        .map(
                          (g) => DropdownMenuItem(
                            value: g.id,
                            child: Text(strings.goal(g.titleKey)),
                          ),
                        )
                        .toList(),
                    _goalId,
                    (id) => setState(() => _goalId = id),
                  ),
                if (life.exams.isNotEmpty)
                  _link(
                    'exam',
                    life.exams
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.id,
                            child: Text(e.name),
                          ),
                        )
                        .toList(),
                    _examId,
                    (id) => setState(() => _examId = id),
                  ),
              ],
              if (_error != null) Text(_error!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: Text(t('cancel')),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(),
                )
              : Text(t('save')),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _date.dispose();
    _start.dispose();
    _end.dispose();
    super.dispose();
  }
}
