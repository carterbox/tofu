import 'package:flutter/material.dart';

class TofuAppTheme {
  static ThemeData lightTheme(ColorScheme? lightColorScheme){
    return ThemeData.from(
        colorScheme: lightColorScheme ?? tofuLightColorScheme,
        useMaterial3: true,
      );
  }

  static ThemeData darkTheme(ColorScheme? darkColorScheme){
    return ThemeData.from(
        colorScheme: darkColorScheme ?? tofuDarkColorScheme,
        useMaterial3: true,
      );
  }
}

const tofuLightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFF7D5800),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFFFDEA9),
  onPrimaryContainer: Color(0xFF271900),
  secondary: Color(0xFF9A4522),
  onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFFFDBCE),
  onSecondaryContainer: Color(0xFF370D00),
  tertiary: Color(0xFF636100),
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFEAE86E),
  onTertiaryContainer: Color(0xFF1D1D00),
  error: Color(0xFFBA1A1A),
  errorContainer: Color(0xFFFFDAD6),
  onError: Color(0xFFFFFFFF),
  onErrorContainer: Color(0xFF410002),
  background: Color(0xFFFFFBFF),
  onBackground: Color(0xFF3F0300),
  surface: Color(0xFFFFFBFF),
  onSurface: Color(0xFF3F0300),
  surfaceVariant: Color(0xFFEEE1CF),
  onSurfaceVariant: Color(0xFF4E4639),
  outline: Color(0xFF807667),
  onInverseSurface: Color(0xFFFFEDE9),
  inverseSurface: Color(0xFF5F150A),
  inversePrimary: Color(0xFFF9BC49),
  shadow: Color(0xFF000000),
  surfaceTint: Color(0xFF7D5800),
  // outlineVariant: Color(0xFFD1C5B4),
  // scrim: Color(0xFF000000),
);

const tofuDarkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFF9BC49),
  onPrimary: Color(0xFF422C00),
  primaryContainer: Color(0xFF5E4100),
  onPrimaryContainer: Color(0xFFFFDEA9),
  secondary: Color(0xFFFFB59A),
  onSecondary: Color(0xFF5A1B00),
  secondaryContainer: Color(0xFF7B2E0C),
  onSecondaryContainer: Color(0xFFFFDBCE),
  tertiary: Color(0xFFCECB56),
  onTertiary: Color(0xFF333200),
  tertiaryContainer: Color(0xFF4A4900),
  onTertiaryContainer: Color(0xFFEAE86E),
  error: Color(0xFFFFB4AB),
  errorContainer: Color(0xFF93000A),
  onError: Color(0xFF690005),
  onErrorContainer: Color(0xFFFFDAD6),
  background: Color(0xFF3F0300),
  onBackground: Color(0xFFFFDAD4),
  surface: Color(0xFF3F0300),
  onSurface: Color(0xFFFFDAD4),
  surfaceVariant: Color(0xFF4E4639),
  onSurfaceVariant: Color(0xFFD1C5B4),
  outline: Color(0xFF9A8F80),
  onInverseSurface: Color(0xFF3F0300),
  inverseSurface: Color(0xFFFFDAD4),
  inversePrimary: Color(0xFF7D5800),
  shadow: Color(0xFF000000),
  surfaceTint: Color(0xFFF9BC49),
  // outlineVariant: Color(0xFF4E4639),
  // scrim: Color(0xFF000000),
);
