import 'package:flutter_test/flutter_test.dart';
import 'package:smart_med_cabinet/services/inventory_status.dart';

void main() {
  final today = DateTime(2026, 9, 2);

  group('InventoryStatus.expirationStatus', () {
    test('reports missing or malformed dates as unknown', () {
      expect(
        InventoryStatus.expirationStatus({}, now: today),
        ExpirationStatus.unknown,
      );
      expect(
        InventoryStatus.expirationStatus({
          'expiry_date': 'not-a-date',
        }, now: today),
        ExpirationStatus.unknown,
      );
    });

    test('treats yesterday as expired and today as expiring soon', () {
      expect(
        InventoryStatus.expirationStatus({
          'expiry_date': '2026-09-01',
        }, now: today),
        ExpirationStatus.expired,
      );
      expect(
        InventoryStatus.expirationStatus({
          'expiry_date': '2026-09-02',
        }, now: today),
        ExpirationStatus.expiringSoon,
      );
    });

    test('warns within 30 days and accepts later dates', () {
      expect(
        InventoryStatus.expirationStatus({
          'expiry_date': '2026-10-02',
        }, now: today),
        ExpirationStatus.expiringSoon,
      );
      expect(
        InventoryStatus.expirationStatus({
          'expiry_date': '2026-10-03',
        }, now: today),
        ExpirationStatus.valid,
      );
    });
  });

  test('low stock means fewer than three units', () {
    expect(InventoryStatus.isLowStock({'quantity': 2}), isTrue);
    expect(InventoryStatus.isLowStock({'quantity': 3}), isFalse);
  });
}
