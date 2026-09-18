import 'dart:convert';

class CabinetBackupData {
  const CabinetBackupData({
    required this.exportedAt,
    required this.cabinet,
    required this.medicationHistory,
  });

  final DateTime exportedAt;
  final List<Map<String, dynamic>> cabinet;
  final List<Map<String, dynamic>> medicationHistory;
}

class CabinetBackupService {
  static const schemaVersion = 1;
  static const maxBackupBytes = 10 * 1024 * 1024;

  String encode({
    required List<Map<String, dynamic>> cabinet,
    required List<Map<String, dynamic>> medicationHistory,
    DateTime? exportedAt,
  }) {
    final sanitizedCabinet = cabinet.map((item) {
      final copy = Map<String, dynamic>.from(item);
      copy.remove('image_path');
      return copy;
    }).toList();

    return const JsonEncoder.withIndent('  ').convert({
      'app': 'smart_med_cabinet',
      'schema_version': schemaVersion,
      'exported_at': (exportedAt ?? DateTime.now()).toIso8601String(),
      'privacy_note': 'Medicine photos are intentionally excluded.',
      'cabinet': sanitizedCabinet,
      'medication_history': medicationHistory,
    });
  }

  CabinetBackupData decode(String raw) {
    if (utf8.encode(raw).length > maxBackupBytes) {
      throw const FormatException('備份檔超過 10 MB 限制');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw const FormatException('不是有效的 JSON 備份檔');
    }
    if (decoded is! Map ||
        decoded['app'] != 'smart_med_cabinet' ||
        decoded['schema_version'] != schemaVersion) {
      throw const FormatException('不是支援的智慧藥櫃備份版本');
    }

    final exportedAt = DateTime.tryParse(
      decoded['exported_at']?.toString() ?? '',
    );
    final cabinet = _mapList(decoded['cabinet'], label: '庫存');
    final history = _mapList(decoded['medication_history'], label: '服藥紀錄');
    if (exportedAt == null) throw const FormatException('備份日期無效');

    for (final item in cabinet) {
      final name = (item['中文品名'] ?? item['chinese_name'])?.toString().trim();
      final quantity = (item['quantity'] as num?)?.toInt();
      if (name == null || name.isEmpty || quantity == null || quantity < 0) {
        throw const FormatException('庫存資料格式不完整');
      }
      item.remove('image_path');
    }
    for (final entry in history) {
      final name = entry['medicine_name']?.toString().trim();
      final quantity = (entry['quantity'] as num?)?.toInt();
      final takenAt = DateTime.tryParse(entry['taken_at']?.toString() ?? '');
      if (name == null ||
          name.isEmpty ||
          quantity == null ||
          quantity <= 0 ||
          takenAt == null) {
        throw const FormatException('服藥紀錄格式不完整');
      }
    }

    return CabinetBackupData(
      exportedAt: exportedAt,
      cabinet: cabinet,
      medicationHistory: history,
    );
  }

  List<Map<String, dynamic>> _mapList(Object? value, {required String label}) {
    if (value is! List || value.any((item) => item is! Map)) {
      throw FormatException('$label不是有效的資料清單');
    }
    return value
        .cast<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
