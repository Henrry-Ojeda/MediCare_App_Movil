## Descripción del Cambio (App Móvil Doctor)
- ¿Qué pantalla, flujo o corrección incluye?

## Ambiente Destino
- [ ] `develop` (Desarrollo)
- [ ] `qa` (Genera APK de QA — viene desde `develop`)
- [ ] `main` (PRODUCCIÓN — **solo desde `qa` o `hotfix/*` y con autorización**)

## Checklist Obligatorio antes de Aprobar
- [ ] `flutter analyze` sin errores.
- [ ] Probado en APK de **QA** contra `BD_MEDICARE_QA` (login biométrico/JWT, historial y permisos de diagnóstico).
