# Android Release Checklist

## Antes de publicar

- Confirmar `applicationId` final `com.habitobarberia.app` en `android/app/build.gradle.kts`
- Confirmar el paquete Kotlin `com.habitobarberia.app`
- Descargar un `google-services.json` nuevo desde Firebase que coincida con `com.habitobarberia.app`
- Crear `android/key.properties` a partir de `android/key.properties.example`
- Guardar el `.jks` fuera del repo, por ejemplo en `keystores/habito-release.jks`
- Confirmar que `targetSdk` sea 35 o superior. Con Flutter 3.44.2 el proyecto usa `targetSdk 36`.
- Confirmar en Play Console la ficha Data safety para cuenta, reservas, compras, ubicación aproximada/precisa, fotos seleccionadas, analíticas y crash reports.
- La build debug actual muestra el warning de migración futura de Kotlin Gradle Plugin. No bloquea esta release; planificar la migración a built-in Kotlin junto con Flutter 3.47+ y plugins compatibles.

## Firma release

La build release exige `android/key.properties`.

Si el archivo no existe, `flutter build appbundle --release` falla a propósito para evitar subir una build firmada con debug.

## Comandos

### APK release

```bash
flutter build apk --release --no-pub
```

### AAB para Google Play

```bash
flutter build appbundle --release --no-pub
```

## Antes de subir a Play Console

- Confirmar `versionName` y `versionCode`
- Validar permisos reales usados
- Completar ficha de privacidad y Data safety
- Verificar que el nombre visible de la app sea correcto
- Probar login, push, reservas, tienda y checkout en build release
