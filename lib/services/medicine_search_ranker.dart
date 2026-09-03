class MedicineSearchRanker {
  MedicineSearchRanker._();

  static const _ignoredOcrWords = {
    '智慧藥櫃',
    '輸入',
    '藥品或症狀',
    '使用',
    '或使用',
    'ocr',
    '掃描',
    '使用ocr',
    'ocr掃描',
    '搜尋結果',
    '目前庫存',
  };

  static List<String> extractKeywords(String query, {int limit = 30}) {
    final pureText = query.replaceAll(
      RegExp(r'[^a-zA-Z0-9\u4E00-\u9FA5\u3040-\u30FF\s]'),
      ' ',
    );

    final keywords = <String>[];
    final seen = <String>{};
    for (final token in pureText.split(RegExp(r'\s+'))) {
      final normalized = normalize(token);
      if (normalized.length < 2 ||
          _ignoredOcrWords.contains(normalized) ||
          (RegExp(r'^\d+$').hasMatch(normalized) && normalized.length < 5) ||
          !seen.add(normalized)) {
        continue;
      }
      keywords.add(normalized);
      if (keywords.length == limit) break;
    }
    return keywords;
  }

  static int score(Map<String, dynamic> medicine, Iterable<String> keywords) {
    final primaryFields = [
      medicine['中文品名'],
      medicine['英文品名'],
      medicine['aliases'],
      medicine['permit_number'],
    ].map((value) => normalize(value?.toString() ?? '')).toList();
    final secondaryFields = [
      medicine['主成分略述'],
      medicine['適應症'],
    ].map((value) => normalize(value?.toString() ?? '')).toList();

    var total = 0;
    for (final rawKeyword in keywords) {
      final keyword = normalize(rawKeyword);
      if (keyword.length < 2) continue;

      var strongest = 0;
      for (final field in primaryFields) {
        if (field.isEmpty) continue;
        if (field == keyword) {
          strongest = _max(strongest, 1000 + keyword.length * 20);
        } else if (field.startsWith(keyword)) {
          strongest = _max(strongest, 650 + keyword.length * 15);
        } else if (field.contains(keyword)) {
          strongest = _max(strongest, 400 + keyword.length * 12);
        }
      }
      for (final field in secondaryFields) {
        if (field.contains(keyword)) {
          strongest = _max(strongest, 20 + keyword.length * 3);
        }
      }
      total += strongest;
    }
    return total;
  }

  static String normalize(String value) => value
      .toLowerCase()
      .replaceAll('薬', '藥')
      .replaceAll('剤', '劑')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static int _max(int a, int b) => a > b ? a : b;
}
