---
name: Auditoría de release Hábito
fecha: 2026-08-23
version_local: 3.0.13+50
version_publica_ios_verificada: 3.0.12
---

# Auditoría de release — Hábito

## Resultado

La app local está preparada como siguiente release `3.0.13+50`. Se corrigieron mensajes técnicos expuestos al usuario, se unificaron errores de carga en tienda, productos, servicios y sucursales, y se sincronizaron los números de versión de Flutter y de la extensión de notificaciones de iOS.

## Estado de plataformas

- Android: `com.habitobarberia.app`, target/compile SDK provistos por Flutter 3.44.2, SDK local 36 y Java 17 disponibles.
- iOS: `com.habitobarberia.app`, extensión `com.habitobarberia.app.ImageNotification`, Team y perfiles de distribución declarados en el proyecto.
- Deep links Android: `https://habitobarberia.com/.well-known/assetlinks.json` responde correctamente para el paquete publicado.
- Deep links iOS: no existe `apple-app-site-association`; actualmente no se debe anunciar que los enlaces `/referir...` abren la app en iPhone hasta activar Associated Domains y publicar ese archivo.

## Riesgos y bloqueos antes de publicar

1. No existe `android/key.properties` en la máquina. No se debe generar ni subir el AAB hasta configurar el keystore de release.
2. El archive de iOS se genera, pero la exportación IPA requiere un provisioning profile válido para `com.habitobarberia.app.ImageNotification`.
3. El endpoint público de actualización Android todavía reporta `latest_version: 3.0.7`, `latest_build: 25` y `update_available: false`. Después de publicar la nueva versión, actualizarlo a `3.0.13` / `50` y comprobar que no fuerce la descarga de un APK antiguo.
4. La app usa Meta/TikTok con tracking publicitario activo por defecto. Confirmar el consentimiento ATT de iOS y que App Privacy/Data Safety describan exactamente los datos recolectados antes de enviar la build.
5. Las dependencias de Firebase, `local_auth`, `share_plus`, `package_info_plus` y `app_links` tienen versiones mayores disponibles. No se actualizaron en esta release para evitar introducir cambios de plataforma sin una ronda de pruebas dedicada.

## Verificaciones ejecutadas

- `flutter build ios --simulator --no-codesign --no-pub`: correcto.
- `flutter build apk --debug --no-pub`: correcto; muestra warning de migración futura a built-in Kotlin.
- `flutter build appbundle --release --no-pub`: bloqueado correctamente por falta de `android/key.properties`.
- `flutter build ipa --release --no-pub`: archive correcto; exportación bloqueada por el provisioning profile de `ImageNotification`.

## QA manual mínimo

- Android release: login, registro, biometría, push en foreground/background, abrir una notificación, reservar, cancelar, reagendar, puntos, referidos, tienda, carrito, checkout, comprobante, sucursales y enlaces de mapas.
- iPhone release: los mismos flujos, permiso de notificaciones, calendario, galería de fotos, ubicación, Face ID, recepción de push y extensión `ImageNotification`.
- Regresión de datos: cerrar la app con productos en carrito, abrir de nuevo, cambiar entrega/retiro, validar stock/precio y confirmar que una doble pulsación no crea dos pedidos.
- Verificar que el nombre visible sea `Hábito Barbería Cuenca`, que el número sea `3.0.13 (50)` y que las notas de la tienda correspondan a esta release.

## Artefactos de publicación

```bash
flutter build appbundle --release --no-pub
flutter build ipa --release --export-options-plist=ios/UploadOptions.plist
```

El envío final depende de las cuentas de Google Play/App Store Connect, el keystore Android, perfiles de Apple y las credenciales de distribución; no se ejecuta automáticamente desde el repositorio.
