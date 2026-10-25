import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../compartido/componentes/boton_principal.dart';
import '../../../compartido/componentes/desplazamiento_con_fundido.dart';
import '../../../compartido/movimiento/coordinador_carta.dart';
import '../../../compartido/movimiento/movimiento.dart';
import '../../../tema/tema_trivia_antiguedad.dart';
import '../modelos/pregunta.dart';

/// El mismo mazo se usa en juego, tutorial y laboratorio.
class MazoPreguntas extends StatefulWidget {
  const MazoPreguntas({
    super.key,
    required this.cartas,
    required this.indice,
    required this.nivel,
    required this.coordinador,
    this.accionesPermitidas = const {
      AccionCarta.avanzar,
      AccionCarta.pasar,
      AccionCarta.girar,
    },
  });
  final List<Pregunta> cartas;
  final int indice;
  final String nivel;
  final CoordinadorCarta coordinador;
  final Set<AccionCarta> accionesPermitidas;

  @override
  State<MazoPreguntas> createState() => _MazoPreguntasState();
}

class _MazoPreguntasState extends State<MazoPreguntas> {
  _VistaCarta? _saliente;
  bool _pasada = false;
  final _scrollFrente = ScrollController();
  final _scrollReverso = ScrollController();
  final _instantaneasScroll = <ScrollController>[];
  ScrollController? _scrollSaliente;
  final _dedos = <int>{};
  bool _multitactil = false;

  @override
  void initState() {
    super.initState();
    widget.coordinador.addListener(_cambio);
  }

