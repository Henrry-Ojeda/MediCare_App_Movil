class OmsEvaluation {
  final double bmi;
  final String statusLabel;
  final String weightPercentile;
  final String heightPercentile;
  final String? headStatusLabel;

  const OmsEvaluation({
    required this.bmi,
    required this.statusLabel,
    required this.weightPercentile,
    required this.heightPercentile,
    this.headStatusLabel,
  });
}

class GrowthTrendEvaluation {
  final bool hasPrevious;
  final String? previousDate;
  final double deltaWeightKg;
  final double deltaHeightCm;
  final double deltaHeadCm;
  final bool isNormalGrowth;
  final String summary;
  final List<String> alerts;

  const GrowthTrendEvaluation({
    required this.hasPrevious,
    this.previousDate,
    required this.deltaWeightKg,
    required this.deltaHeightCm,
    required this.deltaHeadCm,
    required this.isNormalGrowth,
    required this.summary,
    required this.alerts,
  });
}

const List<List<double>> _whoWeightAnchors = [
  [0, 3.3, 0.45, 3.2, 0.42],
  [3, 6.4, 0.72, 5.8, 0.68],
  [6, 7.9, 0.85, 7.3, 0.82],
  [12, 9.6, 1.05, 8.9, 1.0],
  [24, 12.2, 1.35, 11.5, 1.3],
  [36, 14.3, 1.65, 13.9, 1.6],
  [48, 16.3, 1.95, 16.1, 1.95],
  [60, 18.3, 2.3, 18.2, 2.35],
  [84, 22.9, 3.1, 22.4, 3.2],
  [120, 31.2, 4.8, 31.9, 5.1],
];

const List<List<double>> _whoHeightAnchors = [
  [0, 49.9, 1.9, 49.1, 1.9],
  [3, 61.4, 2.1, 59.8, 2.1],
  [6, 67.6, 2.2, 65.7, 2.2],
  [12, 75.7, 2.5, 74.0, 2.5],
  [24, 87.8, 3.1, 86.4, 3.1],
  [36, 96.1, 3.6, 95.1, 3.6],
  [48, 103.3, 4.1, 102.7, 4.1],
  [60, 110.0, 4.5, 109.4, 4.6],
  [84, 121.7, 5.2, 120.8, 5.3],
  [120, 137.8, 6.2, 138.6, 6.4],
];

const List<List<double>> _whoHeadAnchors = [
  [0, 34.5, 1.2, 33.9, 1.2],
  [3, 40.5, 1.2, 39.5, 1.2],
  [6, 43.3, 1.2, 42.2, 1.2],
  [12, 46.1, 1.3, 44.9, 1.3],
  [24, 48.3, 1.3, 47.2, 1.3],
  [36, 49.5, 1.4, 48.5, 1.4],
  [48, 50.3, 1.4, 49.3, 1.4],
  [60, 50.7, 1.4, 49.9, 1.4],
];

({double median, double sd}) _interpolateWho(
  List<List<double>> anchors,
  int ageMonths,
  String sex,
) {
  final clamped = ageMonths.clamp(anchors.first[0].toInt(), anchors.last[0].toInt()).toDouble();
  for (var i = 0; i < anchors.length - 1; i++) {
    final a = anchors[i];
    final b = anchors[i + 1];
    if (clamped >= a[0] && clamped <= b[0]) {
      final ratio = b[0] == a[0] ? 0.0 : (clamped - a[0]) / (b[0] - a[0]);
      final medIdx = sex == 'F' ? 3 : 1;
      final sdIdx = sex == 'F' ? 4 : 2;
      return (
        median: a[medIdx] + (b[medIdx] - a[medIdx]) * ratio,
        sd: a[sdIdx] + (b[sdIdx] - a[sdIdx]) * ratio,
      );
    }
  }
  final last = anchors.last;
  return (median: sex == 'F' ? last[3] : last[1], sd: sex == 'F' ? last[4] : last[2]);
}

