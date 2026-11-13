# MediCare Doctor App (Flutter Nativo)

Aplicación móvil nativa para médicos de **MediCare**, conectada a `MediCare.API` (`.NET 8 + SQL Server`), con arquitectura de seguridad bancaria:
- Almacenamiento cifrado de JWT en hardware (`flutter_secure_storage` / Android Keystore).
- Desbloqueo biométrico (Huella / Face ID con `local_auth`).
- Bloqueo automático por inactividad / cambio de app.
- `FLAG_SECURE` en Android para impedir capturas de pantalla sobre historias clínicas.

## Requisitos en Windows para compilar el APK
1. Instalar Flutter SDK:
   ```powershell
   winget install Google.Flutter
   ```
2. Instalar Android Studio (incluye Android SDK y cmdline-tools) y aceptar licencias:
   ```powershell
   flutter doctor --android-licenses
   ```
3. Generar la carpeta nativa `android/` (si aún no la generaste con `flutter create .`) y compilar el APK:
   ```powershell
   flutter create . --org com.medicare --project-name medicare_doctor_app
   flutter pub get
   flutter build apk --release
   ```
   El APK final quedará en `build/app/outputs/flutter-apk/app-release.apk`.

