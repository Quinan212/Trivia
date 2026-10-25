import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/acta_pdf.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/modelos.dart';

import 'motor_test.dart' show muestra, banco;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'genera una muestra del informe con tres aciertos y siete errores',
    () async {
      final motor = muestra(1)..iniciar();
      var numero = 0;
      while (!motor.sesion.finalizada) {
        motor.siguiente();
        if (motor.sesion.finalizada) break;
        motor.reanudar();
        final correcta = motor.sesion.actual!.indiceCorrecto(banco);
        motor.responder(numero++ < 3 ? correcta : (correcta + 1) % 4);
        if (motor.sesion.fase == FaseEvaluacion.esperaRobo)
          motor.cerrarPregunta();
      }
      final dir = Directory('qa/evaluacion/revision-informe')
        ..createSync(recursive: true);
      final datos = motor.sesion.toJson()..['id'] = 'IV_SIMULACION_REVISION';
      final sesion = SesionTrivia.fromJson(datos, banco);
      await File('${dir.path}/muestra.pdf').writeAsBytes(
        await GeneradorActa(await RecursosActa.cargar())
            .crear(sesion, banco, alumnoId: 'S0'),
      );
    },
  );
}
