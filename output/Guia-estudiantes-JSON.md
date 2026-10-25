# Cargar estudiantes

En Estudiantes, el botón del archivo con flecha hacia arriba carga un JSON. El de descarga guarda una plantilla con los nombres y la asistencia actuales; el de restaurar vuelve a la lista original.

1. Abrí Plantilla-estudiantes.json y cambiá sus filas por los estudiantes del curso.
2. Cada fila lleva apellido y nombre, de hasta 120 caracteres cada uno. presente es opcional y admite true o false; si falta, se toma true.
3. Se admiten entre 1 y 20 estudiantes y archivos de hasta 256 KB. No hace falta escribir identificadores: la app los asigna. Si el archivo incluye id, debe tener entre 1 y 24 letras/números/guiones/guiones bajos y ser distinto en cada fila. Se permiten homónimos, con identificadores diferentes.
4. El banco debe alcanzar para reservar 10 preguntas por cada estudiante registrado, incluidos ausentes.
5. Cargá el archivo desde Estudiantes y confirmá el reemplazo. Si la evaluación ya empezó, se crea otra con puntajes en cero y la anterior queda guardada. Cancelar o un archivo inválido conserva la lista anterior.

Para corregir un nombre, mantené apretada su fila. La ventana permite guardar o cancelar la edición; antes de iniciar también permite eliminar, siempre que quede al menos un estudiante. Durante la evaluación se conserva la identidad interna y sus resultados al corregir el nombre. Deshacer respuestas no revierte esa corrección.

También se admiten listas JSON antiguas de estudiantes sin el envoltorio formato/version/estudiantes. Los datos permanecen locales en la tableta; no se envían a un servicio.
