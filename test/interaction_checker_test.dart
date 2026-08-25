import 'package:flutter_test/flutter_test.dart';
import 'package:smart_med_cabinet/main.dart';

void main() {
  group('InteractionChecker', () {
    test('returns null when the pillbox is empty', () {
      final result = InteractionChecker.checkConflict(
        [],
        {'中文品名': '測試藥品', '主成分略述': 'ACETAMINOPHEN'},
      );

      expect(result, isNull);
    });

    test('detects duplicate high-risk ingredients', () {
      final currentPillbox = [
        {'中文品名': '藥品 A', '主成分略述': 'ACETAMINOPHEN 500 MG'},
      ];
      final newMedicine = {
        '中文品名': '藥品 B',
        '主成分略述': 'CAFFEINE, ACETAMINOPHEN',
      };

      final result = InteractionChecker.checkConflict(
        currentPillbox,
        newMedicine,
      );

      expect(result, isNotNull);
      expect(result, contains('ACETAMINOPHEN'));
    });

    test('allows medicines without duplicated configured ingredients', () {
      final currentPillbox = [
        {'中文品名': '藥品 A', '主成分略述': 'IBUPROFEN'},
      ];
      final newMedicine = {
        '中文品名': '藥品 B',
        '主成分略述': 'ACETAMINOPHEN',
      };

      final result = InteractionChecker.checkConflict(
        currentPillbox,
        newMedicine,
      );

      expect(result, isNull);
    });
  });
}
