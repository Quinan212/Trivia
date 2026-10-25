import 'dart:async';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';

enum AccionCarta { avanzar, pasar, girar }

enum FaseCarta { reposo, pista, arrastre, retorno, salida, asentamiento, giro }

/// Estado visual transitorio. Ninguna posición o cara se guarda en la sesión.
class CoordinadorCarta extends ChangeNotifier {
  CoordinadorCarta({required TickerProvider vsync}) {
    _animacion = AnimationController.unbounded(vsync: vsync)
      ..addListener(_actualizar);
  }

  late final AnimationController _animacion;
  VoidCallback? alEstabilizar;
  ValueChanged<AccionCarta>? alConfirmar;
  bool Function(AccionCarta)? permitirAccion;
  FaseCarta fase = FaseCarta.reposo;
  bool reducido = false;
  bool reverso = false;
  bool _destinoReverso = false;
  bool hayRepregunta = false;
  bool hayCarta = true;
  AccionCarta? ultimaAccion;
  double ancho = 320;
  double desplazamiento = 0;
  double progreso = 0;
  double _desde = 0;
  int _generacion = 0;
  bool _cerrado = false;
  bool _pistaPausada = false;
  bool _arrastreDesdePista = false;
  double _movimientoReal = 0;
  double intensidadPista = 0;
  double _realceSalida = 0;
  double _realceRetorno = 0;
  double _distanciaRetorno = 0;
  double get _amplitudPista => (ancho * .05).clamp(0.0, 12.0);
  static const _resorte = SpringDescription(
    mass: 1,
    stiffness: 300,
    damping: 30,
  );

  bool get ocupado =>
      fase != FaseCarta.reposo &&
      fase != FaseCarta.arrastre &&
      fase != FaseCarta.pista;
  double get desplazamientoInicial => _desde;
  bool get caraReversa => fase == FaseCarta.giro
      ? (progreso < .5 ? reverso : _destinoReverso)
      : reverso;

  static bool confirmaArrastre(
    double distancia,
    double velocidad,
    double ancho,
  ) =>
      ancho > 0 &&
      (distancia / ancho <= -.28 ||
          (distancia / ancho <= -.12 && velocidad < -900));

  void comenzarArrastre() {
    final desdePista = fase == FaseCarta.pista;
    if (fase == FaseCarta.pista) _interrumpirPista();
    if (fase != FaseCarta.reposo || !hayCarta) return;
    _arrastreDesdePista = desdePista;
    _movimientoReal = 0;
    fase = FaseCarta.arrastre;
    notifyListeners();
  }

  void arrastrar(double delta) {
    if (fase != FaseCarta.arrastre) return;
    _movimientoReal += delta.abs();
    intensidadPista = (intensidadPista - delta.abs() / 80).clamp(0.0, 1.0);
    desplazamiento = (desplazamiento + delta).clamp(-ancho, ancho * .32);
    notifyListeners();
  }

  void soltar(double velocidad) {
    if (fase != FaseCarta.arrastre) return;
    if (_arrastreDesdePista && _movimientoReal == 0) {
      _volverSinGesto();
      return;
    }
    if (confirmaArrastre(desplazamiento, velocidad, ancho)) {
      ejecutar(AccionCarta.avanzar);
    } else {
      unawaited(_retornar(velocidad));
    }
  }

  void cancelarArrastre() {
    if (fase != FaseCarta.arrastre) return;
    if (_arrastreDesdePista && _movimientoReal == 0) {
      _volverSinGesto();
    } else {
      unawaited(_retornar(0));
    }
  }

  void _volverSinGesto() {
    // El reconocedor puede activarse al agregar/quitar un segundo dedo.
    // Sin desplazamiento del usuario, termina la pista sin simular un retorno.
    fase = FaseCarta.pista;
    _pistaPausada = false;
    notifyListeners();
    unawaited(_volverDePista(++_generacion));
  }

  /// Demostración visual sin confirmación ni cambios de carta. Comparte la
  /// transformación del arrastre y su resorte; el usuario puede tomar el control.
  bool mostrarPistaArrastre() {
    if (reducido || !hayCarta || ancho <= 0 || fase != FaseCarta.reposo) {
      return false;
    }
    final generacion = ++_generacion;
    fase = FaseCarta.pista;
    _pistaPausada = false;
    _animacion.value = desplazamiento / ancho;
    notifyListeners();
    unawaited(_pista(generacion));
    return true;
  }

  Future<void> _pista(int generacion) async {
    try {
      await _animacion
          .animateTo(
            -_amplitudPista / ancho,
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOutCubic,
          )
          .orCancel;
      if (_cerrado || generacion != _generacion) return;
      await _volverDePista(generacion);
    } on TickerCanceled {
      // Tomar la tarjeta conserva su posición actual, sin saltar a la base.
    }
  }

  void pausarPista() {
    if (fase != FaseCarta.pista || _pistaPausada) return;
    _generacion++;
    _animacion.stop();
    _pistaPausada = true;
  }

  void reanudarPista() {
    if (fase != FaseCarta.pista || !_pistaPausada) return;
    _pistaPausada = false;
    unawaited(_volverDePista(++_generacion));
  }

