# Reglas conservadoras para release. Flutter y varias dependencias ya incluyen
# consumer rules; estas reglas protegen los puntos criticos usados por la app.

-keepattributes Signature,*Annotation*,InnerClasses,EnclosingMethod

# Flutter embedding y plugins cargados por reflexion/registro.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# Firebase Core y Cloud Messaging.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class io.flutter.plugins.firebase.** { *; }
-keep class io.flutter.plugins.firebase.messaging.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
-dontwarn io.flutter.plugins.firebase.**

# Biometria / local_auth.
-keep class androidx.biometric.** { *; }
-keep class io.flutter.plugins.localauth.** { *; }
-dontwarn androidx.biometric.**
-dontwarn io.flutter.plugins.localauth.**

# Geolocalizacion.
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

# Mantener clases nativas propias referenciadas desde AndroidManifest.
-keep class com.habitobarberia.app.** { *; }
