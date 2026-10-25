import 'dart:convert';

import 'package:flutter/services.dart';

import '../modelos/catalogo_preguntas.dart';
import '../modelos/pregunta.dart';

class RepositorioPreguntas {
  const RepositorioPreguntas({this.bundle});
  final AssetBundle? bundle;
  Future<CatalogoPreguntas> cargar() async {
    final raw = await (bundle ?? rootBundle).loadString(
      'assets/contenido/preguntas-base.json',
    );
    return decodificar(raw);
  }

  static CatalogoPreguntas decodificar(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return CatalogoPreguntas(
      version: json['version'] as String,
      textosAnteriores: {
        for (final entrada
            in (json['textosAnteriores'] as Map? ?? const {}).entries)
          entrada.key as String: Map<String, String>.from(entrada.value as Map),
      },
      cartas: [
        for (final item in json['preguntas'] as List)
          Pregunta.fromJson(Map<String, dynamic>.from(item as Map)),
        for (final item in json['consignas'] as List)
          Pregunta.fromJson(
            Map<String, dynamic>.from(item as Map),
            consigna: true,
          ),
      ],
    );
  }
}
