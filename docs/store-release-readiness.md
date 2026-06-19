# Store Release Readiness

## Estado local

- Flutter 3.44.2 / Dart 3.12.2.
- Xcode 26.5 con SDK iOS 26.5.
- iOS simulator build probado.
- macOS release build probado.
- Web release build probado.
- Android requiere instalar Android Studio, Android SDK y Java en esta Mac antes de generar AAB.

## Bloqueos antes de subir a App Store

- Descargar desde Firebase el `GoogleService-Info.plist` de la app iOS con bundle id `com.habitobarberia.app`.
- Agregar ese plist al target `Runner` en Xcode.
- Confirmar Apple Developer Team, signing automático/manual y provisioning profiles para:
  - `com.habitobarberia.app`
  - `com.habitobarberia.app.ImageNotification`
- Configurar Push Notifications y APNs en Apple Developer + Firebase.
- Completar App Privacy en App Store Connect para datos de cuenta, contacto, compras/pedidos, reservas, ubicación, fotos seleccionadas, analíticas y crash reports.
- Completar consentimiento ATT/App Privacy si se mantiene tracking publicitario activo.

## Bloqueos antes de subir a Google Play

- Instalar Android SDK/JDK localmente o generar el AAB en CI.
- Crear `android/key.properties` desde `android/key.properties.example`.
- Guardar el keystore fuera del repo.
- Generar `flutter build appbundle --release`.
- Completar Data safety en Play Console para datos de cuenta, contacto, compras/pedidos, reservas, ubicación, fotos seleccionadas, analíticas y crash reports.

## Comandos de validación

```bash
flutter pub get
flutter analyze
flutter test
flutter build ios --release
flutter build appbundle --release
```
