import 'package:flutter/material.dart';

abstract final class TemaTriviaAntiguedad {
  static const tinta = Color(0xFF2C1D19);
  static const tenue = Color(0xFF594238);
  static const naranja = Color(0xFFB2190E);
  static const sobreNaranja = Color(0xFFFCF8F0);
  static const naranjaTexto = Color(0xFFB2190E);
  static const salvia = Color(0xFFD99C84);
  static const fondo = Color(0xFFFCF8F0);
  static const hoja = Color(0xFFFFFDF8);
  static const borde = Color(0xFF96503E);
  static const salviaClara = Color(0xFFF1D1C1);
  static const salviaMedia = Color(0xFFE6B49D);
  static const salviaOscura = Color(0xFFBD7F65);
  static const deshabilitado = Color(0xFF79665C);
  static const fondoDeshabilitado = Color(0xFFE4D8CC);

  // Recolorear al pintar preserva el original, su textura y su transparencia.
  // Portada: crema, figuras rosa y marcas rojas; conserva textura y alfa.
  static const filtroFondo = ColorFilter.matrix([
    -0.497357787,
    1.446565123,
    -0.793596519,
    0.000000000,
    215.319241529,
    -2.099160709,
    5.728908922,
    -3.363848306,
    0.000000000,
    187.195523780,
    -1.301834006,
    4.292384210,
    -2.519738888,
    0.000000000,
    134.943114703,
    0.000000000,
    0.000000000,
    0.000000000,
    1.000000000,
    0.000000000,
  ]);
  // Portada: tinta marrón, acento rojo y crema; forma, textura y alfa originales.
  static const filtroLogo = ColorFilter.matrix([
    1.711408540,
    -2.563836089,
    1.840662843,
    0.000000000,
    0.000000000,
    -0.245506692,
    0.672803959,
    0.545251753,
    0.000000000,
    0.000000000,
    -0.366475462,
    0.862463915,
    0.445188018,
    0.000000000,
    0.000000000,
    0.000000000,
    0.000000000,
    0.000000000,
    1.000000000,
    0.000000000,
  ]);
  static const coloresCartas = [salviaClara, salviaMedia, salviaOscura, fondo];
  static Color colorCarta(int indice) =>
      coloresCartas[indice % coloresCartas.length];
  static final claro = ThemeData(
    useMaterial3: true,
    fontFamily: 'Outfit',
    scaffoldBackgroundColor: fondo,
    canvasColor: hoja,
    disabledColor: deshabilitado,
    colorScheme: ColorScheme.fromSeed(seedColor: naranja).copyWith(
      primary: naranjaTexto,
      onPrimary: Colors.white,
      primaryContainer: coloresCartas[1],
      onPrimaryContainer: tinta,
      secondary: tenue,
      onSecondary: Colors.white,
      secondaryContainer: salvia,
      onSecondaryContainer: tinta,
      tertiary: tinta,
      onTertiary: Colors.white,
      tertiaryContainer: salviaClara,
      onTertiaryContainer: tinta,
      surface: hoja,
      onSurface: tinta,
      onSurfaceVariant: tenue,
      surfaceContainerLowest: hoja,
      surfaceContainerLow: fondo,
      surfaceContainer: fondo,
      surfaceContainerHigh: salviaClara,
      surfaceContainerHighest: salvia,
      outline: tenue,
      outlineVariant: borde,
      inverseSurface: tinta,
      onInverseSurface: hoja,
      inversePrimary: coloresCartas[1],
      shadow: tinta,
      scrim: tinta,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: tinta, fontSize: 16),
      bodySmall: TextStyle(color: tenue, fontSize: 13),
    ),
    iconTheme: const IconThemeData(color: tinta),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: tinta,
        backgroundColor: hoja,
        disabledForegroundColor: deshabilitado,
        disabledBackgroundColor: fondoDeshabilitado,
        side: const BorderSide(color: borde),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: naranja,
        foregroundColor: sobreNaranja,
        disabledBackgroundColor: fondoDeshabilitado,
        disabledForegroundColor: deshabilitado,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: naranjaTexto,
        backgroundColor: hoja,
        disabledBackgroundColor: fondoDeshabilitado,
        disabledForegroundColor: deshabilitado,
        side: const BorderSide(color: tenue),
      ),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? naranja
            : fondoDeshabilitado,
      ),
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? hoja : tenue,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(borde),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: hoja,
      labelStyle: TextStyle(color: tenue),
      hintStyle: TextStyle(color: tenue),
      prefixIconColor: tenue,
      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: borde)),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: naranja, width: 2),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: hoja,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: hoja,
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: const DividerThemeData(color: borde, thickness: 1),
    chipTheme: const ChipThemeData(
      backgroundColor: salviaClara,
      labelStyle: TextStyle(
        color: tinta,
        fontFamily: 'Outfit',
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(color: borde),
    ),
    dataTableTheme: const DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(salviaClara),
      dataRowColor: WidgetStatePropertyAll(hoja),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: hoja,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: tinta,
    ),
  );
}
