import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_antiguedad/funcionalidades/evaluacion/configuracion.dart';
import 'package:trivia_antiguedad/tema/paleta_evaluacion.dart';
import 'package:trivia_antiguedad/tema/tema_evaluacion.dart';

void main() {
  test('interpola roles reales y conserva neutros al retomar desde un color intermedio', () {
    const roja = PaletaEvaluacion(ColorEvaluacion.rojo),
        azul = PaletaEvaluacion(ColorEvaluacion.azul),
        verde = PaletaEvaluacion(ColorEvaluacion.verde);
    final mitad = roja.lerp(azul, .5);
    expect(mitad.naranja, Color.lerp(roja.naranja, azul.naranja, .5));
    expect(
      mitad.salviaClara,
      Color.lerp(roja.salviaClara, azul.salviaClara, .5),
    );
    expect(mitad.borde, Color.lerp(roja.borde, azul.borde, .5));
    expect(mitad.fondo, roja.fondo);
    expect(mitad.error, roja.error);
    final nueva = mitad.lerp(verde, .25);
    expect(nueva.naranja, Color.lerp(mitad.naranja, verde.naranja, .25));
    expect(mitad.lerp(verde, 0), mitad);
    expect(mitad.lerp(verde, 1), verde);
  });
  testWidgets(
    'la pantalla cambia gradualmente y un segundo color continúa desde el visible',
    (tester) async {
      final seleccion = ValueNotifier(ColorEvaluacion.rojo);
      addTearDown(seleccion.dispose);
      const clave = ValueKey('superficie-color');
      await tester.pumpWidget(
        ValueListenableBuilder(
          valueListenable: seleccion,
          builder: (context, tipo, _) => MaterialApp(
            theme: temaEvaluacion(PaletaEvaluacion(tipo)),
            themeAnimationDuration: duracionCambioPaleta,
            themeAnimationCurve: curvaCambioPaleta,
            home: Builder(
              builder: (context) => ColoredBox(
                key: clave,
                color: PaletaEvaluacion.of(context).salviaClara,
              ),
            ),
          ),
        ),
      );
      Color visible() => tester.widget<ColoredBox>(find.byKey(clave)).color;
      final inicial = visible();
      seleccion.value = ColorEvaluacion.azul;
      await tester.pump();
      expect(visible(), inicial);
      await tester.pump(const Duration(milliseconds: 250));
      final intermedio = visible();
      expect(intermedio, isNot(inicial));
      expect(
        intermedio,
        isNot(const PaletaEvaluacion(ColorEvaluacion.azul).salviaClara),
      );
      seleccion.value = ColorEvaluacion.verde;
      await tester.pump();
      expect(visible(), intermedio);
      await tester.pump(const Duration(milliseconds: 100));
      expect(visible(), isNot(intermedio));
      await tester.pumpAndSettle();
      expect(
        visible(),
        const PaletaEvaluacion(ColorEvaluacion.verde).salviaClara,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
