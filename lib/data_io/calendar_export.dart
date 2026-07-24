import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:firstapp/database/database_helper.dart';
import 'package:firstapp/other_utilities/unit_conversions.dart';

/// Exports all logged workout sessions as an iCalendar (.ics) file and
/// opens the platform share sheet. One VEVENT per workout session.
class CalendarExport {
  /// Queries all set_log rows, groups them into sessions, builds an ICS
  /// VCALENDAR string, writes it to a temp file, and shares it.
  ///
  /// Returns false (no share sheet) if there is no workout history yet.
  static Future<bool> exportWorkoutsAsIcs({
    required bool useMetric,
    Rect? sharePositionOrigin,
  }) async {
    final db = await DatabaseHelper.instance.database;

    // One query — LEFT JOIN so history survives exercises deleted after logging.
    final rows = await db.rawQuery('''
      SELECT
        sl.session_id,
        sl.date,
        sl.num_sets,
        sl.reps,
        sl.weight,
        sl.rpe,
        sl.day_title,
        sl.program_title,
        COALESCE(e.exercise_title, 'Unknown exercise') AS exercise_title
      FROM set_log sl
      LEFT JOIN exercises e ON e.id = sl.exercise_id
      ORDER BY sl.session_id ASC, sl.date ASC, sl.id ASC
    ''');

    if (rows.isEmpty) return false;

    // Group rows into sessions while preserving chronological order.
    final sessions = <String, List<Map<String, Object?>>>{};
    for (final row in rows) {
      final sessionId = row['session_id'] as String;
      sessions.putIfAbsent(sessionId, () => []).add(row);
    }

    final buffer = StringBuffer();
    // RFC 5545 requires CRLF line endings and long-line folding.
    void writeLine(String line) => buffer.write('${_fold(line)}\r\n');

    writeLine('BEGIN:VCALENDAR');
    writeLine('VERSION:2.0');
    writeLine('PRODID:-//tracket//Workout History//EN');
    writeLine('CALSCALE:GREGORIAN');
    writeLine('METHOD:PUBLISH');
    writeLine('X-WR-CALNAME:tracket Workouts');

    final dtStamp = _formatUtc(DateTime.now().toUtc());
    final unit = useMetric ? 'kg' : 'lbs';

    for (final entry in sessions.entries) {
      final sets = entry.value;

      // Parse timestamps; skip malformed rows; skip session if none parse.
      final times = <DateTime>[];
      for (final row in sets) {
        final t = DateTime.tryParse(row['date'] as String? ?? '');
        if (t != null) times.add(t);
      }
      if (times.isEmpty) continue;
      times.sort();

      final start = times.first;
      var end = times.last;
      if (!end.isAfter(start)) {
        // Single-set or simultaneous timestamps: give session a 1-hour block.
        end = start.add(const Duration(hours: 1));
      }

      final dayTitle = (sets.first['day_title'] as String?)?.trim() ?? '';
      final programTitle = (sets.first['program_title'] as String?)?.trim() ?? '';
      final summary = dayTitle.isNotEmpty ? dayTitle : 'Workout';

      // Group by exercise so interleaved/superset rows read cleanly.
      final byExercise = <String, List<Map<String, Object?>>>{};
      for (final row in sets) {
        final title = row['exercise_title'] as String;
        byExercise.putIfAbsent(title, () => []).add(row);
      }

      // Build DESCRIPTION text.
      final descLines = <String>[];
      if (programTitle.isNotEmpty) descLines.add('Program: $programTitle');
      for (final ex in byExercise.entries) {
        for (final row in ex.value) {
          final numSets = (row['num_sets'] as num).toInt();
          final reps = _fmtNum(row['reps'] as num);
          final weightLbs = (row['weight'] as num).toDouble();
          final displayWeight = useMetric ? lbToKg(pounds: weightLbs) : weightLbs;
          final rpe = (row['rpe'] as num).toDouble();
          final rpePart = rpe > 0 ? ' @ RPE ${_fmtNum(rpe)}' : '';
          descLines.add(
            '${ex.key}: $numSets×$reps ${_fmtNum(displayWeight)}$unit$rpePart',
          );
        }
      }
      final description = descLines.join('\n');

      writeLine('BEGIN:VEVENT');
      // Stable UID: re-exporting and re-importing updates events in most
      // calendar apps rather than duplicating them.
      writeLine('UID:tracket-${_sanitizeUid(entry.key)}@tracket.app');
      writeLine('DTSTAMP:$dtStamp');
      // NOTE: set_log.date has no timezone offset. DateTime.parse treats it as
      // device-local time; .toUtc() applies the historically-correct offset.
      // Workouts logged while traveling may display slightly shifted.
      writeLine('DTSTART:${_formatUtc(start.toUtc())}');
      writeLine('DTEND:${_formatUtc(end.toUtc())}');
      writeLine('SUMMARY:${_escapeText(summary)}');
      writeLine('DESCRIPTION:${_escapeText(description)}');
      writeLine('END:VEVENT');
    }

    writeLine('END:VCALENDAR');

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .substring(0, 19);
    final filePath = '${tempDir.path}/tracket_workouts_$timestamp.ics';
    await File(filePath).writeAsString(buffer.toString());

    await Share.shareXFiles(
      [XFile(filePath, mimeType: 'text/calendar')],
      subject: 'tracket Workout Calendar',
      sharePositionOrigin: sharePositionOrigin,
    );
    return true;
  }

  // ─── ICS text helpers ───

  /// Formats a UTC DateTime as RFC 5545 UTC timestamp: 20260723T183000Z
  static String _formatUtc(DateTime utc) {
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}'
        '${p2(utc.month)}${p2(utc.day)}T'
        '${p2(utc.hour)}${p2(utc.minute)}${p2(utc.second)}Z';
  }

  /// RFC 5545 §3.3.11 TEXT escaping (backslash first, then ; , \n).
  static String _escapeText(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll(';', '\\;')
      .replaceAll(',', '\\,')
      .replaceAll('\r\n', '\n')
      .replaceAll('\n', '\\n');

  /// Strip characters unsafe for UIDs; session_id is a timestamp string.
  static String _sanitizeUid(String s) =>
      s.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '-');

  /// RFC 5545 line folding: fold at 70 chars; continuation lines start with
  /// one space (CRLF + SPACE). Keeps multi-byte UTF-8 characters within bounds.
  static String _fold(String line) {
    if (line.length <= 70) return line;
    final sb = StringBuffer();
    var i = 0;
    while (i < line.length) {
      final end = (i + 70 < line.length) ? i + 70 : line.length;
      if (i > 0) sb.write('\r\n ');
      sb.write(line.substring(i, end));
      i = end;
    }
    return sb.toString();
  }

  /// Renders num cleanly: 8.0 → "8", 8.5 → "8.5", 102.50 → "102.5".
  static String _fmtNum(num v) {
    final d = v.toDouble();
    if (d == d.roundToDouble()) return d.toInt().toString();
    var s = d.toStringAsFixed(2);
    while (s.endsWith('0')) s = s.substring(0, s.length - 1);
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
    return s;
  }
}
