import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../compartido/componentes/entrada_inicio.dart';

/// La práctica conserva sus medidas. La explicación ocupa el espacio libre
/// más cercano a las superficies visibles, sin perseguir el gesto de la carta.
class GuiaAncladaTutorial extends StatefulWidget {
  const GuiaAncladaTutorial({
    super.key,
    required this.practica,
    required this.guia,
    required this.alturaGuia,
    required this.objetivos,
    required this.ancla,
    required this.alMover,
    required this.paso,
    required this.fijarPosicion,
  });
  final Widget practica;
  final Widget Function(double puntero, double lectura) guia;
  final int paso;
  final bool fijarPosicion;
  final double alturaGuia;
  final List<GlobalKey> objetivos;
  final GlobalKey ancla;
  final ValueChanged<bool> alMover;

  @override
  State<GuiaAncladaTutorial> createState() => _GuiaAncladaTutorialState();
}

class _GuiaAncladaTutorialState extends State<GuiaAncladaTutorial>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _superficie = GlobalKey();
  final _practica = GlobalKey();
  late final _reloj =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 420),
        animationBehavior: AnimationBehavior.preserve,
      )..addStatusListener((estado) {
        if (estado == AnimationStatus.completed && _moviendo) {
          _moviendo = false;
          widget.alMover(false);
        }
      });
  Rect? _desde, _hasta;
  double? _objetivoX;
  int? _pasoPresentado;
  bool _cambiandoTexto = false;
  bool _pendiente = false, _moviendo = false, _suspendida = false;
  bool _primerPlano = true;

  Rect get _actual => _reloj.value == 1
      ? _hasta!
      : _reloj.value == 0
      ? _desde!
      : Rect.lerp(
          _desde!,
          _hasta!,
          Curves.easeInOutCubic.transform(_reloj.value),
        )!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _medir() {
    if (_pendiente ||
        widget.fijarPosicion ||
        !_primerPlano ||
        EntradaInicio.of(context)?.enCurso == true) {
      return;
    }
    _pendiente = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendiente = false;
      if (!mounted || !_primerPlano) return;
      final zona = _superficie.currentContext?.findRenderObject();
      final practica = _practica.currentContext?.findRenderObject();
      if (zona is! RenderBox || practica is! RenderBox || !zona.hasSize) return;
      final visible =
          practica.localToGlobal(Offset.zero, ancestor: zona) & practica.size;
      Rect? rect(GlobalKey key) {
        final caja = key.currentContext?.findRenderObject();
        if (caja is! RenderBox || !caja.hasSize || !caja.attached) return null;
        return (caja.localToGlobal(Offset.zero, ancestor: zona) & caja.size)
            .intersect(visible);
      }

      final superficies = widget.objetivos
          .map(rect)
          .whereType<Rect>()
          .where((r) => !r.isEmpty);
      final base = superficies.fold<double>(
        0,
        (abajo, r) => math.max(abajo, r.bottom),
      );
      final objetivo = rect(widget.ancla);
      final x = objetivo == null || objetivo.isEmpty
          ? zona.size.width / 2
          : objetivo.center.dx;
      final ancho = math.min(zona.size.width, 344.0);
      final borde = math.max(0.0, zona.size.width - ancho);
      final inferior = math.max(0.0, zona.size.height - widget.alturaGuia);
      final destino = Rect.fromLTWH(
        (x - ancho / 2).clamp(0.0, borde),
        (base + 10).clamp(0.0, inferior),
        ancho,
        widget.alturaGuia,
      );
      final cambioPaso = _pasoPresentado != widget.paso;
      final igual =
          _hasta != null &&
          (_hasta!.left - destino.left).abs() < .1 &&
          (_hasta!.top - destino.top).abs() < .1 &&
          (_hasta!.width - destino.width).abs() < .1 &&
          (_hasta!.height - destino.height).abs() < .1;
      if (igual && (_objetivoX! - x).abs() < .1 && !cambioPaso) return;
      final primera = _hasta == null;
      final origen = primera ? destino : _actual;
      setState(() {
        _desde = origen;
        _hasta = destino;
        _objetivoX = x;
        _pasoPresentado = widget.paso;
        _cambiandoTexto = !primera && cambioPaso;
      });
      if (primera ||
          MediaQuery.disableAnimationsOf(context) ||
          (origen == destino && !cambioPaso)) {
        _reloj.value = 1;
      } else {
        if (!_moviendo) {
          _moviendo = true;
          widget.alMover(true);
        }
        _reloj.forward(from: 0);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    _primerPlano = estado == AppLifecycleState.resumed;
    if (estado != AppLifecycleState.resumed && _reloj.isAnimating) {
      _suspendida = true;
      _reloj.stop();
    } else if (estado == AppLifecycleState.resumed && _suspendida) {
      _suspendida = false;
      _reloj.forward();
    }
    if (_primerPlano) _medir();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reloj.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limites) {
      _medir();
      final altoPractica = math.max(0.0, limites.maxHeight - widget.alturaGuia);
      return AnimatedBuilder(
        animation: _reloj,
        builder: (context, _) {
          final guia = _hasta == null
              ? Rect.fromLTWH(
                  (limites.maxWidth - math.min(limites.maxWidth, 344)) / 2,
                  altoPractica,
                  math.min(limites.maxWidth, 344),
                  widget.alturaGuia,
                )
              : _actual;
          final puntero =
              ((_objetivoX ?? limites.maxWidth / 2) - guia.left - 20) /
              math.max(1.0, guia.width - 40);
          return Stack(
            key: _superficie,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: altoPractica,
                child: SizedBox(
                  key: _practica,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (_) {
                      _medir();
                      return false;
                    },
                    child: widget.practica,
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: guia,
                child: IgnorePointer(
                  ignoring: _moviendo,
                  child: widget.guia(
                    puntero.clamp(0.0, 1.0),
                    _cambiandoTexto ? (_reloj.value * 2).clamp(0.0, 1.0) : 1.0,
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
