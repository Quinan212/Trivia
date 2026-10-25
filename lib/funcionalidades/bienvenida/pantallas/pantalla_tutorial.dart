import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/componentes/fondo_conversacion.dart';
import '../../../compartido/componentes/entrada_inicio.dart';
import '../../../compartido/componentes/desplazamiento_con_fundido.dart';
import '../../../compartido/movimiento/coordinador_carta.dart';
import '../../../compartido/sonidos/respuesta_interfaz.dart';
import '../../../tema/iconos_trivia_antiguedad.dart';
import '../../../tema/tema_trivia_antiguedad.dart';
import '../../ajustes/controladores/controlador_experiencia.dart';
import '../../partida/componentes/mazo_preguntas.dart';
import '../../partida/componentes/resumen_ronda.dart';
import '../../partida/modelos/catalogo_preguntas.dart';
import '../modelos/sesion_demostracion.dart';
import '../componentes/foco_tutorial.dart';
import '../componentes/ruta_tutorial.dart';
import '../componentes/guia_anclada_tutorial.dart';

Future<void> mostrarTutorial(
  BuildContext context, {
  bool conSonido = true,
  ValueChanged<Animation<double>?>? enlazarTransicion,
}) async {
  if (ModalRoute.of(context)?.isCurrent != true) return;
  final respuesta = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(respuestaInterfazProvider);
  final enlazar =
      enlazarTransicion ?? EntradaInicio.of(context)?.enlazarTutorial;
  final ruta = RutaTutorial(
    context,
    const PantallaTutorial(),
    fondoCompartido: enlazar != null,
  );
  final salida = Navigator.of(context).push<void>(ruta);
  enlazar?.call(ruta.animation);
  unawaited(ruta.completed.then((_) => enlazar?.call(null)));
  if (conSonido) respuesta.emitir(EfectoInterfaz.abrirTutorial);
  await salida;
  if (!context.mounted) return;
  await ProviderScope.containerOf(
    context,
    listen: false,
  ).read(experienciaProvider.notifier).marcarTutorialVisto();
}

const _pasos = [
  (
    'Elegí el tono.',
    'Elegí un nivel para probar. Esta práctica no cambia tu partida.',
  ),
  (
    'Esta es tu carta.',
    'Léanla en voz alta. Tocá «Otra carta» para probar cómo llega la siguiente.',
  ),
  (
    'Probá moverla.',
    'Deslizá a la izquierda o tocá «Otra carta». Si soltás antes, vuelve a su lugar.',
  ),
  (
    'Si pinta, una más.',
    'Tocá «Una más». La carta gira y aparece otra entrada para seguir charlando.',
  ),
  (
    'Pasar está bien.',
    'Tocá «Esta la paso». Pasar está bien, sin tener que explicar por qué.',
  ),
  (
    'Listo. A charlar.',
    'Al terminar vas a ver un resumen de la ronda. Esto es una pequeña muestra.',
  ),
];

class PantallaTutorial extends ConsumerStatefulWidget {
  const PantallaTutorial({super.key});
  @override
  ConsumerState<PantallaTutorial> createState() => _PantallaTutorialState();
}

