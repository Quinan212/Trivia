import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/compartido/sonidos/respuesta_interfaz.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/sonidos_evaluacion.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/modelos.dart';

import 'motor_test.dart' show banco, muestra;

EfectoInterfaz? aplicar(MotorEvaluacion m, void Function() accion) {
  final antes = EstadoSonoroEvaluacion(m.sesion);
  accion();
  return EstadoSonoroEvaluacion(m.sesion).cambioDesde(antes);
}

void main() {
  test(
    '18 efectos originales breves, distintos, PCM16 mono y sin clipping',
    () {
      final nuevos = EfectoInterfaz.values
          .skip(EfectoInterfaz.evaluacionToque.index)
          .toList();
      expect(nuevos.length, 18);
      final contenidos = <String>{};
      var total = 0;
      for (final efecto in nuevos) {
        final bytes = File('assets/${archivoSonido(efecto)}').readAsBytesSync();
        final datos = ByteData.sublistView(bytes);
        expect(datos.getUint16(20, Endian.little), 1);
        expect(datos.getUint16(22, Endian.little), 1);
        expect(datos.getUint32(24, Endian.little), 22050);
        expect(datos.getUint16(34, Endian.little), 16);
        expect(bytes.length, lessThan(44144));
        expect(datos.getInt16(44, Endian.little).abs(), lessThan(5));
        expect(
          datos.getInt16(bytes.length - 2, Endian.little).abs(),
          lessThan(5),
        );
        for (var i = 44; i < bytes.length; i += 2) {
          expect(datos.getInt16(i, Endian.little).abs(), lessThan(20000));
        }
        contenidos.add(bytes.join(','));
        total += bytes.length;
      }
      expect(contenidos.length, nuevos.length);
      expect(total, lessThan(300000));
    },
  );

  test(
    'cada cambio produce su señal y un rechazo o pulso no produce sonido',
    () {
      final m = muestra(3);
      expect(aplicar(m, m.iniciar), EfectoInterfaz.evaluacionInicio);
      expect(aplicar(m, m.siguiente), EfectoInterfaz.evaluacionPasar);
      expect(aplicar(m, () => m.responder(0)), isNull);
      expect(aplicar(m, m.reanudar), EfectoInterfaz.evaluacionTiempo);
      expect(aplicar(m, () => m.transcurrir(200)), isNull);
      expect(aplicar(m, m.pausar), EfectoInterfaz.evaluacionPausa);
      expect(aplicar(m, m.reanudar), EfectoInterfaz.evaluacionTiempo);
      final correcta = m.sesion.actual!.indiceCorrecto(banco);
      expect(
        aplicar(m, () => m.responder((correcta + 1) % 4)),
        EfectoInterfaz.evaluacionIncorrecta,
      );
      expect(
        aplicar(m, () => m.iniciarRobo(m.sesion.habilitadosRobo.first.id)),
        EfectoInterfaz.evaluacionRobo,
      );
      expect(
        aplicar(m, () => m.responder(correcta)),
        EfectoInterfaz.evaluacionCorrecta,
      );
      expect(aplicar(m, m.deshacer), EfectoInterfaz.evaluacionDeshacer);
      expect(
        aplicar(m, m.cerrarPregunta),
        EfectoInterfaz.evaluacionSinRespuesta,
      );
      expect(aplicar(m, m.siguiente), EfectoInterfaz.evaluacionPasar);
      m.reanudar();
      expect(
        aplicar(m, () => m.transcurrir(60000)),
        EfectoInterfaz.evaluacionAgotado,
      );
      expect(aplicar(m, m.cerrarPregunta), EfectoInterfaz.evaluacionCerrar);
    },
  );

  test(
    'aprobación y diez sustituyen el acierto; confirmar no repite celebración',
    () {
      final m = muestra(1)..iniciar();
      for (var i = 1; i <= 10; i++) {
        m.siguiente();
        m.reanudar();
        final sonido = aplicar(
          m,
          () => m.responder(m.sesion.actual!.indiceCorrecto(banco)),
        );
        expect(
          sonido,
          i == 7
              ? EfectoInterfaz.evaluacionAprobado
              : i == 10
              ? EfectoInterfaz.evaluacionDiez
              : EfectoInterfaz.evaluacionCorrecta,
        );
        if (m.sesion.avisoPuntajeId != null) {
          expect(
            aplicar(m, () => m.resolverAvisoPuntaje(finalizar: false)),
            EfectoInterfaz.evaluacionToque,
          );
        }
      }
      expect(aplicar(m, m.siguiente), EfectoInterfaz.evaluacionFinal);
      expect(aplicar(m, m.siguiente), isNull);
    },
  );
}
