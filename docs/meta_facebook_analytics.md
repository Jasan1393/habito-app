# Meta / Facebook App Events

La app ya tiene el SDK instalado y conectado al servicio central de analitica. Meta App Events queda activo por defecto con el App ID de Hábito:

```text
13459473576995552
```

## Eventos Enviados

- `login`
- `fb_mobile_complete_registration`
- `referral_code_saved`
- `referral_code_applied`
- `booking_created`
- `order_created`
- `payment_proof_uploaded`
- Cualquier evento registrado por `AnalyticsService.logEvent(...)`

No se envia cedula, RUC, telefono, correo ni nombres a Meta. Solo se envia el ID interno del usuario y parametros operativos no sensibles.

## Android

La version Android usa el App ID por defecto y activa eventos/ad tracking si no se pasan overrides:

```powershell
flutter build appbundle --release
```

Puedes apagarlo o cambiar el App ID con `dart-define` si necesitas un build especial:

```powershell
flutter build appbundle --release `
  --dart-define=HABITO_FACEBOOK_EVENTS_ENABLED=false
```

El permiso `com.google.android.gms.permission.AD_ID` esta declarado porque `HABITO_FACEBOOK_AD_TRACKING_ENABLED` queda activo por defecto. En Google Play, la declaracion de ID de publicidad debe mantenerse como uso para publicidad o marketing.

El `FACEBOOK_CLIENT_TOKEN` tambien queda configurado con el identificador de acceso del cliente de Meta. No uses la clave secreta de la app como client token.

## iOS

El App ID y el client token tambien estan configurados en `Info.plist`.

Y compila con:

```bash
flutter build ipa --release
```

## Modo Seguro

Para builds donde no quieres enviar eventos a Meta, compila con:

```bash
flutter build appbundle --release \
  --dart-define=HABITO_FACEBOOK_EVENTS_ENABLED=false
```

Firebase Analytics/Crashlytics siguen funcionando aunque Meta este apagado.
