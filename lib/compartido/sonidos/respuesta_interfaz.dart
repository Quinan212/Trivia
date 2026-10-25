import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../funcionalidades/ajustes/controladores/controlador_experiencia.dart';

enum EfectoInterfaz {
  nivelSuave,
  nivelMedio,
  nivelProfundo,
  rondaCorta,
  rondaLarga,
  carta,
  deslizamiento,
  giro,
  pasar,
  bienvenida,
  comenzar,
  entradaInicio,
  cierre,
  iniciarRonda,
  retomarRonda,
  otraRonda,
  abrirConsignas,
  abrirTutorial,
  abrirLaboratorio,
  volverCarta,
  abrirAyuda,
  cerrarAyuda,
  volverInicio,
  tutorialSiguiente,
  tutorialAnterior,
  tutorialOmitir,
  tutorialCompletar,
  activarSonido,
  activarVibracion,
  desactivarVibracion,
  reintentar,
  evaluacionToque,
  evaluacionInicio,
  evaluacionTiempo,
  evaluacionPausa,
  evaluacionAgotado,
  evaluacionCorrecta,
  evaluacionIncorrecta,
  evaluacionSinRespuesta,
  evaluacionRobo,
  evaluacionCerrar,
  evaluacionDeshacer,
  evaluacionAprobado,
  evaluacionDiez,
  evaluacionFinal,
  evaluacionNavegar,
  evaluacionMenu,
  evaluacionExplicacion,
  evaluacionPasar,
}

EfectoInterfaz sonidoNivel(int nivel) => switch (nivel) {
  1 => EfectoInterfaz.nivelSuave,
  2 => EfectoInterfaz.nivelMedio,
  _ => EfectoInterfaz.nivelProfundo,
};

EfectoInterfaz sonidoRonda(int cantidad) =>
    cantidad == 12 ? EfectoInterfaz.rondaCorta : EfectoInterfaz.rondaLarga;

int cantidadVariantes(EfectoInterfaz efecto) => switch (efecto) {
  EfectoInterfaz.carta ||
  EfectoInterfaz.giro ||
  EfectoInterfaz.volverCarta ||
  EfectoInterfaz.pasar => 4,
  _ => 1,
};

String archivoSonido(EfectoInterfaz efecto, [int variante = 0]) =>
    'sonidos/${efecto.index >= EfectoInterfaz.evaluacionToque.index ? 'evaluacion/' : ''}${efecto.name}${variante == 0 ? '' : '_${variante + 1}'}.wav';

abstract interface class RespuestaInterfaz {
  void emitir(EfectoInterfaz efecto);
  void silenciar();
}

Future<void> prepararRespuesta(RespuestaInterfaz respuesta) =>
    respuesta is RespuestaSonora ? respuesta.preparar() : Future.value();

Future<void> prepararRespuestaApertura(RespuestaInterfaz respuesta) =>
    respuesta is RespuestaSonora
    ? respuesta.prepararApertura()
    : Future.value();

class RespuestaSilenciosa implements RespuestaInterfaz {
  const RespuestaSilenciosa();
  @override
  void emitir(EfectoInterfaz efecto) {}
  @override
  void silenciar() {}
}

/// Los controles de navegación y ajustes no añaden vibración.
bool vibracionDelEfecto(EfectoInterfaz efecto) => switch (efecto) {
  EfectoInterfaz.nivelSuave ||
  EfectoInterfaz.nivelMedio ||
  EfectoInterfaz.nivelProfundo ||
  EfectoInterfaz.rondaCorta ||
  EfectoInterfaz.rondaLarga ||
  EfectoInterfaz.carta ||
  EfectoInterfaz.giro ||
  EfectoInterfaz.volverCarta ||
  EfectoInterfaz.pasar ||
  EfectoInterfaz.cierre ||
  EfectoInterfaz.iniciarRonda ||
  EfectoInterfaz.otraRonda ||
  EfectoInterfaz.tutorialSiguiente ||
  EfectoInterfaz.tutorialAnterior => true,
  _ => false,
};

class RespuestaSonora with WidgetsBindingObserver implements RespuestaInterfaz {
  RespuestaSonora(this.habilitado, this.vibracion) {
    WidgetsBinding.instance.addObserver(this);
    _primerPlano =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }
  final bool Function() habilitado;
  final bool Function() vibracion;
  final _reproductores = <(EfectoInterfaz, int), AudioPlayer>{};
  final _preparaciones = <(EfectoInterfaz, int), Future<void>>{};
  final _turnos = <EfectoInterfaz, int>{};
  Future<void>? _preparacion;
  Future<void>? _apertura;
  Future<void> _cola = Future.value();
  bool _cerrado = false;
  int _generacion = 0;
  AudioPlayer? _activo;
  bool _primerPlano = true;
  Future<void> preparar() => _preparacion ??= _precargar();
  Future<void> prepararApertura() => _apertura ??= Future.wait(
    [
      EfectoInterfaz.bienvenida,
      EfectoInterfaz.comenzar,
      EfectoInterfaz.entradaInicio,
      EfectoInterfaz.activarSonido,
    ].map((efecto) => _prepararClave((efecto, 0))),
  );

