# Meta / Facebook App Events

La app ya tiene el SDK instalado y conectado al servicio central de analitica, pero queda apagado por defecto para no afectar releases existentes.

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

Antes de compilar una version con Meta activo, define las credenciales de Meta:

```powershell
$env:FACEBOOK_APP_ID="TU_FACEBOOK_APP_ID"
$env:FACEBOOK_CLIENT_TOKEN="TU_FACEBOOK_CLIENT_TOKEN"
flutter build appbundle --release `
  --dart-define=HABITO_FACEBOOK_EVENTS_ENABLED=true `
  --dart-define=HABITO_FACEBOOK_APP_ID=$env:FACEBOOK_APP_ID
```

Si quieres habilitar recoleccion de Advertising ID para atribucion publicitaria:

```powershell
flutter build appbundle --release `
  --dart-define=HABITO_FACEBOOK_EVENTS_ENABLED=true `
  --dart-define=HABITO_FACEBOOK_AD_TRACKING_ENABLED=true `
  --dart-define=HABITO_FACEBOOK_APP_ID=$env:FACEBOOK_APP_ID
```

## iOS

Configura en Xcode las variables de build:

- `FACEBOOK_APP_ID`
- `FACEBOOK_CLIENT_TOKEN`

Y compila con:

```bash
flutter build ipa --release \
  --dart-define=HABITO_FACEBOOK_EVENTS_ENABLED=true \
  --dart-define=HABITO_FACEBOOK_APP_ID="$FACEBOOK_APP_ID"
```

## Modo Seguro

Si no se pasan los `dart-define`, el SDK queda instalado pero no registra eventos. Esto permite seguir usando Firebase Analytics/Crashlytics normalmente.
