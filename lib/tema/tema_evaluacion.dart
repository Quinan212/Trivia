import 'package:flutter/material.dart';

import 'paleta_evaluacion.dart';

const duracionCambioPaleta = Duration(milliseconds: 500);
const curvaCambioPaleta = Curves.easeInOutCubic;

ThemeData temaEvaluacion(PaletaEvaluacion p) {
  return ThemeData(
    useMaterial3: true,
    extensions: [p],
    fontFamily: 'Outfit',
    scaffoldBackgroundColor: p.fondo,
    canvasColor: p.hoja,
    disabledColor: p.deshabilitado,
    colorScheme: ColorScheme.fromSeed(seedColor: p.naranja).copyWith(
      primary: p.naranjaTexto,
      onPrimary: p.sobreNaranja,
      primaryContainer: p.salviaMedia,
      onPrimaryContainer: p.tinta,
      secondary: p.tenue,
      onSecondary: Colors.white,
      secondaryContainer: p.salvia,
      onSecondaryContainer: p.tinta,
      tertiary: p.tinta,
      onTertiary: Colors.white,
      tertiaryContainer: p.salviaClara,
      onTertiaryContainer: p.tinta,
      surface: p.hoja,
      onSurface: p.tinta,
      onSurfaceVariant: p.tenue,
      surfaceContainerLowest: p.hoja,
      surfaceContainerLow: p.fondo,
      surfaceContainer: p.fondo,
      surfaceContainerHigh: p.salviaClara,
      surfaceContainerHighest: p.salvia,
      outline: p.tenue,
      outlineVariant: p.borde,
      inverseSurface: p.tinta,
      onInverseSurface: p.hoja,
      inversePrimary: p.salviaMedia,
      shadow: p.tinta,
      scrim: p.tinta,
    ),
    textTheme: TextTheme(
      bodyMedium: TextStyle(color: p.tinta, fontSize: 16),
      bodySmall: TextStyle(color: p.tenue, fontSize: 13),
    ),
    iconTheme: IconThemeData(color: p.tinta),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: p.tinta,
        backgroundColor: p.hoja,
        disabledForegroundColor: p.deshabilitado,
        disabledBackgroundColor: p.fondoDeshabilitado,
        side: BorderSide(color: p.borde),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.naranja,
        foregroundColor: p.sobreNaranja,
        disabledBackgroundColor: p.fondoDeshabilitado,
        disabledForegroundColor: p.deshabilitado,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.naranjaTexto,
        backgroundColor: p.hoja,
        disabledBackgroundColor: p.fondoDeshabilitado,
        disabledForegroundColor: p.deshabilitado,
        side: BorderSide(color: p.tenue),
      ),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? p.naranja
            : p.fondoDeshabilitado,
      ),
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackOutlineColor: WidgetStatePropertyAll(p.borde),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.hoja,
      labelStyle: TextStyle(color: p.tenue),
      hintStyle: TextStyle(color: p.tenue),
      prefixIconColor: p.tenue,
      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: p.borde)),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: p.naranjaTexto, width: 2),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.hoja,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.hoja,
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: DividerThemeData(color: p.borde, thickness: 1),
    chipTheme: ChipThemeData(
      backgroundColor: p.salviaClara,
      labelStyle: TextStyle(
        color: p.tinta,
        fontFamily: 'Outfit',
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(color: p.borde),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(p.salviaClara),
      dataRowColor: WidgetStatePropertyAll(p.hoja),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.hoja,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.tinta,
    ),
  );
}
