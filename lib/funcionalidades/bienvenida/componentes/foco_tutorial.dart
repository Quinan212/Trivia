import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../compartido/movimiento/coordinador_carta.dart';
import '../../../tema/tema_trivia_antiguedad.dart';
import '../../partida/componentes/mazo_preguntas.dart';

class ObjetivoFoco {
  const ObjetivoFoco(this.clave, {this.radio = 23, this.profundidad});
  final GlobalKey clave;
  final double radio;

  /// 0: frente; 1/2: las superficies reales que hay detrás.
  final int? profundidad;
}

/// Un solo plano difuminado. Las aberturas usan las formas y medidas reales;
/// no capturan toques, no mueven el layout y no siguen el dedo con rectángulos.
class FocoTutorial extends StatefulWidget {
  const FocoTutorial({
    super.key,
    required this.child,
    required this.objetivos,
    required this.ancla,
    required this.movimiento,
    this.cartasDetras = 0,
  });
  final Widget child;
  final List<ObjetivoFoco> objetivos;
  final GlobalKey ancla;
  final CoordinadorCarta movimiento;
  final int cartasDetras;
  @override
  State<FocoTutorial> createState() => _FocoTutorialState();
}

class _Hueco {
  const _Hueco(this.forma, this.carta);
  final RRect forma;
  final bool carta;
}

