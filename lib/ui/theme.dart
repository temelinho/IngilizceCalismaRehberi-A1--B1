import 'package:flutter/material.dart';

/// Uygulamanın görsel dili: sıcak krem zemin, koyu yeşil ana renk,
/// seviyelere özel renkler ve ortak küçük bileşenler.
class AppColors {
  static const primary = Color(0xFF0F6E56);
  static const primaryDark = Color(0xFF0A4F3E);
  static const cream = Color(0xFFF7F4EE);
  static const creamCard = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1F2A27);
  static const amber = Color(0xFFE8A33D);
  static const coral = Color(0xFFD9653B);
  static const success = Color(0xFF2E8B57);
  static const danger = Color(0xFFC8423B);

  static const darkBg = Color(0xFF111614);
  static const darkCard = Color(0xFF1A211E);
}

/// Seviye başına renk (A1 yeşil, A2 mavi, B1 mor).
Color levelColor(String level) {
  switch (level) {
    case 'A1':
      return const Color(0xFF3B9A5F);
    case 'A2':
      return const Color(0xFF3577C9);
    case 'B1':
      return const Color(0xFF7A55C7);
    default:
      return AppColors.primary;
  }
}

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  var scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: b,
  );
  scheme = scheme.copyWith(
    primary: dark ? const Color(0xFF6FD3B4) : AppColors.primary,
    onPrimary: dark ? const Color(0xFF00382B) : Colors.white,
    surface: dark ? AppColors.darkBg : AppColors.cream,
    surfaceContainerLowest: dark ? const Color(0xFF0C100F) : Colors.white,
    surfaceContainerLow: dark ? AppColors.darkCard : Colors.white,
    surfaceContainer: dark ? const Color(0xFF1F2724) : const Color(0xFFF1EDE5),
    surfaceContainerHigh: dark ? const Color(0xFF252E2B) : const Color(0xFFEAE5DB),
    surfaceContainerHighest:
        dark ? const Color(0xFF2C3632) : const Color(0xFFE3DDD1),
    tertiary: AppColors.amber,
    tertiaryContainer: dark ? const Color(0xFF4A3613) : const Color(0xFFFCEBCB),
    onTertiaryContainer: dark ? const Color(0xFFFCE3B4) : const Color(0xFF5A3A06),
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: b,
  );
  final tt = base.textTheme;
  final textTheme = tt.copyWith(
    headlineMedium: tt.headlineMedium
        ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
    headlineSmall: tt.headlineSmall
        ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
    titleLarge: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    titleMedium: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    titleSmall: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    labelLarge: tt.labelLarge?.copyWith(fontWeight: FontWeight.w600),
  );

  final radius = BorderRadius.circular(14);
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? AppColors.darkCard : Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primary.withOpacity(dark ? 0.25 : 0.12),
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 50),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: radius),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide(color: scheme.outlineVariant),
      backgroundColor: dark ? AppColors.darkCard : Colors.white,
      selectedColor: scheme.primary.withOpacity(dark ? 0.3 : 0.14),
      labelStyle: textTheme.bodyMedium,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? AppColors.darkCard : Colors.white,
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    dividerColor: scheme.outlineVariant.withOpacity(0.6),
    splashFactory: InkSparkle.splashFactory,
  );
}

/// Kenarlıklı, gölgesiz, yuvarlak köşeli kart.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 12),
    this.onTap,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: margin,
      child: Material(
        color: color ?? scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: borderColor ?? scheme.outlineVariant.withOpacity(0.5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Küçük seviye etiketi (A1 / A2 / B1).
class LevelBadge extends StatelessWidget {
  final String level;
  final bool large;
  const LevelBadge(this.level, {super.key, this.large = false});

  @override
  Widget build(BuildContext context) {
    final c = levelColor(level);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: large ? 10 : 7, vertical: large ? 4 : 2),
      decoration: BoxDecoration(
        color: c.withOpacity(0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        level,
        style: TextStyle(
          color: c,
          fontWeight: FontWeight.w800,
          fontSize: large ? 13 : 11,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Renkli küçük etiket.
class Pill extends StatelessWidget {
  final String text;
  final Color? color;
  final IconData? icon;
  const Pill(this.text, {super.key, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: c),
            const SizedBox(width: 4),
          ],
          Text(text,
              style: TextStyle(
                  color: c, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Bölüm başlığı.
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  const SectionTitle(this.text,
      {super.key,
      this.trailing,
      this.padding = const EdgeInsets.fromLTRB(4, 16, 4, 10)});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: theme.textTheme.titleMedium
                    ?.copyWith(letterSpacing: -0.2)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Yuvarlak ilerleme göstergesi + ortada yüzde.
class ProgressRing extends StatelessWidget {
  final double? value; // null = hiç çalışılmadı
  final double size;
  final Color? color;
  const ProgressRing({super.key, required this.value, this.size = 40, this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final v = value;
    final c = color ?? masteryColor(v, scheme);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: v ?? 0,
              strokeWidth: size / 9,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(c),
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            v == null ? '–' : '${(v * 100).round()}',
            style: TextStyle(
              fontSize: size / 3.6,
              fontWeight: FontWeight.w700,
              color: v == null ? scheme.outline : scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

Color masteryColor(double? v, ColorScheme scheme) {
  if (v == null) return scheme.outlineVariant;
  if (v >= 0.8) return AppColors.success;
  if (v >= 0.5) return AppColors.amber;
  return AppColors.coral;
}

/// Simge + sayı + etiket kutusu.
class StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: AppCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.13),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 10),
            Text(value,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(height: 1.0, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// Boş ekran.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 18),
            Text(title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
