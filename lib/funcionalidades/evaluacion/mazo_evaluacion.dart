import 'package:flutter/material.dart';

import '../../compartido/movimiento/coordinador_carta.dart';

/// Usa la salida y el asentamiento del mazo original, conservando la cara
/// saliente hasta que termina su recorrido. Las dos preguntas no se funden.
class MazoEvaluacion extends StatefulWidget {
  const MazoEvaluacion({
    super.key,
    required this.coordinador,
    required this.preguntaId,
    required this.indice,
    required this.alMostrarSiguiente,
    required this.child,
  });

  final CoordinadorCarta coordinador;
  final String preguntaId;
  final int indice;
  final VoidCallback alMostrarSiguiente;
  final Widget child;

  @override
  State<MazoEvaluacion> createState() => _MazoEvaluacionState();
}

class _MazoEvaluacionState extends State<MazoEvaluacion> {
  GlobalKey _claveActual = GlobalKey();
  Widget? _saliente;
  double _altoSaliente = 0;

  @override
  void initState() {
    super.initState();
    widget.coordinador.addListener(_cambio);
  }

  Widget _actual() => KeyedSubtree(key: _claveActual, child: widget.child);

  void _cambio() {
    final fase = widget.coordinador.fase;
    if (fase == FaseCarta.salida && _saliente == null) {
      _altoSaliente = _claveActual.currentContext?.size?.height ?? 0;
      _saliente = _actual();
    } else if (fase == FaseCarta.asentamiento && _saliente != null) {
      _saliente = null;
      _altoSaliente = 0;
      widget.alMostrarSiguiente();
    } else if (fase == FaseCarta.reposo) {
      final habiaSaliente = _saliente != null;
      _saliente = null;
      _altoSaliente = 0;
      if (habiaSaliente) widget.alMostrarSiguiente();
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(MazoEvaluacion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.preguntaId != oldWidget.preguntaId) {
      _claveActual = GlobalKey();
    }
    if (widget.coordinador != oldWidget.coordinador) {
      oldWidget.coordinador.removeListener(_cambio);
      widget.coordinador.addListener(_cambio);
    }
  }

  @override
  void dispose() {
    widget.coordinador.removeListener(_cambio);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limites) {
      final motor = widget.coordinador;
      motor.ancho = limites.maxWidth;
      motor.reducido = MediaQuery.disableAnimationsOf(context);
      final promocion = motor.fase == FaseCarta.salida
          ? 0.0
          : motor.fase == FaseCarta.asentamiento
          ? motor.progreso
          : 1.0;
      return IgnorePointer(
        ignoring: motor.ocupado,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: _altoSaliente),
              child: Transform.translate(
                key: const ValueKey('carta-entrante'),
                offset: Offset(0, motor.reducido ? 0 : 8 * (1 - promocion)),
                child: Transform.scale(
                  scale: motor.reducido ? 1 : .97 + .03 * promocion,
                  child: _actual(),
                ),
              ),
            ),
            if (_saliente != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ExcludeSemantics(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: motor.reducido ? 1 - motor.progreso : 1,
                      child: Transform.translate(
                        key: const ValueKey('carta-saliente'),
                        offset: Offset(
                          motor.reducido ? 0 : motor.desplazamiento,
                          0,
                        ),
                        child: Transform.rotate(
                          angle: motor.reducido ? 0 : -.035 * motor.progreso,
                          child: _saliente,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
