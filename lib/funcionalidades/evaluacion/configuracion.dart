enum ColorEvaluacion { rojo, verde, azul, amarillo, naranja }

class ConfiguracionEvaluacion {
  const ConfiguracionEvaluacion({
    this.materia = 'Procesos sociales, políticos, económicos y culturales de la Antigüedad',
    this.nombreCorto = 'Antigüedad',
    this.tema = 'Unidad IV',
    this.docente = 'Javier Patricio Borche',
    this.ayudante = '',
    this.comision = '1B · 2026',
    this.color = ColorEvaluacion.rojo,
  });

  final String materia, nombreCorto, tema, docente, ayudante, comision;
  final ColorEvaluacion color;
  String get titulo => '$nombreCorto - $tema';
  Map<String, dynamic> toJson() => {
    'materia': materia,
    'nombreCorto': nombreCorto,
    'tema': tema,
    'docente': docente,
    'ayudante': ayudante,
    'comision': comision,
    'color': color.name,
  };

  factory ConfiguracionEvaluacion.fromJson(Map<String, dynamic> j) {
    String campo(String clave, int maximo, {bool opcional = false}) {
      final valor = opcional && !j.containsKey(clave) ? '' : j[clave];
      if (valor is! String) {
        throw const FormatException('Configuración inválida.');
      }
      final limpio = valor.trim().replaceAll(RegExp(r'\s+'), ' ');
      if ((!opcional && limpio.isEmpty) || limpio.length > maximo) {
        throw const FormatException('Revisá los nombres de la configuración.');
      }
      return limpio;
    }

    return ConfiguracionEvaluacion(
      materia: campo('materia', 180),
      nombreCorto: campo('nombreCorto', 60),
      tema: campo('tema', 80),
      docente: campo('docente', 120),
      ayudante: campo('ayudante', 120, opcional: true),
      comision: campo('comision', 40),
      color: ColorEvaluacion.values.firstWhere(
        (v) => v.name == j['color'],
        orElse: () => throw const FormatException('Paleta inválida.'),
      ),
    );
  }
}
