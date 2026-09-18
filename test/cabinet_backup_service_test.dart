import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_med_cabinet/services/cabinet_backup_service.dart';

void main() {
  const cabinet = [
    {
      'inventory_id': 'batch-1',
      '中文品名': '測試藥品',
      'quantity': 8,
      'expiry_date': '2028-05-01',
      'image_path': '/private/photo.jpg',
    },
  ];
  const history = [
    {
      'medicine_name': '測試藥品',
      'quantity': 1,
      'taken_at': '2026-09-11T09:30:00.000',
    },
  ];

  test('round trips inventory and history without private photo paths', () {
    final service = CabinetBackupService();
    final raw = service.encode(
      cabinet: cabinet,
      medicationHistory: history,
      exportedAt: DateTime(2026, 9, 11),
    );
    final restored = service.decode(raw);

    expect(restored.cabinet, hasLength(1));
    expect(restored.cabinet.single['中文品名'], '測試藥品');
    expect(restored.cabinet.single, isNot(contains('image_path')));
    expect(restored.medicationHistory, history);
  });

  test('rejects unrelated or malformed backup files', () {
    final service = CabinetBackupService();

    expect(() => service.decode('not json'), throwsFormatException);
    expect(
      () => service.decode(jsonEncode({'app': 'another_app'})),
      throwsFormatException,
    );
  });

  test('rejects invalid medicine data and strips injected photo paths', () {
    final service = CabinetBackupService();
    final invalid = jsonEncode({
      'app': 'smart_med_cabinet',
      'schema_version': 1,
      'exported_at': '2026-09-11T00:00:00.000',
      'cabinet': [
        {'中文品名': '', 'quantity': -1, 'image_path': 'C:/unsafe.jpg'},
      ],
      'medication_history': [],
    });

    expect(() => service.decode(invalid), throwsFormatException);
  });
}
