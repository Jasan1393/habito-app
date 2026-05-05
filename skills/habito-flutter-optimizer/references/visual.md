# Patrones visuales — Hábito

## Identidad de marca

Barbería de lujo. Paleta:
- **Negro** `#111111` (primary)
- **Dorado** `#D4AF37` (secondary / acento)
- **Crema** `#F6F4F1` (background)

Tipografía: la del tema base de Material 3 (Roboto en Android, SF en iOS). No agregar fuentes custom sin pedir permiso.

Estilo: bordes redondeados (12-28 px), sombras suaves, mucho whitespace, jerarquía clara entre negro/blanco/dorado.

---

## Cuándo usar `AppColors`

`lib/core/theme/app_colors.dart` ya define la paleta. Si necesitas un color que no está, **agrégalo allí primero** con un nombre semántico (no `goldDark2`, sino `goldDeep` o `goldOnDarkSurface`).

**Casos típicos a agregar a AppColors** (cuando ejecutes la fase de design system):

```dart
// lib/core/theme/app_colors.dart
class AppColors {
  // Existentes
  static const Color primary = Color(0xFF111111);
  static const Color secondary = Color(0xFFD4AF37);
  static const Color background = Color(0xFFF6F4F1);
  // ...

  // Agregar (variantes de oro detectadas en el repo):
  static const Color goldDeep = Color(0xFF9C7732);
  static const Color goldDark = Color(0xFF8B6A28);
  static const Color goldDarkOnLight = Color(0xFF7A5C20);

  // Gradientes oscuros del home (agregar como pares):
  static const Color darkSurface1 = Color(0xFF0A0A0A);
  static const Color darkSurface2 = Color(0xFF161616);
  static const Color darkSurface3 = Color(0xFF201B14);

  // Estado destructivo / negativo en historial:
  static const Color danger = Color(0xFFC62828);  // ya existe
  static const Color dangerDeep = Color(0xFFA33A3A);

  // Para feedback de éxito en SnackBars:
  static const Color successBg = Color(0xFF1E8E3E);
}
```

## Cuándo usar `Theme.of(context).textTheme.X`

El theme define 4 estilos: `headlineMedium`, `titleLarge`, `bodyLarge`, `bodyMedium`. **Faltan**: `titleSmall`, `bodySmall`, `labelMedium`, `labelSmall`. Cuando el design system se extienda, agrega:

```dart
// lib/core/theme/app_theme.dart  (dentro de textTheme:)
textTheme: const TextTheme(
  // existentes
  headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
  titleLarge:     TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
  titleMedium:    TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
  titleSmall:     TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
  bodyLarge:      TextStyle(fontSize: 16, color: AppColors.textPrimary),
  bodyMedium:     TextStyle(fontSize: 14, color: AppColors.textSecondary),
  bodySmall:      TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
  labelLarge:     TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
  labelMedium:    TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
  labelSmall:     TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
),
```

Migración desde `fontSize: N`:

| Antes | Después |
|---|---|
| `TextStyle(fontSize: 22, fontWeight: FontWeight.w800)` | `Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 22)` o `titleLarge` si encaja |
| `TextStyle(fontSize: 14, fontWeight: FontWeight.w700)` | `Theme.of(context).textTheme.labelLarge` |
| `TextStyle(fontSize: 12.5, color: AppColors.textSecondary)` | `Theme.of(context).textTheme.bodySmall` |

## Espaciado: `AppSpacing`

Crear `lib/core/theme/app_spacing.dart`:

```dart
class AppSpacing {
  AppSpacing._();
  
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  
  // Helpers comunes:
  static const SizedBox gapXs = SizedBox(height: xs, width: xs);
  static const SizedBox gapSm = SizedBox(height: sm, width: sm);
  static const SizedBox gapMd = SizedBox(height: md, width: md);
  static const SizedBox gapLg = SizedBox(height: lg, width: lg);
  static const SizedBox gapXl = SizedBox(height: xl, width: xl);
  static const SizedBox gapXxl = SizedBox(height: xxl, width: xxl);

  static const EdgeInsets pageHorizontal = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets cardAll = EdgeInsets.all(lg);
  static const EdgeInsets sectionAll = EdgeInsets.all(xl);
}
```

Migración:

| Antes | Después |
|---|---|
| `SizedBox(height: 16)` | `AppSpacing.gapLg` |
| `EdgeInsets.all(16)` | `AppSpacing.cardAll` o `EdgeInsets.all(AppSpacing.lg)` |
| `EdgeInsets.symmetric(horizontal: 16, vertical: 14)` | `EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg - 2)` o agregar un nuevo helper |

## Bordes: `AppRadius`

Crear `lib/core/theme/app_radius.dart`:

```dart
class AppRadius {
  AppRadius._();
  
  static const double sm = 12;   // chips, pills pequeños
  static const double md = 18;   // cards estándar (alineado al theme actual)
  static const double lg = 22;   // cards destacadas
  static const double xl = 28;   // hero cards
  static const double pill = 999;
  
  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get xlAll => BorderRadius.circular(xl);
  static BorderRadius get pillAll => BorderRadius.circular(pill);
}
```

