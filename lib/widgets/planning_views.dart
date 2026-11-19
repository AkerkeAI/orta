import 'package:flutter/material.dart';

import '../models/life_data.dart';
import '../models/language.dart';
import '../models/scheduling_preferences.dart';
import '../services/scheduling_engine.dart';
import '../services/planning_strings.dart';
import '../services/life_data_strings.dart';
import '../services/localization_service.dart';
import '../services/orta_localization.dart';

class DailyOverview extends StatelessWidget {
  final LifeData data;
  final void Function(String, String)? onSelect;
  const DailyOverview({super.key, required this.data, this.onSelect});
  @override
  Widget build(BuildContext context) {
    final engine = SchedulingEngine(data),
        language = data.life.interfaceLanguage;
    final strings = AppLocalizations(AppLocaleExtension.fromLanguage(language));
    final commitments = engine.onDay(engine.today),
        recommendations = engine.recommendations();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 112),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF087F73), Color(0xFF10B9A2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF087F73).withValues(alpha: 0.18),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.wb_sunny_outlined,
                      color: Colors.white70,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        planningDate(language, engine.today),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${commitments.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                Text(
                  '${planningText(language, 'greeting')}, ${data.life.name}',
                  style: const TextStyle(
                    fontSize: 27,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  engine.zone,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _PlanningCard(
            title: planningText(language, 'commitments'),
            children: commitments.isEmpty
                ? [_EmptyAgenda(text: planningText(language, 'empty'))]
                : commitments
                      .take(5)
                      .map(
                        (o) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F7F4),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.event_available_rounded,
                              color: Color(0xFF078F7D),
                            ),
                          ),
                          title: Text(o.event.title),
                          subtitle: Text(occurrenceTime(language, o)),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () =>
                              onSelect?.call('calendar_event', o.event.id),
                        ),
                      )
                      .toList(),
          ),
          if (recommendations.isNotEmpty)
            _PlanningCard(
              title: planningText(language, 'focus'),
              children: recommendations
                  .take(3)
                  .map(
                    (r) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        r.code == 'conflict' || r.code == 'overload'
                            ? Icons.warning_amber_rounded
                            : Icons.auto_awesome_rounded,
                        color: r.code == 'conflict' || r.code == 'overload'
                            ? const Color(0xFFD78A25)
                            : const Color(0xFF078F7D),
                      ),
                      title: Text(
                        recommendationText(
                          language,
                          Recommendation(
                            r.code,
                            r.kind == 'goal' ? strings.goal(r.title) : r.title,
                            r.kind,
                            r.id,
                            date: r.date,
                          ),
                        ),
                      ),
                      onTap: () => onSelect?.call(r.kind, r.id),
                      trailing: const Icon(Icons.arrow_forward_rounded),
                    ),
                  )
                  .toList(),
            ),
          if (!data.scheduling.availableFor('study') &&
              !data.scheduling.availableFor('work'))
            Text(planningText(language, 'availability')),
          if (data.completedTasks.isNotEmpty ||
              data.events.any((e) => e.completedAt != null))
            _PlanningCard(
              title: planningText(language, 'progress'),
              children: [
                ...data.completedTasks.reversed
                    .take(2)
                    .map(
                      (t) => Text(
                        '${t.title} · ${planningDate(language, SchedulingEngine(data, nowOverride: t.completedAt).today)}',
                      ),
                    ),
                ...data.events
                    .where((e) => e.completedAt != null)
                    .toList()
                    .reversed
                    .take(2)
                    .map(
                      (e) => Text(
                        '${e.title} · ${planningDate(language, SchedulingEngine(data, nowOverride: e.completedAt).today)}',
                      ),
                    ),
              ],
            ),
        ],
      ),
    );
  }
}

String occurrenceTime(Language l, CalendarOccurrence o) => o.event.isAllDay
    ? planningText(l, 'allDay')
    : '${minuteClock(o.start)}–${minuteClock(o.end)}';

