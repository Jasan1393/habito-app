# Design system — Hábito

Este archivo es la fuente de verdad de los tokens visuales. Cuando agregues una constante nueva, documéntala aquí *antes* de usarla en el código.

## Estructura objetivo

```
lib/core/theme/
├── app_colors.dart      ← existe; expandir
├── app_theme.dart       ← existe; expandir textTheme
├── app_spacing.dart     ← CREAR
├── app_radius.dart      ← CREAR
├── app_shadows.dart     ← CREAR
└── app_icon_size.dart   ← CREAR (opcional)
```

Cada uno debe ser una clase final con constructor privado y miembros estáticos. Sin singletons mutables.

---

## AppColors (expandir)

```dart
// lib/core/theme/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // === Existentes ===
  static const Color primary = Color(0xFF111111);
  static const Color secondary = Color(0xFFD4AF37);
  static const Color background = Color(0xFFF6F4F1);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF3EFE9);
  static const Color cardDark = Color(0xFF181818);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B6258);
  static const Color textOnDark = Color(0xFFF8F5EF);
  static const Color border = Color(0xFFE7DFD4);
  static const Color borderStrong = Color(0xFFE0CEA0);
  static const Color goldSoft = Color(0xFFF8E7A8);
  static const Color goldMuted = Color(0xFFF7F1E2);
  static const Color success = Color(0xFF1E8E3E);
  static const Color danger = Color(0xFFC62828);

  // === A AGREGAR ===
  // Variantes de oro (extraídas de hardcoded en home/shop):
  static const Color goldDeep = Color(0xFF9C7732);
  static const Color goldDark = Color(0xFF8B6A28);
  static const Color goldDarkOnLight = Color(0xFF7A5C20);

  // Superficies oscuras del home (gradientes hero):
  static const Color darkSurface1 = Color(0xFF0A0A0A);
  static const Color darkSurface2 = Color(0xFF161616);
  static const Color darkSurface3 = Color(0xFF201B14);
  static const Color darkSurfaceWarm = Color(0xFF2B2118);  // SnackBar dark, fallback img

  // Estado destructivo intermedio:
  static const Color dangerDeep = Color(0xFFA33A3A);

  // Indicador del bottom nav:
  // (Hoy hardcoded como 0xFFE7D39A, equivalente a goldSoft con menos saturación)
  static const Color navIndicator = Color(0xFFE7D39A);
}
```

---

## AppTheme.textTheme (expandir)

`lib/core/theme/app_theme.dart` — añadir estilos faltantes al `TextTheme`:

```dart
textTheme: const TextTheme(
  // Existentes (mantener)
  headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
  titleLarge:     TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
  bodyLarge:      TextStyle(fontSize: 16, color: AppColors.textPrimary),
  bodyMedium:     TextStyle(fontSize: 14, color: AppColors.textSecondary),
  
  // Nuevos
  headlineLarge:  TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.textPrimary),  // hero saldo
  titleMedium:    TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
  titleSmall:     TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
  bodySmall:      TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
  labelLarge:     TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
  labelMedium:    TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
  labelSmall:     TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
),
```

Mapeo de tamaños hardcodeados detectados en el repo:

| Hardcoded | Token |
|---|---|
| `fontSize: 11` | `labelSmall` |
| `fontSize: 12` | `labelMedium` |
| `fontSize: 12.5` | `bodySmall` |
| `fontSize: 14` | `bodyMedium` o `labelLarge` (depende de weight) |
| `fontSize: 15` | `titleSmall` (si w700) o ad-hoc |
| `fontSize: 16` | `bodyLarge` |
| `fontSize: 17` | `titleMedium` |
| `fontSize: 20` | `titleLarge` |
| `fontSize: 22` | `titleLarge` con `.copyWith(fontSize: 22)` o ad-hoc |
| `fontSize: 24` | `headlineMedium` |
| `fontSize: 34` | `headlineLarge` |

---

## AppSpacing (crear)

```dart
// lib/core/theme/app_spacing.dart
import 'package:flutter/widgets.dart';

class AppSpacing {
  AppSpacing._();

  // Escala
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  // Helpers SizedBox (usa altura y ancho iguales para que sirvan en row y column)
  static const SizedBox gapXs  = SizedBox(width: xs,  height: xs);
  static const SizedBox gapSm  = SizedBox(width: sm,  height: sm);
  static const SizedBox gapMd  = SizedBox(width: md,  height: md);
  static const SizedBox gapLg  = SizedBox(width: lg,  height: lg);
  static const SizedBox gapXl  = SizedBox(width: xl,  height: xl);
  static const SizedBox gapXxl = SizedBox(width: xxl, height: xxl);

  // Insets comunes
  static const EdgeInsets pageHorizontal = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets pageAll = EdgeInsets.all(lg);
  static const EdgeInsets cardAll = EdgeInsets.all(lg);
  static const EdgeInsets cardCompact = EdgeInsets.all(md);
  static const EdgeInsets cardSpacious = EdgeInsets.all(xl);
  static const EdgeInsets sectionAll = EdgeInsets.all(xxl);

  // Escala de alturas para inputs / botones
  static const double inputHeight = 52;
  static const double inputHeightCompact = 44;
  static const double minTapTarget = 48;  // Material guideline
}
```

Mapeo:

