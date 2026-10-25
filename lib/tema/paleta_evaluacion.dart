import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show mapEquals;

import '../funcionalidades/evaluacion/configuracion.dart';
import 'tema_trivia_antiguedad.dart';

@immutable
class PaletaEvaluacion extends ThemeExtension<PaletaEvaluacion> {
  const PaletaEvaluacion(this.tipo) : _colores = null;
  const PaletaEvaluacion._interpolada(this.tipo, this._colores);
  final Map<String, Color>? _colores;
  Color _resolver(String clave, Color base) => _colores?[clave] ?? base;
  final ColorEvaluacion tipo;
  static PaletaEvaluacion of(BuildContext context) =>
      Theme.of(context).extension<PaletaEvaluacion>() ??
      const PaletaEvaluacion(ColorEvaluacion.rojo);
  bool get original => tipo == ColorEvaluacion.rojo && _colores == null;
  bool get esAmarillo => tipo == ColorEvaluacion.amarillo;
  Color elegir(int rojo, int verde, int azul, int amarillo, int naranja) =>
      Color(switch (tipo) {
        ColorEvaluacion.rojo => rojo,
        ColorEvaluacion.verde => verde,
        ColorEvaluacion.azul => azul,
        ColorEvaluacion.amarillo => amarillo,
        ColorEvaluacion.naranja => naranja,
      });
  // Principales exactos de las muestras de Alan; acentos legibles para texto.
  // Tonos secundarios con la misma luminosidad perceptual que la base roja.
  // Derivación reproducible: scripts/calcular_paletas.py.
  Color get naranja => _resolver(
    'naranja',
    elegir(0xFFB2190E, 0xFF118E0B, 0xFF0973BA, 0xFFFFCC00, 0xFFC44E0F),
  );
  Color get naranjaTexto => _resolver(
    'naranjaTexto',
    elegir(0xFFB2190E, 0xFF10850A, 0xFF0973BA, 0xFF896300, 0xFFC34D0E),
  );
  Color get sobreNaranja => _resolver('sobreNaranja', switch (tipo) {
    ColorEvaluacion.amarillo => Colors.black,
    ColorEvaluacion.rojo => const Color(0xFFFCF8F0),
    _ => Colors.white,
  });
  Color get tinta => _resolver('tinta', TemaTriviaAntiguedad.tinta);
  Color get tenue => _resolver('tenue', TemaTriviaAntiguedad.tenue);
  Color get fondo => _resolver('fondo', TemaTriviaAntiguedad.fondo);
  Color get hoja => _resolver('hoja', TemaTriviaAntiguedad.hoja);
  Color get borde => _resolver(
    'borde',
    elegir(0xFF96503E, 0xFF436E38, 0xFF29669F, 0xFF9C7400, 0xFF965201),
  );
  Color get salvia => _resolver(
    'salvia',
    elegir(0xFFD99C84, 0xFF90B485, 0xFF88ACDF, 0xFFF4D16A, 0xFFE39A58),
  );
  Color get salviaClara => _resolver(
    'salviaClara',
    elegir(0xFFF1D1C1, 0xFFCADDC4, 0xFFC8D8F3, 0xFFFFF1B8, 0xFFFBCFAD),
  );
  Color get salviaMedia => _resolver(
    'salviaMedia',
    elegir(0xFFE6B49D, 0xFFAAC7A0, 0xFFA5C1EB, 0xFFFFE08A, 0xFFF2B17B),
  );
  Color get salviaOscura => _resolver(
    'salviaOscura',
    elegir(0xFFBD7F65, 0xFF729866, 0xFF6690C5, 0xFFD9AC38, 0xFFC77D36),
  );
  Color get deshabilitado =>
      _resolver('deshabilitado', TemaTriviaAntiguedad.deshabilitado);
  Color get fondoDeshabilitado =>
      _resolver('fondoDeshabilitado', TemaTriviaAntiguedad.fondoDeshabilitado);
  Color get error => const Color(0xFFB2190E);
  Color get correcto => const Color(0xFF246447);
  ColorFilter get filtroFondo => TemaTriviaAntiguedad.filtroFondo;
  ColorFilter get filtroLogo => original
      ? TemaTriviaAntiguedad.filtroLogo
      : ColorFilter.mode(naranja, BlendMode.srcIn);
  Map<String, Color> get _valores => {
    'naranja': naranja,
    'naranjaTexto': naranjaTexto,
    'sobreNaranja': sobreNaranja,
    'tinta': tinta,
    'tenue': tenue,
    'fondo': fondo,
    'hoja': hoja,
    'borde': borde,
    'salvia': salvia,
    'salviaClara': salviaClara,
    'salviaMedia': salviaMedia,
    'salviaOscura': salviaOscura,
    'deshabilitado': deshabilitado,
    'fondoDeshabilitado': fondoDeshabilitado,
  };
  @override
  PaletaEvaluacion copyWith({ColorEvaluacion? tipo}) =>
      tipo == null ? this : PaletaEvaluacion(tipo);
  @override
  PaletaEvaluacion lerp(covariant PaletaEvaluacion? other, double t) {
    if (other == null || t <= 0) return this;
    if (t >= 1) return other;
    final inicio = _valores, fin = other._valores;
    return PaletaEvaluacion._interpolada(other.tipo, {
      for (final clave in inicio.keys)
        clave: Color.lerp(inicio[clave], fin[clave], t)!,
    });
  }

  @override
  bool operator ==(Object other) =>
      other is PaletaEvaluacion &&
      tipo == other.tipo &&
      mapEquals(_colores, other._colores);
  @override
  int get hashCode => Object.hash(
    tipo,
    _colores == null
        ? null
        : Object.hashAllUnordered(
            _colores.entries.map((e) => Object.hash(e.key, e.value)),
          ),
  );
}
