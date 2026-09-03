import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_med_cabinet/services/cabinet_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('round trips cabinet batches including expiry dates', () async {
    final service = CabinetStorageService();
    final cabinet = [
      {
        'inventory_id': 'batch-1',
        '中文品名': '示範藥品',
        'quantity': 10,
        'expiry_date': '2027-09-02',
      },
    ];

    await service.saveCabinet(cabinet);

    expect(await service.loadCabinet(), cabinet);
  });

  test('returns an empty list for malformed data', () async {
    SharedPreferences.setMockInitialValues({
      CabinetStorageService.cabinetKey: '{broken json',
    });
    expect(await CabinetStorageService().loadCabinet(), isEmpty);

    SharedPreferences.setMockInitialValues({
      CabinetStorageService.cabinetKey: jsonEncode({'not': 'a list'}),
    });
    expect(await CabinetStorageService().loadCabinet(), isEmpty);
  });
}
