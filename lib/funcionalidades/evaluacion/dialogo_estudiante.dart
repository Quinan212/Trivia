import 'package:flutter/material.dart';

import 'estudiantes_json.dart';
import 'modelos.dart';

typedef EdicionEstudiante = ({String apellido, String nombre, bool eliminar});

Future<EdicionEstudiante?> editarEstudiante(
  BuildContext context,
  AlumnoTrivia alumno, {
  required bool puedeEliminar,
  required bool iniciada,
}) => showDialog<EdicionEstudiante>(
  context: context,
  builder: (_) => _DialogoEstudiante(alumno, puedeEliminar, iniciada),
);

class _DialogoEstudiante extends StatefulWidget {
  const _DialogoEstudiante(this.alumno, this.puedeEliminar, this.iniciada);
  final AlumnoTrivia alumno;
  final bool puedeEliminar, iniciada;
  @override
  State<_DialogoEstudiante> createState() => _DialogoEstudianteState();
}

class _DialogoEstudianteState extends State<_DialogoEstudiante> {
  final _form = GlobalKey<FormState>();
  late final _apellido = TextEditingController(text: widget.alumno.apellido);
  late final _nombre = TextEditingController(text: widget.alumno.nombre);
  bool _cerrando = false;

  void _cerrar({bool eliminar = false}) {
    if (_cerrando || (!eliminar && !_form.currentState!.validate())) return;
    _cerrando = true;
    Navigator.of(context).pop<EdicionEstudiante>((
      apellido: EstudiantesJson.limpiar(_apellido.text),
      nombre: EstudiantesJson.limpiar(_nombre.text),
      eliminar: eliminar,
    ));
  }

  @override
  void dispose() {
    _apellido.dispose();
    _nombre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const ValueKey('dialogo-estudiante'),
    title: const Text('Estudiante'),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final campo in [
                (_apellido, 'Apellido', 'apellido'),
                (_nombre, 'Nombre', 'nombre'),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    key: ValueKey('editar-estudiante-${campo.$3}'),
                    controller: campo.$1,
                    decoration: InputDecoration(labelText: campo.$2),
                    maxLength: 120,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: campo.$3 == 'apellido'
                        ? TextInputAction.next
                        : TextInputAction.done,
                    onFieldSubmitted: campo.$3 == 'nombre'
                        ? (_) => _cerrar()
                        : null,
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Completá este campo.'
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      Tooltip(
        message: widget.puedeEliminar
            ? 'Eliminar estudiante'
            : widget.iniciada
            ? 'No se puede eliminar durante una evaluación.'
            : 'Debe quedar al menos un estudiante.',
        child: TextButton.icon(
          key: const ValueKey('eliminar-estudiante'),
          onPressed: widget.puedeEliminar
              ? () => _cerrar(eliminar: true)
              : null,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Eliminar'),
        ),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const ValueKey('guardar-estudiante'),
        onPressed: _cerrar,
        child: const Text('Guardar'),
      ),
    ],
  );
}
