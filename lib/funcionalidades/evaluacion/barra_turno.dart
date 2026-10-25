import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../compartido/movimiento/movimiento.dart';
import '../../tema/paleta_evaluacion.dart';
import 'modelos.dart';
import 'reloj_evaluacion.dart';
import 'selector_robo.dart';

const _verde = Color(0xFF246447);
double _tramo(double t, double a, double b) =>
    Interval(a, b, curve: Curves.easeInOutCubic).transform(t);

/// La identidad permanece horizontal y fuera de las dos cápsulas verticales.
class DatosTurnoVertical extends StatelessWidget {
  const DatosTurnoVertical({super.key, required this.sesion, this.candidato});
  final SesionTrivia sesion;
  final String? candidato;

  @override
  Widget build(BuildContext context) {
    final actor = BarraTurno.actor(sesion, candidato: candidato);
    final r = sesion.actual!;
    final numero =
        sesion.resultado(r.titularId).presentadas + (r.propio == null ? 1 : 0);
    return Column(
      key: const ValueKey('datos-turno-vertical'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: duracionMovimiento(context, 600),
            switchInCurve: const Interval(.35, 1),
            switchOutCurve: const Interval(.6, 1),
            layoutBuilder: (actual, anteriores) => Stack(
              alignment: Alignment.topLeft,
              children: [...anteriores, ?actual],
            ),
            child: Text(
              actor.completo,
              key: ValueKey(actor.id),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 24,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Row(
          children: [
            Text(
              '${sesion.resultado(actor.id).puntos} pts',
              key: const ValueKey('puntos-estudiante-vertical'),
              style: TextStyle(
                fontSize: 16,
                color: PaletaEvaluacion.of(context).naranjaTexto,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 14),
            Text(
              '$numero/10',
              key: const ValueKey('respuestas-estudiante-vertical'),
              style: TextStyle(
                fontSize: 16,
                color: PaletaEvaluacion.of(context).tenue,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Geometría del boceto aprobado: el ancho depende del nombre; las fases
/// intercambian contenidos dentro de los mismos espacios de la cápsula.
class BarraTurno extends StatefulWidget {
  const BarraTurno({
    super.key,
    required this.sesion,
    required this.motor,
    required this.accion,
    required this.siguiente,
    required this.explicacion,
    required this.datos,
    required this.controles,
    required this.reverso,
    required this.candidato,
    required this.onCandidato,
    this.vertical = false,
    this.onAbrirSelector,
  });
  final SesionTrivia sesion;
  final MotorEvaluacion motor;
  final void Function(void Function(MotorEvaluacion)) accion;
  final VoidCallback siguiente, explicacion;
  final VoidCallback? onAbrirSelector;
  final double datos, controles;
  final bool reverso, vertical;
  final String? candidato;
  final ValueChanged<String> onCandidato;

  static AlumnoTrivia actor(SesionTrivia s, {String? candidato}) {
    final r = s.actual!;
    return s.alumno(
      s.ladronId ??
          (s.fase == FaseEvaluacion.esperaRobo ? candidato : null) ??
          (r.robos.isNotEmpty ? r.robos.last.alumnoId : r.titularId),
    );
  }

  static double anchoNombre(
    BuildContext context,
    SesionTrivia s, {
    String? candidato,
  }) {
    final estilo = Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontFamily: 'Outfit',
      fontSize: 18,
      fontWeight: FontWeight.w700,
    );
    final medida = TextPainter(
      text: TextSpan(
        text: actor(s, candidato: candidato).completo,
        style: estilo,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final minimo = actor(s, candidato: candidato).completo.length > 23
        ? 260.0
        : 200.0;
    final ancho = (medida.width + 8).clamp(minimo, 360.0);
    medida.dispose();
    return ancho;
  }

  static double anchoPreferido(
    BuildContext context,
    SesionTrivia s, {
    String? candidato,
  }) => 752 + math.max(0, anchoNombre(context, s, candidato: candidato) - 200);

  static double altoPreferidoVertical(
    BuildContext context,
    SesionTrivia s, {
    String? candidato,
  }) => 548;

  @override
  State<BarraTurno> createState() => _BarraTurnoState();
}

class _BarraTurnoState extends State<BarraTurno> with TickerProviderStateMixin {
  final _selector = GlobalKey();
  final _anclaSelector = LayerLink();
  late final _respuesta = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3700),
    value: 1,
  );
  late final _cambio = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    value: 1,
  );
  late String _modo;
  late String _intento;
  @override
  void initState() {
    super.initState();
    _modo = _leerModo();
    _intento = _firmaIntento();
  }

  String _origen = '';
  String _leerModo() {
    final s = widget.sesion;
    return s.cronometrada
        ? s.tiempoSinIniciar
              ? 'lectura'
              : 'respuestas'
        : s.fase == FaseEvaluacion.robo
        ? 'robo'
        : s.fase == FaseEvaluacion.esperaRobo
        ? 'espera'
        : 'revision';
  }

  String _firmaIntento() {
    final r = widget.sesion.actual!;
    return '${r.preguntaId}-${r.propio != null}-${r.robos.length}';
  }

  @override
  void didUpdateWidget(BarraTurno oldWidget) {
    super.didUpdateWidget(oldWidget);
    final modo = _leerModo(), intento = _firmaIntento();
    final reducida = MediaQuery.disableAnimationsOf(context);
    if (intento != _intento &&
        (modo == 'espera' || modo == 'revision') &&
        (_modo == 'respuestas' || _modo == 'lectura' || _modo == 'robo')) {
      _origen = '';
      _cambio.value = 1;
      if (reducida) {
        _respuesta.value = 1;
      } else {
        _respuesta.forward(from: 0);
      }
    } else if (modo != _modo || intento != _intento) {
      _origen = _modo;
      _respuesta.value = 1;
      _cambio.duration = Duration(milliseconds: modo == 'lectura' ? 1100 : 950);
      if (reducida) {
        _cambio.value = 1;
      } else {
        _cambio.forward(from: 0);
      }
    }
    _modo = modo;
    _intento = intento;
  }

  @override
  void dispose() {
    _respuesta.dispose();
    _cambio.dispose();
    super.dispose();
  }

  Future<void> _seleccionar() async {
    if (widget.sesion.fase != FaseEvaluacion.esperaRobo ||
        widget.sesion.habilitadosRobo.isEmpty) {
      return;
    }
    final caja = _selector.currentContext?.findRenderObject() as RenderBox?;
    final capa = Overlay.of(context).context.findRenderObject() as RenderBox;
    if (caja == null) return;
    widget.onAbrirSelector?.call();
    final id = await mostrarSelectorRobo(
      context: context,
      enlace: _anclaSelector,
      posicion: () => MatrixUtils.transformRect(
        caja.getTransformTo(capa),
        Offset.zero & caja.size,
      ),
      opciones: [
        PopupMenuItem<String>(
          enabled: false,
          height: 34,
          child: Text(
            'Estudiante para robar',
            style: TextStyle(
              fontSize: 13,
              color: PaletaEvaluacion.of(context).tenue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (final a in widget.sesion.habilitadosRobo)
          PopupMenuItem(
            value: a.id,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: a.id == widget.candidato
                    ? PaletaEvaluacion.of(context).salviaClara
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      a.completo,
                      style: const TextStyle(fontSize: 17),
                    ),
                  ),
                  if (a.id == widget.candidato)
                    Icon(
                      Icons.check,
                      size: 18,
                      color: PaletaEvaluacion.of(context).naranjaTexto,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
    if (mounted && id != null) widget.onCandidato(id);
  }

  Widget _boton(
    String clave,
    String etiqueta,
    IconData icono,
    VoidCallback? accion, {
    bool principal = false,
    double tamano = 44,
    Widget? dibujo,
    Color? tono,
    bool deshabilitada = false,
  }) => ToqueConRebote(
    child: IconButton(
      key: ValueKey(clave),
      tooltip: etiqueta,
      onPressed: accion,
      style: IconButton.styleFrom(
        fixedSize: Size.square(tamano),
        minimumSize: Size.square(tamano),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.all(8),
        shape: const CircleBorder(),
        backgroundColor: tono != null
            ? Color.alphaBlend(
                tono.withValues(alpha: .1),
                PaletaEvaluacion.of(context).hoja,
              )
            : principal
            ? PaletaEvaluacion.of(context).naranja
            : PaletaEvaluacion.of(context).hoja,
        foregroundColor:
            tono ??
            (principal
                ? PaletaEvaluacion.of(context).sobreNaranja
                : PaletaEvaluacion.of(context).naranjaTexto),
        disabledBackgroundColor: deshabilitada
            ? PaletaEvaluacion.of(context).fondoDeshabilitado
            : tono != null
            ? Color.alphaBlend(
                tono.withValues(alpha: .1),
                PaletaEvaluacion.of(context).hoja,
              )
            : PaletaEvaluacion.of(context).hoja,
        disabledForegroundColor: deshabilitada
            ? PaletaEvaluacion.of(context).deshabilitado
            : tono ?? PaletaEvaluacion.of(context).naranjaTexto,
        side: BorderSide(
          color: deshabilitada
              ? PaletaEvaluacion.of(context).deshabilitado
              : tono ?? PaletaEvaluacion.of(context).borde,
          width: 1.3,
        ),
      ),
      icon: dibujo ?? Icon(icono, size: tamano == 52 ? 28 : 24),
    ),
  );

  Widget _animar(
    Widget child,
    double t, {
    bool interactiva = true,
    bool escalar = true,
  }) => IgnorePointer(
    ignoring: !interactiva || t < .95,
    child: ExcludeSemantics(
      excluding: !interactiva || t < .95,
      child: Opacity(
        opacity: t,
        child: Transform.scale(scale: escalar ? .2 + .8 * t : 1, child: child),
      ),
    ),
  );

  Widget _respuestas({
    required double entrada,
    required bool retroalimentacion,
  }) {
    final s = widget.sesion, r = s.actual!;
    final ultimo = r.robos.lastOrNull ?? r.propio;
    bool nueva(int i) => retroalimentacion && ultimo?.opcion == i;
    bool anterior(int i) => r.opcionesUsadas.contains(i) && !nueva(i);
    return Flex(
      direction: widget.vertical ? Axis.vertical : Axis.horizontal,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0)
            SizedBox(
              width: widget.vertical ? 0 : 6,
              height: widget.vertical ? 6 : 0,
            ),
          Transform.translate(
            offset: widget.vertical
                ? Offset(0, -i * 50 * (1 - entrada))
                : Offset(-i * 50 * (1 - entrada), 0),
            child: Transform.scale(
              scale: .15 + .85 * entrada,
              child: _boton(
                'responder-$i',
                'Responder ${'ABCD'[i]}',
                Icons.circle,
                !retroalimentacion &&
                        s.aceptaRespuesta &&
                        !r.opcionesUsadas.contains(i)
                    ? () => widget.accion((m) => m.responder(i))
                    : null,
                deshabilitada: anterior(i),
                tono: nueva(i)
                    ? (ultimo!.correcto
                          ? _verde
                          : PaletaEvaluacion.of(context).error)
                    : null,
                dibujo: widget.vertical && r.opcionesUsadas.contains(i)
                    ? Icon(
                        nueva(i) && ultimo?.correcto == true
                            ? Icons.check
                            : Icons.close,
                        key: ValueKey('marca-opcion-$i'),
                        size: 24,
                        color: nueva(i)
                            ? (ultimo!.correcto
                                  ? _verde
                                  : PaletaEvaluacion.of(context).error)
                            : PaletaEvaluacion.of(context).deshabilitado,
                      )
                    : Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'ABCD'[i],
                              maxLines: 1,
                              softWrap: false,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (r.opcionesUsadas.contains(i))
                            Positioned(
                              right: -8,
                              bottom: -7,
                              child: Icon(
                                nueva(i) && ultimo?.correcto == true
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                key: ValueKey('marca-opcion-$i'),
                                size: 16,
                                color: nueva(i)
                                    ? (ultimo!.correcto
                                          ? _verde
                                          : PaletaEvaluacion.of(context).error)
                                    : PaletaEvaluacion.of(context)
                                          .deshabilitado,
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _robo() {
    final s = widget.sesion;
    final permitido =
        s.fase == FaseEvaluacion.esperaRobo && s.habilitadosRobo.isNotEmpty;
    final elegido = s.habilitadosRobo.any((a) => a.id == widget.candidato);
    return Flex(
      direction: widget.vertical ? Axis.vertical : Axis.horizontal,
      mainAxisSize: MainAxisSize.min,
      children: [
        KeyedSubtree(
          key: _selector,
          child: CompositedTransformTarget(
            link: _anclaSelector,
            child: _boton(
              'seleccion-robo',
              elegido
                  ? 'Estudiante para robar: ${s.alumno(widget.candidato!).completo}'
                  : 'Estudiante para robar',
              Icons.person_add_alt_1,
              permitido ? _seleccionar : null,
              tamano: 52,
            ),
          ),
        ),
        SizedBox(
          width: widget.vertical ? 0 : 12,
          height: widget.vertical ? 12 : 0,
        ),
        _boton(
          'iniciar-robo',
          'Iniciar robo',
          Icons.bolt,
          !permitido
              ? null
              : elegido
              ? () => widget.accion((m) => m.iniciarRobo(widget.candidato!))
              : _seleccionar,
          tamano: 52,
          principal: true,
        ),
        SizedBox(
          width: widget.vertical ? 0 : 12,
          height: widget.vertical ? 12 : 0,
        ),
        _boton(
          'cerrar-pregunta',
          'Cerrar pregunta',
          Icons.close,
          s.fase == FaseEvaluacion.esperaRobo
              ? () => widget.accion((m) => m.cerrarPregunta())
              : null,
          tamano: 52,
        ),
      ],
    );
  }

  Widget _resultado(double entradaExplicacion) {
    final r = widget.sesion.actual!;
    final ultimo = r.robos.lastOrNull ?? r.propio;
    final bien = ultimo?.correcto == true;
    final tono = bien ? _verde : PaletaEvaluacion.of(context).error;
    return Flex(
      direction: widget.vertical ? Axis.vertical : Axis.horizontal,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          key: const ValueKey('resultado-respuesta'),
          width: widget.vertical ? 52 : 142,
          height: widget.vertical ? 52 : 44,
          padding: EdgeInsets.symmetric(horizontal: widget.vertical ? 0 : 10),
          decoration: BoxDecoration(
            color: bien
                ? const Color(0xFFE6EDE4)
                : PaletaEvaluacion.of(context).hoja,
            border: Border.all(color: tono, width: 1.5),
            borderRadius: BorderRadius.circular(widget.vertical ? 26 : 22),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [
                Icon(
                  bien ? Icons.check : Icons.close,
                  color: tono,
                  size: widget.vertical ? 28 : 22,
                  semanticLabel: widget.vertical
                      ? (bien
                            ? 'Correcto'
                            : ultimo?.opcion == null
                            ? 'Sin respuesta'
                            : 'Incorrecto')
                      : null,
                ),
                if (!widget.vertical) const SizedBox(width: 6),
                if (!widget.vertical)
                  Text(
                    bien
                        ? 'Correcto'
                        : ultimo?.opcion == null
                        ? 'Sin respuesta'
                        : 'Incorrecto',
                    style: TextStyle(
                      color: tono,
                      fontSize: widget.vertical ? 14 : 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: widget.vertical ? 0 : 8,
          height: widget.vertical ? 8 : 0,
        ),
        if (entradaExplicacion > 0)
          _animar(
            _boton(
              'ver-explicacion',
              widget.reverso ? 'Volver a las opciones' : 'Ver explicación',
              widget.reverso
                  ? Icons.flip_camera_android_outlined
                  : Icons.visibility_outlined,
              () {
                if (widget.sesion.fase == FaseEvaluacion.revision &&
                    widget.sesion.actual?.estado == EstadoPregunta.cerrada &&
                    _respuesta.value >= .65 &&
                    _cambio.isCompleted) {
                  widget.explicacion();
                }
              },
            ),
            entradaExplicacion,
            interactiva: entradaExplicacion >= 1,
          )
        else
          const SizedBox.square(dimension: 44),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, limites) {
      final s = widget.sesion, r = s.actual!;
      final actor = BarraTurno.actor(s, candidato: widget.candidato);
      final numero =
          s.resultado(r.titularId).presentadas + (r.propio == null ? 1 : 0);
      final ancho = widget.vertical
          ? 76.0
          : limites.maxWidth >= 749
          ? limites.maxWidth
          : BarraTurno.anchoPreferido(context, s, candidato: widget.candidato) -
                2.6;
      final delta = math.max(0.0, ancho + 2.6 - 752);
      final contenido = SizedBox(
        width: ancho,
        height: widget.vertical ? limites.maxHeight : 76,
        child: AnimatedBuilder(
          animation: Listenable.merge([_respuesta, _cambio]),
          builder: (context, _) {
            final t = _respuesta.value, c = _cambio.value;
            final post = _modo == 'espera' || _modo == 'revision';
            final ultimo = r.robos.lastOrNull ?? r.propio;
            final salidaAD = post && ultimo?.opcion != null
                ? 1 - _tramo(t, .216, .365)
                : 0.0;
            final feedback = post
                ? _tramo(t, .284, .46) *
                      (_modo == 'espera' ? 1 - _tramo(t, .757, .878) : 1.0)
                : 0.0;
            final robo = _modo == 'espera'
                ? _tramo(t, widget.vertical ? .878 : .824, 1)
                : 0.0;
            final entradaExplicacion =
                s.fase == FaseEvaluacion.revision &&
                    r.estado == EstadoPregunta.cerrada
                ? _tramo(t, .49, .65) * _tramo(c, .48, 1)
                : 0.0;
            final entrada = _tramo(
              c,
              widget.vertical && _origen == 'espera' ? .45 : .15,
              1,
            );
            final salidaReloj = s.cronometrada
                ? 1 - _tramo(c, .20, 1)
                : post && r.robos.isEmpty
                ? _tramo(t, .054, .27)
                : 1.0;
            final yAcciones = limites.maxHeight >= 500 ? 126.0 : 88.0;
            final ySiguiente = math.max(
              yAcciones + 206,
              limites.maxHeight - 158,
            );
            Widget colocar(double x, Widget child, {double alto = 52}) {
              if (!widget.vertical) {
                return Positioned(
                  left: x + delta,
                  top: (76 - alto) / 2 - 1.3,
                  height: alto,
                  child: child,
                );
              }
              final y = switch (x) {
                346 => alto == 64 ? 12.0 : yAcciones,
                430 => yAcciones,
                636 => ySiguiente,
                _ => limites.maxHeight - 60,
              };
              return Positioned(
                left: 0,
                width: 76,
                top: y,
                child: Align(alignment: Alignment.topCenter, child: child),
              );
            }

            Widget acciones(Widget child, double p, {bool tocar = true}) =>
                _animar(child, p * widget.controles, interactiva: tocar);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                if (!widget.vertical)
                  Positioned(
                    left: widget.vertical ? 12 : 22,
                    top: widget.vertical ? 16 : 0,
                    bottom: widget.vertical ? null : 0,
                    height: null,
                    width: widget.vertical ? 104 : 200 + delta,
                    child: ClipRect(
                      child: _animar(
                        Align(
                          alignment: widget.vertical
                              ? Alignment.topCenter
                              : Alignment.centerLeft,
                          child: Tooltip(
                            message: actor.completo,
                            child: AnimatedSwitcher(
                              duration: duracionMovimiento(context, 600),
                              switchInCurve: const Interval(.35, 1),
                              switchOutCurve: const Interval(.6, 1),
                              child: Text(
                                actor.completo,
                                key: ValueKey(actor.id),
                                maxLines: widget.vertical ? null : 1,
                                textAlign: widget.vertical
                                    ? TextAlign.center
                                    : TextAlign.start,
                                overflow: widget.vertical
                                    ? TextOverflow.clip
                                    : TextOverflow.ellipsis,
                                style: TextStyle(
                                  height: widget.vertical ? 1.2 : null,
                                  fontSize: widget.vertical ? 16 : 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        widget.datos,
                        escalar: false,
                      ),
                    ),
                  ),
                if (!widget.vertical)
                  colocar(
                    240,
                    SizedBox(
                      width: 92,
                      child: _animar(
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${s.resultado(actor.id).puntos} pts',
                                key: const ValueKey('puntos-estudiante'),
                                style: TextStyle(
                                  color: PaletaEvaluacion.of(context)
                                      .naranjaTexto,
                                  fontSize: widget.vertical ? 12 : 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(
                                width: widget.vertical ? 0 : 12,
                                height: widget.vertical ? 12 : 0,
                              ),
                              Text(
                                '$numero/10',
                                key: const ValueKey('respuestas-estudiante'),
                                style: TextStyle(
                                  fontSize: widget.vertical ? 12 : 15,
                                  color: PaletaEvaluacion.of(context).tenue,
                                ),
                              ),
                            ],
                          ),
                        ),
                        widget.datos,
                        escalar: false,
                      ),
                    ),
                  ),
                if (salidaReloj < 1)
                  colocar(
                    346,
                    acciones(
                      Tooltip(
                        message: s.tiempoSinIniciar
                            ? 'Tiempo sin iniciar'
                            : s.pausada
                            ? 'Reanudar tiempo'
                            : 'Pausar tiempo',
                        child: GestureDetector(
                          onTap: s.cronometrada && !s.tiempoSinIniciar
                              ? () => widget.accion(
                                  (m) => s.pausada ? m.reanudar() : m.pausar(),
                                )
                              : null,
                          child: RelojEvaluacion(
                            compacto: true,
                            soloSegundos: widget.vertical,
                            restanteMs: s.restanteMs,
                            sinIniciar: s.tiempoSinIniciar,
                            pausado: s.pausada,
                            salida: salidaReloj,
                          ),
                        ),
                      ),
                      1,
                    ),
                    alto: 64,
                  ),
                if (_modo == 'lectura' || (_origen == 'lectura' && c < .45))
                  colocar(
                    430,
                    acciones(
                      _boton(
                        'control-tiempo',
                        'Iniciar tiempo',
                        Icons.play_arrow,
                        () => widget.accion((m) => m.reanudar()),
                        principal: true,
                      ),
                      _modo == 'lectura' ? entrada : 1 - _tramo(c, 0, .45),
                    ),
                    alto: 44,
                  ),
                if (_modo == 'respuestas' || _modo == 'robo')
                  colocar(
                    430,
                    Opacity(
                      opacity: widget.controles,
                      child: IgnorePointer(
                        ignoring: c < 1,
                        child: _respuestas(
                          entrada: entrada,
                          retroalimentacion: false,
                        ),
                      ),
                    ),
                    alto: 44,
                  ),
                if (salidaAD > 0)
                  colocar(
                    430,
                    acciones(
                      _respuestas(entrada: 1, retroalimentacion: true),
                      salidaAD,
                      tocar: false,
                    ),
                    alto: 44,
                  ),
                if (feedback > 0)
                  colocar(
                    430,
                    acciones(
                      _resultado(entradaExplicacion),
                      feedback * (_origen == 'espera' ? _tramo(c, .48, 1) : c),
                    ),
                    alto: 44,
                  ),
                if (robo > 0 || (_origen == 'espera' && c < .45))
                  colocar(
                    346,
                    acciones(
                      _robo(),
                      _modo == 'espera' ? robo : 1 - _tramo(c, 0, .45),
                      tocar: _modo == 'espera',
                    ),
                  ),
                if (s.cronometrada || (post && r.robos.isEmpty && t < .27))
                  colocar(
                    636,
                    acciones(
                      _boton(
                        'no-contesta',
                        'No contesta',
                        Icons.skip_next,
                        post
                            ? null
                            : () => widget.accion((m) {
                                if (m.sesion.pausada) m.reanudar();
                                m.sinRespuesta();
                              }),
                      ),
                      post ? 1 - _tramo(t, .054, .27) : entrada,
                    ),
                    alto: 44,
                  ),
                if (_modo == 'revision')
                  colocar(
                    636,
                    acciones(
                      _boton(
                        'siguiente-turno',
                        'Siguiente turno',
                        Icons.arrow_forward,
                        widget.siguiente,
                        principal: true,
                      ),
                      _tramo(t, .324, .49) * c,
                    ),
                    alto: 44,
                  ),
                colocar(
                  692,
                  acciones(
                    _boton(
                      'deshacer-evaluacion',
                      'Deshacer última acción',
                      Icons.undo,
                      widget.motor.puedeDeshacer
                          ? () => widget.accion((m) => m.deshacer())
                          : null,
                    ),
                    1,
                  ),
                  alto: 44,
                ),
              ],
            );
          },
        ),
      );
      return widget.vertical
          ? contenido
          : SingleChildScrollView(
              key: const ValueKey('scroll-barra-turno'),
              scrollDirection: Axis.horizontal,
              child: contenido,
            );
    },
  );
}
