import 'package:flutter_test/flutter_test.dart';
import 'package:smart_med_cabinet/services/medicine_search_ranker.dart';

void main() {
  group('MedicineSearchRanker', () {
    test('keeps complete OCR medicine names and drops app chrome words', () {
      final keywords = MedicineSearchRanker.extractKeywords(
        '智慧藥櫃 輸入 藥品或症狀 或使用 OCR 掃描 060119 大正百保能感冒錠',
      );

      expect(keywords, contains('大正百保能感冒錠'));
      expect(keywords, isNot(contains('智慧藥櫃')));
      expect(keywords, isNot(contains('輸入')));
    });

    test('ranks an exact OCR medicine name above generic symptom matches', () {
      const exactMedicine = {
        '中文品名': '大正百保能感冒錠',
        '英文品名': 'Taisho Pabron Tablets',
        'aliases': '大正百保能|Pabron|パブロン',
        'permit_number': '衛部藥製字第060119號',
        '適應症': '緩解感冒之各種症狀',
      };
      const genericMedicine = {
        '中文品名': '一般感冒液',
        '英文品名': 'Cold medicine',
        'aliases': '',
        'permit_number': '測試字號',
        '適應症': '緩解感冒之各種症狀',
      };
      final keywords = ['大正百保能感冒錠', '感冒'];

      expect(
        MedicineSearchRanker.score(exactMedicine, keywords),
        greaterThan(MedicineSearchRanker.score(genericMedicine, keywords)),
      );
    });

    test('normalizes Japanese medicine characters for local search', () {
      expect(MedicineSearchRanker.normalize('  風邪薬 剤  '), '風邪藥 劑');
    });
  });
}
