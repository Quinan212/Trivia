import 'pregunta.dart';

class NivelConversacion {
  const NivelConversacion(this.id, this.nombre, this.descripcion);
  final int id;
  final String nombre;
  final String descripcion;
}

const nivelesConversacion = [
  NivelConversacion(
    1,
    'Para arrancar',
    'Costumbres, gustos y papelones chicos.',
  ),
  NivelConversacion(2, 'Se pone bueno', 'Amistad, plata y tu manera de ser.'),
  NivelConversacion(
    3,
    'En confianza',
    'Lealtad, cariño y lo que cuesta decir.',
  ),
];
String nombreNivel(int nivel) => nivel == 0
    ? 'Hagamos algo'
    : nivelesConversacion.firstWhere((item) => item.id == nivel).nombre;

class CatalogoPreguntas {
  CatalogoPreguntas({
    required this.version,
    required List<Pregunta> cartas,
    Map<String, Map<String, String>> textosAnteriores = const {},
  }) : cartas = List.unmodifiable(cartas),
       porId = Map.unmodifiable({for (final carta in cartas) carta.id: carta}),
       textosAnteriores = Map.unmodifiable({
         for (final entrada in textosAnteriores.entries)
           entrada.key: Map<String, String>.unmodifiable(entrada.value),
       }) {
    if (version.isEmpty || porId.length != cartas.length) {
      throw const FormatException('Catálogo inválido o IDs repetidos.');
    }
    for (var nivel = 0; nivel <= 3; nivel++) {
      if (deNivel(nivel).isEmpty) {
        throw const FormatException('Faltan cartas en un nivel.');
      }
    }
    for (final edicion in this.textosAnteriores.entries) {
      if (edicion.key.isEmpty ||
          edicion.key == version ||
          edicion.value.isEmpty ||
          edicion.value.entries.any(
            (texto) =>
                !porId.containsKey(texto.key) || texto.value.trim().isEmpty,
          )) {
        throw const FormatException('Edición anterior incompatible.');
      }
    }
  }
  final String version;
  final List<Pregunta> cartas;
  final Map<String, Pregunta> porId;
  final Map<String, Map<String, String>> textosAnteriores;
  List<Pregunta> deNivel(int nivel) =>
      cartas.where((carta) => carta.nivel == nivel).toList(growable: false);
}