class _PantallaTutorialState extends ConsumerState<PantallaTutorial>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _sesion = SesionDemostracion(tutorial: true);
  late final _motor = CoordinadorCarta(vsync: this)
    ..permitirAccion = ((accion) => _permitidas.contains(accion))
    ..alConfirmar = _confirmar
    ..alEstabilizar = _estable
    ..addListener(_movimiento);
  final _niveles = [GlobalKey(), GlobalKey(), GlobalKey()];
  final _mazo = GlobalKey();
  final _avanzar = GlobalKey();
  final _girar = GlobalKey();
  final _pasar = GlobalKey();
  final _cierre = GlobalKey();
  int _paso = 0;
  String? _resultado;
  bool _transicion = false;
  bool _guiaEnMovimiento = false;
  bool _enPrimerPlano = true;
  int? _pasoPendiente;
  bool? _caraConfirmada;
  Timer? _continuacion;
  Timer? _demoraPista;
  bool _pistaMostrada = false;
  final _toquesPractica = <int>{};
  FaseCarta _faseAnterior = FaseCarta.reposo;
  EfectoInterfaz _salidaEfecto = EfectoInterfaz.tutorialOmitir;

  AccionCarta? get _accion => switch (_paso) {
    1 || 2 => AccionCarta.avanzar,
    3 => AccionCarta.girar,
    4 => AccionCarta.pasar,
    _ => null,
  };
  Set<AccionCarta> get _permitidas =>
      _entradaLista &&
          !_guiaEnMovimiento &&
          _pasoPendiente == null &&
          _accion != null
      ? {_accion!}
      : {};
  bool get _entradaLista =>
      EntradaInicio.of(context)?.enCurso != true &&
      ModalRoute.of(context)?.isCurrent == true;

  void _movimiento() {
    if (_motor.fase == _faseAnterior) return;
    _faseAnterior = _motor.fase;
    if (_motor.fase == FaseCarta.retorno && mounted) {
      setState(
        () => _resultado = 'Así vuelve si la soltás antes. Probá deslizar más.',
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entradaLista) _programarPista();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    _enPrimerPlano = estado == AppLifecycleState.resumed;
    if (!_enPrimerPlano) {
      _toquesPractica.clear();
      _demoraPista?.cancel();
      _demoraPista = null;
      _continuacion?.cancel();
      _continuacion = null;
      _motor.estabilizar(mostrarReverso: _caraConfirmada ?? _motor.reverso);
    } else {
      _programarContinuacion();
      _programarPista();
    }
  }

  void _programarPista() {
    if (_paso != 2 ||
        !_entradaLista ||
        _guiaEnMovimiento ||
        !_enPrimerPlano ||
        _pistaMostrada ||
        _toquesPractica.isNotEmpty ||
        _pasoPendiente != null ||
        _demoraPista != null ||
        _motor.reducido) {
      return;
    }
    // Primero termina de recomponerse el foco y la guía queda lista para leer.
    _demoraPista = Timer(const Duration(milliseconds: 900), () {
      _demoraPista = null;
      if (!mounted ||
          !_enPrimerPlano ||
          !_entradaLista ||
          _paso != 2 ||
          _pasoPendiente != null) {
        return;
      }
      _pistaMostrada = true;
      if (_motor.mostrarPistaArrastre()) {
        ref
            .read(respuestaInterfazProvider)
            .emitir(EfectoInterfaz.deslizamiento);
      }
    });
  }

  void _tocarPractica(PointerDownEvent evento) {
    _toquesPractica.add(evento.pointer);
    _demoraPista?.cancel();
    _demoraPista = null;
    if (_paso == 2) _pistaMostrada = true;
    _motor.pausarPista();
  }

  void _soltarPractica(PointerEvent evento) {
    _toquesPractica.remove(evento.pointer);
    if (_toquesPractica.isEmpty) _motor.reanudarPista();
  }

  void _confirmar(AccionCarta accion) {
    _demoraPista?.cancel();
    _demoraPista = null;
    _pistaMostrada = true;
    _pasoPendiente = _paso + 1;
    _caraConfirmada = accion == AccionCarta.girar ? !_motor.reverso : false;
    _transicion = accion != AccionCarta.girar;
    _sesion.confirmar(accion);
    _resultado = switch (accion) {
      AccionCarta.avanzar => 'Llegó otra carta. Seguimos en un segundo.',
      AccionCarta.pasar => 'Carta pasada. Seguimos en un segundo.',
      AccionCarta.girar =>
        _motor.reverso
            ? 'Volvés al frente. Seguimos en un segundo.'
            : 'Ahí está Una más. Seguimos en un segundo.',
    };
    ref.read(respuestaInterfazProvider).emitir(switch (accion) {
      AccionCarta.avanzar => EfectoInterfaz.carta,
      AccionCarta.pasar => EfectoInterfaz.pasar,
      AccionCarta.girar =>
        _motor.reverso ? EfectoInterfaz.volverCarta : EfectoInterfaz.giro,
    });
    setState(() {});
  }

  void _estable() {
    if (!mounted) return;
    setState(() => _transicion = false);
    _programarContinuacion();
  }

  void _programarContinuacion() {
    if (!_enPrimerPlano ||
        !_entradaLista ||
        _pasoPendiente == null ||
        _continuacion != null ||
        _motor.ocupado) {
      return;
    }
    final destino = _pasoPendiente!;
    _continuacion = Timer(const Duration(seconds: 1), () {
      _continuacion = null;
      if (mounted && _enPrimerPlano && _pasoPendiente == destino) {
        _mover(destino, automatico: true);
      }
    });
  }

  void _mover(int paso, {bool automatico = false}) {
    if (!_entradaLista || !_enPrimerPlano) return;
    _demoraPista?.cancel();
    _demoraPista = null;
    _continuacion?.cancel();
    _continuacion = null;
    _pasoPendiente = null;
    if (paso == _pasos.length) {
      _salidaEfecto = EfectoInterfaz.tutorialCompletar;
      _salir();
      return;
    }
    if (_motor.fase != FaseCarta.reposo) {
      _motor.estabilizar(mostrarReverso: _caraConfirmada ?? false);
    }
    if (paso < _paso || (_sesion.terminada && paso < 5)) {
      _motor.estabilizar();
      _sesion.reiniciar();
    }
    _caraConfirmada = null;
    if (!automatico) {
      ref
          .read(respuestaInterfazProvider)
          .emitir(
            paso < _paso
                ? EfectoInterfaz.tutorialAnterior
                : EfectoInterfaz.tutorialSiguiente,
          );
    }
    setState(() {
      _paso = paso;
      _pistaMostrada = false;
      _resultado = null;
    });
    _programarPista();
  }

  void _salir() {
    if (ModalRoute.of(context)?.isCurrent == true) Navigator.pop(context);
  }

  void _moverGuia(bool moviendo) {
    if (!mounted) return;
    setState(() => _guiaEnMovimiento = moviendo);
    if (moviendo) {
      _demoraPista?.cancel();
      _demoraPista = null;
    } else {
      _programarPista();
    }
  }

  @override
  void dispose() {
    _demoraPista?.cancel();
    _continuacion?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _motor.removeListener(_movimiento);
    _motor.dispose();
    _sesion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    onPopInvokedWithResult: (salio, _) {
      if (salio) {
        _demoraPista?.cancel();
        _demoraPista = null;
        _continuacion?.cancel();
        _continuacion = null;
        _pasoPendiente = null;
        _motor.estabilizar(mostrarReverso: _caraConfirmada ?? _motor.reverso);
        ref.read(respuestaInterfazProvider).emitir(_salidaEfecto);
      }
    },
    child: FondoConversacion(
      fondoSereno: true,
      sonido: true,
      child: LayoutBuilder(
        builder: (context, limites) {
          final escala = MediaQuery.textScalerOf(context).scale(14) / 14;
          // Reservar la misma altura de práctica evita mover el mazo con cada
          // resultado; la burbuja flota junto a las superficies de cada paso.
          final alturaGuia = math.min(
            limites.maxHeight * .52,
            280.0 + 64.0 * (escala - 1).clamp(0.0, 1.0),
          );
          return GuiaAncladaTutorial(
            paso: _paso,
            fijarPosicion:
                _pasoPendiente != null || _motor.fase != FaseCarta.reposo,
            alturaGuia: alturaGuia,
            objetivos: _objetivos.map((objetivo) => objetivo.clave).toList(),
            ancla: _ancla,
            alMover: _moverGuia,
            practica: RevelarInicio(
              inicio: .12,
              fin: .72,
              child: IgnorePointer(
                ignoring: !_entradaLista || _guiaEnMovimiento,
                child: FocoTutorial(
                  movimiento: _motor,
                  cartasDetras: math.max(
                    0,
                    math.min(2, _sesion.cartas.length - _sesion.indice - 1),
                  ),
                  objetivos: _objetivos,
                  ancla: _ancla,
                  child: Listener(
                    onPointerDown: _tocarPractica,
                    onPointerUp: _soltarPractica,
                    onPointerCancel: _soltarPractica,
                    child: _contenidoDemo(),
                  ),
                ),
              ),
            ),
            guia: (puntero, lectura) => RevelarInicio(
              inicio: .45,
              fin: 1,
              child: IgnorePointer(
                ignoring: !_entradaLista,
                child: _GuiaTutorial(
                  paso: _paso,
                  resultado: _resultado,
                  puntero: puntero,
                  lectura: lectura,
                  siguiente: () => _mover(_paso + 1),
                  atras: () => _mover(_paso - 1),
                  omitir: _salir,
                ),
              ),
            ),
          );
        },
      ),
    ),
  );

  GlobalKey get _ancla => _paso == 0
      ? _niveles.first
      : _paso == 5 || (_sesion.terminada && !_transicion)
      ? _cierre
      : switch (_accion) {
          AccionCarta.girar => _girar,
          AccionCarta.pasar => _pasar,
          _ => _avanzar,
        };
  List<ObjetivoFoco> get _objetivos => _paso == 0
      ? [for (final clave in _niveles) ObjetivoFoco(clave, radio: 20)]
      : _paso == 5 || (_sesion.terminada && !_transicion)
      ? [ObjetivoFoco(_cierre, radio: 28)]
      : [
          for (var i = 0; i < 3; i++)
            ObjetivoFoco(_mazo, radio: 28, profundidad: i),
          ObjetivoFoco(_ancla),
        ];

  Widget _contenidoDemo() {
    _motor.hayCarta = !_sesion.terminada;
    _motor.hayRepregunta =
        !_sesion.terminada && _sesion.cartas[_sesion.indice].repregunta != null;
    _motor.reducido = MediaQuery.disableAnimationsOf(context);
    if (_paso == 0) {
      return DesplazamientoConFundido(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final nivel in nivelesConversacion)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: _sesion.nivel == nivel.id
                      ? TemaTriviaAntiguedad.salvia
                      : TemaTriviaAntiguedad.hoja,
                  borderRadius: BorderRadius.circular(20),
                  child: ListTile(
                    key: _niveles[nivel.id - 1],
                    selected: _sesion.nivel == nivel.id,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    leading: Text(
                      '0${nivel.id}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    title: Text(
                      nivel.nombre,
                      key: ValueKey('tutorial-nivel-${nivel.id}'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onTap: () {
                      setState(() {
                        _sesion.seleccionar(nivel.id);
                        _resultado = 'Elegiste ${nivel.nombre.toLowerCase()}.';
                      });
                      ref
                          .read(respuestaInterfazProvider)
                          .emitir(sonidoNivel(nivel.id));
                    },
                  ),
                ),
              ),
          ],
        ),
      );
    }
    if (_paso == 5 || (_sesion.terminada && !_transicion)) {
      return DesplazamientoConFundido(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ResumenRonda(
              key: _cierre,
              compacto: true,
              partida: _sesion.cierreEjemplo,
              catalogo: _sesion.catalogo,
              mostrarAcciones: false,
              otraRonda: () {},
              elegirNivel: () {},
            ),
          ],
        ),
      );
    }
    return MesaCartas(
      mazo: MazoPreguntas(
        key: _mazo,
        cartas: _sesion.cartas,
        indice: _sesion.indice,
        nivel: nombreNivel(_sesion.nivel),
        coordinador: _motor,
        accionesPermitidas: _permitidas,
      ),
      controles: ControlesCarta(
        coordinador: _motor,
        claveAvanzar: _avanzar,
        claveGirar: _girar,
        clavePasar: _pasar,
        accionesVisibles: _accion == null ? {} : {_accion!},
        bloqueado: _pasoPendiente != null,
        destacar: _accion,
      ),
    );
  }
}