  Future<void> _volverDePista(int generacion) async {
    try {
      await _animacion
          .animateWith(
            _RetornoPista(
              SpringSimulation(
                _resorte,
                desplazamiento / ancho,
                0,
                0,
                tolerance: const Tolerance(distance: .001, velocity: .001),
              ),
            ),
          )
          .orCancel;
      if (_cerrado || generacion != _generacion) return;
      desplazamiento = 0;
      intensidadPista = 0;
      fase = FaseCarta.reposo;
      notifyListeners();
    } on TickerCanceled {
      // Navegar, salir o comenzar un gesto detiene esta demostración.
    }
  }

  void _interrumpirPista() {
    _generacion++;
    _animacion.stop();
    _pistaPausada = false;
    fase = FaseCarta.reposo;
  }

  Future<void> _retornar(double velocidad) async {
    final generacion = ++_generacion;
    _realceRetorno = intensidadPista;
    _distanciaRetorno = desplazamiento;
    fase = FaseCarta.retorno;
    notifyListeners();
    try {
      if (reducido) {
        desplazamiento = 0;
      } else {
        _animacion.value = desplazamiento / ancho;
        await _animacion
            .animateWith(
              SpringSimulation(
                _resorte,
                desplazamiento / ancho,
                0,
                velocidad / ancho,
                tolerance: const Tolerance(distance: .001, velocity: .001),
              ),
            )
            .orCancel;
      }
      if (_cerrado || generacion != _generacion) return;
      desplazamiento = 0;
      intensidadPista = 0;
      fase = FaseCarta.reposo;
      notifyListeners();
    } on TickerCanceled {
      // La pantalla recupera directamente el último estado confirmado.
    }
  }

  /// Admite una sola acción y comunica la confirmación antes de animarla.
  bool ejecutar(AccionCarta accion) {
    if (permitirAccion?.call(accion) == false) return false;
    if (!hayCarta || ocupado) return false;
    if (accion == AccionCarta.girar &&
        (fase == FaseCarta.arrastre || !hayRepregunta)) {
      return false;
    }
    if (fase == FaseCarta.pista) _interrumpirPista();
    final generacion = ++_generacion;
    _realceSalida = intensidadPista;
    _desde = desplazamiento;
    progreso = 0;
    _destinoReverso = !reverso;
    fase = accion == AccionCarta.girar ? FaseCarta.giro : FaseCarta.salida;
    ultimaAccion = accion;
    _animacion.value = 0;
    notifyListeners();
    alConfirmar?.call(accion);
    notifyListeners();
    unawaited(_ejecutar(accion, generacion));
    return true;
  }

  Future<void> _ejecutar(AccionCarta accion, int generacion) async {
    try {
      await _animacion
          .animateTo(
            1,
            duration: Duration(
              milliseconds: reducido
                  ? 100
                  : accion == AccionCarta.girar
                  ? 320
                  : 220,
            ),
            curve: Curves.easeInOutCubic,
          )
          .orCancel;
      if (_cerrado || generacion != _generacion) return;
      desplazamiento = 0;
      intensidadPista = 0;
      if (accion == AccionCarta.girar) {
        reverso = _destinoReverso;
      } else {
        reverso = false;
        fase = FaseCarta.asentamiento;
        progreso = 0;
        _animacion.value = 0;
        notifyListeners();
        if (!reducido && hayCarta) {
          await _animacion
              .animateTo(
                1,
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
              )
              .orCancel;
        }
      }
      if (_cerrado || generacion != _generacion) return;
      fase = FaseCarta.reposo;
      progreso = 0;
      notifyListeners();
      alEstabilizar?.call();
    } on TickerCanceled {
      // Cancelar no repite la confirmación ni revierte el dominio.
    }
  }

  void _actualizar() {
    if (fase == FaseCarta.retorno || fase == FaseCarta.pista) {
      desplazamiento = _animacion.value * ancho;
      intensidadPista = fase == FaseCarta.pista
          ? (-desplazamiento / _amplitudPista).clamp(0.0, 1.0)
          : _distanciaRetorno == 0
          ? 0
          : _realceRetorno *
                (desplazamiento / _distanciaRetorno).clamp(0.0, 1.0);
    } else {
      progreso = _animacion.value.clamp(0, 1);
      if (fase == FaseCarta.salida || fase == FaseCarta.giro) {
        intensidadPista = _realceSalida * (1 - progreso);
      }
      if (fase == FaseCarta.salida && !reducido) {
        desplazamiento = _desde + (-ancho - 100 - _desde) * progreso;
      }
    }
    if (!_cerrado) notifyListeners();
  }

  void estabilizar({bool mostrarReverso = false}) {
    if (_cerrado) return;
    _generacion++;
    _animacion.stop();
    _pistaPausada = false;
    fase = FaseCarta.reposo;
    reverso = mostrarReverso && hayCarta && hayRepregunta;
    desplazamiento = 0;
    intensidadPista = 0;
    progreso = 0;
    notifyListeners();
    alEstabilizar?.call();
  }

  @override
  void dispose() {
    _cerrado = true;
    _generacion++;
    _animacion.dispose();
    super.dispose();
  }
}

/// Conserva la forma del resorte habitual y le da tiempo para enseñar el retorno.
class _RetornoPista extends Simulation {
  _RetornoPista(this.resorte);
  final Simulation resorte;
  static const _escalaTiempo = 1.8;
  @override
  double x(double time) => resorte.x(time / _escalaTiempo);
  @override
  double dx(double time) => resorte.dx(time / _escalaTiempo) / _escalaTiempo;
  @override
  bool isDone(double time) => resorte.isDone(time / _escalaTiempo);
}