class PlanningCalendar extends StatefulWidget {
  final LifeData data;
  final Future<void> Function(String, bool)? onCompleteTask;
  final Future<void> Function(String, bool)? onCompleteSession;
  final VoidCallback? onAddTask, onPreferences;
  final void Function(String, String)? onSelect;
  const PlanningCalendar({
    super.key,
    required this.data,
    this.onCompleteTask,
    this.onCompleteSession,
    this.onAddTask,
    this.onPreferences,
    this.onSelect,
  });
  @override
  State<PlanningCalendar> createState() => _PlanningCalendarState();
}

class _PlanningCalendarState extends State<PlanningCalendar> {
  late String selected = SchedulingEngine(widget.data).today;
  bool week = false;
  @override
  Widget build(BuildContext context) {
    final data = widget.data,
        engine = SchedulingEngine(data),
        l = data.life.interfaceLanguage;
    final first = week ? SchedulingEngine.weekStart(selected) : selected,
        last = week ? SchedulingEngine.shift(first, 6) : selected;
    final dates = SchedulingEngine.dates(first, last);
    final items = dates.expand(engine.onDay).toList();
    final conflicts = dates.expand(engine.conflicts).toList();
    final suggestions = data.actionProposals
        .where(
          (p) =>
              p.status == 'pending' &&
              [
                'create_calendar_event',
                'update_calendar_event',
              ].contains(p.tool) &&
              p.arguments['date'] is String &&
              (p.arguments['date'] as String).compareTo(first) >= 0 &&
              (p.arguments['date'] as String).compareTo(last) <= 0,
        )
        .toList();
    final exams =
        data.life.exams
            .where(
              (e) =>
                  e.date != null &&
                  e.date!.compareTo(first) >= 0 &&
                  e.date!.compareTo(last) <= 0,
            )
            .toList()
          ..sort((a, b) => a.date!.compareTo(b.date!));
    final tasks = data.tasks
        .where(
          (t) =>
              !data.events.any((e) => e.taskId == t.id) ||
              items.any((o) => o.event.taskId == t.id),
        )
        .toList();
    final kind = data.scheduling.availableFor('study') ? 'study' : 'work';
    final free = <TimeWindow>[];
    if (data.scheduling.availableFor(kind)) {
      for (final date in dates) {
        free.addAll(engine.freeWindows(date, kind));
      }
    }
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
        children: [
          Text(
            planningText(l, 'plan'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          Text(engine.zone),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(planningText(l, 'day'))),
              ButtonSegment(value: true, label: Text(planningText(l, 'week'))),
            ],
            selected: {week},
            onSelectionChanged: (v) => setState(() => week = v.first),
          ),
          Row(
            children: [
              IconButton(
                tooltip: planningText(l, 'previousWeek'),
                onPressed: () => setState(
                  () => selected = SchedulingEngine.shift(selected, -7),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      locale: Locale(l.code),
                      initialDate: SchedulingEngine.day(selected),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (date != null && mounted) {
                      setState(
                        () => selected = SchedulingEngine.dateString(date),
                      );
                    }
                  },
                  child: Text(
                    '${planningDate(l, first)}${week ? ' — ${planningDate(l, last)}' : ''}',
                  ),
                ),
              ),
              IconButton(
                tooltip: planningText(l, 'nextWeek'),
                onPressed: () => setState(
                  () => selected = SchedulingEngine.shift(selected, 7),
                ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          TextButton(
            onPressed: () => setState(() => selected = engine.today),
            child: Text(planningText(l, 'today')),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final date in SchedulingEngine.dates(
                  SchedulingEngine.weekStart(selected),
                  SchedulingEngine.shift(
                    SchedulingEngine.weekStart(selected),
                    6,
                  ),
                ))
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(planningDate(l, date, short: true)),
                      selected: selected == date,
                      onSelected: (_) => setState(() => selected = date),
                    ),
                  ),
              ],
            ),
          ),
          if (widget.onPreferences != null)
            OutlinedButton.icon(
              onPressed: widget.onPreferences,
              icon: const Icon(Icons.tune),
              label: Text(planningText(l, 'preferences')),
            ),
          if (conflicts.isNotEmpty)
            _PlanningCard(
              title: planningText(l, 'conflict'),
              children: conflicts
                  .map(
                    (pair) => Text(
                      '${pair[0].event.title} / ${pair[1].event.title} · ${planningDate(l, pair[0].date)}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                  .toList(),
            ),
          _PlanningCard(
            title: planningText(l, 'confirmed'),
            children: [
              if (items.isEmpty && exams.isEmpty)
                Text(planningText(l, 'empty')),
              for (final e in exams)
                ListTile(
                  title: Text(e.name),
                  subtitle: Text(
                    '${planningText(l, 'exam')} · ${planningDate(l, e.date!)}',
                  ),
                  onTap: () => widget.onSelect?.call('exam', e.id),
                ),
              for (final o in items)
                ListTile(
                  title: Text(o.event.title),
                  subtitle: Text(
                    '${planningDate(l, o.date)} · ${occurrenceTime(l, o)}',
                  ),
                  leading: Icon(
                    o.event.completedAt == null
                        ? Icons.event_outlined
                        : Icons.check_circle_outline,
                  ),
                  onTap: () =>
                      widget.onSelect?.call('calendar_event', o.event.id),
                  trailing:
                      widget.onCompleteSession == null ||
                          o.event.planningKind.isEmpty
                      ? null
                      : IconButton(
                          tooltip: planningText(l, 'completeSession'),
                          onPressed: () async {
                            final answer = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(planningText(l, 'completeSession')),
                                content: Text(o.event.title),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: Text(planningText(l, 'cancel')),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: Text(planningText(l, 'save')),
                                  ),
                                ],
                              ),
                            );
                            if (answer == true) {
                              await widget.onCompleteSession!(o.event.id, true);
                            }
                          },
                          icon: const Icon(Icons.done),
                        ),
                ),
            ],
          ),
          if (suggestions.isNotEmpty)
            _PlanningCard(
              title: planningText(l, 'suggestions'),
              color: Colors.orange.shade50,
              children: suggestions.map((p) => Text(p.summary)).toList(),
            ),
          _PlanningCard(
            title: planningText(l, kind == 'study' ? 'free' : 'workFree'),
            children: !data.scheduling.availableFor(kind)
                ? [Text(planningText(l, 'availability'))]
                : free.isEmpty
                ? [Text(planningText(l, 'none'))]
                : free
                      .take(14)
                      .map(
                        (s) => Text(
                          '${planningDate(l, s.date)} · ${minuteClock(s.start)}–${minuteClock(s.end)}',
                        ),
                      )
                      .toList(),
          ),
          if (widget.onAddTask != null)
            OutlinedButton.icon(
              onPressed: widget.onAddTask,
              icon: const Icon(Icons.add),
              label: Text(lifeDataText(l, 'task')),
            ),
          if (tasks.isNotEmpty) Text(planningText(l, 'tasks')),
          ...tasks.map(
            (t) => CheckboxListTile(
              title: Text(t.title),
              value: t.completed,
              onChanged: widget.onCompleteTask == null
                  ? null
                  : (v) => widget.onCompleteTask!(t.id, v ?? false),
              subtitle: Text(
                t.dueDate == null
                    ? lifeDataText(l, 'unknownDate')
                    : planningDate(l, t.dueDate!),
              ),
              secondary: IconButton(
                icon: const Icon(Icons.auto_awesome),
                onPressed: () => widget.onSelect?.call('task', t.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanningCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Color? color;
  const _PlanningCard({
    required this.title,
    required this.children,
    this.color,
  });
  @override
  Widget build(BuildContext context) => Card(
    color: color,
    margin: const EdgeInsets.only(bottom: 14),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );
}

class _EmptyAgenda extends StatelessWidget {
  final String text;
  const _EmptyAgenda({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 8, bottom: 5),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF2F8F7),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const Icon(Icons.event_note_rounded, color: Color(0xFF078F7D)),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
