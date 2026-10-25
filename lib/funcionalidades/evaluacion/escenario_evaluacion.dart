import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../tema/paleta_evaluacion.dart';
import 'capsula_secciones.dart';

const _aireSecciones = 72.0;

double _tramo(double t, double a, double b) =>
    Curves.easeInOutCubic.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

// Un tercio menos y otro 20 % sobre esa duración: conservar los desfases internos.
Duration _duracionBarras(int ms) =>
    Duration(milliseconds: (ms * 2 / 3 * .8).round());

// Reducir primero los espacios, manteniendo círculos de 52 y cápsulas de 76.
({double herramientas, Rect navegacion}) _laterales(
  double x,
  double h, {
  double altoHerramientas = 228,
}) {
  final faltante = math.max(0.0, altoHerramientas + 304 + 72 - h);
  final herramientas =
      altoHerramientas - math.min(altoHerramientas - 180, faltante);
  final altoNav = 304.0 - math.min(72.0, math.max(0.0, faltante - 48.0));
  final top = math.max(24 + herramientas + 24, (h - altoNav) / 2);
  return (
    herramientas: herramientas,
    navegacion: Rect.fromLTWH(x, top, 76, altoNav),
  );
}

/// Una sola geometría para tarjeta, círculo y cápsula. La navegación conserva
/// su trazo circular mientras se recoge, viaja y se despliega en horizontal.
class EscenarioEvaluacion extends StatefulWidget {
  const EscenarioEvaluacion({
    super.key,
    required this.vista,
    required this.enPregunta,
    required this.esperandoSorteo,
    required this.cabecera,
    required this.datosTurno,
    required this.pagina,
    required this.pregunta,
    required this.barra,
    required this.contenidoSorteo,
    required this.anchoBarra,
    required this.altoBarraVertical,
    required this.onSortear,
    required this.onVista,
    required this.onSalir,
    this.onRebote,
    this.herramientas,
  });
  final int vista;
  final VoidCallback? onRebote;
  final bool enPregunta, esperandoSorteo;
  final Widget cabecera, datosTurno, pagina, pregunta, contenidoSorteo;
  final Widget? herramientas;
  final Widget Function(double datos, double controles) barra;
  final double anchoBarra, altoBarraVertical;
  final VoidCallback onSortear, onSalir;
  final ValueChanged<int> onVista;

  @override
  State<EscenarioEvaluacion> createState() => EscenarioEvaluacionState();
}

