# Store Release Readiness

## Estado local

- Flutter 3.44.2 / Dart 3.12.2.
- Xcode 26.6 con SDK iOS 26.6.
- Build de iOS simulator disponible localmente.
- macOS release build probado.
- Web release build probado.
- Android SDK 36 y Java 17 están disponibles en esta Mac; todavía falta configurar la firma release.

## Bloqueos antes de subir a App Store

- Verificar que `ios/Runner/GoogleService-Info.plist` corresponde a `com.habitobarberia.app` y está incluido en el target `Runner`.
- Confirmar Apple Developer Team, signing automático/manual y provisioning profiles para:
  - `com.habitobarberia.app`
  - `com.habitobarberia.app.ImageNotification`
- La exportación local de IPA ya mostró el bloqueo exacto: `ImageNotification.appex` requiere un provisioning profile válido.
- Configurar Push Notifications y APNs en Apple Developer + Firebase.
- Completar App Privacy en App Store Connect para datos de cuenta, contacto, compras/pedidos, reservas, ubicación, fotos seleccionadas, analíticas y crash reports.
- Completar consentimiento ATT/App Privacy si se mantiene tracking publicitario activo.

## Bloqueos antes de subir a Google Play

- Crear `android/key.properties` desde `android/key.properties.example`.
- Guardar el keystore fuera del repo.
- Generar `flutter build appbundle --release`.
- La build release local se detiene correctamente si no existe `android/key.properties`.
- Completar Data safety en Play Console para datos de cuenta, contacto, compras/pedidos, reservas, ubicación, fotos seleccionadas, analíticas y crash reports.

## Comandos de validación

```bash
flutter pub get
flutter analyze
flutter test
flutter build ios --release
flutter build appbundle --release
```

El build Android debug y el archive iOS pasan; la firma/exportación de distribución depende de los certificados y perfiles del propietario.
