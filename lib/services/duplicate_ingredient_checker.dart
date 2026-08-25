class DuplicateIngredientChecker {
  static const monitoredIngredients = <String>[
    'ACETAMINOPHEN',
    'IBUPROFEN',
    'ASPIRIN',
  ];

  static String? checkDuplicate(
    List<Map<String, dynamic>> selectedMedicines,
    Map<String, dynamic> newMedicine,
  ) {
    if (selectedMedicines.isEmpty) return null;

    final newIngredients = _ingredientsOf(newMedicine);
    final newName = _nameOf(newMedicine);

    for (final existing in selectedMedicines) {
      final existingIngredients = _ingredientsOf(existing);
      final existingName = _nameOf(existing);

      for (final ingredient in monitoredIngredients) {
        if (newIngredients.contains(ingredient) &&
            existingIngredients.contains(ingredient)) {
          return '⚠️ 重複有效成分提醒\n\n'
              '「$newName」與「$existingName」皆含有：$ingredient\n\n'
              '可能造成重複攝取。請確認藥品包裝，並在需要時諮詢醫師或藥師。';
        }
      }
    }

    return null;
  }

  static String _ingredientsOf(Map<String, dynamic> medicine) {
    return (medicine['主成分略述'] ?? medicine['ingredients'] ?? '')
        .toString()
        .toUpperCase();
  }

  static String _nameOf(Map<String, dynamic> medicine) {
    return (medicine['中文品名'] ?? medicine['chinese_name'] ?? '未知藥品')
        .toString();
  }
}
