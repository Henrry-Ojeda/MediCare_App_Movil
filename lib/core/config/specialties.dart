class SpecialtyMeta {
  final int id;
  final String code;
  final String name;
  final int colorHex;

  const SpecialtyMeta({
    required this.id,
    required this.code,
    required this.name,
    required this.colorHex,
  });
}

const List<SpecialtyMeta> kSpecialties = [
  SpecialtyMeta(id: 1, code: 'MEDICINA_GENERAL', name: 'Medicina General', colorHex: 0xFF0F766E),
  SpecialtyMeta(id: 2, code: 'PEDIATRIA', name: 'Pediatría', colorHex: 0xFF0284C7),
  SpecialtyMeta(id: 3, code: 'GINECOLOGIA', name: 'Ginecología', colorHex: 0xFFDB2777),
  SpecialtyMeta(id: 4, code: 'CARDIOLOGIA', name: 'Medicina Interna / Cardiología', colorHex: 0xFFDC2626),
  SpecialtyMeta(id: 5, code: 'TRAUMATOLOGIA', name: 'Traumatología', colorHex: 0xFFD97706),
  SpecialtyMeta(id: 6, code: 'DERMATOLOGIA', name: 'Dermatología', colorHex: 0xFF7C3AED),
];

