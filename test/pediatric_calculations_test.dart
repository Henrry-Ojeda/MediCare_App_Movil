import 'package:flutter_test/flutter_test.dart';
import 'package:medicare_doctor_app/core/utils/pediatric_calculations.dart';

void main() {
  group('pediatric_calculations', () {
    test('calcula IMC y estado OMS por edad y sexo', () {
      expect(calculateBmi(18, 100), 18.0);
      final oms = evaluateOmsStatus(
        weightKg: 14.3,
        heightCm: 96,
        ageMonths: 36,
        sex: 'M',
        headCircumferenceCm: 49.5,
      );
      expect(oms.statusLabel, contains('Eutrófico'));
      expect(oms.headStatusLabel, 'PC Normal OMS');
    });

    test('evalúa tendencia de crecimiento frente a cita previa', () {
      final drop = evaluateGrowthTrend(
        weightKg: 8.5,
        heightCm: 75.5,
        currentAgeMonths: 12,
        previousDate: '2026-09-20',
        previousAgeMonths: 10,
        previousWeightKg: 9.0,
        previousHeightCm: 73.0,
      );
      expect(drop.isNormalGrowth, isFalse);
      expect(drop.alerts, isNotEmpty);
    });

    test('bloquea horas pasadas y detecta >24h para WhatsApp', () {
      final tenAm = DateTime(2026, 11, 20, 10, 0);
      expect(isSlotInPast('2026-11-20', '08:00 AM', tenAm), isTrue);
      expect(isSlotInPast('2026-11-20', '11:00 AM', tenAm), isFalse);
      expect(isMoreThan24HoursAhead('2026-11-21', '11:00 AM', tenAm), isTrue);
    });
  });
}
