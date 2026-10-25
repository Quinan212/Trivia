import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/componentes/fondo_conversacion.dart';
import '../../../compartido/movimiento/coordinador_carta.dart';
import '../../../compartido/sonidos/respuesta_interfaz.dart';
import '../../partida/componentes/mazo_preguntas.dart';
import '../../partida/componentes/resumen_ronda.dart';
import '../modelos/sesion_demostracion.dart';

class PantallaExperimentos extends ConsumerStatefulWidget {
  const PantallaExperimentos({super.key});
  @override
  ConsumerState<PantallaExperimentos> createState() =>
      _PantallaExperimentosState();
}

class _PantallaExperimentosState extends ConsumerState<PantallaExperimentos>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _sesion = SesionDemostracion();
  late final _motor = CoordinadorCarta(vsync: this)
    ..alConfirmar = _confirmar
    ..alEstabilizar = _estable;
  bool _transicion = false;
  bool _cierreEmitido = false;
  bool _primerPlano = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _confirmar(AccionCarta accion) {
    _transicion = accion != AccionCarta.girar;
    _sesion.confirmar(accion);
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
    if (_sesion.terminada && !_cierreEmitido && _primerPlano) {
      _cierreEmitido = true;
      ref.read(respuestaInterfazProvider).emitir(EfectoInterfaz.cierre);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    _primerPlano = estado == AppLifecycleState.resumed;
    if (estado != AppLifecycleState.resumed) _motor.estabilizar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motor.dispose();
    _sesion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _motor.hayCarta = !_sesion.terminada;
    _motor.hayRepregunta =
        !_sesion.terminada && _sesion.cartas[_sesion.indice].repregunta != null;
    _motor.reducido = MediaQuery.disableAnimationsOf(context);
    return PopScope(
      onPopInvokedWithResult: (salio, _) {
        if (salio) {
          ref
              .read(respuestaInterfazProvider)
              .emitir(EfectoInterfaz.volverInicio);
        }
      },
      child: FondoConversacion(
        pieSeparado: true,
        volver: () => Navigator.pop(context),
        child: _sesion.terminada && !_transicion
            ? CuerpoDesplazable(
                child: ResumenRonda(
                  partida: _sesion.cierreEjemplo,
                  catalogo: _sesion.catalogo,
                  otraRonda: () {
                    setState(() {
                      _cierreEmitido = false;
                      _sesion.reiniciar();
                    });
                    ref
                        .read(respuestaInterfazProvider)
                        .emitir(EfectoInterfaz.otraRonda);
                  },
                  elegirNivel: () => Navigator.pop(context),
                ),
              )
            : MesaCartas(
                mazo: MazoPreguntas(
                  cartas: _sesion.cartas,
                  indice: _sesion.indice,
                  nivel: 'Ejemplo aislado',
                  coordinador: _motor,
                ),
                controles: ControlesCarta(coordinador: _motor),
              ),
      ),
    );
  }
}
