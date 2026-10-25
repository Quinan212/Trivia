class Pregunta {
  const Pregunta({
    required this.id,
    required this.nivel,
    required this.tema,
    required this.texto,
    this.repregunta,
  });
  final String id;
  final int nivel;
  final String tema;
  final String texto;
  final String? repregunta;
  factory Pregunta.fromJson(
    Map<String, dynamic> json, {
    bool consigna = false,
  }) {
    final pregunta = Pregunta(
      id: json['id'] as String,
      nivel: consigna ? 0 : json['nivel'] as int,
      tema: consigna ? 'Hagamos algo' : json['tema'] as String,
      texto: json[consigna ? 'consigna' : 'pregunta'] as String,
      repregunta: consigna ? null : json['repregunta'] as String?,
    );
    if (pregunta.id.isEmpty ||
        pregunta.texto.trim().isEmpty ||
        pregunta.nivel < 0 ||
        pregunta.nivel > 3) {
      throw const FormatException('Carta inválida.');
    }
    return pregunta;
  }
}
