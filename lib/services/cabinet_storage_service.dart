import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CabinetStorageService {
  static const cabinetKey = 'smart_medicine_cabinet_items_v1';
  static const cabinetBackupKey = 'smart_medicine_cabinet_items_backup_v1';

  Future<List<Map<String, dynamic>>> loadCabinet() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(cabinetKey);
    final cabinet = _decodeList(raw);
    if (cabinet != null) return cabinet;

    final backupRaw = preferences.getString(cabinetBackupKey);
    final backup = _decodeList(backupRaw);
    if (backup == null) return [];

    if (backupRaw != null) {
      await preferences.setString(cabinetKey, backupRaw);
    }
    return backup;
  }

  Future<void> saveCabinet(List<Map<String, dynamic>> medicines) async {
    final preferences = await SharedPreferences.getInstance();
    final current = preferences.getString(cabinetKey);
    if (_decodeList(current) != null && current != null) {
      await preferences.setString(cabinetBackupKey, current);
    }
    final saved = await preferences.setString(
      cabinetKey,
      jsonEncode(medicines),
    );
    if (!saved) throw StateError('無法儲存藥櫃資料');
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
