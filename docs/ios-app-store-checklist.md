# iOS App Store Checklist

## Estado tecnico actual

- Bundle ID principal: `com.habitobarberia.app`.
- Extension de notificaciones: `com.habitobarberia.app.ImageNotification`.
- Version publicada actualmente: `3.0.12`.
- Siguiente release preparada en el código: `3.0.13 (50)`.
- Firebase iOS plist agregado en `ios/Runner/GoogleService-Info.plist`.
- App icon 1024x1024 sin alpha verificado.
- La build de simulador y el archive de iOS se generan localmente; la exportación IPA queda bloqueada si falta el provisioning profile de `ImageNotification`.
- Tracking publicitario activo por defecto.

## Cuando Apple apruebe la cuenta Developer

1. Abrir `ios/Runner.xcworkspace`.
2. Seleccionar el Team en target `Runner`.
3. Seleccionar el mismo Team en target `ImageNotification`.
4. Activar Push Notifications en Apple Developer para:
   - `com.habitobarberia.app`
   - `com.habitobarberia.app.ImageNotification`
5. Activar Associated Domains si se quiere que los links `https://habitobarberia.com/referir...` abran la app en iOS.
6. Subir la clave APNs a Firebase Cloud Messaging.
7. Generar y subir build:

```bash
flutter build ipa --release
```

## App Store Connect

- Nombre sugerido: `Hábito Barbería Cuenca`.
- Categoria sugerida: `Lifestyle` o `Shopping`.
- URL de soporte: `https://habitobarberia.com/`
- Politica de privacidad: `https://habitobarberia.com/politica-de-privacidad/`
- Eliminacion de cuenta: `https://habitobarberia.com/eliminacion-de-datos/`

## Datos para App Privacy

Marcar segun uso real de la app:

- Contact Info: nombre, email, telefono.
- User Content: foto seleccionada para perfil o comprobante.
- Purchases: pedidos y pagos/comprobantes.
- Location: ubicacion aproximada/precisa para sucursales cercanas.
- Identifiers: user ID interno, Firebase installation/device token.
- Usage Data: analiticas de uso.
- Diagnostics: crash reports.

Declarar tracking publicitario si se mantiene IDFA/ATT activo.

## Firebase Analytics

Firebase Analytics queda activo en iOS con `IS_ANALYTICS_ENABLED=true`.
La recopilacion publicitaria de Firebase en el plist sigue con `IS_ADS_ENABLED=false`, pero Meta/TikTok quedan configurados para tracking publicitario por defecto.
