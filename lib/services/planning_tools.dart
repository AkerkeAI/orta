import '../models/life_data.dart';
import '../models/scheduling_preferences.dart';
import 'scheduling_engine.dart';

class PlanningTools {
  static List<Map<String, dynamic>> calculate(
    LifeData data,
    String name,
    Map<String, dynamic> args,
  ) {
    final engine = SchedulingEngine(data);
    if (name == 'plan_sessions') return engine.plan(args);
    if (name == 'reschedule_calendar_event') {
      final event = data.events.where((e) => e.id == args['id']).firstOrNull;
      if (event == null) throw const PlanningError('missing_record');
      final occurrences = SchedulingEngine.dates(
        SchedulingEngine.shift(event.date, -2),
        SchedulingEngine.shift(event.date, 2),
      ).expand(engine.onDay).where((e) => e.event.id == event.id).toList();
      if (occurrences.length != 1) throw const PlanningError('timezone');
      final occurrence = occurrences.single;
      final moved = move(
        event.toJson(),
        args,
        occurrence.date,
        start: occurrence.start,
        end: occurrence.end,
      );
      final updates = <String, dynamic>{
        'id': event.id,
        'date': moved['date'],
        if (!event.isAllDay) 'timezone': engine.zone,
        if (!event.isAllDay) 'startTime': moved['startTime'],
        if (!event.isAllDay) 'endTime': moved['endTime'],
      };
      return [
        {'name': 'update_calendar_event', 'arguments': updates},
      ];
    }
    if (name == 'modify_pending_session') {
      final pending = data.currentProposals
          .where((p) => p.status == 'pending')
          .toList();
      final selected = pending
          .where((p) => p.id == args['actionId'])
          .firstOrNull;
      if (selected == null ||
          ![
            'create_calendar_event',
            'update_calendar_event',
          ].contains(selected.tool)) {
        throw const PlanningError('missing_record');
      }
      if (selected.expired(DateTime.now())) {
        throw const PlanningError('expired');
      }
      Map<String, dynamic> source = selected.arguments;
      if (selected.tool == 'update_calendar_event') {
        final e = data.events.where((e) => e.id == source['id']).firstOrNull;
        if (e == null) throw const PlanningError('missing_record');
        source = {...e.toJson(), ...source};
      }
      final moved = move(
        source,
        args,
        source['date'] as String,
        start: source['isAllDay'] == true
            ? 0
            : clockMinutes(source['startTime'] as String),
        end: source['isAllDay'] == true
            ? 1440
            : clockMinutes(source['endTime'] as String),
      );
      return [
        for (final p in pending)
          {
            'name': p.tool,
            'arguments': p.id == selected.id
                ? {
                    ...p.arguments,
                    'date': moved['date'],
                    if (source['isAllDay'] != true)
                      'startTime': moved['startTime'],
                    if (source['isAllDay'] != true) 'endTime': moved['endTime'],
                  }
                : p.arguments,
          },
      ];
    }
    throw const PlanningError('missing_record');
  }

  static Map<String, dynamic> move(
    Map<String, dynamic> source,
    Map<String, dynamic> args,
    String originalDate, {
    required int start,
    required int end,
  }) {
    if (args['targetDate'] != null && args['weekday'] != null ||
        args['targetDate'] == null && args['weekday'] == null) {
      throw const PlanningError('range');
    }
    final date =
        args['targetDate'] as String? ??
        SchedulingEngine.shift(
          SchedulingEngine.weekStart(originalDate),
          (args['weekday'] as int) - 1,
        );
    final duration = end - start;
    final newStart = args['startTime'] == null
        ? start
        : clockMinutes(args['startTime'] as String);
    if (source['isAllDay'] != true && newStart + duration >= 1440) {
      throw const PlanningError('constraints');
    }
    return {
      ...source,
      'date': date,
      if (source['isAllDay'] != true) 'startTime': minuteClock(newStart),
      if (source['isAllDay'] != true)
        'endTime': minuteClock(newStart + duration),
    };
  }
}
