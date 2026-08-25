import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CabinetStorageService {
  static const _cabinetKey = 'smart_medicine_cabinet_items_v1';

  Future<List<Map<String, dynamic>>> loadCabinet() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_cabinetKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } on FormatException {
      return [];
    }
  }

  Future<void> saveCabinet(List<Map<String, dynamic>> medicines) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_cabinetKey, jsonEncode(medicines));
  }
}