class _FocoTutorialState extends State<FocoTutorial>
    with SingleTickerProviderStateMixin {
  final _superficie = GlobalKey();
  late final _animacion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  List<_Hueco> _desde = [], _hasta = [];
  bool _pendiente = false, _desplazar = true, _primera = true;

  @override
  void didUpdateWidget(FocoTutorial anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.ancla != widget.ancla) _desplazar = true;
  }

  List<_Hueco> _interpolar() {
    final t = Curves.easeInOutCubic.transform(_animacion.value);
    final cantidad = _desde.length > _hasta.length
        ? _desde.length
        : _hasta.length;
    return List.generate(cantidad, (i) {
      final origen = i < _desde.length ? _desde[i] : null;
      final destino = i < _hasta.length ? _hasta[i] : null;
      final centro = (destino ?? origen)!.forma.outerRect.center;
      final vacio = RRect.fromRectAndRadius(
        Rect.fromCenter(center: centro, width: 0, height: 0),
        Radius.zero,
      );
      return _Hueco(
        RRect.lerp(origen?.forma ?? vacio, destino?.forma ?? vacio, t)!,
        destino?.carta ?? origen!.carta,
      );
    });
  }

  void _medir({bool animar = true}) {
    if (_pendiente) return;
    _pendiente = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _pendiente = false;
      if (!mounted) return;
      if (_desplazar) {
        _desplazar = false;
        final ancla = widget.ancla.currentContext;
        if (ancla != null) {
          final caja = ancla.findRenderObject();
          final zona = _superficie.currentContext?.findRenderObject();
          final objetivoAlto =
              caja is RenderBox &&
              zona is RenderBox &&
              caja.size.height > zona.size.height - 24;
          await Scrollable.ensureVisible(
            ancla,
            // Una acción corta tiene aire debajo; una muestra larga empieza
            // por el título, conservando su margen superior y su lectura.
            alignment: objetivoAlto ? 0 : .85,
            alignmentPolicy: objetivoAlto
                ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
                : ScrollPositionAlignmentPolicy.explicit,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 220),
          );
        }
      }
      if (!mounted) return;
      final superficie = _superficie.currentContext?.findRenderObject();
      if (superficie is! RenderBox || !superficie.hasSize) return;
      final nuevos = <_Hueco>[];
      for (final objetivo in widget.objetivos) {
        final caja = objetivo.clave.currentContext?.findRenderObject();
        if (caja is! RenderBox || !caja.hasSize) continue;
        var rect =
            caja.localToGlobal(Offset.zero, ancestor: superficie) & caja.size;
        var radio = objetivo.radio;
        final profundidad = objetivo.profundidad;
        if (profundidad != null) {
          final escala = profundidad == 2
              ? .94
              : profundidad == 1
              ? .97
              : 1.0;
          rect = Rect.fromCenter(
            center: rect.center + Offset(0, profundidad * 8),
            width: rect.width * escala,
            height: rect.height * escala,
          );
          radio *= escala;
          if (profundidad > widget.cartasDetras) {
            rect = Rect.fromCenter(center: rect.center, width: 0, height: 0);
          }
        }
        nuevos.add(
          _Hueco(
            RRect.fromRectAndRadius(rect, Radius.circular(radio)),
            profundidad != null,
          ),
        );
      }
      if (listEquals(
        nuevos.map((h) => h.forma).toList(),
        _hasta.map((h) => h.forma).toList(),
      )) {
        return;
      }
      final primera = _hasta.isEmpty;
      setState(() {
        _desde = primera ? nuevos : _interpolar();
        _hasta = nuevos;
        _primera = primera;
      });
      if (!animar || MediaQuery.disableAnimationsOf(context)) {
        _animacion.value = 1;
      } else {
        _animacion.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _animacion.dispose();
    super.dispose();
  }

  List<Path> _cartasPintadas() {
    final superficie = _superficie.currentContext?.findRenderObject();
    if (superficie is! RenderBox) return [];
    final formas = <Path>[];
    void visitar(Element elemento) {
      if (elemento.widget is SuperficieCarta) {
        final caja = elemento.findRenderObject();
        if (caja is RenderBox && caja.attached && caja.hasSize) {
          formas.add(
            (Path()..addRRect(
                  RRect.fromRectAndRadius(
                    Offset.zero & caja.size,
                    const Radius.circular(28),
                  ),
                ))
                .transform(caja.getTransformTo(superficie).storage),
          );
        }
        return;
      }
      elemento.visitChildElements(visitar);
    }

    for (final objetivo in widget.objetivos) {
      if (objetivo.profundidad == 0) {
        (objetivo.clave.currentContext as Element?)?.visitChildElements(
          visitar,
        );
      }
    }
    return formas;
  }

  @override
  Widget build(BuildContext context) {
    _medir();
    return LayoutBuilder(
      builder: (context, limites) => Stack(
        key: _superficie,
        children: [
          Positioned.fill(
            child: NotificationListener<ScrollNotification>(
              onNotification: (_) {
                _medir(animar: false);
                return false;
              },
              child: widget.child,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_animacion, widget.movimiento]),
                  builder: (context, _) {
                    if (_hasta.isEmpty) return const SizedBox.shrink();
                    final formas = <RRect>[];
                    final enMovimiento =
                        widget.movimiento.fase != FaseCarta.reposo;
                    for (final hueco in _interpolar()) {
                      if (!enMovimiento || !hueco.carta) {
                        formas.add(hueco.forma);
                      }
                    }
                    return Opacity(
                      opacity: _primera ? _animacion.value : 1,
                      child: ClipPath(
                        key: const ValueKey('tutorial-difuminado'),
                        // Se leen al pintar, después de que Flutter aplicó las
                        // transformaciones. No hay un cuadro claro adicional ni
                        // un retraso de un frame detrás del gesto.
                        clipper: RecorteFocoTutorial(
                          formas,
                          superficiesEnMovimiento: enMovimiento
                              ? _cartasPintadas
                              : null,
                        ),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                          child: ColoredBox(
                            color: TemaTriviaAntiguedad.tinta.withValues(
                              alpha: .56,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RecorteFocoTutorial extends CustomClipper<Path> {
  const RecorteFocoTutorial(this.huecos, {this.superficiesEnMovimiento});
  final List<RRect> huecos;
  final List<Path> Function()? superficiesEnMovimiento;
  @override
  Path getClip(Size size) {
    var libres = Path();
    for (final hueco in huecos) {
      if (hueco.outerRect.isEmpty) continue;
      libres = Path.combine(
        PathOperation.union,
        libres,
        Path()..addRRect(hueco),
      );
    }
    for (final forma in superficiesEnMovimiento?.call() ?? <Path>[]) {
      libres = Path.combine(PathOperation.union, libres, forma);
    }
    return Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      libres,
    );
  }

  @override
  bool shouldReclip(RecorteFocoTutorial anterior) =>
      superficiesEnMovimiento != null ||
      anterior.superficiesEnMovimiento != null ||
      !listEquals(huecos, anterior.huecos);
}
