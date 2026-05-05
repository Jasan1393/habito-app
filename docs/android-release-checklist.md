# Android Release Checklist

## Antes de publicar

- Confirmar `applicationId` final `com.habitobarberia.app` en `android/app/build.gradle.kts`
- Confirmar el paquete Kotlin `com.habitobarberia.app`
- Descargar un `google-services.json` nuevo desde Firebase que coincida con `com.habitobarberia.app`
- Crear `android/key.properties` a partir de `android/key.properties.example`
- Guardar el `.jks` fuera del repo, por ejemplo en `keystores/habito-release.jks`

## Firma release

La build release ya busca `android/key.properties`.

Si el archivo existe:
- usa firma release

Si no existe:
- cae temporalmente a firma debug para pruebas locales

## Comandos

### APK release

```powershell
flutter build apk --release --no-pub
```

### AAB para Google Play

```powershell
flutter build appbundle --release --no-pub
```

## Antes de subir a Play Console

- Confirmar `versionName` y `versionCode`
- Validar permisos reales usados
- Completar ficha de privacidad y Data safety
- Verificar que el nombre visible de la app sea correcto
- Probar login, push, reservas, tienda y checkout en build release
