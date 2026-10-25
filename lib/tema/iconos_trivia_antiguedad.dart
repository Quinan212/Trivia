import 'package:flutter/widgets.dart';

/// Glifos oficiales Phosphor Bold. Se usa IconData estándar para evitar
/// la incompatibilidad del wrapper antiguo con Flutter 3.47.
abstract final class IconosTriviaAntiguedad {
  static const arrowLeft = IconData(0xe058, fontFamily: 'PhosphorBold');
  static const arrowRight = IconData(0xe06c, fontFamily: 'PhosphorBold');
  static const question = IconData(0xe3e8, fontFamily: 'PhosphorBold');
  static const x = IconData(0xe4f6, fontFamily: 'PhosphorBold');
  static const sonido = IconData(0xe450, fontFamily: 'PhosphorBold');
  static const silencio = IconData(0xe456, fontFamily: 'PhosphorBold');
}
