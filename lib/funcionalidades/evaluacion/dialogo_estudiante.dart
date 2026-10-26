import 'package:flutter/material.dart';

import '../../tema/paleta_evaluacion.dart';
import 'estudiantes_json.dart';
import 'modelos.dart';

typedef EdicionEstudiante = ({String apellido, String nombre, bool eliminar});

Future<EdicionEstudiante?> agregarEstudiante(BuildContext context) =>
    showDialog<EdicionEstudiante>(
      context: context,
      barrierColor: const Color(0x52000000),
      builder: (_) => const _DialogoEstudiante(null, false, false),
    );

Future<EdicionEstudiante?> editarEstudiante(
  BuildContext context,
  AlumnoTrivia alumno, {
  required bool puedeEliminar,
  required bool iniciada,
}) => showDialog<EdicionEstudiante>(
  context: context,
  barrierColor: const Color(0x52000000),
  builder: (_) => _DialogoEstudiante(alumno, puedeEliminar, iniciada),
);

class _DialogoEstudiante extends StatefulWidget {
  const _DialogoEstudiante(this.alumno, this.puedeEliminar, this.iniciada);
  final AlumnoTrivia? alumno;
  final bool puedeEliminar, iniciada;
  @override
  State<_DialogoEstudiante> createState() => _DialogoEstudianteState();
}

class _DialogoEstudianteState extends State<_DialogoEstudiante> {
  final _form = GlobalKey<FormState>();
  late final _apellido = TextEditingController(
    text: widget.alumno?.apellido ?? '',
  );
  late final _nombre = TextEditingController(text: widget.alumno?.nombre ?? '');
  late final _focos = {_apellido: FocusNode(), _nombre: FocusNode()};
  bool _cerrando = false;

  bool get _puedeGuardar =>
      !_cerrando &&
      _apellido.text.trim().isNotEmpty &&
      _nombre.text.trim().isNotEmpty &&
      (widget.alumno == null ||
          EstudiantesJson.limpiar(_apellido.text) != widget.alumno!.apellido ||
          EstudiantesJson.limpiar(_nombre.text) != widget.alumno!.nombre);

  @override
  void initState() {
    super.initState();
    for (final c in [_apellido, _nombre]) {
      c.addListener(_actualizar);
      _focos[c]!.addListener(_actualizar);
    }
  }

  void _actualizar() {
    if (mounted) setState(() {});
  }

  void _cancelar() {
    if (_cerrando) return;
    setState(() => _cerrando = true);
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
  }

  void _cerrar({bool eliminar = false}) {
    if (_cerrando ||
        (eliminar && !widget.puedeEliminar) ||
        (!eliminar && (!_puedeGuardar || !_form.currentState!.validate()))) {
      return;
    }
    setState(() => _cerrando = true);
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop<EdicionEstudiante>((
      apellido: EstudiantesJson.limpiar(_apellido.text),
      nombre: EstudiantesJson.limpiar(_nombre.text),
      eliminar: eliminar,
    ));
  }

  @override
  void dispose() {
    for (final c in [_apellido, _nombre]) {
      c.removeListener(_actualizar);
      _focos[c]!
        ..removeListener(_actualizar)
        ..dispose();
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = PaletaEvaluacion.of(context);
    final nuevo = widget.alumno == null;
    return Dialog(
      key: const ValueKey('dialogo-estudiante'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      backgroundColor: p.fondo,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: TextButton(
                      onPressed: _cerrando ? null : _cancelar,
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Cancelar', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          nuevo ? 'Nuevo estudiante' : 'Estudiante',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: p.tinta,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: FilledButton(
                      key: const ValueKey('guardar-estudiante'),
                      onPressed: _puedeGuardar ? _cerrar : null,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(100, 44),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          nuevo ? 'Añadir' : 'Guardar',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                key: const ValueKey('contenido-estudiante'),
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
                child: Form(
                  key: _form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _grupo(context, 'Datos del estudiante', [
                        _campo(context, 'Apellido', 'apellido', _apellido, 120),
                        _campo(
                          context,
                          'Nombre',
                          'nombre',
                          _nombre,
                          120,
                          ultimo: true,
                        ),
                      ]),
                      if (!nuevo) ...[
                        const SizedBox(height: 14),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Tooltip(
                            message: widget.puedeEliminar
                                ? 'Eliminar estudiante'
                                : widget.iniciada
                                ? 'No se puede eliminar durante una evaluación.'
                                : 'Debe quedar al menos un estudiante.',
                            child: TextButton.icon(
                              key: const ValueKey('eliminar-estudiante'),
                              onPressed: widget.puedeEliminar && !_cerrando
                                  ? () => _cerrar(eliminar: true)
                                  : null,
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Eliminar estudiante'),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grupo(BuildContext context, String titulo, List<Widget> filas) {
    final p = PaletaEvaluacion.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.fondo,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.tenue.withValues(alpha: .14), width: .8),
      ),
      padding: const EdgeInsets.all(.8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Text(
              titulo,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: p.tinta,
              ),
            ),
          ),
          ColoredBox(
            color: p.hoja,
            child: Column(
              children: [
                for (var i = 0; i < filas.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: .8,
                      thickness: .8,
                      color: p.tenue.withValues(alpha: .12),
                    ),
                  filas[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fila(
    BuildContext context,
    String titulo,
    Widget contenido, {
    bool enfocada = false,
  }) {
    final p = PaletaEvaluacion.of(context);
    return ColoredBox(
      color: enfocada
          ? Color.alphaBlend(p.naranja.withValues(alpha: .035), p.hoja)
          : p.hoja,
      child: LayoutBuilder(
        builder: (context, limites) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: (limites.maxWidth * .28).clamp(140.0, 186.0),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                child: ExcludeSemantics(
                  child: Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      color: enfocada ? p.naranjaTexto : p.tenue,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: SizedBox(
                  width: .8,
                  child: ColoredBox(
                    color: p.tenue.withValues(alpha: enfocada ? .3 : .12),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: contenido,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _campo(
    BuildContext context,
    String titulo,
    String clave,
    TextEditingController controlador,
    int limite, {
    bool multilinea = false,
    bool opcional = false,
    bool ultimo = false,
  }) {
    final p = PaletaEvaluacion.of(context);
    return _fila(
      context,
      titulo,
      Semantics(
        label: titulo,
        child: TextFormField(
          key: ValueKey('editar-estudiante-$clave'),
          controller: controlador,
          focusNode: _focos[controlador],
          maxLength: limite,
          minLines: multilinea ? 2 : 1,
          maxLines: multilinea ? null : 2,
          style: TextStyle(fontSize: 16, height: 1.4, color: p.tinta),
          textCapitalization: TextCapitalization.words,
          textInputAction: ultimo ? TextInputAction.done : TextInputAction.next,
          onFieldSubmitted: (_) {
            if (ultimo) {
              _cerrar();
            } else {
              FocusScope.of(context).nextFocus();
            }
          },
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(
            filled: false,
            isDense: true,
            counterText: '',
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
          ),
          validator: (valor) =>
              !opcional && (valor == null || valor.trim().isEmpty)
              ? 'Completá este campo.'
              : null,
        ),
      ),
      enfocada: _focos[controlador]!.hasFocus,
    );
  }
}
