import 'dart:convert';

import '../../../compartido/almacenamiento/almacen_preferencias.dart';
import '../modelos/catalogo_preguntas.dart';
import '../modelos/estado_partida.dart';

class CargaPartida {
  const CargaPartida(
    this.partida, {
    this.recuperada = false,
    this.invalida = false,
  });
  final EstadoPartida? partida;
  final bool recuperada;
  final bool invalida;
}

class RepositorioPartida {
  const RepositorioPartida(this.almacen);
  static const clave = 'trivia_antiguedad_partida_v1';
  static const claveRespaldo = 'trivia_antiguedad_partida_respaldo_v1';
  final AlmacenPreferencias almacen;
  EstadoPartida? _leerRegistro(String? raw, CatalogoPreguntas catalogo) {
    if (raw == null) return null;
    try {
      return EstadoPartida.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
        catalogo,
      );
    } on Object {
      return null;
    }
  }

  Future<CargaPartida> cargar(CatalogoPreguntas catalogo) async {
    final raw = await almacen.leer(clave);
    final actual = _leerRegistro(raw, catalogo);
    if (actual != null) return CargaPartida(actual);
    final respaldoRaw = await almacen.leer(claveRespaldo);
    final respaldo = _leerRegistro(respaldoRaw, catalogo);
    return CargaPartida(
      respaldo,
      recuperada: respaldo != null,
      invalida: respaldo == null && (raw != null || respaldoRaw != null),
    );
  }

  /// Conserva un registro previo válido. No constituye una transacción.
  Future<void> guardar(
    EstadoPartida partida,
    CatalogoPreguntas catalogo,
  ) async {
    final anterior = await almacen.leer(clave);
    if (_leerRegistro(anterior, catalogo) != null) {
      await almacen.escribir(claveRespaldo, anterior!);
    }
    await almacen.escribir(clave, jsonEncode(partida.toJson()));
  }
}
