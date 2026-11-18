import 'dart:math';

import 'package:timezone/timezone.dart' as tz;

import '../models/life_data.dart';
import '../models/orta_models.dart';
import '../models/scheduling_preferences.dart';

class PlanningError implements Exception {
  final String code;
  const PlanningError(this.code);
}

class TimeWindow {
  final String date;
  final int start, end;
  const TimeWindow(this.date, this.start, this.end);
  Map<String, dynamic> toJson() => {
    'date': date,
    'startTime': minuteClock(start),
    'endTime': minuteClock(end),
  };
}

class CalendarOccurrence {
  final CalendarEvent event;
  final String date;
  final int start, end;
  const CalendarOccurrence(this.event, this.date, this.start, this.end);
}

class Recommendation {
  final String code, title, kind, id;
  final String? date;
  const Recommendation(this.code, this.title, this.kind, this.id, {this.date});
  Map<String, dynamic> toJson() => {
    'code': code,
    'title': title,
    'kind': kind,
    'id': id,
    'date': date,
  };
}

/// Pure, local calendar arithmetic. No LLM-generated clock calculations are trusted.
class SchedulingEngine {
  final LifeData data;
  final DateTime? nowOverride;
  SchedulingEngine(this.data, {this.nowOverride});
  SchedulingPreferences get preferences => data.scheduling;
  String get zone => preferences.timezone.isNotEmpty
      ? preferences.timezone
      : knownSchedulingZone(data.life.preferences['timezone'] ?? '')
      ? data.life.preferences['timezone']!
      : 'UTC';
  DateTime get now {
    initializeSchedulingZones();
    return tz.TZDateTime.from(
      nowOverride ?? DateTime.now(),
      schedulingLocation(zone),
    );
  }

