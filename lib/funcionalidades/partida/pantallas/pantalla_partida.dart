import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/componentes/fondo_conversacion.dart';
import '../../../compartido/componentes/hojas_conversacion.dart';
import '../../../compartido/movimiento/coordinador_carta.dart';
import '../../../compartido/movimiento/movimiento.dart';
import '../../../compartido/sonidos/respuesta_interfaz.dart';
import '../componentes/mazo_preguntas.dart';
import '../componentes/resumen_ronda.dart';
import '../controladores/controlador_partida.dart';
import '../modelos/catalogo_preguntas.dart';

class PantallaPartida extends ConsumerStatefulWidget {
  const PantallaPartida({super.key});
  @override
  ConsumerState<PantallaPartida> createState() => _PantallaPartidaState();
}

class _PantallaPartidaState extends ConsumerState<PantallaPartida>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  late final ControladorPartida _controlador;
  late final CoordinadorCarta _motor;
  PageRoute<dynamic>? _ruta;
  bool _visible = true;
  bool _primerPlano = true;
  bool _transicion = false;
  bool _ayudaAbierta = false;
  bool _cierreEmitido = false;
  bool _reiniciando = false;
  @override
  void initState() {
    super.initState();
    _controlador = ref.read(partidaProvider.notifier);
    _motor = CoordinadorCarta(vsync: this)
      ..alConfirmar = _confirmar
      ..alEstabilizar = _estable;
    _primerPlano =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  void _confirmar(AccionCarta accion) {
    if (accion != AccionCarta.girar) {
      _transicion = true;
      _pausar();
      // El índice cambia al confirmar; la escritura no marca la duración visual.
      unawaited(_controlador.avanzar(pasar: accion == AccionCarta.pasar));
    }
    ref.read(respuestaInterfazProvider).emitir(switch (accion) {
      AccionCarta.avanzar => EfectoInterfaz.carta,
      AccionCarta.pasar => EfectoInterfaz.pasar,
      AccionCarta.girar =>
        _motor.reverso ? EfectoInterfaz.volverCarta : EfectoInterfaz.giro,
    });
  }

  void _estable() {
    if (!mounted) return;
    setState(() => _transicion = false);
    final partida = ref.read(partidaProvider).value?.partida;
    if (partida?.terminada == true && !_cierreEmitido) {
      _cierreEmitido = true;
      if (_visible && _primerPlano) {
        ref.read(respuestaInterfazProvider).emitir(EfectoInterfaz.cierre);
      }
    } else {
      _activar();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ruta = ModalRoute.of(context);
    if (ruta is PageRoute && ruta != _ruta) {
      observadorPaginas.unsubscribe(this);
      _ruta = ruta;
      observadorPaginas.subscribe(this, ruta);
    }
  }

  void _activar() {
    if (_visible && _primerPlano && !_transicion && !_ayudaAbierta) {
      _controlador.iniciarMedicion();
    }
  }

  void _pausar() => unawaited(_controlador.pausarMedicion());
  void _suspender() {
    _pausar();
    _motor.estabilizar();
    ref.read(respuestaInterfazProvider).silenciar();
  }

  void _volver() {
    if (_motor.fase == FaseCarta.giro) {
      _motor.estabilizar();
      return;
    }
    if (_motor.reverso && !_motor.ocupado) {
      _motor.ejecutar(AccionCarta.girar);
      return;
    }
    _visible = false;
    _suspender();
    Navigator.pop(context);
  }

  Future<void> _ayuda() async {
    _ayudaAbierta = true;
    _pausar();
    await mostrarReglas(context);
    _ayudaAbierta = false;
    if (mounted) _activar();
  }

  Future<void> _otraRonda() async {
    if (_reiniciando ||
        ref.read(partidaProvider).value?.partida?.terminada != true) {
      return;
    }
    _reiniciando = true;
    _cierreEmitido = false;
    try {
      await _controlador.otraRonda();
      if (mounted && _visible && _primerPlano) {
        ref.read(respuestaInterfazProvider).emitir(EfectoInterfaz.otraRonda);
      }
    } finally {
      _reiniciando = false;
    }
  }

  @override
  void didPush() {
    _visible = true;
    _activar();
  }

  @override
  void didPopNext() {
    _visible = true;
    _activar();
  }

  @override
  void didPushNext() {
    _visible = false;
    _suspender();
  }

  @override
  void didPop() {
    _visible = false;
    _pausar();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    _primerPlano = estado == AppLifecycleState.resumed;
    if (_primerPlano) {
      _activar();
    } else {
      _suspender();
    }
  }

  @override
  void dispose() {
    _visible = false;
    observadorPaginas.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _motor.dispose();
    _pausar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(partidaProvider, (previa, nueva) {
      if (nueva.value?.partida?.terminada == false) _activar();
    });
    final datos = ref.watch(partidaProvider).value;
    final partida = datos?.partida;
    _motor.hayCarta = partida != null && !partida.terminada;
    _motor.hayRepregunta =
        _motor.hayCarta &&
        datos!.catalogo.porId[partida!.cartaActual]?.repregunta != null;
    _motor.reducido = MediaQuery.disableAnimationsOf(context);
    return ListenableBuilder(
      listenable: _motor,
      builder: (context, _) => PopScope(
        canPop: !_motor.reverso && _motor.fase != FaseCarta.giro,
        onPopInvokedWithResult: (salio, _) {
          if (!salio) {
            _volver();
          } else {
            _suspender();
            ref
                .read(respuestaInterfazProvider)
                .emitir(EfectoInterfaz.volverInicio);
          }
        },
        child: FondoConversacion(
          pieSeparado: true,
          volver: _volver,
          child: datos == null || partida == null
              ? const Center(child: CircularProgressIndicator())
              : partida.terminada && !_transicion
              ? CuerpoDesplazable(
                  arriba: 32,
                  child: ResumenRonda(
                    partida: partida,
                    catalogo: datos.catalogo,
                    otraRonda: () => unawaited(_otraRonda()),
                    elegirNivel: _volver,
                  ),
                )
              : MesaCartas(
                  mazo: MazoPreguntas(
                    cartas: [
                      for (final id in partida.cartas)
                        datos.catalogo.porId[id]!,
                    ],
                    indice: partida.indice,
                    nivel: nombreNivel(partida.nivel),
                    coordinador: _motor,
                  ),
                  controles: ControlesCarta(
                    coordinador: _motor,
                    ayuda: () => unawaited(_ayuda()),
                  ),
                ),
        ),
      ),
    );
  }
}