String _zToPercentile(double z) {
  if (z < -2) return '< P3';
  if (z < -1) return 'P3–P15';
  if (z <= 1) return 'P15–P85';
  if (z <= 2) return 'P85–P97';
  return '> P97';
}

int calculateAgeInMonths(String birthDateStr, [DateTime? now]) {
  final birth = DateTime.tryParse(birthDateStr);
  if (birth == null) return 0;
  final ref = now ?? DateTime.now();
  final months = (ref.year - birth.year) * 12 + (ref.month - birth.month);
  return months < 0 ? 0 : months;
}

String calculateExactAgeLabel(String birthDateStr, [DateTime? now]) {
  final birth = DateTime.tryParse(birthDateStr);
  if (birth == null) return 'Edad N/D';
  final ref = now ?? DateTime.now();
  var years = ref.year - birth.year;
  var months = ref.month - birth.month;
  if (months < 0) {
    years -= 1;
    months += 12;
  }
  if (years <= 0) {
    final safeMonths = months < 1 ? 1 : months;
    return '$safeMonths ${safeMonths == 1 ? 'mes' : 'meses'}';
  }
  return '$years ${years == 1 ? 'año' : 'años'}, $months ${months == 1 ? 'mes' : 'meses'}';
}

double calculateBmi(double weightKg, double heightCm) {
  final m = heightCm / 100.0;
  if (m <= 0 || weightKg <= 0) return 0;
  return double.parse((weightKg / (m * m)).toStringAsFixed(1));
}

OmsEvaluation evaluateOmsStatus({
  required double weightKg,
  required double heightCm,
  required int ageMonths,
  String sex = 'M',
  double? headCircumferenceCm,
}) {
  final bmi = calculateBmi(weightKg, heightCm);
  if (weightKg <= 0 && heightCm <= 0) {
    return const OmsEvaluation(
      bmi: 0,
      statusLabel: 'Pendiente antropometría',
      weightPercentile: 'N/A',
      heightPercentile: 'N/A',
    );
  }

  final wRef = _interpolateWho(_whoWeightAnchors, ageMonths, sex);
  final hRef = _interpolateWho(_whoHeightAnchors, ageMonths, sex);
  final double? weightZ = weightKg > 0 ? (weightKg - wRef.median) / wRef.sd : null;
  final double? heightZ = heightCm > 0 ? (heightCm - hRef.median) / hRef.sd : null;

  String? headStatusLabel;
  if (headCircumferenceCm != null && headCircumferenceCm > 0 && ageMonths <= 60) {
    final hcRef = _interpolateWho(_whoHeadAnchors, ageMonths, sex);
    final headZ = (headCircumferenceCm - hcRef.median) / hcRef.sd;
    headStatusLabel = headZ < -2
        ? 'Microcefalia (< -2 DE)'
        : headZ > 2
            ? 'Macrocefalia (> +2 DE)'
            : 'PC Normal OMS';
  }

  var statusLabel = 'Eutrófico · OMS';
  if (weightZ != null) {
    if (weightZ < -2) {
      statusLabel = 'Bajo peso (< -2 DE) · OMS';
    } else if (weightZ < -1) {
      statusLabel = 'Riesgo bajo peso · OMS';
    } else if (weightZ > 2) {
      statusLabel = 'Obesidad (> +2 DE) · OMS';
    } else if (weightZ > 1) {
      statusLabel = 'Sobrepeso leve · OMS';
    }
  }
  if (heightZ != null && heightZ < -2) {
    statusLabel = '$statusLabel / Talla baja';
  }

  return OmsEvaluation(
    bmi: bmi,
    statusLabel: statusLabel,
    weightPercentile: weightZ != null ? _zToPercentile(weightZ) : 'N/A',
    heightPercentile: heightZ != null ? _zToPercentile(heightZ) : 'N/A',
    headStatusLabel: headStatusLabel,
  );
}

