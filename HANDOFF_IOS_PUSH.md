# Handoff iOS Push - Habito App

Fecha: 2026-06-23  
Rama: `codex/cumpleanos-referidos`  
Version actual: `3.0.11+36`  
Ultimo build subido a TestFlight: `3.0.11 (36)`

## Objetivo

Retomar desde la Mac el build iOS revisado para corregir el caso donde un cliente que inicio sesion en iOS no registraba token FCM activo y seguia apareciendo solo con token Android en el panel de clientes.

Estado actual: el build `36` ya fue archivado y subido a App Store Connect/TestFlight desde la Mac. Falta esperar/probar el procesamiento en TestFlight y validar que el usuario registre un token activo `ios`.

## Diagnostico

- El backend de WordPress si soporta varios tokens por usuario.
- El problema no era que Android reemplazara a iOS.
- El problema probable era que iOS no alcanzaba a registrar un token FCM/APNs valido.
- La configuracion iOS de Firebase debia quedar alineada con la app real de Firebase.

## Firebase confirmado

Firebase Console, app iOS:

- Bundle ID: `com.habitobarberia.app`
- Google App ID: `1:577447468142:ios:77bea4d35d0a8354191a7f`
- Project ID: `habito-app-4e2de`
- Sender ID: `577447468142`

El archivo `ios/Runner/GoogleService-Info.plist` fue descargado desde esa app iOS y verificado contra `lib/firebase_options.dart`.

## Cambios aplicados

- `lib/firebase_options.dart`
  - iOS ahora usa `appId: 1:577447468142:ios:77bea4d35d0a8354191a7f`.
  - iOS ahora usa `iosBundleId: com.habitobarberia.app`.

- `firebase.json`
  - La configuracion FlutterFire de iOS apunta al mismo App ID correcto.

- `ios/Runner/GoogleService-Info.plist`
  - Agregado al proyecto.
  - Registrado como recurso del target Runner en `ios/Runner.xcodeproj/project.pbxproj`.

- `ios/Runner/Runner.entitlements`
  - Agregado `aps-environment` usando `$(APS_ENVIRONMENT)`.

- `ios/Runner.xcodeproj/project.pbxproj`
  - Runner usa `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements`.
  - Debug usa `APS_ENVIRONMENT = development`.
  - Profile y Release usan `APS_ENVIRONMENT = production`.

- `ios/Podfile`
  - Agregado Podfile estandar Flutter con `platform :ios, '13.0'`.

- `lib/core/services/push_notification_service.dart`
  - El registro del token FCM ahora espera APNs en iOS.
  - Agrega reintentos antes de rendirse.
  - Agrega logs cuando iOS no entrega APNs o cuando no se puede guardar el token.

- `lib/features/profile/presentation/pages/profile_page.dart`
  - Agrega boton `Verificar notificaciones` en Perfil.
  - El boton muestra permiso, APNs, FCM y si el token fue guardado en backend.
  - Permite copiar el token FCM para probar envio directo desde Firebase Console.

## Checks ya ejecutados en Windows

```powershell
flutter pub get
flutter analyze
flutter test
```

Resultado:

- `flutter pub get`: OK
- `flutter analyze`: OK, sin issues
- `flutter test`: OK, 5 tests pasaron
- `GoogleService-Info.plist`: XML OK
- `Runner.entitlements`: XML OK
- Android sigue usando `com.habitobarberia.app`

## Checks ejecutados en la Mac

- `pod install`: OK
- `plutil -lint` para `Info.plist`, `Runner.entitlements`, `ExportOptions.plist` y `UploadOptions.plist`: OK
- `flutter analyze`: OK
- `xcodebuild -showBuildSettings` Release:
  - `CURRENT_PROJECT_VERSION = 36`
  - `APS_ENVIRONMENT = production`
  - `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements`
  - `PRODUCT_BUNDLE_IDENTIFIER = com.habitobarberia.app`
  - `PROVISIONING_PROFILE_SPECIFIER = Habito App Store`
- Archive generado:
  - Version: `3.0.11`
  - Build: `36`
  - Display Name: `Hábito Barbería Cuenca`
  - Bundle Identifier: `com.habitobarberia.app`
- Export/subida manual con `ios/UploadOptions.plist`: OK
  - Resultado: `Upload succeeded`
  - Resultado: `EXPORT SUCCEEDED`

Notas:

- Flutter sigue fallando al crear el IPA directo con `flutter build ipa` porque `ImageNotification.appex` requiere provisioning profile. El archive es valido; la exportacion/subida se hizo correctamente con `xcodebuild -exportArchive` y `ios/UploadOptions.plist`.
- Los warnings de dSYM de Firebase/Google no bloquearon la subida a TestFlight. Afectan simbolos de crash reports, no la entrega de notificaciones.

## Pasos si se retoma desde otra Mac

1. Abrir GitHub Desktop o terminal y actualizar la rama:

```bash
git checkout codex/cumpleanos-referidos
git pull
```

2. Preparar Flutter y CocoaPods:

```bash
flutter pub get
cd ios
pod install
cd ..
```

3. Abrir el workspace correcto:

```bash
open ios/Runner.xcworkspace
```

4. En Xcode revisar antes de archivar:

- Target `Runner`
- Bundle Identifier: `com.habitobarberia.app`
- Team: `P6W2XW7GMR`
- Signing automatico o perfil que incluya Push Notifications
- Capability Push Notifications activa
- Build number `36` o superior si App Store Connect ya uso ese numero

5. Crear Archive y subir a TestFlight/App Store Connect.

Comando usado para generar el archive:

```bash
flutter build ipa --release --build-name 3.0.11 --build-number 36
```

Si Flutter falla al exportar por la extension `ImageNotification.appex`, usar la exportacion/subida manual:

```bash
rm -rf build/ios/upload
xcodebuild -exportArchive \
  -archivePath build/ios/archive/Runner.xcarchive \
  -exportPath build/ios/upload \
  -exportOptionsPlist ios/UploadOptions.plist
```

## Prueba funcional despues del build

1. Instalar el nuevo build iOS.
2. Abrir la app.
3. Aceptar permisos de notificaciones.
4. Iniciar sesion con un cliente real.
5. Ir en WordPress al panel de clientes registrados de la app.
6. Confirmar que el cliente muestre un token activo `ios`.
7. En Perfil, tocar `Verificar notificaciones`.
8. Confirmar que el dialogo muestre:
   - `Permiso: authorized`
   - `APNs: OK`
   - `FCM: OK`
   - `Backend: Guardado`
9. Copiar el token FCM desde el dialogo y probar envio directo desde Firebase Console.

El caso esperado es:

- El cliente puede conservar tokens Android historicos o inactivos.
- Debe aparecer al menos un token activo con plataforma `ios`.
- Las notificaciones deben enviarse al token iOS activo.

## Si no aparece token iOS

Revisar logs de la app buscando:

- `iOS no entrego APNs token; FCM no se puede registrar todavia.`
- `No se obtuvo token FCM para registrar en backend.`
- `No se pudo guardar el token FCM en el backend.`

Si aparecen esos logs, revisar:

- Que Firebase tenga APNs Key de produccion cargada para Team ID `P6W2XW7GMR`.
- Que el provisioning profile de Apple incluya Push Notifications.
- Que el build haya usado `com.habitobarberia.app`.
- Que el archivo `GoogleService-Info.plist` empaquetado sea el de `GOOGLE_APP_ID = 1:577447468142:ios:77bea4d35d0a8354191a7f`.

## Comandos para publicar cambios desde Windows

```powershell
git status
git add -A
git commit -m "Fix iOS Firebase push configuration"
git push
```