/// Explicación oscura con puntero. Ocupa su propia región y no tapa el objetivo.
class _GuiaTutorial extends StatelessWidget {
  const _GuiaTutorial({
    required this.paso,
    required this.resultado,
    required this.puntero,
    required this.lectura,
    required this.siguiente,
    required this.atras,
    required this.omitir,
  });
  final int paso;
  final String? resultado;
  final double puntero;
  final double lectura;
  final VoidCallback siguiente, atras, omitir;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
    child: CustomPaint(
      painter: _PunteroGuia(puntero),
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: DecoratedBox(
          key: const ValueKey('tutorial-burbuja'),
          decoration: BoxDecoration(
            color: TemaTriviaAntiguedad.tinta,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: TemaTriviaAntiguedad.tinta.withValues(alpha: .2),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      key: const ValueKey('tutorial-atras'),
                      tooltip: 'Paso anterior',
                      onPressed: paso > 0 ? atras : null,
                      icon: const Icon(
                        IconosTriviaAntiguedad.arrowLeft,
                        size: 22,
                      ),
                      color: Colors.white,
                      disabledColor: Colors.white38,
                    ),
                    Expanded(
                      child: Text(
                        '${paso + 1} de 6',
                        key: const ValueKey('tutorial-contador'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          key: const ValueKey('tutorial-omitir'),
                          onPressed: omitir,
                          child: const Text(
                            'Omitir',
                            style: TextStyle(fontSize: 12, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: EntradaInicio(
                    progreso: lectura,
                    enCurso: lectura < 1,
                    child: RevelarInicio(
                      child: _LecturaGuia(
                        key: ValueKey('explicacion-$paso'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _pasos[paso].$1,
                              style: const TextStyle(
                                fontSize: 23,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _pasos[paso].$2,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: Colors.white70,
                              ),
                            ),
                            SizedBox(
                              height:
                                  MediaQuery.textScalerOf(context).scale(13) *
                                      2.5 +
                                  8,
                              width: double.infinity,
                              child: SingleChildScrollView(
                                primary: false,
                                child: Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    resultado ?? '',
                                    key: const ValueKey('tutorial-resultado'),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.25,
                                      fontWeight: FontWeight.w600,
                                      color: TemaTriviaAntiguedad.salvia,
                                    ),
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
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('tutorial-siguiente'),
                    onPressed: siguiente,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      paso == 5 ? '¡A charlar!' : 'Siguiente',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
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
  );
}

class _LecturaGuia extends StatefulWidget {
  const _LecturaGuia({super.key, required this.child});
  final Widget child;
  @override
  State<_LecturaGuia> createState() => _LecturaGuiaState();
}

class _LecturaGuiaState extends State<_LecturaGuia> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: _scroll,
    thumbVisibility: true,
    child: SingleChildScrollView(
      controller: _scroll,
      padding: const EdgeInsets.only(right: 8),
      child: widget.child,
    ),
  );
}

class _PunteroGuia extends CustomPainter {
  const _PunteroGuia(this.posicion);
  final double posicion;
  @override
  void paint(Canvas canvas, Size size) {
    final x = (size.width * posicion).clamp(28.0, size.width - 28);
    canvas.drawPath(
      Path()
        ..moveTo(x, 0)
        ..lineTo(x - 11, 13)
        ..lineTo(x + 11, 13)
        ..close(),
      Paint()..color = TemaTriviaAntiguedad.tinta,
    );
  }

  @override
  bool shouldRepaint(_PunteroGuia anterior) => anterior.posicion != posicion;
}
