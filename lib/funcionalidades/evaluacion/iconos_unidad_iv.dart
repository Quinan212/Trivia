import 'package:flutter/material.dart';

import '../../tema/paleta_evaluacion.dart';

class IconoUnidadIV extends StatelessWidget {
  const IconoUnidadIV({
    super.key,
    required this.indice,
    this.tamano = 52,
    this.color,
    this.conservarColores = false,
  });
  final int indice;
  final double tamano;
  final Color? color;
  final bool conservarColores;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset(
      'assets/imagenes/iconos-unidad-iv/optimizados/${['estudiantes', 'evaluacion', 'resultados', 'banco'][indice]}.webp',
      width: tamano,
      height: tamano,
      cacheWidth: 256,
      fit: BoxFit.contain,
      color: conservarColores && PaletaEvaluacion.of(context).original
          ? null
          : color ?? PaletaEvaluacion.of(context).naranjaTexto,
      colorBlendMode: BlendMode.srcIn,
      filterQuality: FilterQuality.high,
    ),
  );
}
