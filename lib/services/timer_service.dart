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
    final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    return await getTimerSessionsByDateRange(startOfWeek, endOfWeek);
  }

  Future<int> deleteTimerSession(int id) async {
    return await _db.deleteTimerSession(id);
  }
}
