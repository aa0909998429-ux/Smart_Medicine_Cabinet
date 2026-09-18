class DuplicateIngredientChecker {
  static const _canonicalAliases = <String, List<String>>{
    'ACETAMINOPHEN': ['ACETAMINOPHEN', 'PARACETAMOL', '乙醯胺酚', '撲熱息痛'],
    'ASPIRIN': ['ACETYLSALICYLIC ACID', 'ASPIRIN', '阿斯匹靈'],
    'IBUPROFEN': ['IBUPROFEN', '布洛芬'],
  };

  static String? checkDuplicate(
    List<Map<String, dynamic>> selectedMedicines,
    Map<String, dynamic> newMedicine,
  ) {
    if (selectedMedicines.isEmpty) return null;

    final newIngredients = _ingredientsOf(newMedicine);
    if (newIngredients.isEmpty) return null;
    final newName = _nameOf(newMedicine);

    for (final existing in selectedMedicines) {
      final duplicated = newIngredients.intersection(_ingredientsOf(existing));
      if (duplicated.isEmpty) continue;

      final names = duplicated.toList()..sort();
      return '⚠️ 重複有效成分提醒\n\n'
          '「$newName」與「${_nameOf(existing)}」的官方資料皆列出：\n'
          '${names.join('、')}\n\n'
          '可能造成重複攝取。這只是成分文字比對，不代表完整交互作用判定；請核對藥品包裝，並諮詢醫師或藥師。';
    }

    return null;
  }

  static Set<String> _ingredientsOf(Map<String, dynamic> medicine) {
    final raw = (medicine['主成分略述'] ?? medicine['ingredients'] ?? '')
        .toString()
        .toUpperCase();
    if (raw.trim().isEmpty) return const {};

    return raw
        .split(RegExp(r';;|；|,|\n|\+'))
        .map(_canonicalize)
        .where((ingredient) => ingredient.length >= 3)
        .toSet();
  }

  static String _canonicalize(String raw) {
    final value = raw
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(
          RegExp(r'\b\d+(?:\.\d+)?\s*(?:MCG|MG|G|ML|L|IU|I\.U\.|%)\b'),
          ' ',
        )
        .replaceAll(RegExp(r'\b\d+(?:\.\d+)?\b'), ' ')
        .replaceAll(RegExp(r'[^A-Z\u4E00-\u9FFF]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    for (final entry in _canonicalAliases.entries) {
      if (entry.value.any(value.contains)) return entry.key;
    }
    return value;
  }

  static String _nameOf(Map<String, dynamic> medicine) {
    return (medicine['中文品名'] ?? medicine['chinese_name'] ?? '未知藥品').toString();
  }
}
