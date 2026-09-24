import 'package:flutter/material.dart';

enum AppThemeStyle { solid, liquidGlass }

@immutable
class AppThemeDefinition {
  const AppThemeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.premium,
    required this.background,
    required this.surface,
    required this.surfaceSoft,
    required this.primary,
    required this.primaryDark,
    required this.primarySoft,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    this.style = AppThemeStyle.solid,
  });

  final String id;
  final String name;
  final String description;
  final bool premium;
  final Color background;
  final Color surface;
  final Color surfaceSoft;
  final Color primary;
  final Color primaryDark;
  final Color primarySoft;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final AppThemeStyle style;

  factory AppThemeDefinition.fromJson(Map<String, dynamic> json) {
    Color color(String key) {
      final raw = (json[key] as String? ?? '').replaceFirst('#', '');
      if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(raw)) {
        throw FormatException('Invalid theme color: $key');
      }
      return Color(0xFF000000 | int.parse(raw, radix: 16));
    }

    final styleValue = json['style'] as String? ?? 'solid';
    final style = switch (styleValue) {
      'solid' => AppThemeStyle.solid,
      'liquidGlass' || 'liquid_glass' => AppThemeStyle.liquidGlass,
      _ => throw FormatException('Invalid theme style: $styleValue'),
    };

    return AppThemeDefinition(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      premium: json['premium'] as bool? ?? true,
      background: color('background'),
      surface: color('surface'),
      surfaceSoft: color('surfaceSoft'),
      primary: color('primary'),
      primaryDark: color('primaryDark'),
      primarySoft: color('primarySoft'),
      textPrimary: color('textPrimary'),
      textSecondary: color('textSecondary'),
      divider: color('divider'),
      style: style,
    );
  }
}

@immutable
class AppThemeMaterial extends ThemeExtension<AppThemeMaterial> {
  const AppThemeMaterial({
    required this.style,
    required this.glassTint,
    required this.glassBorder,
    required this.glassHighlight,
    required this.blurSigma,
  });

  final AppThemeStyle style;
  final Color glassTint;
  final Color glassBorder;
  final Color glassHighlight;
  final double blurSigma;

  bool get usesLiquidGlass => style == AppThemeStyle.liquidGlass;

  @override
  AppThemeMaterial copyWith({
    AppThemeStyle? style,
    Color? glassTint,
    Color? glassBorder,
    Color? glassHighlight,
    double? blurSigma,
  }) {
    return AppThemeMaterial(
      style: style ?? this.style,
      glassTint: glassTint ?? this.glassTint,
      glassBorder: glassBorder ?? this.glassBorder,
      glassHighlight: glassHighlight ?? this.glassHighlight,
      blurSigma: blurSigma ?? this.blurSigma,
    );
  }

  @override
  AppThemeMaterial lerp(
    covariant AppThemeMaterial? other,
    double t,
  ) {
    if (other == null) return this;
    return AppThemeMaterial(
      style: t < .5 ? style : other.style,
      glassTint: Color.lerp(glassTint, other.glassTint, t) ?? glassTint,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t) ?? glassBorder,
      glassHighlight:
          Color.lerp(glassHighlight, other.glassHighlight, t) ?? glassHighlight,
      blurSigma: blurSigma + (other.blurSigma - blurSigma) * t,
    );
  }
}

abstract final class BuiltInThemes {
  static const freshGreen = AppThemeDefinition(
    id: 'fresh_green',
    name: '好好绿',
    description: '明亮、干净的默认主题',
    premium: false,
    background: Color(0xFFFBFCF7),
    surface: Color(0xFFFFFFFF),
    surfaceSoft: Color(0xFFF5F7EF),
    primary: Color(0xFF76A33A),
    primaryDark: Color(0xFF527A24),
    primarySoft: Color(0xFFEDF4DF),
    textPrimary: Color(0xFF1E241C),
    textSecondary: Color(0xFF747A70),
    divider: Color(0xFFE8EBE2),
  );

  static const mistBlue = AppThemeDefinition(
    id: 'mist_blue',
    name: '云雾蓝',
    description: '冷白与灰蓝，更安静',
    premium: true,
    background: Color(0xFFF7FAFC),
    surface: Color(0xFFFFFFFF),
    surfaceSoft: Color(0xFFF0F5F8),
    primary: Color(0xFF527C98),
    primaryDark: Color(0xFF365D77),
    primarySoft: Color(0xFFE4EFF5),
    textPrimary: Color(0xFF1D252A),
    textSecondary: Color(0xFF707A80),
    divider: Color(0xFFE4EAEE),
  );

  static const almond = AppThemeDefinition(
    id: 'almond_warm',
    name: '杏仁暖',
    description: '奶白与杏色，柔和温暖',
    premium: true,
    background: Color(0xFFFCFAF5),
    surface: Color(0xFFFFFFFF),
    surfaceSoft: Color(0xFFF8F1E7),
    primary: Color(0xFF9B7549),
    primaryDark: Color(0xFF74532F),
    primarySoft: Color(0xFFF3E6D3),
    textPrimary: Color(0xFF29231D),
    textSecondary: Color(0xFF7D756C),
    divider: Color(0xFFEDE5DA),
  );

  static const liquidGlass = AppThemeDefinition(
    id: 'liquid_glass',
    name: '液态玻璃',
    description: '夕阳奶油与暖金玻璃，沉浸、通透而有层次',
    premium: true,
    style: AppThemeStyle.liquidGlass,
    background: Color(0xFFF6EBDD),
    surface: Color(0xFFFFFAF3),
    surfaceSoft: Color(0xFFF4E7D8),
    primary: Color(0xFFD88A3D),
    primaryDark: Color(0xFF8C5729),
    primarySoft: Color(0xFFF5DDBF),
    textPrimary: Color(0xFF2C2118),
    textSecondary: Color(0xFF7E6D5E),
    divider: Color(0xFFE7D5C2),
  );

  static const all = [freshGreen, mistBlue, almond, liquidGlass];
}
