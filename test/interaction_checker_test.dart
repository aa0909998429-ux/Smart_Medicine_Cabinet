import 'package:flutter_test/flutter_test.dart';
import 'package:smart_med_cabinet/services/duplicate_ingredient_checker.dart';

void main() {
  group('DuplicateIngredientChecker', () {
    test('returns null when no medicine has been selected', () {
      final result = DuplicateIngredientChecker.checkDuplicate([], {
        '中文品名': '測試藥品',
        '主成分略述': 'ACETAMINOPHEN',
      });

      expect(result, isNull);
    });

    test('detects duplicated monitored ingredients', () {
      final selectedMedicines = [
        {'中文品名': '藥品 A', '主成分略述': 'ACETAMINOPHEN 500 MG'},
      ];
      final newMedicine = {'中文品名': '藥品 B', '主成分略述': 'CAFFEINE, ACETAMINOPHEN'};

      final result = DuplicateIngredientChecker.checkDuplicate(
        selectedMedicines,
        newMedicine,
      );

      expect(result, isNotNull);
      expect(result, contains('ACETAMINOPHEN'));
    });

    test('allows medicines without duplicated monitored ingredients', () {
      final selectedMedicines = [
        {'中文品名': '藥品 A', '主成分略述': 'IBUPROFEN'},
      ];
      final newMedicine = {'中文品名': '藥品 B', '主成分略述': 'ACETAMINOPHEN'};

      final result = DuplicateIngredientChecker.checkDuplicate(
        selectedMedicines,
        newMedicine,
      );

      expect(result, isNull);
    });
  });
}
