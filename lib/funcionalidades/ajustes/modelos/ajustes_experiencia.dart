class AjustesExperiencia {
  const AjustesExperiencia({
    this.tutorialVisto = false,
    this.sonidos = true,
    this.vibracion = true,
    this.aviso,
  });
  final bool tutorialVisto;
  final bool sonidos;
  final bool vibracion;
  final String? aviso;

  AjustesExperiencia copyWith({
    bool? tutorialVisto,
    bool? sonidos,
    bool? vibracion,
    String? aviso,
    bool limpiarAviso = false,
  }) => AjustesExperiencia(
    tutorialVisto: tutorialVisto ?? this.tutorialVisto,
    sonidos: sonidos ?? this.sonidos,
    vibracion: vibracion ?? this.vibracion,
    aviso: limpiarAviso ? null : aviso ?? this.aviso,
  );

  Map<String, dynamic> toJson() => {
    'version': 2,
    'tutorialVisto': tutorialVisto,
    'sonidos': sonidos,
    'vibracion': vibracion,
  };
  factory AjustesExperiencia.fromJson(Map<String, dynamic> json) {
    if (![1, 2].contains(json['version']) ||
        json['tutorialVisto'] is! bool ||
        json['sonidos'] is! bool ||
        (json['version'] == 2 && json['vibracion'] is! bool)) {
      throw const FormatException('Preferencias de bienvenida inválidas.');
    }
    return AjustesExperiencia(
      tutorialVisto: json['tutorialVisto'] as bool,
      sonidos: json['sonidos'] as bool,
      vibracion: json['version'] == 1 ? true : json['vibracion'] as bool,
    );
  }
}
