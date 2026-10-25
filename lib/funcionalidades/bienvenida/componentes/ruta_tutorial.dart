import 'package:flutter/material.dart';

import '../../../compartido/componentes/entrada_inicio.dart';
import '../../../compartido/movimiento/movimiento.dart';

/// Retira el menú y revela la práctica sobre el mismo fondo. Al volver, el
/// reloj recorre las etapas en sentido inverso, sin mover la textura verde salvia.
class RutaTutorial extends PageRouteBuilder<void> {
  RutaTutorial(
    BuildContext context,
    Widget pantalla, {
    required bool fondoCompartido,
  }) : super(
         opaque: false,
         barrierColor: Colors.transparent,
         transitionDuration: duracionMovimiento(context, 900),
         reverseTransitionDuration: duracionMovimiento(context, 900),
         pageBuilder: (_, _, _) => pantalla,
         transitionsBuilder: (_, animacion, _, child) {
           final progreso = ((animacion.value - .24) / .76).clamp(0.0, 1.0);
           return Stack(
             fit: StackFit.expand,
             children: [
               if (!fondoCompartido) const FondoApertura(progreso: 1),
               EntradaInicio(
                 key: const ValueKey('entrada-tutorial'),
                 progreso: progreso,
                 enCurso: progreso < 1,
                 child: child,
               ),
             ],
           );
         },
       );

  AnimationStatus? _suspendida;
  late final _observador = _ObservadorRuta(_cambiarEstado);

  @override
  void install() {
    super.install();
    WidgetsBinding.instance.addObserver(_observador);
  }

  void _cambiarEstado(AppLifecycleState estado) {
    if (estado != AppLifecycleState.resumed) {
      if (controller?.isAnimating ?? false) {
        _suspendida = controller!.status;
        controller!.stop();
      }
    } else {
      final pendiente = _suspendida;
      _suspendida = null;
      if (pendiente == AnimationStatus.forward) controller?.forward();
      if (pendiente == AnimationStatus.reverse) controller?.reverse();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_observador);
    super.dispose();
  }
}

class _ObservadorRuta with WidgetsBindingObserver {
  _ObservadorRuta(this.cambiarEstado);
  final ValueChanged<AppLifecycleState> cambiarEstado;
  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) =>
      cambiarEstado(estado);
}
