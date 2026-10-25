import 'dart:convert';

import '../../../compartido/almacenamiento/almacen_preferencias.dart';
import '../modelos/ajustes_juego.dart';

class RepositorioAjustes {
  const RepositorioAjustes(this.almacen);
  static const clave = 'trivia_antiguedad_ajustes_v1';
  final AlmacenPreferencias almacen;
  Future<AjustesJuego> cargar() async {
    final raw = await almacen.leer(clave);
    if (raw == null) return const AjustesJuego();
    try {
      return AjustesJuego.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return const AjustesJuego();
    }
  }

  Future<void> guardar(AjustesJuego ajustes) =>
      almacen.escribir(clave, jsonEncode(ajustes.toJson()));
}
