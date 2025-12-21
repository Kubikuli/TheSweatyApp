import '../database/database_helper.dart';
import '../models/timer_session.dart';

class TimerService {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<int> saveTimerSession(TimerSession session) async {
    return await _db.createTimerSession(session);
  }

  Future<List<TimerSession>> getTimerSessionsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    return await _db.getTimerSessionsByDateRange(start, end);
  }

  Future<List<TimerSession>> getTimerSessionsForWeek(DateTime date) async {
    // Normalize to date-only (midnight) to avoid time-based comparison issues
    final dateOnly = DateTime(date.year, date.month, date.day);
    final startOfWeek = dateOnly.subtract(Duration(days: dateOnly.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));
    return await getTimerSessionsByDateRange(startOfWeek, endOfWeek);
  }

  Future<int> deleteTimerSession(int id) async {
    return await _db.deleteTimerSession(id);
  }
}
