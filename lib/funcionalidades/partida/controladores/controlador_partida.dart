import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartido/almacenamiento/proveedores_almacenamiento.dart';
import '../../../compartido/migraciones/migrador_preferencias.dart';
import '../../ajustes/datos/repositorio_ajustes.dart';
import '../../ajustes/modelos/ajustes_juego.dart';
import '../datos/repositorio_partida.dart';
import '../datos/repositorio_preguntas.dart';
import '../dominio/armador_rondas.dart';
import '../dominio/reloj_carta.dart';
import '../modelos/datos_juego.dart';

export '../../../compartido/almacenamiento/proveedores_almacenamiento.dart';

final preguntasProvider = Provider((ref) => const RepositorioPreguntas());
final partidaProvider = AsyncNotifierProvider<ControladorPartida, DatosJuego>(
  ControladorPartida.new,
);

class ControladorPartida extends AsyncNotifier<DatosJuego> {
  Future<void> _cola = Future.value();
  bool _midiendo = false;
  bool _dispuesto = false;
  Timer? _respaldoTiempo;
  RelojCarta get _reloj => ref.read(relojCartaProvider);
  RepositorioPartida get _partidas =>
      RepositorioPartida(ref.read(almacenProvider));
  RepositorioAjustes get _ajustes =>
      RepositorioAjustes(ref.read(almacenProvider));
  @override
  Future<DatosJuego> build() async {
    final reloj = _reloj;
    ref.onDispose(() {
      _dispuesto = true;
      _respaldoTiempo?.cancel();
      reloj.detener();
    });
    await MigradorPreferencias.ejecutar(ref.read(almacenProvider));
    final catalogo = await ref.read(preguntasProvider).cargar();
    final ajustes = await _ajustes.cargar();
    final carga = await _partidas.cargar(catalogo);
    return DatosJuego(
      catalogo: catalogo,
      ajustes: ajustes,
      partida: carga.partida,
      aviso: carga.recuperada
          ? 'Recuperamos la última copia de tu ronda.'
          : carga.invalida
          ? 'La ronda guardada no se pudo recuperar. Podés empezar otra.'
          : null,
    );
  }

  DatosJuego get _actual => state.requireValue;

  void iniciarMedicion() {
    if (_midiendo ||
        !state.hasValue ||
        _actual.partida == null ||
        _actual.partida!.terminada) {
      return;
    }
    _midiendo = true;
    _reloj.iniciar();
    // Limita la pérdida de tiempo ante un cierre abrupto, sin un contador visible.
    final intervalo = ref.read(intervaloRespaldoProvider);
    if (intervalo != null) {
      _respaldoTiempo = Timer.periodic(
        intervalo,
        (_) => unawaited(_guardarTiempo()),
      );
    }
  }

  Future<void> _guardarTiempo() {
    if (!state.hasValue || _actual.partida == null) return Future.value();
    final tiempo = _reloj.tomarMilisegundos();
    if (tiempo <= 0 || _actual.partida!.terminada) return Future.value();
    final actual = _actual;
    final partida = actual.partida!.registrarTiempo(tiempo);
    state = AsyncData(actual.copyWith(partida: partida));
    return _guardar(() => _partidas.guardar(partida, actual.catalogo));
  }

  Future<void> pausarMedicion() {
    if (_dispuesto) return Future.value();
    _midiendo = false;
    _respaldoTiempo?.cancel();
    _respaldoTiempo = null;
    _reloj.detener();
    return _guardarTiempo();
  }

  // Las escrituras en serie evitan que toques rápidos guarden un estado viejo
  // después del nuevo. Un fallo de almacenamiento deja la partida jugable.
  Future<void> _guardar(Future<void> Function() operacion) {
    _cola = _cola.then((_) async {
      try {
        await operacion();
      } on Object {
        if (!ref.mounted || !state.hasValue) return;
        state = AsyncData(
          _actual.copyWith(
            aviso:
                'La ronda sigue abierta, pero no pudimos guardar los cambios.',
          ),
        );
      }
    });
    return _cola;
  }

  Future<void> seleccionar({int? nivel, int? cantidad}) {
    final actuales = _actual.ajustes;
    final nuevos = AjustesJuego(
      nivel: nivel ?? actuales.nivel,
      cantidad: cantidad ?? actuales.cantidad,
    );
    if (nuevos.nivel < 1 ||
        nuevos.nivel > 3 ||
        ![12, 25].contains(nuevos.cantidad)) {
      throw ArgumentError('Selección inválida.');
    }
    state = AsyncData(_actual.copyWith(ajustes: nuevos));
    return _guardar(() => _ajustes.guardar(nuevos));
  }

  Future<void> empezar({bool nueva = false, bool consignas = false}) {
    final actual = _actual;
    if (!nueva && !consignas && actual.coincideSeleccion) return Future.value();
    final nivel = consignas ? 0 : actual.ajustes.nivel;
    final cantidad = consignas
        ? actual.catalogo.deNivel(0).length
        : actual.ajustes.cantidad;
    final ronda = actual.partida?.nivel == nivel
        ? actual.partida!.ronda + 1
        : 0;
    final partida = ArmadorRondas.crear(
      actual.catalogo,
      nivel: nivel,
      cantidad: cantidad,
      ronda: ronda,
    );
    _reloj.tomarMilisegundos();
    state = AsyncData(actual.copyWith(partida: partida));
    return _guardar(() => _partidas.guardar(partida, actual.catalogo));
  }

  Future<void> avanzar({bool pasar = false}) {
    final actual = _actual;
    final previa = actual.partida;
    if (previa == null || previa.terminada) return Future.value();
    final partida = previa.avanzar(
      pasar: pasar,
      milisegundos: _midiendo ? _reloj.tomarMilisegundos() : 0,
      textoCompartido: actual.catalogo.porId[previa.cartaActual]!.texto,
    );
    if (partida.terminada) {
      _midiendo = false;
      _reloj.detener();
      _respaldoTiempo?.cancel();
      _respaldoTiempo = null;
    }
    state = AsyncData(actual.copyWith(partida: partida));
    return _guardar(() => _partidas.guardar(partida, actual.catalogo));
  }

  Future<void> otraRonda() async {
    final previa = _actual.partida;
    if (previa == null) return;
    if (previa.nivel == 0) {
      await empezar(nueva: true, consignas: true);
      return;
    }
    await seleccionar(nivel: previa.nivel, cantidad: previa.cartas.length);
    await empezar(nueva: true);
  }

  void cerrarAviso() => state = AsyncData(_actual.copyWith(limpiarAviso: true));
  Future<void> reintentarGuardado() async {
    cerrarAviso();
    final actual = _actual;
    await _guardar(() async {
      await _ajustes.guardar(actual.ajustes);
      if (actual.partida != null) {
        await _partidas.guardar(actual.partida!, actual.catalogo);
      }
    });
  }
}
