import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_med_cabinet/db_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> payload;
  late Map<String, dynamic> metadata;
  late List<Map<String, dynamic>> medicines;

  setUpAll(() async {
    final raw = await rootBundle.loadString(DatabaseHelper.datasetAsset);
    payload = jsonDecode(raw) as Map<String, dynamic>;
    metadata = Map<String, dynamic>.from(payload['metadata'] as Map);
    medicines = (payload['medicines'] as List)
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .toList();
  });

  test('metadata matches the bundled official-data subset', () {
    expect(metadata['source_url'], contains('data.fda.gov.tw'));
    expect(metadata['license'], contains('政府資料開放授權條款'));
    expect(metadata['medicine_count'], medicines.length);
    expect(medicines.length, greaterThan(5000));
  });

  test('every bundled medicine has a unique permit and valid category', () {
    const allowedCategories = {'成藥', '乙類成藥', '醫師藥師藥劑生指示藥品'};
    final permitNumbers = medicines
        .map((medicine) => medicine['permit_number'])
        .toSet();

    expect(permitNumbers.length, medicines.length);
    for (final medicine in medicines) {
      expect(medicine['chinese_name'], isNotEmpty);
      expect(allowedCategories, contains(medicine['category']));
      expect(medicine['license_expiry_date'], isNotEmpty);
    }
  });

  test('includes active Taisho Pabron products and search aliases', () {
    final pabron = medicines.singleWhere(
      (medicine) => medicine['chinese_name'] == '大正百保能感冒錠',
    );

    expect(pabron['permit_number'], '衛部藥製字第060119號');
    expect(pabron['aliases'], containsAll(['大正百保能', 'パブロン', 'Pabron']));
  });
}
