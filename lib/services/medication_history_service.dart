import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class MedicationHistoryService {
  static const historyKey = 'smart_medicine_cabinet_history_v1';

  Future<List<Map<String, dynamic>>> loadHistory() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(historyKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveHistory(List<Map<String, dynamic>> history) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(historyKey, jsonEncode(history));
    if (!saved) throw StateError('無法儲存服藥紀錄');
  }

  Future<void> addEntries(List<Map<String, dynamic>> entries) async {
    if (entries.isEmpty) return;

    final history = await loadHistory();
    history.insertAll(0, entries);
    await saveHistory(history);
  }
}
