import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_med_cabinet/services/medication_history_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('stores new medication entries newest first', () async {
    final service = MedicationHistoryService();
    await service.addEntries([
      {
        'medicine_name': '示範藥品',
        'ingredients': 'DEMO',
        'quantity': 1,
        'taken_at': '2026-09-02T12:00:00.000',
      },
    ]);

    final history = await service.loadHistory();

    expect(history, hasLength(1));
    expect(history.single['medicine_name'], '示範藥品');
    expect(history.single['quantity'], 1);
  });

  test('returns an empty list for invalid stored data', () async {
    SharedPreferences.setMockInitialValues({
      MedicationHistoryService.historyKey: jsonEncode({'invalid': true}),
    });

    expect(await MedicationHistoryService().loadHistory(), isEmpty);
  });

  test('can clear all persisted history', () async {
    final service = MedicationHistoryService();
    await service.addEntries([
      {
        'medicine_name': '示範藥品',
        'quantity': 1,
        'taken_at': '2026-09-02T12:00:00.000',
      },
    ]);

    await service.saveHistory([]);

    expect(await service.loadHistory(), isEmpty);
  });
}
