enum ExpirationStatus { unknown, valid, expiringSoon, expired }

class InventoryStatus {
  static ExpirationStatus expirationStatus(
    Map<String, dynamic> medicine, {
    DateTime? now,
  }) {
    final expiryDate = DateTime.tryParse(
      medicine['expiry_date']?.toString() ?? '',
    );
    if (expiryDate == null) return ExpirationStatus.unknown;

    final todayValue = now ?? DateTime.now();
    final today = DateTime(todayValue.year, todayValue.month, todayValue.day);
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final daysRemaining = expiry.difference(today).inDays;

    if (daysRemaining < 0) return ExpirationStatus.expired;
    if (daysRemaining <= 30) return ExpirationStatus.expiringSoon;
    return ExpirationStatus.valid;
  }

  static bool isLowStock(Map<String, dynamic> medicine) {
    final quantity = (medicine['quantity'] as num?)?.toInt() ?? 0;
    return quantity < 3;
  }
}
