import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class MedicationHistoryService {
  static const historyKey = 'smart_medicine_cabinet_history_v1';
  static const historyBackupKey = 'smart_medicine_cabinet_history_backup_v1';

  Future<List<Map<String, dynamic>>> loadHistory() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(historyKey);
    final history = _decodeList(raw);
    if (history != null) return history;

    final backupRaw = preferences.getString(historyBackupKey);
    final backup = _decodeList(backupRaw);
    if (backup == null) return [];

    if (backupRaw != null) {
      await preferences.setString(historyKey, backupRaw);
    }
    return backup;
  }

  Future<void> saveHistory(List<Map<String, dynamic>> history) async {
    final preferences = await SharedPreferences.getInstance();
    final current = preferences.getString(historyKey);
    if (_decodeList(current) != null && current != null) {
      await preferences.setString(historyBackupKey, current);
    }
    final saved = await preferences.setString(historyKey, jsonEncode(history));
    if (!saved) throw StateError('無法儲存服藥紀錄');
  }

  Future<void> addEntries(List<Map<String, dynamic>> entries) async {
    if (entries.isEmpty) return;

    final history = await loadHistory();
    history.insertAll(0, entries);
    await saveHistory(history);
  }

  List<Map<String, dynamic>>? _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return null;
    }
  }
}