  String get today => dateString(now);
  static String dateString(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  static DateTime day(String date) => DateTime.parse('${date}T00:00:00Z');
  static String shift(String date, int days) =>
      dateString(day(date).add(Duration(days: days)));
  static String weekStart(String date) => shift(date, 1 - day(date).weekday);
  static List<String> dates(String first, String last) {
    final count = day(last).difference(day(first)).inDays;
    if (count < 0 || count > 31) throw const PlanningError('range');
    return List.generate(count + 1, (i) => shift(first, i));
  }

  tz.TZDateTime wall(String date, int minute, [String? timezone]) {
    initializeSchedulingZones();
    final d = day(date);
    return tz.TZDateTime(
      schedulingLocation(timezone ?? zone),
      d.year,
      d.month,
      d.day,
      minute ~/ 60,
      minute % 60,
    );
  }

  List<CalendarOccurrence> onDay(String date, {List<CalendarEvent>? events}) {
    final result = <CalendarOccurrence>[];
    final start = wall(date, 0), end = wall(shift(date, 1), 0);
    for (final e in events ?? data.events) {
      if (e.isAllDay) {
        if (e.date == date) result.add(CalendarOccurrence(e, date, 0, 1440));
        continue;
      }
      final eventZone = e.timezone.isNotEmpty ? e.timezone : zone;
      final from = wall(e.date, clockMinutes(e.startTime), eventZone),
          to = wall(e.date, clockMinutes(e.endTime), eventZone);
      if (!from.isBefore(end) || !to.isAfter(start)) continue;
      final localFrom = tz.TZDateTime.from(from, schedulingLocation(zone)),
          localTo = tz.TZDateTime.from(to, schedulingLocation(zone));
      result.add(
        CalendarOccurrence(
          e,
          date,
          from.isBefore(start) ? 0 : localFrom.hour * 60 + localFrom.minute,
          to.isAfter(end) || to.isAtSameMomentAs(end)
              ? 1440
              : localTo.hour * 60 + localTo.minute,
        ),
      );
    }
    result.sort((a, b) {
      final cmp = a.start.compareTo(b.start);
      return cmp != 0 ? cmp : a.event.id.compareTo(b.event.id);
    });
    return result;
  }

  List<CalendarOccurrence> inWeek(String date) =>
      dates(weekStart(date), shift(weekStart(date), 6)).expand(onDay).toList();
  List<List<CalendarOccurrence>> conflicts(
    String date, {
    List<CalendarEvent>? events,
  }) {
    final items = onDay(date, events: events);
    final pairs = <List<CalendarOccurrence>>[];
    for (var i = 0; i < items.length; i++) {
      for (var j = i + 1; j < items.length; j++) {
        if (items[j].start >= items[i].end) break;
        pairs.add([items[i], items[j]]);
      }
    }
    return pairs;
  }

  int workload(String date, {List<CalendarEvent>? events}) =>
      onDay(date, events: events)
          .where((o) => o.event.planningKind.isNotEmpty)
          .fold(0, (sum, e) => sum + e.end - e.start);
  List<TimeWindow> freeWindows(
    String date,
    String kind, {
    List<CalendarEvent>? events,
    String? notAfter,
  }) {
    final p = preferences;
    if (!p.availableFor(kind)) throw const PlanningError('availability');
    final weekday = day(date).weekday;
    if (!p.weekdays.contains(weekday) || p.daysOff.contains(weekday)) return [];
    var start = clockMinutes(kind == 'study' ? p.studyStart : p.workStart);
    final end = min(
      clockMinutes(kind == 'study' ? p.studyEnd : p.workEnd),
      min(
        clockMinutes(p.notAfter),
        notAfter == null ? 1440 : clockMinutes(notAfter),
      ),
    );
    if (date.compareTo(today) < 0) return [];
    if (date == today) start = max(start, now.hour * 60 + now.minute + 1);
    var spans = <TimeWindow>[if (start < end) TimeWindow(date, start, end)];
    final busy = <TimeWindow>[
      ...onDay(date, events: events).map(
        (e) => TimeWindow(
          date,
          max(0, e.start - p.breakMinutes),
          min(1440, e.end + p.breakMinutes),
        ),
      ),
      ...p.unavailable
          .where((e) => e['date'] == date)
          .map(
            (e) => TimeWindow(
              date,
              clockMinutes(e['startTime']!),
              clockMinutes(e['endTime']!),
            ),
          ),
    ];
    for (final block in busy) {
      final next = <TimeWindow>[];
      for (final span in spans) {
        if (block.end <= span.start || block.start >= span.end) {
          next.add(span);
          continue;
        }
        if (block.start > span.start) {
          next.add(TimeWindow(date, span.start, min(span.end, block.start)));
        }
        if (block.end < span.end) {
          next.add(TimeWindow(date, max(span.start, block.end), span.end));
        }
      }
      spans = next;
    }
    return spans;
  }

  bool stableClock(String date, int start, int end, {String? timezone}) {
    final location = schedulingLocation(timezone ?? zone);
    final d = day(date);
    bool unique(int minute) {
      final target = DateTime.utc(
        d.year,
        d.month,
        d.day,
        minute ~/ 60,
        minute % 60,
      ).millisecondsSinceEpoch;
      final matches = <int>{};
      for (final offset
          in location.zones.map((z) => z.offset.inMilliseconds).toSet()) {
        final instant = target - offset;
        final value = tz.TZDateTime.from(
          DateTime.fromMillisecondsSinceEpoch(instant, isUtc: true),
          location,
        );
        if (dateString(value) == date &&
            value.hour * 60 + value.minute == minute &&
            value.second == 0) {
          matches.add(instant);
        }
      }
      return matches.length == 1;
    }

    if (!unique(start) || !unique(end)) return false;
    return wall(
          date,
          end,
          timezone,
        ).difference(wall(date, start, timezone)).inMinutes ==
        end - start;
  }

  void checkPlanned(CalendarEvent event, {List<CalendarEvent>? events}) {
    if (event.planningDeadline != null &&
        event.date.compareTo(event.planningDeadline!) > 0) {
      throw const PlanningError('deadline');
    }
    if (event.planningKind.isEmpty) return;
    final remaining = (events ?? data.events)
        .where((e) => e.id != event.id)
        .toList();
    if (event.isAllDay ||
        event.timezone != zone ||
        !stableClock(
          event.date,
          clockMinutes(event.startTime),
          clockMinutes(event.endTime),
        )) {
      throw const PlanningError('timezone');
    }
    final start = clockMinutes(event.startTime),
        end = clockMinutes(event.endTime);
    if (!freeWindows(
      event.date,
      event.planningKind,
      events: remaining,
      notAfter: event.latestEnd,
    ).any((s) => start >= s.start && end <= s.end)) {
      throw const PlanningError('constraints');
    }
    if (workload(event.date, events: remaining) + end - start >
        preferences.maxDailyMinutes) {
      throw const PlanningError('workload');
    }
    if (event.taskId != null &&
        data.tasks.where((t) => t.id == event.taskId).firstOrNull?.completed ==
            true) {
      throw const PlanningError('completed');
    }
    final deadline = event.taskId == null
        ? null
        : data.tasks.where((t) => t.id == event.taskId).firstOrNull?.dueDate;
    final exam = event.examId == null
        ? null
        : data.life.exams.where((e) => e.id == event.examId).firstOrNull?.date;
    if ((deadline != null && event.date.compareTo(deadline) > 0) ||
        (exam != null && event.date.compareTo(exam) >= 0)) {
      throw const PlanningError('deadline');
    }
  }

  int remainingEffort(String taskId, int estimate) {
    final spans = <List<DateTime>>[];
    for (final e in data.events.where(
      (e) => e.taskId == taskId && !e.isAllDay,
    )) {
      final eventZone = e.timezone.isEmpty ? zone : e.timezone;
      final start = wall(e.date, clockMinutes(e.startTime), eventZone),
          end = wall(e.date, clockMinutes(e.endTime), eventZone);
      if (e.completedAt != null || end.isAfter(now)) {
        spans.add([start.toUtc(), end.toUtc()]);
      }
    }
    spans.sort((a, b) => a[0].compareTo(b[0]));
    var credited = 0;
    DateTime? first, last;
    for (final span in spans) {
      if (first == null) {
        first = span[0];
        last = span[1];
      } else if (!span[0].isAfter(last!)) {
        if (span[1].isAfter(last)) last = span[1];
      } else {
        credited += last.difference(first).inMinutes;
        first = span[0];
        last = span[1];
      }
    }
    if (first != null) credited += last!.difference(first).inMinutes;
    return max(0, estimate - credited);
  }

  List<Map<String, dynamic>> plan(Map<String, dynamic> args) {
    final kind = args['kind'] as String;
    if (!preferences.availableFor(kind)) {
      throw const PlanningError('availability');
    }
    String first, last;
    switch (args['period']) {
      case 'today':
        first = today;
        last = today;
      case 'this_week':
        first = today;
        last = shift(weekStart(today), 6);
      case 'next_week':
        first = shift(weekStart(today), 7);
        last = shift(first, 6);
      case 'custom':
        first = args['startDate'] as String? ?? '';
        last = args['endDate'] as String? ?? '';
        if (!isLifeDate(first) || !isLifeDate(last)) {
          throw const PlanningError('range');
        }
      default:
        throw const PlanningError('range');
    }
    final task = args['taskId'] == null
        ? null
        : data.tasks.where((t) => t.id == args['taskId']).firstOrNull;
    final exam = args['examId'] == null
        ? null
        : data.life.exams.where((e) => e.id == args['examId']).firstOrNull;
    if (args['taskId'] != null && task == null ||
        args['examId'] != null && exam == null) {
      throw const PlanningError('missing_record');
    }
    if (task?.completed == true) throw const PlanningError('completed');
    if (exam?.date != null && !isLifeDate(exam!.date!)) {
      throw const PlanningError('range');
    }
    final limits = [
      args['deadline'] as String?,
      task?.dueDate,
      exam?.date == null ? null : shift(exam!.date!, -1),
    ].whereType<String>();
    for (final deadline in limits) {
      if (deadline.compareTo(last) < 0) last = deadline;
    }
    if (last.compareTo(first) < 0) throw const PlanningError('deadline');
    final days = dates(first, last);
    final defaultDuration =
        args['durationMinutes'] as int? ?? preferences.sessionMinutes;
    final remaining = task?.estimatedMinutes == null
        ? null
        : remainingEffort(task!.id, task.estimatedMinutes!);
    if (args['count'] == null && remaining == 0) {
      throw const PlanningError('covered');
    }
    final count =
        args['count'] as int? ??
        (remaining == null
            ? throw const PlanningError('effort')
            : (remaining / defaultDuration).ceil());
    if (count < 1 ||
        count > 8 ||
        defaultDuration < 15 ||
        defaultDuration > 180) {
      throw const PlanningError('range');
    }
    final planned = <CalendarEvent>[];
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < count; i++) {
      final duration = args['count'] == null && remaining != null
          ? min(defaultDuration, max(15, remaining - i * defaultDuration))
          : defaultDuration;
      final events = [...data.events, ...planned];
      final candidates = <TimeWindow>[];
      for (final date in days) {
        if (workload(date, events: events) + duration >
            preferences.maxDailyMinutes) {
          continue;
        }
        for (final span in freeWindows(
          date,
          kind,
          events: events,
          notAfter: args['notAfter'] as String?,
        )) {
          // Scan in 15-minute steps; never normalize a nonexistent/ambiguous DST time.
          for (
            var start = ((span.start + 14) ~/ 15) * 15;
            start + duration <= span.end;
            start += 15
          ) {
            if (stableClock(date, start, start + duration)) {
              candidates.add(TimeWindow(date, start, start + duration));
              break;
            }
          }
        }
      }
      candidates.sort((a, b) {
        final load = workload(
          a.date,
          events: events,
        ).compareTo(workload(b.date, events: events));
        if (load != 0) return load;
        final date = a.date.compareTo(b.date);
        return date != 0 ? date : a.start.compareTo(b.start);
      });
      if (candidates.isEmpty) throw const PlanningError('insufficient');
      final slot = candidates.first;
      final values = <String, dynamic>{
        'title': args['title'],
        'date': slot.date,
        'startTime': minuteClock(slot.start),
        'endTime': minuteClock(slot.end),
        'planningKind': kind,
        'timezone': zone,
        'latestEnd': args['notAfter'] ?? preferences.notAfter,
        if (args['deadline'] != null) 'planningDeadline': args['deadline'],
        for (final key in ['goalId', 'examId', 'projectId', 'taskId'])
          if (args[key] != null) key: args[key],
      };
      planned.add(
        CalendarEvent(
          id: 'preview_$i',
          title: values['title'] as String,
          date: slot.date,
          startTime: values['startTime'] as String,
          endTime: values['endTime'] as String,
          category: 'Event',
          planningKind: kind,
          timezone: zone,
          latestEnd: values['latestEnd'] as String,
          taskId: args['taskId'] as String?,
          examId: args['examId'] as String?,
        ),
      );
      result.add({'name': 'create_calendar_event', 'arguments': values});
    }
    return result;
  }

