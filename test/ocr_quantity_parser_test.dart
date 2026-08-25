import 'package:flutter_test/flutter_test.dart';
import 'package:smart_med_cabinet/services/ocr_quantity_parser.dart';

void main() {
  group('OcrQuantityParser', () {
    test('extracts common Chinese package quantities', () {
      expect(OcrQuantityParser.extractQuantity('本盒 30 錠'), 30);
      expect(OcrQuantityParser.extractQuantity('內容 12包'), 12);
    });

    test('extracts Japanese and English quantity formats', () {
      expect(OcrQuantityParser.extractQuantity('24錠剤'), 24);
      expect(OcrQuantityParser.extractQuantity('20 tablets'), 20);
    });

    test('does not treat unrelated Chinese text as a medicine unit', () {
      expect(OcrQuantityParser.extractQuantity('保存期限 2028 年'), isNull);
      expect(OcrQuantityParser.extractQuantity('價格 99 元'), isNull);
    });
  });
}
