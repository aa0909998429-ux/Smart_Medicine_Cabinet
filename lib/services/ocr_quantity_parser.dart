class OcrQuantityParser {
  static final RegExp _numberThenUnit = RegExp(
    r'(\d{1,4})\s*(?:顆|粒|錠(?:剤|劑)?|包|丸|片|tablets?|capsules?|packs?)',
    caseSensitive: false,
  );

  static final RegExp _labelThenNumber = RegExp(
    r'(?:容量|內容|内容|入數|入数|入り)\s*[:：]?\s*(\d{1,4})',
    caseSensitive: false,
  );

  static int? extractQuantity(String text) {
    final directMatch = _numberThenUnit.firstMatch(text);
    if (directMatch != null) {
      return int.tryParse(directMatch.group(1)!);
    }

    final labeledMatch = _labelThenNumber.firstMatch(text);
    if (labeledMatch != null) {
      return int.tryParse(labeledMatch.group(1)!);
    }

    return null;
  }
}