  List<Recommendation> recommendations() {
    final result = <Recommendation>[];
    for (final date in dates(today, shift(today, 6))) {
      for (final pair in conflicts(date)) {
        result.add(
          Recommendation(
            'conflict',
            '${pair[0].event.title} / ${pair[1].event.title}',
            'calendar_event',
            pair[0].event.id,
            date: date,
          ),
        );
      }
      if (workload(date) > preferences.maxDailyMinutes) {
        result.add(Recommendation('overload', date, 'day', date, date: date));
      }
    }
    final tasks = data.tasks.where((t) => !t.completed).toList()
      ..sort((a, b) => (a.dueDate ?? '9999').compareTo(b.dueDate ?? '9999'));
    for (final task in tasks) {
      final scheduled = data.events.any(
        (e) =>
            e.taskId == task.id &&
            e.date.compareTo(today) >= 0 &&
            e.completedAt == null,
      );
      if (task.dueDate != null &&
          task.dueDate!.compareTo(shift(today, 7)) <= 0) {
        result.add(
          Recommendation(
            task.dueDate!.compareTo(today) < 0
                ? 'overdue'
                : scheduled
                ? 'deadline'
                : 'unscheduledDeadline',
            task.title,
            'task',
            task.id,
            date: task.dueDate,
          ),
        );
      } else if (!scheduled && task.priority == 'high') {
        result.add(
          Recommendation(
            'important',
            task.title,
            'task',
            task.id,
            date: task.dueDate,
          ),
        );
      }
    }
    for (final exam in data.life.exams.where(
      (e) =>
          e.date != null &&
          e.date!.compareTo(today) >= 0 &&
          e.date!.compareTo(shift(today, 14)) <= 0,
    )) {
      result.add(
        Recommendation('exam', exam.name, 'exam', exam.id, date: exam.date),
      );
    }
    if (result.isEmpty && data.life.goals.isNotEmpty) {
      final goal = data.life.goals.first;
      result.add(Recommendation('goal', goal.titleKey, 'goal', goal.id));
    }
    return result.take(6).toList();
  }

  Map<String, dynamic> snapshot() => {
    'date': today,
    'timezone': zone,
    'timezoneConfirmed': preferences.timezone.isNotEmpty,
    'currentLocalTime': minuteClock(now.hour * 60 + now.minute),
    'todayAvailability': {
      for (final kind in ['study', 'work'])
        kind: {
          'confirmed': preferences.availableFor(kind),
          'windows': preferences.availableFor(kind)
              ? freeWindows(today, kind).map((w) => w.toJson()).toList()
              : <Map<String, dynamic>>[],
        },
    },
    'nextWeekStart': shift(weekStart(today), 7),
    'nextWeekEnd': shift(weekStart(today), 13),
    'preferences': preferences.toJson(),
    'recommendations': recommendations().map((r) => r.toJson()).toList(),
    'todayCommitments': onDay(today)
        .take(12)
        .map(
          (e) => {
            'id': e.event.id,
            'title': e.event.title,
            'isAllDay': e.event.isAllDay,
            ...TimeWindow(e.date, e.start, e.end).toJson(),
          },
        )
        .toList(),
  };
}