Migración: cualquier `BorderRadius.circular(N)` mapea a `sm` (≤14), `md` (15-20), `lg` (21-26), `xl` (27+). Usa el más cercano al original.

## Sombras: `AppShadows`

Crear `lib/core/theme/app_shadows.dart`:

```dart
class AppShadows {
  AppShadows._();
  
  static const List<BoxShadow> light = [
    BoxShadow(
      color: Color(0x0A000000),  // negro alpha 0.04
      blurRadius: 14,
      offset: Offset(0, 4),
    ),
  ];
  
  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color(0x0E000000),  // negro alpha 0.055
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];
  
  static const List<BoxShadow> strong = [
    BoxShadow(
      color: Color(0x24000000),  // negro alpha 0.14
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
  
  // Sombra dorada para CTAs principales:
  static const List<BoxShadow> goldGlow = [
    BoxShadow(
      color: Color(0x33D4AF37),  // dorado alpha 0.2
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];
}
```

## Iconos

Tamaños permitidos: 14, 16, 20, 24, 28, 38. Crear opcionalmente `AppIconSize`:

```dart
class AppIconSize {
  AppIconSize._();
  static const double xs = 14;
  static const double sm = 16;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 28;
  static const double xxl = 38;
}
```

Solo Material Icons. **No mezclar Cupertino** (excepto `cupertino_icons` que ya está en pubspec por compatibilidad de assets — no usar widgets Cupertino).

## Componentes reusables a crear

Estos widgets aún no existen. Cuando una pantalla los necesite, créalos en `lib/shared/widgets/` siguiendo este shape:

### `HabitoLoadingShimmer`

```dart
// lib/shared/widgets/habito_loading_shimmer.dart
class HabitoLoadingShimmer extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadius borderRadius;
  
  const HabitoLoadingShimmer({
    super.key,
    required this.height,
    this.width,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadius.md)),
  });
  
  // Implementa con AnimationController + LinearGradient (sin paquetes externos).
}
```

### `HabitoEmptyState`

```dart
// lib/shared/widgets/habito_empty_state.dart
class HabitoEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? ctaLabel;
  final VoidCallback? onCtaPressed;
  
  const HabitoEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.ctaLabel,
    this.onCtaPressed,
  });
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppIconSize.xxl, color: AppColors.textSecondary),
            AppSpacing.gapMd,
            Text(title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            AppSpacing.gapSm,
            Text(subtitle,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (ctaLabel != null && onCtaPressed != null) ...[
              AppSpacing.gapLg,
              ElevatedButton(onPressed: onCtaPressed, child: Text(ctaLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
```

### `HabitoErrorState`

Igual que `EmptyState` pero con `icon: Icons.error_outline`, color `AppColors.danger` y CTA "Reintentar" obligatorio.

## Headers / AppBar

`AppTopHeader` ya existe (`lib/shared/widgets/app_top_header.dart`). **Usarlo siempre** que la pantalla sea parte del flujo principal. Excepción documentada: `ProfilePage` (usa `AppBar` nativo con tema oscuro).

Pantallas que actualmente usan `AppBar` y deberían migrar:
- `MyAppointmentsPage`
- `OrdersPage`
- `AppointmentDetailPage` (parcialmente)

## Botones

Solo `ElevatedButton` (CTA primario) y `OutlinedButton` (CTA secundario). Evitar `TextButton` salvo en diálogos. Si necesitas un botón "destructivo" (cancelar cita, eliminar), usar:

```dart
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: AppColors.danger,
    foregroundColor: Colors.white,
  ),
  onPressed: ...,
  child: const Text('Cancelar cita'),
)
```

O un `OutlinedButton` con borde rojo si quieres una acción menos enfática.

**No reusar el dorado** para acciones destructivas — es el color de las acciones positivas.

## Bottom navigation

`HabitoBottomNavigationBar` ya existe. Usar `AppColors.goldSoft` en lugar del hardcoded `Color(0xFFE7D39A)` cuando se haga la limpieza de tema.

## Splash & icon

Configurados en `pubspec.yaml:40-49`. Si se cambia el logo, regenerar con:

```
flutter pub run flutter_launcher_icons
flutter pub run flutter_native_splash:create
```

(Pedir al usuario que ejecute estos comandos — no los corras desde la skill).

---

## Cómo migrar una pantalla al design system

Receta paso a paso (ej. migrar `home_page.dart`):

1. Leer la pantalla completa.
2. Listar todos los `Color(0xFF...)`, `fontSize: N`, `BorderRadius.circular(N)`, `EdgeInsets`, `BoxShadow`, `SizedBox(height/width: N)` con valores numéricos.
3. Por cada uno, decidir:
   - ¿Existe ya en `AppColors`/`AppSpacing`/`AppRadius`/`AppShadows`/`textTheme`? → reemplazar.
   - ¿Es un caso recurrente que aún no está? → agregar al design system primero, luego reemplazar.
   - ¿Es un caso único justificado? → mantener pero comentar por qué.
4. Aplicar todos los reemplazos en una sola edición coherente.
5. Verificar que no rompiste imports — agrega `import '../../../../core/theme/app_spacing.dart'` etc.
6. Recompilar mentalmente.