  void _cambio() {
    final motor = widget.coordinador;
    if (motor.fase == FaseCarta.salida &&
        _saliente == null &&
        widget.indice < widget.cartas.length) {
      _saliente = _VistaCarta(
        widget.cartas[widget.indice],
        widget.indice,
        widget.cartas.length,
        widget.nivel,
        motor.reverso,
      );
      final anterior = motor.reverso ? _scrollReverso : _scrollFrente;
      _scrollSaliente = ScrollController(
        initialScrollOffset: anterior.hasClients ? anterior.offset : 0,
      );
      _instantaneasScroll.add(_scrollSaliente!);
      _pasada = motor.ultimaAccion == AccionCarta.pasar;
    }
    if (motor.fase == FaseCarta.asentamiento ||
        motor.fase == FaseCarta.reposo) {
      _saliente = null;
      _pasada = false;
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(MazoPreguntas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.indice != oldWidget.indice) {
      // La cara nueva se monta a cero debajo de la instantánea saliente.
      for (final scroll in [_scrollFrente, _scrollReverso]) {
        if (scroll.hasClients) scroll.jumpTo(0);
      }
      _pasada =
          widget.coordinador.fase == FaseCarta.salida &&
          widget.coordinador.ultimaAccion == AccionCarta.pasar;
    }
  }

  @override
  void dispose() {
    widget.coordinador.removeListener(_cambio);
    _scrollFrente.dispose();
    _scrollReverso.dispose();
    for (final scroll in _instantaneasScroll) {
      scroll.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limites) {
      final motor = widget.coordinador;
      motor.ancho = limites.maxWidth;
      motor.reducido = MediaQuery.disableAnimationsOf(context);
      motor.hayCarta = widget.indice < widget.cartas.length;
      motor.hayRepregunta =
          motor.hayCarta && widget.cartas[widget.indice].repregunta != null;
      final frente = motor.hayCarta
          ? _VistaCarta(
              widget.cartas[widget.indice],
              widget.indice,
              widget.cartas.length,
              widget.nivel,
              _saliente == null && motor.caraReversa,
            )
          : null;
      final promocion = motor.fase == FaseCarta.salida
          ? 0.0
          : motor.fase == FaseCarta.asentamiento
          ? motor.progreso
          : 1.0;
      final inicio = (motor.desplazamientoInicial / motor.ancho).clamp(
        -1.0,
        1.0,
      );
      return Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          if (frente != null) ...[
            for (
              var profundidad = math.min(
                2,
                widget.cartas.length - widget.indice - 1,
              );
              profundidad >= 1;
              profundidad--
            )
              Transform.translate(
                offset: Offset(0, profundidad * 8),
                child: Transform.scale(
                  scale: profundidad == 2 ? .94 : .97,
                  child: ExcludeSemantics(
                    child: SuperficieCarta(
                      child: DecoratedBox(
                        key: ValueKey('mazo-detras-$profundidad'),
                        decoration: _superficie(
                          indice: widget.indice + profundidad,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Transform.translate(
              offset: Offset(0, motor.reducido ? 0 : 8 * (1 - promocion)),
              child: Transform.scale(
                scale: motor.reducido ? 1 : .97 + .03 * promocion,
                child: _saliente == null
                    ? _interactiva(frente, motor)
                    : ExcludeSemantics(
                        child: IgnorePointer(
                          child: _CaraCarta(
                            vista: frente,
                            scroll: _scrollFrente,
                          ),
                        ),
                      ),
              ),
            ),
          ],
          if (_saliente != null)
            ExcludeSemantics(
              child: IgnorePointer(
                child: Opacity(
                  opacity: motor.reducido ? 1 - motor.progreso : 1,
                  child: Transform.translate(
                    offset: Offset(
                      motor.reducido ? 0 : motor.desplazamiento,
                      motor.reducido
                          ? 0
                          : -inicio.abs() * 3 * (1 - motor.progreso) +
                                16 * motor.intensidadPista,
                    ),
                    child: Transform.rotate(
                      angle: motor.reducido
                          ? 0
                          : inicio * math.pi / 45 * (1 - motor.progreso) -
                                .035 * motor.progreso -
                                motor.intensidadPista * math.pi / 50,
                      child: Transform.scale(
                        scale: motor.reducido
                            ? 1
                            : 1 +
                                  inicio.abs() * .015 * (1 - motor.progreso) -
                                  .03 * motor.intensidadPista,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _CaraCarta(
                              vista: _saliente!,
                              scroll: _scrollSaliente,
                              realce: motor.reducido
                                  ? 0
                                  : motor.intensidadPista,
                            ),
                            if (_pasada)
                              Positioned(
                                top: 22,
                                right: 22,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: TemaTriviaAntiguedad.naranja,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: const Text(
                                    'Pasada',
                                    style: TextStyle(
                                      color: TemaTriviaAntiguedad.sobreNaranja,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                          ],
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

  Widget _interactiva(_VistaCarta vista, CoordinadorCarta motor) {
    final distancia = (motor.desplazamiento / motor.ancho).clamp(-1.0, 1.0);
    final giro = motor.fase == FaseCarta.giro;
    final p = motor.progreso;
    final angulo = giro && !motor.reducido
        ? (p < .5 ? p : p - 1) * math.pi
        : 0.0;
    final opacidad = giro && motor.reducido
        ? (2 * (p - .5).abs()).clamp(0.0, 1.0)
        : 1.0;
    return Semantics(
      label:
          'Tarjeta ${vista.indice + 1} de ${vista.total}${vista.reverso ? ", reverso" : ""}',
      customSemanticsActions: {
        if (widget.accionesPermitidas.contains(AccionCarta.avanzar))
          const CustomSemanticsAction(label: 'Otra carta'): () =>
              motor.ejecutar(AccionCarta.avanzar),
        if (widget.accionesPermitidas.contains(AccionCarta.pasar))
          const CustomSemanticsAction(label: 'Esta la paso'): () =>
              motor.ejecutar(AccionCarta.pasar),
        if (vista.pregunta.repregunta != null &&
            widget.accionesPermitidas.contains(AccionCarta.girar))
          CustomSemanticsAction(
            label: vista.reverso ? 'Volver a la carta' : 'Una más',
          ): () =>
              motor.ejecutar(AccionCarta.girar),
      },
      child: Listener(
        onPointerDown: (evento) {
          _dedos.add(evento.pointer);
          if (_dedos.length > 1) {
            _multitactil = true;
            motor.cancelarArrastre();
          }
        },
        onPointerUp: (evento) {
          _dedos.remove(evento.pointer);
          if (_dedos.isEmpty) _multitactil = false;
        },
        onPointerCancel: (evento) {
          _dedos.remove(evento.pointer);
          if (_dedos.isEmpty) _multitactil = false;
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart:
              !widget.accionesPermitidas.contains(AccionCarta.avanzar)
              ? null
              : (_) {
                  if (!_multitactil) motor.comenzarArrastre();
                },
          onHorizontalDragUpdate:
              !widget.accionesPermitidas.contains(AccionCarta.avanzar)
              ? null
              : (evento) {
                  if (!_multitactil) motor.arrastrar(evento.delta.dx);
                },
          onHorizontalDragEnd:
              !widget.accionesPermitidas.contains(AccionCarta.avanzar)
              ? null
              : (evento) => motor.soltar(evento.velocity.pixelsPerSecond.dx),
          onHorizontalDragCancel: motor.cancelarArrastre,
          child: Transform.translate(
            offset: motor.reducido
                ? Offset.zero
                : Offset(
                    motor.desplazamiento,
                    -distancia.abs() * 3 + 16 * motor.intensidadPista,
                  ),
            child: Transform.rotate(
              angle: motor.reducido
                  ? 0
                  : distancia * math.pi / 45 -
                        motor.intensidadPista * math.pi / 50,
              child: Transform.scale(
                scale: motor.reducido
                    ? 1
                    : 1 + distancia.abs() * .015 - .03 * motor.intensidadPista,
                child: Opacity(
                  opacity: opacidad,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, .0012)
                      ..rotateY(angulo),
                    child: IgnorePointer(
                      ignoring: motor.ocupado,
                      child: _CaraCarta(
                        key: ValueKey('${vista.pregunta.id}-${vista.reverso}'),
                        vista: vista,
                        scroll: vista.reverso ? _scrollReverso : _scrollFrente,
                        realce: motor.reducido ? 0 : motor.intensidadPista,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration _superficie({required int indice, double realce = 0}) =>
    BoxDecoration(
      color: TemaTriviaAntiguedad.colorCarta(indice),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(
        color: Color.lerp(
          TemaTriviaAntiguedad.borde,
          TemaTriviaAntiguedad.naranja,
          realce,
        )!,
        width: 1 + 2 * realce,
      ),
      boxShadow: [
        BoxShadow(
          color: TemaTriviaAntiguedad.tinta.withValues(alpha: .075),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );

class _VistaCarta {
  const _VistaCarta(
    this.pregunta,
    this.indice,
    this.total,
    this.nivel,
    this.reverso,
  );
  final Pregunta pregunta;
  final int indice;
  final int total;
  final String nivel;
  final bool reverso;
}

/// Permite que la guía reconozca las superficies pintadas y sus transformaciones
/// reales sin reproducir el cálculo de arrastre, giro o salida de este componente.
class SuperficieCarta extends StatelessWidget {
  const SuperficieCarta({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}

class _CaraCarta extends StatelessWidget {
  const _CaraCarta({
    super.key,
    required this.vista,
    this.scroll,
    this.realce = 0,
  });
  final _VistaCarta vista;
  final ScrollController? scroll;
  final double realce;
  @override
  Widget build(BuildContext context) {
    final texto = vista.reverso
        ? vista.pregunta.repregunta!
        : vista.pregunta.texto;
    final tamano = texto.length > 100
        ? 32.0
        : texto.length > 60
        ? 36.0
        : 40.0;
    return SuperficieCarta(
      child: DecoratedBox(
        key: const ValueKey('tarjeta-visible'),
        decoration: _superficie(indice: vista.indice, realce: realce),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Scrollbar(
            controller: scroll,
            child: SingleChildScrollView(
              controller: scroll,
              primary: false,
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vista.reverso
                                  ? 'UNA MÁS'
                                  : vista.nivel.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                                color: TemaTriviaAntiguedad.tenue,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${vista.indice + 1} de ${vista.total}',
                              key: const ValueKey('contador'),
                              style: const TextStyle(
                                fontSize: 15,
                                color: TemaTriviaAntiguedad.tenue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Image.asset(
                        'assets/imagenes/optimizadas/marcas-naranjas.webp',
                        color: TemaTriviaAntiguedad.naranja,
                        colorBlendMode: BlendMode.srcIn,
                        key: const ValueKey('adorno-pregunta'),
                        width: 46,
                        height: 44,
                        fit: BoxFit.contain,
                        excludeFromSemantics: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text(
                      texto,
                      key: ValueKey(vista.reverso ? 'repregunta' : 'pregunta'),
                      style: TextStyle(
                        fontSize: tamano,
                        height: 1.14,
                        letterSpacing: -.85,
                        fontWeight: FontWeight.w800,
                        color: TemaTriviaAntiguedad.tinta,
                      ),
                    ),
                  ),
                  if (vista.reverso) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Quédense con esta charla un ratito más.',
                      style: TextStyle(
                        fontSize: 14,
                        color: TemaTriviaAntiguedad.tenue,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Mide los controles reales para mantener el mazo estable con texto del sistema.
class MesaCartas extends StatelessWidget {
  const MesaCartas({super.key, required this.mazo, required this.controles});
  final Widget mazo;
  final Widget controles;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limites) {
      final contenido = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _DistribucionMesa(
            altoDisponible: limites.maxHeight,
            children: [mazo, controles],
          ),
        ),
      );
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: DesplazamientoConFundido(child: contenido),
      );
    },
  );
}

/// Ambos hijos se miden en la misma pasada: no hay una altura estimada que
/// cambie al frame siguiente ni una corrección de scroll durante el gesto.
class _DistribucionMesa extends MultiChildRenderObjectWidget {
  const _DistribucionMesa({
    required this.altoDisponible,
    required super.children,
  });
  final double altoDisponible;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMesa(altoDisponible);

  @override
  void updateRenderObject(BuildContext context, _RenderMesa renderObject) {
    renderObject.altoDisponible = altoDisponible;
  }
}

class _DatosMesa extends ContainerBoxParentData<RenderBox> {}

class _RenderMesa extends RenderBox
    with
        ContainerRenderObjectMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        >,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          ContainerBoxParentData<RenderBox>
        > {
  _RenderMesa(this._altoDisponible);
  double _altoDisponible;
  set altoDisponible(double valor) {
    if (_altoDisponible == valor) return;
    _altoDisponible = valor;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! ContainerBoxParentData<RenderBox>) {
      child.parentData = _DatosMesa();
    }
  }

  @override
  void performLayout() {
    final mazo = firstChild!;
    final controles = lastChild!;
    final ancho = constraints.maxWidth;
    controles.layout(
      BoxConstraints.tightFor(width: ancho),
      parentUsesSize: true,
    );
    final altura = math.max(
      180.0,
      math.min(
        _altoDisponible - controles.size.height - 58,
        math.min(480.0, ancho * 1.12),
      ),
    );
    mazo.layout(
      BoxConstraints.tightFor(width: ancho, height: altura),
      parentUsesSize: true,
    );
    (mazo.parentData! as ContainerBoxParentData<RenderBox>).offset =
        const Offset(0, 20);
    (controles.parentData! as ContainerBoxParentData<RenderBox>).offset =
        Offset(0, 20 + altura + 30);
    size = constraints.constrain(
      Size(ancho, 58 + altura + controles.size.height),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

class ControlesCarta extends StatelessWidget {
  const ControlesCarta({
    super.key,
    required this.coordinador,
    this.ayuda,
    this.claveAvanzar,
    this.claveGirar,
    this.clavePasar,
    this.mostrarAvance = true,
    this.mostrarGiro = true,
    this.mostrarPasar = true,
    this.mostrarPie = true,
    this.destacar,
    this.accionesVisibles,
    this.bloqueado = false,
  });
  final CoordinadorCarta coordinador;
  final VoidCallback? ayuda;
  final Key? claveAvanzar;
  final Key? claveGirar;
  final Key? clavePasar;
  final bool mostrarAvance, mostrarGiro, mostrarPasar, mostrarPie;
  final AccionCarta? destacar;
  final Set<AccionCarta>? accionesVisibles;
  final bool bloqueado;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limites) {
      final anchoAccion =
          limites.maxWidth / (mostrarGiro && mostrarPasar ? 2 : 1) - 16;
      final estiloAccion = TextStyle(
        fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.25,
      );
      var altoAccion = 68.0;
      for (final texto in [
        'Una más',
        'Volver a la carta',
        'Cómo jugar',
        'Esta la paso',
      ]) {
        final medicion = TextPainter(
          text: TextSpan(text: texto, style: estiloAccion),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: math.max(1, anchoAccion));
        altoAccion = math.max(altoAccion, medicion.height + 20);
        medicion.dispose();
      }
      return AnimatedBuilder(
        animation: coordinador,
        builder: (context, _) {
          final disponible = coordinador.hayCarta || coordinador.ocupado;
          return IgnorePointer(
            ignoring: coordinador.ocupado || bloqueado,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (mostrarAvance)
                  _ControlVisible(
                    key: claveAvanzar,
                    visible:
                        accionesVisibles?.contains(AccionCarta.avanzar) ?? true,
                    child: BotonPrincipal(
                      destacado: destacar == AccionCarta.avanzar,
                      key: const ValueKey('otra-carta'),
                      texto: 'Otra carta',
                      feedbackExterno: true,
                      onPressed: disponible
                          ? () => coordinador.ejecutar(AccionCarta.avanzar)
                          : null,
                    ),
                  ),
                if (mostrarAvance && (mostrarGiro || mostrarPasar))
                  const SizedBox(height: 10),
                if (mostrarGiro || mostrarPasar)
                  SizedBox(
                    height: altoAccion,
                    child: Row(
                      children: [
                        if (mostrarGiro)
                          Expanded(
                            child: _ControlVisible(
                              key: claveGirar,
                              visible:
                                  accionesVisibles?.contains(
                                    AccionCarta.girar,
                                  ) ??
                                  true,
                              child: ToqueConRebote(
                                child: TextButton(
                                  style: _estiloAccion(
                                    destacar == AccionCarta.girar,
                                  ),
                                  key: const ValueKey('una-mas'),
                                  onPressed: !disponible
                                      ? null
                                      : coordinador.hayRepregunta
                                      ? () => coordinador.ejecutar(
                                          AccionCarta.girar,
                                        )
                                      : ayuda,
                                  child: Text(
                                    coordinador.hayRepregunta
                                        ? (coordinador.reverso
                                              ? 'Volver a la carta'
                                              : 'Una más')
                                        : 'Cómo jugar',
                                    textAlign: TextAlign.center,
                                    style: estiloAccion,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        if (mostrarPasar)
                          Expanded(
                            child: _ControlVisible(
                              key: clavePasar,
                              visible:
                                  accionesVisibles?.contains(
                                    AccionCarta.pasar,
                                  ) ??
                                  true,
                              child: ToqueConRebote(
                                child: TextButton(
                                  style: _estiloAccion(
                                    destacar == AccionCarta.pasar,
                                  ),
                                  key: const ValueKey('pasar'),
                                  onPressed: disponible
                                      ? () => coordinador.ejecutar(
                                          AccionCarta.pasar,
                                        )
                                      : null,
                                  child: Text(
                                    'Esta la paso',
                                    textAlign: TextAlign.center,
                                    style: estiloAccion,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (mostrarPie) const SizedBox(height: 10),
                if (mostrarPie)
                  const Text(
                    'Respondan a su ritmo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: TemaTriviaAntiguedad.tenue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}

// El borde pertenece a la forma del botón; cambia el énfasis, no sus medidas.
ButtonStyle _estiloAccion(bool destacado) => TextButton.styleFrom(
  // La superficie pintada y el área táctil comparten medidas para que el foco
  // no deje un halo alrededor de la forma real del botón.
  minimumSize: const Size(0, 48),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  backgroundColor: destacado ? TemaTriviaAntiguedad.hoja : null,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(23),
    side: BorderSide(
      color: destacado ? TemaTriviaAntiguedad.naranja : Colors.transparent,
      width: 2,
    ),
  ),
);

// Ocultar una acción de la lección no cambia la mesa ni su ancho en el juego.
class _ControlVisible extends StatelessWidget {
  const _ControlVisible({
    super.key,
    required this.visible,
    required this.child,
  });
  final bool visible;
  final Widget child;
  @override
  Widget build(BuildContext context) => Visibility(
    visible: visible,
    maintainSize: true,
    maintainState: true,
    maintainAnimation: true,
    child: child,
  );
}
