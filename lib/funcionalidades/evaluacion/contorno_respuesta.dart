import 'package:flutter/material.dart';

import '../../tema/paleta_evaluacion.dart';

/// Solo respira el contorno: el texto y las dimensiones de la opción se fijan.
class ContornoRespuesta extends StatefulWidget {
  const ContornoRespuesta({
    super.key,
    required this.color,
    required this.child,
  });
  final Color? color;
  final Widget child;
  @override
  State<ContornoRespuesta> createState() => _ContornoRespuestaState();
}

class _ContornoRespuestaState extends State<ContornoRespuesta>
    with SingleTickerProviderStateMixin {
  late final _reloj = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  void _actualizar() {
    if (widget.color != null && !MediaQuery.disableAnimationsOf(context)) {
      if (!_reloj.isAnimating) _reloj.repeat(reverse: true);
    } else {
      _reloj.stop();
      _reloj.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _actualizar();
  }

  @override
  void didUpdateWidget(ContornoRespuesta oldWidget) {
    super.didUpdateWidget(oldWidget);
    _actualizar();
  }

  @override
  void dispose() {
    _reloj.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    selected: widget.color != null,
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: _reloj,
        child: widget.child,
        builder: (context, child) {
          final t = Curves.easeInOutSine.transform(_reloj.value);
          final color = widget.color;
          return Container(
            decoration: BoxDecoration(
              color: color == null
                  ? PaletaEvaluacion.of(context).salviaClara
                  : Color.alphaBlend(
                      color.withValues(alpha: .07),
                      PaletaEvaluacion.of(context).hoja,
                    ),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(
                color: color ?? PaletaEvaluacion.of(context).borde,
                width: color == null ? 1 : 2 + t,
              ),
            ),
            // Constante aunque se modifique el grosor pintado.
            child: Padding(
              padding: EdgeInsets.all(color == null ? 2 : 1 - t),
              child: child,
            ),
          );
        },
      ),
    ),
  );
}
