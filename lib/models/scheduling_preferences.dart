import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

bool _zonesReady = false;
void initializeSchedulingZones() {
  if (!_zonesReady) {
    tzdata.initializeTimeZones();
    _zonesReady = true;
  }
}

bool knownSchedulingZone(String value) {
  initializeSchedulingZones();
  return value == 'UTC' || tz.timeZoneDatabase.locations.containsKey(value);
}

bool schedulingTime(String value) =>
    RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(value);
int clockMinutes(String value) {
  final parts = value.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

String minuteClock(int value) =>
    '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';

class SchedulingPreferences {
  final String timezone,
      studyStart,
      studyEnd,
      workStart,
      workEnd,
      notAfter,
      intensity;
  final int maxDailyMinutes, breakMinutes, sessionMinutes;
  final List<int> weekdays, daysOff;
  final List<Map<String, String>> unavailable;
  SchedulingPreferences({
    this.timezone = '',
    this.studyStart = '',
    this.studyEnd = '',
    this.workStart = '',
    this.workEnd = '',
    this.notAfter = '21:00',
    this.intensity = 'regular',
    this.maxDailyMinutes = 120,
    this.breakMinutes = 15,
    this.sessionMinutes = 60,
    List<int> weekdays = const [],
    List<int> daysOff = const [],
    List<Map<String, String>> unavailable = const [],
  }) : weekdays = List.unmodifiable(weekdays),
       daysOff = List.unmodifiable(daysOff),
       unavailable = List.unmodifiable(
         unavailable.map((r) => Map<String, String>.unmodifiable(r)),
       );
  bool availableFor(String kind) =>
      timezone.isNotEmpty &&
      weekdays.isNotEmpty &&
      (kind == 'study' ? studyStart.isNotEmpty : workStart.isNotEmpty);
  Map<String, dynamic> toJson() => {
    'timezone': timezone,
    'studyStart': studyStart,
    'studyEnd': studyEnd,
    'workStart': workStart,
    'workEnd': workEnd,
    'notAfter': notAfter,
    'intensity': intensity,
    'maxDailyMinutes': maxDailyMinutes,
    'breakMinutes': breakMinutes,
    'sessionMinutes': sessionMinutes,
    'weekdays': weekdays,
    'daysOff': daysOff,
    'unavailable': unavailable,
  };
  factory SchedulingPreferences.fromJson(Map<String, dynamic> j) =>
      SchedulingPreferences(
        timezone: j['timezone'] as String? ?? '',
        studyStart: j['studyStart'] as String? ?? '',
        studyEnd: j['studyEnd'] as String? ?? '',
        workStart: j['workStart'] as String? ?? '',
        workEnd: j['workEnd'] as String? ?? '',
        notAfter: j['notAfter'] as String? ?? '21:00',
        intensity: j['intensity'] as String? ?? 'regular',
        maxDailyMinutes: j['maxDailyMinutes'] as int? ?? 120,
        breakMinutes: j['breakMinutes'] as int? ?? 15,
        sessionMinutes: j['sessionMinutes'] as int? ?? 60,
        weekdays: List<int>.from(j['weekdays'] as List? ?? []),
        daysOff: List<int>.from(j['daysOff'] as List? ?? []),
        unavailable: (j['unavailable'] as List? ?? [])
            .map((r) => Map<String, String>.from(r as Map))
            .toList(),
      );
  void validate() {
    void check(bool ok) {
      if (!ok) throw const FormatException('Invalid scheduling preferences');
    }

    check(timezone.isEmpty || knownSchedulingZone(timezone));
    for (final pair in [
      [studyStart, studyEnd],
      [workStart, workEnd],
    ]) {
      check(
        pair.every((v) => v.isEmpty) ||
            (pair.every(schedulingTime) && pair[0].compareTo(pair[1]) < 0),
      );
    }
    check(
      schedulingTime(notAfter) &&
          ['light', 'regular', 'intensive'].contains(intensity),
    );
    check(
      maxDailyMinutes >= 15 &&
          maxDailyMinutes <= 720 &&
          breakMinutes >= 0 &&
          breakMinutes <= 120 &&
          sessionMinutes >= 15 &&
          sessionMinutes <= 180,
    );
    for (final days in [weekdays, daysOff]) {
      check(
        days.length <= 7 &&
            days.toSet().length == days.length &&
            days.every((d) => d >= 1 && d <= 7),
      );
    }
    check(unavailable.length <= 60);
    for (final row in unavailable) {
      final date = DateTime.tryParse(row['date'] ?? '');
      check(
        date != null &&
            RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(row['date'] ?? '') &&
            date.toIso8601String().substring(0, 10) == row['date'],
      );
      check(
        schedulingTime(row['startTime'] ?? '') &&
            schedulingTime(row['endTime'] ?? '') &&
            row['startTime']!.compareTo(row['endTime']!) < 0,
      );
    }
  }
}

tz.Location schedulingLocation(String zone) {
  initializeSchedulingZones();
  return zone == 'UTC' ? tz.UTC : tz.getLocation(zone);
}
