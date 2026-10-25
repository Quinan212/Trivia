import 'dart:math' as math;

import 'package:flutter/material.dart';

typedef _EstadoControl = ({
  double reloj,
  double principal,
  double secundario,
  double respuesta,
  double opacidad,
});

/// Cambia el contenido del panel sin modificar su marco ni mover la pregunta.
class TransicionControlEvaluacion extends StatefulWidget {
  const TransicionControlEvaluacion({
    super.key,
    required this.conTiempo,
    required this.tiempo,
    required this.respuesta,
  });

  final bool conTiempo;
  final Widget Function(double reloj, double principal, double secundario)
  tiempo;
  final Widget respuesta;

  @override
  State<TransicionControlEvaluacion> createState() =>
      _TransicionControlEvaluacionState();
}

class _TransicionControlEvaluacionState
    extends State<TransicionControlEvaluacion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animacion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
    value: widget.conTiempo ? 0 : 1,
  );
  late Widget Function(double, double, double) _tiempoAnterior = widget.tiempo;
  late Widget _respuestaAnterior = widget.respuesta;
  late bool _conTiempo = widget.conTiempo;
  bool _entradaIniciada = false;
  _EstadoControl _origen = (
    reloj: 1,
    principal: 1,
    secundario: 1,
    respuesta: 0,
    opacidad: 0,
  );

  _EstadoControl get _estado {
    double interpolar(double desde, double hasta, Interval tramo) =>
        desde + (hasta - desde) * tramo.transform(_animacion.value);
    return (
      reloj: interpolar(
        _origen.reloj,
        _conTiempo ? 0 : 1,
        _conTiempo
            ? const Interval(.28, 1, curve: Curves.easeOutCubic)
            : const Interval(0, .72, curve: Curves.easeInOutCubic),
      ),
      principal: interpolar(
        _origen.principal,
        _conTiempo ? 0 : 1,
        _conTiempo
            ? const Interval(.38, .92, curve: Curves.easeOutCubic)
            : const Interval(0, .46, curve: Curves.easeInCubic),
      ),
      secundario: interpolar(
        _origen.secundario,
        _conTiempo ? 0 : 1,
        _conTiempo
            ? const Interval(.46, 1, curve: Curves.easeOutCubic)
            : const Interval(.06, .52, curve: Curves.easeInCubic),
      ),
      respuesta: interpolar(
        _origen.respuesta,
        _conTiempo ? 0 : 1,
        _conTiempo
            ? const Interval(0, .58, curve: Curves.easeInCubic)
            : const Interval(.28, 1, curve: Curves.easeInOutCubic),
      ),
      opacidad: interpolar(
        _origen.opacidad,
        _conTiempo ? 0 : 1,
        _conTiempo
            ? const Interval(0, .42, curve: Curves.easeInCubic)
            : const Interval(.32, .78, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animacion.value = 1;
    } else if (!_entradaIniciada && widget.conTiempo) {
      _animacion.forward();
    }
    _entradaIniciada = true;
  }

  @override
  void didUpdateWidget(TransicionControlEvaluacion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conTiempo == widget.conTiempo) return;
    // Conservar el fotograma actual permite deshacer incluso a mitad de salida.
    _origen = _estado;
    _conTiempo = widget.conTiempo;
    if (oldWidget.conTiempo) {
      _tiempoAnterior = oldWidget.tiempo;
    } else {
      _respuestaAnterior = oldWidget.respuesta;
    }
    _animacion.duration = Duration(
      milliseconds: widget.conTiempo ? 1250 : 1100,
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      _animacion.value = 1;
    } else {
      _animacion.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _animacion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limites) => AnimatedBuilder(
      animation: _animacion,
      builder: (context, _) {
        final estado = _estado;
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (estado.reloj < 1 ||
                  estado.principal < 1 ||
                  estado.secundario < 1)
                IgnorePointer(
                  ignoring: !widget.conTiempo || _animacion.isAnimating,
                  child: ExcludeSemantics(
                    excluding: !widget.conTiempo,
                    child: (widget.conTiempo ? widget.tiempo : _tiempoAnterior)(
                      estado.reloj,
                      estado.principal,
                      estado.secundario,
                    ),
                  ),
                ),
              if (estado.opacidad > 0)
                IgnorePointer(
                  ignoring: widget.conTiempo || _animacion.isAnimating,
                  child: ExcludeSemantics(
                    excluding: widget.conTiempo,
                    child: Opacity(
                      opacity: estado.opacidad,
                      child: Transform.translate(
                        offset: Offset(
                          0,
                          (1 - estado.respuesta) *
                              math.min(210, limites.maxHeight * .65),
                        ),
                        child: widget.conTiempo
                            ? _respuestaAnterior
                            : widget.respuesta,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
