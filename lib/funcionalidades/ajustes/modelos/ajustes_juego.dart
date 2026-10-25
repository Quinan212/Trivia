class AjustesJuego {
  const AjustesJuego({this.nivel = 2, this.cantidad = 12});
  final int nivel;
  final int cantidad;
  factory AjustesJuego.fromJson(Map<String, dynamic> json) {
    final nivel = json['nivel'];
    final cantidad = json['cantidad'];
    if (json['version'] != 1 ||
        nivel is! int ||
        nivel < 1 ||
        nivel > 3 ||
        (cantidad != 12 && cantidad != 25)) {
      throw const FormatException('Ajustes inválidos.');
    }
    return AjustesJuego(nivel: nivel, cantidad: cantidad as int);
  }
  Map<String, dynamic> toJson() => {
    'version': 1,
    'nivel': nivel,
    'cantidad': cantidad,
  };
}