| Hardcoded | Token |
|---|---|
| 4 | `xs` |
| 8 | `sm` |
| 10, 12 | `md` |
| 14, 16, 18 | `lg` |
| 20, 22 | `xl` |
| 24, 26, 28 | `xxl` |
| 32+ | `xxxl` |

---

## AppRadius (crear)

```dart
// lib/core/theme/app_radius.dart
import 'package:flutter/widgets.dart';

class AppRadius {
  AppRadius._();

  static const double sm = 12;     // chips, pills pequeños, inputs
  static const double md = 18;     // cards estándar (alineado con el theme actual)
  static const double lg = 22;     // cards destacadas, product cards
  static const double xl = 28;     // hero cards, modales grandes
  static const double pill = 999;  // chips redondas

  static const Radius smR = Radius.circular(sm);
  static const Radius mdR = Radius.circular(md);
  static const Radius lgR = Radius.circular(lg);
  static const Radius xlR = Radius.circular(xl);

  static const BorderRadius smAll = BorderRadius.all(smR);
  static const BorderRadius mdAll = BorderRadius.all(mdR);
  static const BorderRadius lgAll = BorderRadius.all(lgR);
  static const BorderRadius xlAll = BorderRadius.all(xlR);
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));

  // Helpers para top-only / bottom-only (modales, sheets)
  static const BorderRadius topOnlyXl = BorderRadius.only(
    topLeft: xlR,
    topRight: xlR,
  );
}
```

Mapeo (10+ valores en el repo → 4 tokens):

| Hardcoded | Token |
|---|---|
| 10, 12, 14 | `sm` |
| 16, 18, 20 | `md` |
| 22, 24, 26 | `lg` |
| 28, 30 | `xl` |
| 999 | `pill` |

---

## AppShadows (crear)

```dart
// lib/core/theme/app_shadows.dart
import 'package:flutter/widgets.dart';

class AppShadows {
  AppShadows._();

  // Card sutil (catálogos, listas)
  static const List<BoxShadow> light = [
    BoxShadow(
      color: Color(0x0A000000),  // negro alpha ~0.04
      blurRadius: 14,
      offset: Offset(0, 4),
    ),
  ];

  // Card destacada (producto, hero)
  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color(0x0E000000),  // alpha ~0.055
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];

  // Modal / bottom sheet
  static const List<BoxShadow> strong = [
    BoxShadow(
      color: Color(0x24000000),  // alpha ~0.14
      blurRadius: 24,
      offset: Offset(0, -2),
    ),
  ];

  // Glow dorado para CTAs primarios destacados
  static const List<BoxShadow> goldGlow = [
    BoxShadow(
      color: Color(0x33D4AF37),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];
}
```

---

## AppIconSize (opcional)

```dart
// lib/core/theme/app_icon_size.dart
class AppIconSize {
  AppIconSize._();
  static const double xs  = 14;
  static const double sm  = 16;
  static const double md  = 20;
  static const double lg  = 24;
  static const double xl  = 28;
  static const double xxl = 38;
  static const double hero = 54;
}
```

---

## Componentes a crear

Documentar shape esperado. La implementación va en `lib/shared/widgets/`.

### `HabitoLoadingShimmer`
- Props: `height` (req), `width` (opc), `borderRadius` (opc, default `AppRadius.mdAll`).
- Animación: `LinearGradient` de blanco translúcido moviéndose horizontal cada 1200 ms.
- Sin paquetes externos.

### `HabitoEmptyState`
- Props: `icon`, `title`, `subtitle`, `ctaLabel?`, `onCtaPressed?`.
- Layout vertical centrado, padding `AppSpacing.xxl`, icon `AppIconSize.xxl`.
- CTA usa `ElevatedButton` del theme.

### `HabitoErrorState`
- Igual que EmptyState pero `icon: Icons.error_outline`, color `AppColors.danger`, CTA "Reintentar" obligatorio.

### `HabitoSectionHeader`
- Props: `title`, `trailing?` (widget), `onSeeAllPressed?`.
- Para todas las secciones de lista (Productos destacados, Servicios, etc.).

### `HabitoStepper`
- Props: `value`, `min`, `max`, `onChanged`.
- Tap target 44×44, redondeado.

### `HabitoBankDataSheet`
- BottomSheet que muestra los datos bancarios para transferencia + WhatsApp + botón "Subir comprobante".
- Se invoca desde el flujo post-orden con `bacs`.

---

## Cuándo NO seguir el design system

Casos justificados de salirse del sistema:

1. Una pantalla que es deliberadamente única (ej. splash, onboarding ilustrativo).
2. Un componente de tercero que ya viene con su estilo (date picker, image picker).
3. Animaciones específicas que requieren valores precisos (ej. spring physics).

En esos casos, **comentar el código** explicando por qué se sale del sistema. Sin comentario, asumir que es deuda técnica y migrarlo.

---

## Convenciones de naming

- Tokens: `AppX.snake_case` (`AppSpacing.xxl`, `AppRadius.md`).
- Componentes: `HabitoXxx` (`HabitoLoadingShimmer`, `HabitoEmptyState`).
- Helpers de tema: `AppTheme.lightTheme` (existente).
- Variables de color con propósito específico: `AppColors.navIndicator` antes que `AppColors.goldEighty`.