class EscenarioEvaluacionState extends State<EscenarioEvaluacion>
    with TickerProviderStateMixin {
  late final _acople = AnimationController(
    vsync: this,
    duration: _duracionBarras(2300),
    value: widget.enPregunta && widget.vista == 1 ? 1 : 0,
  );
  late final _entrada = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
    value: 1,
  );
  late final _origen = AnimationController(
    vsync: this,
    duration: _duracionBarras(3600),
    value: 1,
  );
  late final _rebote = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final _seleccion = AnimationController.unbounded(
    vsync: this,
    value: widget.vista.toDouble(),
  );
  late int _destinoSeleccion = widget.vista;
  void _seleccionar(int destino) {
    _destinoSeleccion = destino;
    _seleccion.animateTo(
      destino.toDouble(),
      duration: _reducido ? Duration.zero : _duracionBarras(650),
      curve: Curves.easeInOutCubic,
    );
  }

  bool _morfosis = false, _ocupado = false;
  bool get _paginaAmpliada => widget.herramientas != null && widget.vista != 1;
  bool get _reducido => MediaQuery.disableAnimationsOf(context);

  @override
  void didUpdateWidget(EscenarioEvaluacion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vista != widget.vista && widget.vista != _destinoSeleccion) {
      _seleccionar(widget.vista);
    }
    if (oldWidget.enPregunta && !widget.enPregunta && !_morfosis) {
      _acople.animateTo(0, duration: _reducido ? Duration.zero : null);
    } else if (!oldWidget.enPregunta && widget.enPregunta && !_morfosis) {
      _acople.animateTo(1, duration: _reducido ? Duration.zero : null);
    }
  }

  Future<void> cambiarVista(int destino) async {
    if (_ocupado) return;
    if (destino == widget.vista) {
      widget.onRebote?.call();
      if (!_reducido) _rebote.forward(from: 0);
      return;
    }
    _ocupado = true;
    _seleccionar(destino);
    widget.onSalir();
    final saleEvaluacion = widget.vista == 1 && widget.enPregunta;
    final entraEvaluacion = destino == 1 && widget.enPregunta;
    final transicionEvaluacion = saleEvaluacion || entraEvaluacion;
    final Future<void> salidaNav = saleEvaluacion
        ? _acople.animateTo(
            0,
            duration: _reducido ? Duration.zero : _duracionBarras(2300),
          )
        : Future<void>.value();
    await Future.wait([
      _entrada.animateTo(
        0,
        duration: _reducido
            ? Duration.zero
            : transicionEvaluacion
            ? _duracionBarras(420)
            : const Duration(milliseconds: 420),
      ),
      if (saleEvaluacion)
        Future<void>.delayed(_reducido ? Duration.zero : _duracionBarras(1800)),
    ]);
    if (!mounted) return;
    widget.onVista(destino);
    // Se monta la página nueva después de retirar por completo la anterior.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await Future.wait([
      salidaNav,
      if (entraEvaluacion)
        _acople.animateTo(
          1,
          duration: _reducido ? Duration.zero : _duracionBarras(1450),
        ),
      _entrada.animateTo(
        1,
        duration: _reducido
            ? Duration.zero
            : transicionEvaluacion
            ? _duracionBarras(850)
            : const Duration(milliseconds: 850),
      ),
    ]);
    if (mounted) setState(() => _ocupado = false);
  }

  void _sortear() {
    if (_ocupado) return;
    if (_reducido) {
      widget.onSortear();
      _acople.value = 1;
      return;
    }
    setState(() {
      _morfosis = true;
      _ocupado = true;
    });
    widget.onSortear();
    if (!widget.enPregunta) {
      // La selección del motor se refleja en el siguiente fotograma.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !widget.enPregunta) {
          setState(() {
            _morfosis = false;
            _ocupado = false;
          });
        }
      });
    }
    _origen.duration = _duracionBarras(
      MediaQuery.orientationOf(context) == Orientation.portrait ? 4300 : 3600,
    );
    _origen.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      _acople.value = 1;
      setState(() {
        _morfosis = false;
        _ocupado = false;
      });
    });
  }

  @override
  void dispose() {
    _acople.dispose();
    _entrada.dispose();
    _origen.dispose();
    _rebote.dispose();
    _seleccion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.portrait
      ? _vertical(context)
      : _horizontal(context);

  Widget _cabeceraAnimada() => Opacity(
    key: const ValueKey('transicion-titulo-evaluacion'),
    opacity: _entrada.value,
    child: Transform.translate(
      offset: Offset(0, 14 * (1 - _entrada.value)),
      child: widget.cabecera,
    ),
  );

  Widget _horizontal(BuildContext context) => LayoutBuilder(
    builder: (context, limites) => TweenAnimationBuilder<double>(
      tween: Tween(begin: widget.anchoBarra, end: widget.anchoBarra),
      duration: _reducido ? Duration.zero : _duracionBarras(900),
      curve: Curves.easeInOutCubic,
      builder: (context, anchoPedido, _) => AnimatedBuilder(
        animation: Listenable.merge([
          _acople,
          _entrada,
          _origen,
          _rebote,
          _seleccion,
        ]),
        builder: (context, _) {
          final w = limites.maxWidth, h = limites.maxHeight;
          const alto = 76.0, anchoNav = 244.0, separacion = 12.0;
          final margen = w < 900 ? 16.0 : 24.0;
          final ancho = math.min(
            anchoPedido,
            w - 2 * margen - 80 - anchoNav - separacion,
          );
          final izquierda = margen + 80;
          // Composición aprobada de 1280 × 800: pregunta 1032 × 468,
          // barra en y=654 y 68 dp de separación entre ambas piezas.
          // Android resta altura con sus barras del sistema. Consumir primero
          // ese aire inferior, manteniendo las medidas de tarjetas y controles.
          final aireInferior = (h - 730).clamp(24.0, 70.0);
          final inferior = h - aireInferior - alto;
          final superior = math.max(
            118.0,
            MediaQuery.textScalerOf(context).scale(26) * 2 + 44,
          );
          final anchoPregunta = math.min(1032.0, w - izquierda - margen - 80);
          final altoPregunta = math.max(180.0, inferior - 18 - superior);
          final laterales = _laterales(w - margen - alto, h);
          final lateral = laterales.navegacion;
          final navFinal = Rect.fromLTWH(
            izquierda + ancho + separacion,
            inferior,
            anchoNav,
            alto,
          );
          final barraFinal = Rect.fromLTWH(izquierda, inferior, ancho, alto);
          final tarjeta = Rect.fromCenter(
            center: Offset(w / 2, h / 2 - 25),
            width: math.min(460, w - 160),
            height: math.min(330, h - 160),
          );
          final t = _morfosis ? _origen.value : _acople.value;
          final recoger = _tramo(t, 0, .23);
          final viaje = _tramo(t, .23, .55);
          final abrir = _tramo(t, .55, 1);
          final navCirculo = Rect.fromCenter(
            center: lateral.center,
            width: alto,
            height: alto,
          );
          final navDestino = Rect.fromLTWH(navFinal.left, inferior, alto, alto);
          final navRecogida = Rect.lerp(lateral, navCirculo, recoger)!;
          final navViajando = Rect.lerp(navCirculo, navDestino, viaje)!;
          var nav = t < .23
              ? navRecogida
              : t < .55
              ? navViajando
              : Rect.lerp(navDestino, navFinal, abrir)!;
          final circuloInicial = Rect.fromCenter(
            center: tarjeta.center,
            width: alto,
            height: alto,
          );
          final circuloFinal = Rect.fromLTWH(
            barraFinal.right - alto,
            inferior,
            alto,
            alto,
          );
          final Rect control;
          final double datos, botones, radio;
          if (_morfosis) {
            final extension = _tramo(t, .55, .85);
            control = t < .23
                ? Rect.lerp(tarjeta, circuloInicial, recoger)!
                : t < .55
                ? Rect.lerp(circuloInicial, circuloFinal, viaje)!
                : Rect.lerp(circuloFinal, barraFinal, extension)!;
            radio = lerpDouble(28, 38, recoger)!;
            datos = _tramo(t, .64, .85);
            botones = _tramo(t, .85, 1);
          } else {
            control = Rect.lerp(circuloFinal, barraFinal, abrir)!;
            radio = 38;
            datos = _tramo(t, .60, .88);
            botones = _tramo(t, .80, 1);
          }

          var individuales = t < .23 ? 1 - recoger : abrir;
          var unificado = _tramo(t, 0, .18) * (1 - _tramo(t, .55, .75));
          if (!_morfosis) {
            // Tiempos del viaje de Hyperframes: recoger .65 s, viajar 1.05 s,
            // desplegar desde 1.5 hasta 2.3 s, con los últimos .2 ya despejados.
            final acoplando = _acople.status != AnimationStatus.reverse;
            final p = acoplando ? t : 1 - t;
            final plegar = _tramo(p, 0, .65 / 2.3);
            final mover = _tramo(p, .65 / 2.3, 1.7 / 2.3);
            final desplegar = _tramo(p, 1.5 / 2.3, 1);
            final desde = acoplando ? lateral : navFinal;
            final circuloDesde = acoplando ? navCirculo : navDestino;
            final circuloHasta = acoplando ? navDestino : navCirculo;
            final hasta = acoplando ? navFinal : lateral;
            if (p < .65 / 2.3) {
              nav = Rect.lerp(desde, circuloDesde, plegar)!;

              individuales = 1 - plegar;
            } else {
              final viajando = Rect.lerp(circuloDesde, circuloHasta, mover)!;
              final anchoNavActual = lerpDouble(76, hasta.width, desplegar)!;
              final altoNavActual = lerpDouble(76, hasta.height, desplegar)!;
              nav = Rect.fromLTWH(
                viajando.left,
                viajando.center.dy - altoNavActual / 2,
                anchoNavActual,
                altoNavActual,
              );

              individuales = desplegar;
            }
            unificado =
                _tramo(p, .3 / 2.3, .65 / 2.3) *
                (1 - _tramo(p, 1.5 / 2.3, 1.9 / 2.3));
          }
          final pregunta = _morfosis ? _tramo(t, .67, .98) : _entrada.value;
          final visibleControl =
              widget.enPregunta && widget.vista == 1 || _morfosis;
          final contenido = widget.vista == 1 && widget.enPregunta;
          final rebote =
              math.sin(_rebote.value * math.pi * 2) * (1 - _rebote.value) * 7;
          return IgnorePointer(
            ignoring: _ocupado,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                if (!_paginaAmpliada)
                  Positioned(
                    left: margen + 80,
                    right: margen + 100,
                    top: 26,
                    child: _cabeceraAnimada(),
                  ),
                if (widget.herramientas != null)
                  Positioned(
                    right: margen,
                    top: 24,
                    width: 76,
                    height: laterales.herramientas,
                    child: widget.herramientas!,
                  ),
                if (!contenido && !_morfosis && !widget.esperandoSorteo)
                  Positioned(
                    key: const ValueKey('area-seccion'),
                    left: margen + 80,
                    right:
                        margen + alto + (_paginaAmpliada ? _aireSecciones : 24),
                    top: _paginaAmpliada ? 0 : superior,
                    bottom: _paginaAmpliada ? 0 : 16,
                    child: Opacity(
                      opacity: _entrada.value,
                      child: Transform.translate(
                        offset: Offset(0, 14 * (1 - _entrada.value)),
                        child: widget.pagina,
                      ),
                    ),
                  ),
                if (widget.vista == 1 && (widget.esperandoSorteo || _morfosis))
                  if (!_morfosis)
                    Positioned.fromRect(
                      rect: tarjeta,
                      child: _superficie(
                        radio: 28,
                        child: _TarjetaSorteo(
                          accion: _sortear,
                          child: widget.contenidoSorteo,
                        ),
                      ),
                    ),
                if (contenido)
                  Positioned(
                    left: izquierda,
                    width: anchoPregunta,
                    top: superior,
                    height: altoPregunta,
                    child: Opacity(
                      opacity: pregunta,
                      child: Transform.scale(
                        scale: math.max(.001, pregunta),
                        alignment: Alignment.topLeft,
                        child: widget.pregunta,
                      ),
                    ),
                  ),
                if (visibleControl)
                  Positioned.fromRect(
                    rect: control,
                    child: Opacity(
                      opacity: _morfosis ? 1 : _entrada.value,
                      child: _superficie(
                        radio: radio,
                        color: _morfosis
                            ? Color.lerp(
                                PaletaEvaluacion.of(context).hoja,
                                PaletaEvaluacion.of(context).salviaClara,
                                _tramo(t, .08, .4),
                              )
                            : PaletaEvaluacion.of(context).salviaClara,
                        child: Stack(
                          children: [
                            if (_morfosis && t < .23)
                              Positioned.fill(
                                child: OverflowBox(
                                  minWidth: tarjeta.width,
                                  maxWidth: tarjeta.width,
                                  minHeight: tarjeta.height,
                                  maxHeight: tarjeta.height,
                                  child: Opacity(
                                    opacity: 1 - _tramo(t, 0, .16),
                                    child: Transform.scale(
                                      scale: 1 - recoger * .5,
                                      child: SizedBox.fromSize(
                                        size: tarjeta.size,
                                        child: _TarjetaSorteo(
                                          accion: null,
                                          child: widget.contenidoSorteo,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (datos > 0)
                              Positioned(
                                right: 0,
                                top: 0,
                                width: ancho - 2.6,
                                height: alto - 2.6,
                                child: widget.barra(datos, botones),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Positioned.fromRect(
                  rect: nav.shift(Offset(rebote, 0)),
                  child: CapsulaSecciones(
                    tamano: nav.size,
                    pasoX: math.max(0, (nav.width - 76) / 3),
                    pasoY: math.max(0, (nav.height - 76) / 3),
                    seleccion: _seleccion.value,
                    individuales: individuales,
                    unificado: unificado,
                    onSeleccion: cambiarVista,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );

  Widget _vertical(BuildContext context) => LayoutBuilder(
    builder: (context, limites) => AnimatedBuilder(
      animation: Listenable.merge([
        _acople,
        _entrada,
        _origen,
        _rebote,
        _seleccion,
      ]),
      builder: (context, _) {
        final w = limites.maxWidth, h = limites.maxHeight;
        const ancho = 76.0, separacion = 24.0;
        final margen = w < 760 ? 16.0 : 24.0;
        final izquierda = w >= 760 ? 48.0 : margen;
        final x = w - margen - ancho;
        final anchoContenido = x - separacion - izquierda;
        final superior = math.max(
          128.0,
          MediaQuery.textScalerOf(context).scale(26) * 2 + 52,
        );
        final altoDatos = math.max(
          84.0,
          MediaQuery.textScalerOf(context).scale(24) * 2.4 +
              MediaQuery.textScalerOf(context).scale(16) +
              12,
        );
        final yPregunta = superior + altoDatos + 24;
        // Reservar sitio a herramientas antes de repartir las otras cápsulas.
        // En tabletas cortas se consumen huecos y luego altura del control;
        // los botones conservan su diámetro y la navegación sus cuatro accesos.
        final aireInferior = h >= 1150 ? (h - 1152).clamp(24.0, 92.0) : 24.0;
        final faltante = math.max(0.0, 1152 + aireInferior - h);
        final altoHerramientas = 228.0 - math.min(48.0, faltante);
        final alto = 548.0 - math.min(148.0, math.max(0.0, faltante - 48));
        final altoNav = 304.0 - math.min(72.0, math.max(0.0, faltante - 196));
        final navFinal = Rect.fromLTWH(
          x,
          h - aireInferior - altoNav,
          ancho,
          altoNav,
        );
        final barraFinal = Rect.fromLTWH(
          x,
          navFinal.top - separacion - alto,
          ancho,
          alto,
        );
        final laterales = _laterales(x, h, altoHerramientas: altoHerramientas);
        final lateral = laterales.navegacion;
        // Ambas piezas se pliegan sobre el extremo que queda junto a la otra.
        final navCirculo = Rect.fromLTWH(x, lateral.top, ancho, ancho);
        final navDestino = Rect.fromLTWH(x, navFinal.top, ancho, ancho);
        final circuloFinal = Rect.fromLTWH(
          x,
          barraFinal.bottom - ancho,
          ancho,
          ancho,
        );
        final tarjeta = Rect.fromCenter(
          center: Offset((izquierda + x - separacion) / 2, h / 2 - 45),
          width: math.min(460, anchoContenido),
          height: math.min(330, h - superior - 32),
        );
        final circuloInicial = Rect.fromCenter(
          center: tarjeta.center,
          width: ancho,
          height: ancho,
        );
        final t = _morfosis ? _origen.value : _acople.value;
        final recoger = _tramo(t, 0, .25);
        final viaje = _tramo(t, .25, .55);
        // Pequeño asentamiento de los dos círculos ANTES del despliegue.
        final abrir = _tramo(t, .62, .92);
        var nav = t < .25
            ? Rect.lerp(lateral, navCirculo, recoger)!
            : t < .55
            ? Rect.lerp(navCirculo, navDestino, viaje)!
            : Rect.lerp(navDestino, navFinal, abrir)!;
        var individuales = t < .25 ? 1 - recoger : abrir;
        var unificado = _tramo(t, .12, .25) * (1 - _tramo(t, .62, .78));
        if (!_morfosis) {
          final acoplando = _acople.status != AnimationStatus.reverse;
          final p = acoplando ? t : 1 - t;
          final plegar = _tramo(p, 0, .65 / 2.3);
          final mover = _tramo(p, .65 / 2.3, 1.7 / 2.3);
          final desplegar = _tramo(p, 1.75 / 2.3, 1);
          final desde = acoplando ? lateral : navFinal;
          final circuloDesde = acoplando ? navCirculo : navDestino;
          final circuloHasta = acoplando ? navDestino : navCirculo;
          final hasta = acoplando ? navFinal : lateral;
          if (p < .65 / 2.3) {
            nav = Rect.lerp(desde, circuloDesde, plegar)!;
            individuales = 1 - plegar;
          } else {
            final viajando = Rect.lerp(circuloDesde, circuloHasta, mover)!;
            nav = Rect.fromLTWH(
              viajando.left,
              viajando.top,
              ancho,
              lerpDouble(76, hasta.height, desplegar)!,
            );
            individuales = desplegar;
          }
          unificado =
              _tramo(p, .3 / 2.3, .65 / 2.3) *
              (1 - _tramo(p, 1.75 / 2.3, 2.1 / 2.3));
        }
        final control = _morfosis
            ? t < .25
                  ? Rect.lerp(tarjeta, circuloInicial, recoger)!
                  : t < .55
                  ? Rect.lerp(circuloInicial, circuloFinal, viaje)!
                  : Rect.lerp(circuloFinal, barraFinal, abrir)!
            : Rect.lerp(circuloFinal, barraFinal, abrir)!;
        final datos = _morfosis ? _tramo(t, .50, .8) : _entrada.value;
        final botones = _tramo(t, .84, 1);
        final pregunta = _morfosis ? _tramo(t, .35, .7) : _entrada.value;
        final contenido = widget.vista == 1 && widget.enPregunta;
        final rebote =
            math.sin(_rebote.value * math.pi * 2) * (1 - _rebote.value) * 7;
        return IgnorePointer(
          ignoring: _ocupado,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              if (!_paginaAmpliada)
                Positioned(
                  left: izquierda,
                  right: margen + 100,
                  top: 26,
                  child: _cabeceraAnimada(),
                ),
              if (widget.herramientas != null)
                Positioned(
                  right: margen,
                  top: 24,
                  width: 76,
                  height: laterales.herramientas,
                  child: widget.herramientas!,
                ),
              if (!contenido && !_morfosis && !widget.esperandoSorteo)
                Positioned(
                  key: const ValueKey('area-seccion'),
                  left: izquierda,
                  right: margen + ancho + separacion,
                  top: _paginaAmpliada ? 0 : superior,
                  bottom: _paginaAmpliada ? 0 : margen,
                  child: Opacity(
                    opacity: _entrada.value,
                    child: Transform.translate(
                      offset: Offset(0, 14 * (1 - _entrada.value)),
                      child: widget.pagina,
                    ),
                  ),
                ),
              if (widget.vista == 1 && widget.esperandoSorteo && !_morfosis)
                Positioned.fromRect(
                  rect: tarjeta,
                  child: _superficie(
                    radio: 28,
                    child: _TarjetaSorteo(
                      accion: _sortear,
                      child: widget.contenidoSorteo,
                    ),
                  ),
                ),
              if (contenido) ...[
                Positioned(
                  left: izquierda,
                  top: superior,
                  width: anchoContenido,
                  height: altoDatos,
                  child: Opacity(
                    opacity: datos,
                    child: Transform.scale(
                      scale: .96 + .04 * datos,
                      alignment: Alignment.topLeft,
                      child: widget.datosTurno,
                    ),
                  ),
                ),
                Positioned(
                  key: const ValueKey('area-pregunta-vertical'),
                  left: izquierda,
                  top: yPregunta,
                  width: anchoContenido,
                  height: math.max(180, h - yPregunta - margen),
                  child: Opacity(
                    opacity: pregunta,
                    child: Transform.scale(
                      scale: math.max(.001, pregunta),
                      alignment: Alignment.topLeft,
                      child: widget.pregunta,
                    ),
                  ),
                ),
              ],
              if (contenido || _morfosis)
                Positioned.fromRect(
                  rect: control,
                  child: _superficie(
                    radio: _morfosis ? lerpDouble(28, 38, recoger)! : 38,
                    color: _morfosis
                        ? Color.lerp(
                            PaletaEvaluacion.of(context).hoja,
                            PaletaEvaluacion.of(context).salviaClara,
                            _tramo(t, .08, .4),
                          )
                        : PaletaEvaluacion.of(context).salviaClara,
                    child: Stack(
                      children: [
                        if (_morfosis && t < .25)
                          Positioned.fill(
                            child: OverflowBox(
                              minWidth: tarjeta.width,
                              maxWidth: tarjeta.width,
                              minHeight: tarjeta.height,
                              maxHeight: tarjeta.height,
                              child: Opacity(
                                opacity: 1 - _tramo(t, 0, .18),
                                child: Transform.scale(
                                  scale: 1 - recoger * .5,
                                  child: SizedBox.fromSize(
                                    size: tarjeta.size,
                                    child: _TarjetaSorteo(
                                      accion: null,
                                      child: widget.contenidoSorteo,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (botones > 0)
                          Positioned(
                            left: -1.3,
                            bottom: -1.3,
                            width: ancho,
                            height: alto,
                            child: widget.barra(datos, botones),
                          ),
                      ],
                    ),
                  ),
                ),
              Positioned.fromRect(
                rect: nav.shift(Offset(rebote, 0)),
                child: CapsulaSecciones(
                  tamano: nav.size,
                  pasoX: 0,
                  pasoY: math.max(0, (nav.height - 76) / 3),
                  seleccion: _seleccion.value,
                  individuales: individuales,
                  unificado: unificado,
                  unificadoArriba: true,
                  onSeleccion: cambiarVista,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
  Widget _superficie({
    required double radio,
    Key? clave,
    Color? color,
    double borde = 1.3,
    required Widget child,
  }) => Container(
    key:
        clave ??
        (color == null ? null : const ValueKey('barra-control-evaluacion')),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: color ?? PaletaEvaluacion.of(context).hoja,
      borderRadius: BorderRadius.circular(radio),
      border: Border.all(
        color: PaletaEvaluacion.of(context).borde,
        width: borde,
      ),
    ),
    child: child,
  );
}

/// El botón pertenece a la tarjeta cuya superficie se convierte en la barra.
class _TarjetaSorteo extends StatelessWidget {
  const _TarjetaSorteo({required this.accion, required this.child});
  final VoidCallback? accion;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        child,
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const ValueKey('sortear-turno'),
          onPressed: accion,
          icon: const Icon(Icons.shuffle),
          label: const Text('Sortear siguiente turno'),
        ),
      ],
    ),
  );
}

/// Entrada de cada bloque de las páginas, independiente del desplazamiento
/// de la navegación. Su estado se conserva durante cambios de datos locales.
class EntradaSeccion extends StatelessWidget {
  const EntradaSeccion({super.key, required this.child, this.orden = 0});
  final Widget child;
  final int orden;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final demora = math.min(orden, 7) * 45;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 560 + demora),
      child: child,
      builder: (context, valor, child) {
        final t = _tramo(valor, demora / (560 + demora), 1);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
}
