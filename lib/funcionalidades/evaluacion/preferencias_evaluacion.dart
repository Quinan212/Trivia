import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../compartido/almacenamiento/proveedores_almacenamiento.dart';
import 'configuracion.dart';

final configuracionEvaluacionProvider =
    AsyncNotifierProvider<PreferenciasEvaluacion, ConfiguracionEvaluacion>(
      PreferenciasEvaluacion.new,
    );

class PreferenciasEvaluacion extends AsyncNotifier<ConfiguracionEvaluacion> {
  static const clave = 'evaluacion_configuracion_v1';
  @override
  Future<ConfiguracionEvaluacion> build() async {
    try {
      final raw = await ref.read(almacenProvider).leer(clave);
      if (raw == null) return const ConfiguracionEvaluacion();
      return ConfiguracionEvaluacion.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } on Object {
      return const ConfiguracionEvaluacion();
    }
  }

  void mostrar(ConfiguracionEvaluacion nueva) => state = AsyncData(nueva);
  Future<void> guardar(ConfiguracionEvaluacion nueva) async {
    await ref.read(almacenProvider).escribir(clave, jsonEncode(nueva.toJson()));
    state = AsyncData(nueva);
  }
}