GrowthTrendEvaluation evaluateGrowthTrend({
  required double weightKg,
  required double heightCm,
  double? headCircumferenceCm,
  required int currentAgeMonths,
  String? previousDate,
  int? previousAgeMonths,
  double? previousWeightKg,
  double? previousHeightCm,
  double? previousHeadCm,
}) {
  if (previousDate == null || previousWeightKg == null || previousHeightCm == null) {
    return const GrowthTrendEvaluation(
      hasPrevious: false,
      deltaWeightKg: 0,
      deltaHeightCm: 0,
      deltaHeadCm: 0,
      isNormalGrowth: true,
      summary: 'Primera medición registrada; servirá como línea base.',
      alerts: [],
    );
  }

  final rawElapsed = (currentAgeMonths - (previousAgeMonths ?? currentAgeMonths)).toDouble();
  final monthsElapsed = rawElapsed < 0.5 ? 0.5 : rawElapsed;
  final deltaWeight = double.parse((weightKg - previousWeightKg).toStringAsFixed(2));
  final deltaHeight = double.parse((heightCm - previousHeightCm).toStringAsFixed(1));
  final deltaHead = (headCircumferenceCm != null && previousHeadCm != null)
      ? double.parse((headCircumferenceCm - previousHeadCm).toStringAsFixed(1))
      : 0.0;

  final alerts = <String>[];
  if (weightKg > 0 && previousWeightKg > 0) {
    if (deltaWeight < 0) {
      alerts.add('Pérdida de peso ($deltaWeight kg) respecto a $previousDate');
    } else if (monthsElapsed >= 1 && currentAgeMonths <= 12 && deltaWeight / monthsElapsed < 0.2) {
      alerts.add('Ganancia ponderal lenta para la edad (< 200 g/mes)');
    }
  }
  if (heightCm > 0 && previousHeightCm > 0 && deltaHeight < 0) {
    alerts.add('Verificar talla: menor que en la cita anterior');
  }
  if (headCircumferenceCm != null &&
      previousHeadCm != null &&
      currentAgeMonths <= 24 &&
      deltaHead < 0) {
    alerts.add('Verificar perímetro cefálico: menor que en cita previa');
  }

  final isNormal = alerts.isEmpty;
  return GrowthTrendEvaluation(
    hasPrevious: true,
    previousDate: previousDate,
    deltaWeightKg: deltaWeight,
    deltaHeightCm: deltaHeight,
    deltaHeadCm: deltaHead,
    isNormalGrowth: isNormal,
    summary: isNormal
        ? 'Crecimiento normal respecto a $previousDate: Peso ${deltaWeight >= 0 ? '+' : ''}$deltaWeight kg · Talla ${deltaHeight >= 0 ? '+' : ''}$deltaHeight cm'
        : 'Atención en tendencia respecto a $previousDate',
    alerts: alerts,
  );
}

List<String> generateTimeSlots(int intervalMinutes, {int startHour = 8, int endHour = 18}) {
  final slots = <String>[];
  for (var mins = startHour * 60; mins <= endHour * 60; mins += intervalMinutes) {
    final h24 = mins ~/ 60;
    final m = mins % 60;
    final period = h24 >= 12 ? 'PM' : 'AM';
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    slots.add('${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period');
  }
  return slots;
}

DateTime? parseSlotToDate(String dateIso, String slotTime) {
  final parts = dateIso.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  final reg = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false);
  final match = reg.firstMatch(slotTime.trim());
  if (match == null) return null;
  var hours = int.parse(match.group(1)!);
  final minutes = int.parse(match.group(2)!);
  final period = match.group(3)!.toUpperCase();
  if (period == 'PM' && hours < 12) hours += 12;
  if (period == 'AM' && hours == 12) hours = 0;
  return DateTime(y, m, d, hours, minutes);
}

bool isSlotInPast(String dateIso, String slotTime, [DateTime? now]) {
  final dt = parseSlotToDate(dateIso, slotTime);
  if (dt == null) return false;
  return dt.isBefore(now ?? DateTime.now());
}

bool isMoreThan24HoursAhead(String dateIso, String slotTime, [DateTime? now]) {
  final dt = parseSlotToDate(dateIso, slotTime);
  if (dt == null) return false;
  return dt.difference(now ?? DateTime.now()) > const Duration(hours: 24);
}
