import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../funcionalidades/ajustes/controladores/controlador_experiencia.dart';

import '../../tema/iconos_trivia_antiguedad.dart';

import '../../tema/tema_trivia_antiguedad.dart';
import 'boton_principal.dart';
import '../movimiento/movimiento.dart';
import '../sonidos/respuesta_interfaz.dart';
import '../../funcionalidades/bienvenida/pantallas/pantalla_tutorial.dart';

Future<void> mostrarReglas(BuildContext context) async {
  final respuesta = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(respuestaInterfazProvider);
  respuesta.emitir(EfectoInterfaz.abrirAyuda);
  final tutorial = await _mostrarHoja(
    context,
    titulo: 'Así se juega',
    descripcion: 'La idea es escucharse y pasarla bien.',
    cuerpo: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Regla(
          '1',
          'Elijan un nivel.',
          'Pueden arrancar tranqui o charlar más en confianza.',
        ),
        _Regla(
          '2',
          'Lean la carta en voz alta.',
          'Hay preguntas, historias, elecciones y juegos breves. Quien tiene la carta empieza; los demás pueden seguir. Vayan cambiando quién arranca.',
        ),
        _Regla(
          '3',
          'Si pinta, sigan.',
          '«Una más» gira la carta y propone cómo seguir. Deslizá a la izquierda o tocá «Otra carta» para cambiar de tema.',
        ),
        _Regla(
          '4',
          'Pasar está bien.',
          'No hace falta dar nombres ni mostrar mensajes. Si una carta no te pinta, pasala sin explicar por qué.',
        ),
        _PreferenciasExperiencia(),
        _AccesoPrivacidad(),
      ],
    ),
    boton: 'Dale, entendido',
    tutorial: true,
  );
  if (tutorial == true && context.mounted) {
    await mostrarTutorial(context);
  } else if (context.mounted) {
    respuesta.emitir(EfectoInterfaz.cerrarAyuda);
  }
}

class _AccesoPrivacidad extends StatelessWidget {
  const _AccesoPrivacidad();

  @override
  Widget build(BuildContext context) => TextButton(
    key: const ValueKey('privacidad-desde-ayuda'),
    onPressed: () => mostrarPrivacidad(context),
    child: const Text('Datos y privacidad'),
  );
}

Future<void> mostrarPrivacidad(BuildContext context) async {
  final respuesta = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(respuestaInterfazProvider);
  respuesta.emitir(EfectoInterfaz.abrirAyuda);
  await _mostrarHoja(
    context,
    titulo: 'Datos y privacidad',
    descripcion: 'Podés consultar esta política sin conexión.',
    cuerpo: const _PoliticaLocal(),
    boton: 'Volver',
  );
}

class _PoliticaLocal extends StatefulWidget {
  const _PoliticaLocal();

  @override
  State<_PoliticaLocal> createState() => _PoliticaLocalState();
}

class _PoliticaLocalState extends State<_PoliticaLocal> {
  late final Future<String> _texto = rootBundle.loadString(
    'assets/contenido/politica-privacidad.txt',
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: _texto,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text(
            'No pudimos abrir la política. Cerrá y volvé a intentarlo.',
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      final bloques = snapshot.data!
          .replaceAll('\r\n', '\n')
          .replaceAllMapped(RegExp(r'(## [^\n]+)\n'), (m) => '${m[1]}\n\n')
          .split('\n\n')
          .where(
            (bloque) => bloque.trim().isNotEmpty && !bloque.startsWith('# '),
          );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final bloque in bloques)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SelectableText(
                bloque.replaceAll('## ', '').replaceAll('**', '').trim(),
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: TemaTriviaAntiguedad.tinta,
                  fontWeight: bloque.startsWith('## ')
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
            ),
        ],
      );
    },
  );
}

Future<void> mostrarRepregunta(BuildContext context, String pregunta) =>
    _mostrarHoja(
      context,
      titulo: 'Nos quedamos un ratito más',
      descripcion: 'Otra entrada para seguir con esta carta.',
      cuerpo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            pregunta,
            key: const ValueKey('repregunta'),
            style: const TextStyle(
              fontSize: 33,
              fontWeight: FontWeight.w700,
              height: 1.18,
              color: TemaTriviaAntiguedad.tinta,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No hace falta tener la respuesta perfecta.',
            style: TextStyle(color: TemaTriviaAntiguedad.tenue),
          ),
          const SizedBox(height: 28),
        ],
      ),
      boton: 'Volver a la carta',
    );

Future<bool?> _mostrarHoja(
  BuildContext context, {
  required String titulo,
  required String descripcion,
  required Widget cuerpo,
  required String boton,
  bool tutorial = false,
}) async {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    sheetAnimationStyle: AnimationStyle(
      duration: duracionMovimiento(context, 360),
      reverseDuration: duracionMovimiento(context, 220),
    ),
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          26,
          0,
          26,
          MediaQuery.paddingOf(context).bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      color: TemaTriviaAntiguedad.tinta,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(IconosTriviaAntiguedad.x, size: 23),
                ),
              ],
            ),
            Text(
              descripcion,
              style: const TextStyle(
                fontSize: 14,
                color: TemaTriviaAntiguedad.tenue,
              ),
            ),
            const SizedBox(height: 20),
            EntradaSuave(child: cuerpo),
            BotonPrincipal(
              texto: boton,
              tamano: 21,
              onPressed: () => Navigator.pop(context),
            ),
            if (tutorial)
              Center(
                child: TextButton(
                  key: const ValueKey('tutorial-desde-ayuda'),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Ver tutorial'),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _Regla extends StatelessWidget {
  const _Regla(this.numero, this.titulo, this.texto);
  final String numero;
  final String titulo;
  final String texto;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$numero.', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                texto,
                style: const TextStyle(
                  fontSize: 14,
                  color: TemaTriviaAntiguedad.tenue,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PreferenciasExperiencia extends ConsumerWidget {
  const _PreferenciasExperiencia();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ajustes = ref.watch(experienciaProvider).value;
    if (ajustes == null) return const SizedBox.shrink();
    final controlador = ref.read(experienciaProvider.notifier);
    return Column(
      children: [
        SwitchListTile.adaptive(
          key: const ValueKey('ajuste-sonido'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Sonido'),
          subtitle: const Text('Sonidos alegres para acompañar la charla'),
          value: ajustes.sonidos,
          onChanged: (valor) async {
            final respuesta = ref.read(respuestaInterfazProvider);
            if (!valor) respuesta.silenciar();
            await controlador.alternarSonidos();
            if (context.mounted && valor) {
              respuesta.emitir(EfectoInterfaz.activarSonido);
            }
          },
        ),
        SwitchListTile.adaptive(
          key: const ValueKey('ajuste-vibracion'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Vibración'),
          subtitle: const Text('Una respuesta suave al confirmar.'),
          value: ajustes.vibracion,
          onChanged: (valor) async {
            final respuesta = ref.read(respuestaInterfazProvider);
            await controlador.alternarVibracion();
            if (context.mounted) {
              respuesta.emitir(
                valor
                    ? EfectoInterfaz.activarVibracion
                    : EfectoInterfaz.desactivarVibracion,
              );
            }
          },
        ),
        const SizedBox(height: 22),
      ],
    );
  }
}
