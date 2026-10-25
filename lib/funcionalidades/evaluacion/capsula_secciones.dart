import 'package:flutter/material.dart';

import '../../tema/paleta_evaluacion.dart';
import 'iconos_unidad_iv.dart';

/// El mismo dibujo y selección continua en ambos recorridos de acople.
class CapsulaSecciones extends StatelessWidget {
  const CapsulaSecciones({
    super.key,
    required this.tamano,
    required this.pasoX,
    required this.pasoY,
    required this.seleccion,
    required this.individuales,
    required this.unificado,
    required this.onSeleccion,
    this.unificadoArriba = false,
  });
  final Size tamano;
  final double pasoX, pasoY, seleccion, individuales, unificado;
  final ValueChanged<int> onSeleccion;
  final bool unificadoArriba;
  @override
  Widget build(BuildContext context) {
    final escalaIconos = .45 + .55 * individuales;
    return Container(
      key: const ValueKey('panel-secciones'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: PaletaEvaluacion.of(context).hoja,
        borderRadius: BorderRadius.circular(38),
        border: Border.all(
          color: PaletaEvaluacion.of(context).borde,
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            key: const ValueKey('seleccion-secciones'),
            left: 10.5 + seleccion * pasoX,
            top: 10.5 + seleccion * pasoY,
            width: 52,
            height: 52,
            child: Opacity(
              opacity: individuales,
              child: Transform.scale(
                scale: escalaIconos,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: PaletaEvaluacion.of(context).salviaClara,
                  ),
                ),
              ),
            ),
          ),
          for (var i = 0; i < 4; i++)
            Positioned(
              left: 10.5 + i * pasoX,
              top: 10.5 + i * pasoY,
              width: 52,
              height: 52,
              child: Opacity(
                opacity: individuales,
                child: Transform.scale(
                  scale: escalaIconos,
                  child: ExcludeSemantics(
                    excluding: individuales < .95,
                    child: IconButton(
                      key: ValueKey('seccion-$i'),
                      tooltip: [
                        'Estudiantes',
                        'Evaluación',
                        'Resultados',
                        'Banco',
                      ][i],
                      onPressed: () => onSeleccion(i),
                      style: IconButton.styleFrom(
                        padding: const EdgeInsets.all(6),
                        backgroundColor: Colors.transparent,
                        foregroundColor: PaletaEvaluacion.of(context)
                            .naranjaTexto,
                        side: BorderSide(
                          color: PaletaEvaluacion.of(context).naranjaTexto,
                          width: 1.5,
                        ),
                        shape: const CircleBorder(),
                      ),
                      icon: IconoUnidadIV(
                        indice: i,
                        tamano: 40,
                        conservarColores: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (unificado > 0)
            Positioned(
              left: 14.5,
              top: unificadoArriba ? 14.5 : (tamano.height - 44) / 2 - 1.5,
              width: 44,
              height: 44,
              child: IgnorePointer(
                child: Opacity(
                  opacity: unificado,
                  child: Transform.scale(
                    scale: .4 + .6 * unificado,
                    child: Container(
                      key: const ValueKey('navegacion-unificada'),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: PaletaEvaluacion.of(context).hoja,
                        border: Border.all(
                          color: PaletaEvaluacion.of(context).borde,
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: SizedBox.square(
                        dimension: 24,
                        child: CustomPaint(
                          painter: _CuadriculaNavegacion(
                            PaletaEvaluacion.of(context).naranjaTexto,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Mismo símbolo de cuatro cuadrados que el SVG de Hyperframes (28 × 28).
class _CuadriculaNavegacion extends CustomPainter {
  const _CuadriculaNavegacion(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 28, size.height / 28);
    final trazo = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.3
      ..strokeJoin = StrokeJoin.round;
    for (final x in [4.0, 17.0]) {
      for (final y in [4.0, 17.0]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, 7, 7),
            const Radius.circular(2),
          ),
          trazo,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CuadriculaNavegacion oldDelegate) =>
      color != oldDelegate.color;
}
