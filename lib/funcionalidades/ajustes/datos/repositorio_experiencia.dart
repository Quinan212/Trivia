import 'dart:convert';

import '../../../compartido/almacenamiento/almacen_preferencias.dart';
import '../modelos/ajustes_experiencia.dart';

class RepositorioExperiencia {
  const RepositorioExperiencia(this.almacen);
  static const clave = 'trivia_antiguedad_experiencia_v1';
  final AlmacenPreferencias almacen;
  Future<AjustesExperiencia> cargar() async {
    final raw = await almacen.leer(clave);
    if (raw == null) return const AjustesExperiencia();
    try {
      return AjustesExperiencia.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } on Object {
      return const AjustesExperiencia();
    }
  }

  Future<void> guardar(AjustesExperiencia ajustes) =>
      almacen.escribir(clave, jsonEncode(ajustes.toJson()));
}