  Future<void> _precargar() async {
    await prepararApertura();
    final claves = EfectoInterfaz.values
        .expand(
          (efecto) => List.generate(
            cantidadVariantes(efecto),
            (variante) => (efecto, variante),
          ),
        )
        .where((clave) => !_preparaciones.containsKey(clave))
        .toList();
    // Lotes pequeños: el resto del catálogo no bloquea ni satura la apertura.
    for (var inicio = 0; inicio < claves.length && !_cerrado; inicio += 4) {
      await Future.wait(claves.skip(inicio).take(4).map(_prepararClave));
    }
  }

  Future<void> _prepararClave((EfectoInterfaz, int) clave) {
    if (_cerrado) return Future.value();
    return _preparaciones.putIfAbsent(clave, () => _cargar(clave));
  }

  Future<void> _cargar((EfectoInterfaz, int) clave) async {
    final (efecto, variante) = clave;
    if (_cerrado) return;
    // Los efectos breves no necesitan consultar la posición en cada frame.
    // SoundPool no informa fin de reproducción: ese seguimiento quedaría vivo.
    final reproductor = AudioPlayer()..positionUpdater = null;
    _reproductores[clave] = reproductor;
    try {
      await reproductor.setPlayerMode(PlayerMode.lowLatency);
      await reproductor.setReleaseMode(ReleaseMode.stop);
      await reproductor.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            // Los efectos de la app siguen el volumen multimedia del usuario.
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );
      await reproductor.setVolume(
        efecto.index >= EfectoInterfaz.evaluacionToque.index
            ? .55
            : switch (efecto) {
                EfectoInterfaz.deslizamiento => .20,
                _ => .32,
              },
      );
      await reproductor.setSource(AssetSource(archivoSonido(efecto, variante)));
    } on Object catch (error) {
      debugPrint('No se pudo preparar ${efecto.name}: $error');
    }
  }

  @override
  void emitir(EfectoInterfaz efecto) {
    if (_cerrado || !_primerPlano) return;
    if (vibracion() && vibracionDelEfecto(efecto)) {
      unawaited(HapticFeedback.lightImpact().catchError((Object _) {}));
    }
    if (!habilitado()) return;
    final generacion = ++_generacion;
    _cola = _cola.then((_) async {
      try {
        final variante = (_turnos[efecto] ?? 0) % cantidadVariantes(efecto);
        await _prepararClave((efecto, variante));
        if (!_vigente(generacion)) return;
        final anterior = _activo;
        _activo = null;
        await anterior?.stop();
        if (!_vigente(generacion)) return;
        final siguiente = _reproductores[(efecto, variante)];
        _activo = siguiente;
        await siguiente?.resume();
        if (kDebugMode && siguiente != null && _vigente(generacion)) {
          debugPrint('AUDIO-TRIVIA-ANTIGUEDAD:${efecto.name}');
          if (cantidadVariantes(efecto) > 1) {
            debugPrint('AUDIO-VARIANTE:${efecto.name}:${variante + 1}');
          }
        }
        if (siguiente != null && _vigente(generacion)) {
          _turnos[efecto] = variante + 1;
        }
        if (!_vigente(generacion)) {
          await siguiente?.stop();
          if (identical(_activo, siguiente)) _activo = null;
        }
      } on Object catch (error) {
        debugPrint('No se pudo reproducir el efecto: $error');
      }
    });
  }

  @override
  void silenciar() {
    _generacion++;
    final reproductor = _activo;
    _activo = null;
    if (reproductor != null) {
      unawaited(reproductor.stop().catchError((Object _) {}));
    }
  }

  bool _vigente(int generacion) =>
      !_cerrado && _primerPlano && generacion == _generacion && habilitado();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _primerPlano = state == AppLifecycleState.resumed;
    if (!_primerPlano) silenciar();
  }

  Future<void> cerrar() async {
    _cerrado = true;
    WidgetsBinding.instance.removeObserver(this);
    _generacion++;
    await _preparacion;
    await Future.wait(_preparaciones.values);
    await _cola;
    await Future.wait(_reproductores.values.map((r) => r.dispose()));
  }
}

final respuestaInterfazProvider = Provider<RespuestaInterfaz>((ref) {
  final respuesta = RespuestaSonora(
    () => ref.read(experienciaProvider).value?.sonidos ?? false,
    () => ref.read(experienciaProvider).value?.vibracion ?? false,
  );
  ref.onDispose(() => unawaited(respuesta.cerrar()));
  return respuesta;
});
