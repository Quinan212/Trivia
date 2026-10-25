import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/acta_pdf.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/modelos.dart';

import 'motor_test.dart' show banco, muestra;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'informe individual conserva siete preguntas realizadas al finalizar',
    () async {
      final m = muestra(1)..iniciar();
      for (var i = 0; i < 7; i++) {
        m.siguiente();
        m.reanudar();
        m.responder(m.sesion.actual!.indiceCorrecto(banco));
      }
      m.resolverAvisoPuntaje(finalizar: true);
      m.siguiente();
      final g = GeneradorActa(await RecursosActa.cargar());
      final carpeta = Directory('qa/evaluacion/pdf/nuevas-reglas')
        ..createSync(recursive: true);
      await File('${carpeta.path}/siete-preguntas.pdf')
          .writeAsBytes(await g.crear(m.sesion, banco, alumnoId: 'S0'));

      // Un registro histórico mixto comprueba el valor real del último robo.
      final otro = muestra(2)..iniciar();
      var fecha = DateTime.utc(2026, 10, 23);
      for (final r
          in otro.sesion.registros.values
              .where((r) => r.titularId == 'S1')
              .take(5)) {
        r.estado = EstadoPregunta.cerrada;
        r.propio = IntentoTrivia(
          alumnoId: 'S1',
          opcion: (r.indiceCorrecto(banco) + 1) % 4,
          estado: EstadoIntento.respondido,
          correcto: false,
          tiempoMs: 1000,
          fecha: fecha,
        );
        r.robos.add(
          IntentoTrivia(
            alumnoId: 'S0',
            opcion: r.indiceCorrecto(banco),
            estado: EstadoIntento.respondido,
            correcto: true,
            puntos: 2,
            tiempoMs: 0,
            fecha: fecha,
          ),
        );
        fecha = fecha.add(const Duration(seconds: 1));
      }
      // Guardar el ajuste de nueve a diez en el último acierto.
      final ultimo = otro.sesion.registros.values
          .where((r) => r.robos.isNotEmpty)
          .last;
      ultimo.robos[0] = IntentoTrivia(
        alumnoId: 'S0',
        opcion: ultimo.indiceCorrecto(banco),
        estado: EstadoIntento.respondido,
        correcto: true,
        puntos: 1,
        tiempoMs: 0,
        fecha: fecha,
      );
      final propio = otro.sesion.registros.values.firstWhere(
        (r) => r.titularId == 'S0',
      );
      propio.estado = EstadoPregunta.cerrada;
      propio.propio = IntentoTrivia(
        alumnoId: 'S0',
        opcion: propio.indiceCorrecto(banco),
        estado: EstadoIntento.respondido,
        correcto: true,
        puntos: 1,
        tiempoMs: 1000,
        fecha: fecha.subtract(const Duration(minutes: 1)),
      );
      otro.sesion.finalizados.add('S0');
      otro.finalizar();
      expect(otro.sesion.resultado('S0').puntos, 10);
      await File('${carpeta.path}/diez-puntos-robo.pdf')
          .writeAsBytes(await g.crear(otro.sesion, banco, alumnoId: 'S0'));
    },
  );
}
