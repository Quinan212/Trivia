import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';

import '../../tema/paleta_evaluacion.dart';

Future<String?> mostrarSelectorRobo({
  required BuildContext context,
  required LayerLink enlace,
  required Rect Function() posicion,
  required List<PopupMenuEntry<String>> opciones,
}) => Navigator.of(context).push<String>(
  _SelectorRobo(
    enlace,
    posicion,
    opciones,
    MaterialLocalizations.of(context).modalBarrierDismissLabel,
    MediaQuery.disableAnimationsOf(context),
  ),
);

/// El borde inferior sigue al botón, independientemente del alto de la lista.
class _SelectorRobo extends PopupRoute<String> {
  _SelectorRobo(
    this.enlace,
    this.posicion,
    this.opciones,
    this.etiqueta,
    this.reducida,
  );
  final LayerLink enlace;
  final Rect Function() posicion;
  final List<PopupMenuEntry<String>> opciones;
  final String etiqueta;
  final bool reducida;

  @override
  Color? get barrierColor => Colors.transparent;
  @override
  bool get barrierDismissible => true;
  @override
  String get barrierLabel => etiqueta;
  @override
  Duration get transitionDuration => Duration(milliseconds: reducida ? 0 : 200);
  @override
  Duration get reverseTransitionDuration =>
      Duration(milliseconds: reducida ? 0 : 160);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return LayoutBuilder(
      builder: (context, limites) {
        final ancla = posicion();
        final seguro = MediaQuery.paddingOf(context);
        final ancho = math.min(
          364.0,
          limites.maxWidth - seguro.horizontal - 16,
        );
        final vertical =
            MediaQuery.orientationOf(context) == Orientation.portrait;
        final izquierda = (vertical ? ancla.left - ancho - 16 : ancla.left - 36)
            .clamp(
              seguro.left + 8,
              limites.maxWidth - seguro.right - 8 - ancho,
            );
        final alto = math.min(
          312.0,
          math.max(1.0, ancla.top - seguro.top - 24),
        );
        final progreso = animation.drive(
          CurveTween(curve: Curves.easeOutCubic),
        );
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: CompositedTransformFollower(
                link: enlace,
                showWhenUnlinked: false,
                targetAnchor: Alignment.topLeft,
                followerAnchor: Alignment.bottomLeft,
                offset: Offset(izquierda - ancla.left, -16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: ancho,
                    maxWidth: ancho,
                    maxHeight: alto,
                  ),
                  child: FadeTransition(
                    opacity: progreso,
                    child: ScaleTransition(
                      scale: Tween(begin: .9, end: 1.0).animate(progreso),
                      alignment: vertical
                          ? Alignment.bottomRight
                          : Alignment.bottomLeft,
                      child: Semantics(
                        role: SemanticsRole.menu,
                        scopesRoute: true,
                        namesRoute: true,
                        label: MaterialLocalizations.of(context).popupMenuLabel,
                        explicitChildNodes: true,
                        child: Material(
                          key: const ValueKey('menu-estudiantes-robo'),
                          color: PaletaEvaluacion.of(context).hoja,
                          surfaceTintColor: Colors.transparent,
                          elevation: 8,
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                            side: BorderSide(
                              color: PaletaEvaluacion.of(context).borde,
                            ),
                          ),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: ListBody(children: opciones),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
