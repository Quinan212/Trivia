# Trivia

**Preguntas, participación y evaluación en el aula.**

Trivia es una app para docentes que permite organizar una evaluación con preguntas de opción múltiple desde una tableta Android. El docente conduce la actividad: prepara la lista de estudiantes, lee las preguntas, registra las respuestas y consulta los resultados. Los turnos, el tiempo, los robos y los puntajes se gestionan en la app.

Se puede adaptar a distintas materias mediante bancos de preguntas propios. Incluye un banco de **200 preguntas de Antigüedad, Unidad IV**, con cuatro alternativas y una explicación por pregunta.

Es **gratuita y funciona sin conexión**, sin cuentas, anuncios ni compras. Está diseñada para tabletas, tanto en horizontal como en vertical.

## Cómo se usa en clase

### 1. Prepará la evaluación

Configurá la materia, el tema o unidad, la comisión, el docente y, si corresponde, el ayudante de cátedra. Podés elegir entre cinco paletas de colores.

El **nombre corto** de la materia se usa en la cabecera; el nombre completo identifica la asignatura en los informes. La paleta se previsualiza al elegirla: **Guardar** aplica los cambios y **Cancelar** conserva la configuración anterior. Los aciertos y errores mantienen sus marcas verdes y rojas con cualquier paleta.

![Dónde configurar la materia, la unidad y los datos docentes](docs/guia-visual/configuracion.png)

![Detalle de las cinco paletas y cómo guardar el color elegido](docs/guia-visual/paletas.png)

En **Estudiantes**, revisá los nombres y marcá presentes y ausentes. Podés cargar una lista propia y corregir un nombre manteniendo presionada su fila. Antes de comenzar también se pueden eliminar estudiantes.

![Cómo cargar la lista de estudiantes desde un archivo JSON](docs/guia-visual/estudiantes.png)

Cada fila tiene un interruptor de asistencia. Quienes figuran como ausentes quedan fuera del sorteo.

Antes de empezar, **Marcar presentes** y **Marcar ausentes** cambian la asistencia de toda la lista. Tiene que haber al menos una persona presente para iniciar.

![Detalle de los interruptores para marcar presentes y ausentes](docs/guia-visual/asistencia.png)

Para corregir un nombre, mantené presionada la fila y guardá los cambios en el cuadro de edición.

También podés **añadir estudiantes manualmente**: completá Apellido y Nombre debajo de la lista y tocá **Añadir**. La eliminación está disponible antes de iniciar, siempre que quede al menos un estudiante. Corregir un nombre durante la evaluación conserva sus respuestas y puntos.

![Edición de apellido y nombre mediante una pulsación prolongada](docs/guia-visual/editar-estudiante.png)

La app admite **hasta 20 estudiantes** y reserva **10 preguntas distintas para cada uno**. El banco debe alcanzar para todas las personas registradas, incluidos los ausentes: una lista de 15 estudiantes necesita al menos 150 preguntas.

### 2. Iniciá y sorteá un turno

Los turnos se sortean entre quienes están presentes y siguen participando, priorizando a quienes tuvieron menos preguntas. Cada estudiante recibe preguntas de su conjunto reservado.

Leé el enunciado y las cuatro alternativas en voz alta. Después tocá **«Iniciar tiempo»**: hay **60 segundos** para responder, sin descontar el tiempo de lectura. El docente registra la opción elegida, de A a D.

La respuesta se registra con los **botones A–D de la barra**, usando la letra que aparece en pantalla. Las tarjetas de las alternativas son de lectura; la app baraja su orden al preparar la evaluación. Si una pregunta o su explicación ocupa más espacio, desplazá el contenido dentro de la tarjeta para leerlo completo.

Mientras corre el tiempo, **tocá el reloj para pausarlo** y volvé a tocarlo para reanudar. El reloj también se pausa al salir de Evaluación, abrir la ayuda, la configuración o un informe, o dejar la app en segundo plano. Al volver, reanudalo cuando corresponda.

### 3. Resolvé la respuesta y los robos

Si la respuesta es incorrecta, no contesta o se agota el tiempo, podés elegir a otro estudiante habilitado para intentar un **robo**. Hay hasta **dos intentos de robo por pregunta**, con un intento por persona.

El selector ofrece estudiantes presentes que siguen participando, distintos del titular y de quienes ya intentaron robar esa pregunta. Elegí una persona y tocá **Iniciar robo**. Los robos **no tienen un nuevo cronómetro de 60 segundos** y no consumen las diez preguntas propias de quien roba. Las alternativas ya elegidas quedan marcadas y bloqueadas.

La respuesta correcta y la explicación quedan disponibles para revisar al cerrar la pregunta. Después se puede avanzar al siguiente turno. **Deshacer** permite corregir un registro equivocado.

| Control | Cuándo usarlo |
| --- | --- |
| **No contesta** | Registra que el titular no responde y pasa a los robos disponibles, sin esperar a que termine el reloj. |
| **Cerrar pregunta** | Termina los robos pendientes sin ofrecer otro intento. Si no hay estudiantes habilitados o se agotan los dos robos, el cierre es automático. |
| **Ver explicación / Volver a las opciones** | Alterna las dos caras de la pregunta una vez cerrada. |
| **Deshacer última acción** | Vuelve a un paso anterior y recupera los puntos correspondientes. Si regresa a una pregunta con tiempo, queda pausada. No revierte las correcciones de nombres. |

![Un turno de Trivia: iniciar el tiempo, registrar una respuesta, abrir un robo y revisar la explicación](docs/guia-visual/trivia-turno.gif)

[Ver el turno con sonido](docs/guia-visual/trivia-turno.mp4).

### 4. Consultá los resultados

En **Resultados** podés seguir los puntajes, las notas y la participación de cada estudiante. Desde ahí se abren los informes individuales o todos los informes reunidos en un único PDF.

**Correctas** cuenta los aciertos en preguntas propias y **Robos** los robos acertados; **Puntos** suma sus valores y **Nota** expresa el resultado sobre diez. Los ausentes aparecen identificados, con guiones en puntos y nota. Mientras la evaluación del grupo sigue abierta, la columna **Resultado** muestra «En curso», aunque una persona ya haya recibido su aviso de aprobación.

![Detalle de las columnas de aciertos, robos, puntos, nota y resultado](docs/guia-visual/resultados.png)

Cuando ya no quedan estudiantes presentes con participación abierta y preguntas propias pendientes, el siguiente avance lleva a **Evaluación finalizada**. Desde esa pantalla podés ir a los resultados o iniciar otra evaluación.

### 5. Empezá otra evaluación

**Nueva evaluación** está disponible en Estudiantes y al finalizar la actividad. Pide confirmación, conserva los nombres, el banco de preguntas y la configuración, y empieza con respuestas y puntos en cero. **Todos vuelven a quedar presentes**, por lo que conviene revisar la asistencia antes de iniciar el nuevo grupo de turnos.

## Cómo se puntúa

| Resultado | Puntaje |
| --- | --- |
| Respuesta correcta en su pregunta | 1 punto |
| Robo correcto | 2 puntos, hasta alcanzar el máximo de 10 |
| Respuesta incorrecta o sin respuesta | 0 puntos; no se descuentan puntos |

La aprobación es desde **7 puntos** y la nota máxima es **10**. Los puntos de las preguntas propias y de los robos se acumulan, sin superar ese máximo: si tiene 9 y acierta un robo, llega a 10.

Las diez preguntas propias son oportunidades de respuesta, no puntos garantizados. Los robos son participaciones adicionales: quien ya respondió sus diez preguntas propias puede seguir apareciendo para robar mientras la evaluación esté abierta y su participación no haya finalizado.

### Al alcanzar la aprobación

Cuando un estudiante alcanza o supera los **7 puntos** por primera vez, aparece un aviso con dos opciones:

- **Finalizar:** termina la evaluación de esa persona con el puntaje alcanzado; deja de participar en los turnos y robos.
- **Continuar:** sigue participando para intentar mejorar su nota, hasta llegar a 10 o completar su participación.

![Aviso al llegar a 7 puntos con las opciones Finalizar y Continuar](docs/guia-visual/aprobacion-7.png)

### Al llegar a la nota máxima

Al alcanzar **10 puntos**, la participación de ese estudiante termina automáticamente: deja de entrar en el sorteo y de estar habilitado para los robos. La app muestra un aviso de nota máxima. En este caso, **Continuar** cierra el aviso para seguir con el resto del grupo; no vuelve a habilitar a esa persona.

![Aviso al alcanzar 10 puntos y finalizar la participación del estudiante](docs/guia-visual/nota-maxima-10.png)

## Tus preguntas y tus estudiantes

Podés preparar Trivia para otra materia cargando un **banco de preguntas en formato JSON**. Cada pregunta incluye un tema, un enunciado, cuatro opciones, la respuesta correcta y una explicación. El banco se puede consultar y filtrar por tema desde la sección **Banco**.

Se admiten bancos de **10 a 2000 preguntas**, en archivos de hasta **2 MB**, siempre que alcancen para reservar diez por estudiante. Las preguntas adicionales quedan en reserva. Para editar un banco, descargá su plantilla y modificá el JSON fuera de la app; la plantilla exportada contiene las preguntas del banco que esté cargado.

Cuando usás un banco personalizado aparece **Usar banco predeterminado**, que recupera el banco de Unidad IV. Esta acción está habilitada antes de iniciar o después de finalizar; si la evaluación está en curso, primero creá una nueva.

![Banco de preguntas con indicaciones para buscar, filtrar, importar JSON, descargar la plantilla y revisar la explicación](docs/guia-visual/banco.png)

Para revisar una parte del banco, elegí un tema en el menú. La búsqueda consulta el enunciado, el subtema y las alternativas, y se puede combinar con el filtro por tema. **Todos** elimina el filtro de tema; para volver a ver el banco completo, borrá también el texto de búsqueda.

![Menú desplegado con los temas disponibles para filtrar las preguntas](docs/guia-visual/filtro-preguntas.png)

La lista de estudiantes también se puede cargar desde un archivo JSON de hasta **256 KB** o descargar como plantilla con los nombres y la asistencia actuales. El botón **Restaurar estudiantes predeterminados** recupera la lista original y pide confirmar el reemplazo. Tanto la carga como la restauración crean una nueva evaluación si ya había una iniciada.

| Qué querés preparar | Plantilla | Guía |
| --- | --- | --- |
| Banco de preguntas | [Descargar plantilla](output/Plantilla-banco-preguntas.json) | [Cómo preparar las preguntas](output/Guia-bancos-JSON.md) |
| Lista de estudiantes | [Descargar plantilla](output/Plantilla-estudiantes.json) | [Cómo preparar la lista](output/Guia-estudiantes-JSON.md) |

Si reemplazás el banco o la lista cuando la evaluación ya comenzó, se solicita confirmar una evaluación nueva, con puntajes en cero; la anterior queda guardada. Cancelar la carga o elegir un archivo inválido conserva los datos actuales.

## Informes para revisar y compartir

Los PDF incluyen la identificación de la evaluación, los datos docentes y el registro de cada estudiante: preguntas, alternativas, respuestas, intentos de robo y resultado. Las marcas permiten distinguir aciertos y errores. El informe individual indica si es **parcial o final**: puede ser final cuando esa persona ya terminó, aunque el grupo siga siendo evaluado.

Se pueden abrir **desde que se inicia la evaluación**, sin esperar al cierre del grupo. El detalle distingue respuestas incorrectas, falta de respuesta, tiempo agotado y preguntas todavía no planteadas. También registra las participaciones en preguntas de otras personas y el tiempo activo de las respuestas propias, sin sumar la lectura ni las pausas.

![Detalle del informe individual con resumen, alternativa marcada y resultado de la pregunta](docs/guia-visual/informe-individual.png)

Podés **guardar, compartir o imprimir** un informe individual. La opción **«Todos los informes (PDF)»** reúne los informes en un solo documento, con portada y numeración por estudiante.

En el visor, las flechas cambian de página y el contador indica dónde estás. Podés **ampliar con dos dedos y arrastrar** para recorrer el detalle; al cambiar de página vuelve al encuadre inicial. Los PDF exportados conservan texto seleccionable, los datos docentes y la paleta de la evaluación.

![Botones del visor para guardar, compartir e imprimir el PDF](docs/guia-visual/acciones-pdf.png)

## Progreso y privacidad

La evaluación, el banco personalizado y las preferencias se guardan localmente para continuar después. Al recuperar una evaluación, el tiempo queda pausado. **Deshacer** conserva hasta veinte pasos durante la sesión abierta; ese historial de pasos no se recupera al cerrar y volver a abrir la app.

Podés corregir la asistencia durante la actividad. Si marcás ausente a quien estaba respondiendo, se suspende ese turno; si estaba robando, se cancela su intento. Los ausentes dejan de aparecer como candidatos a nuevos turnos y robos.

El botón **Cómo evaluar** abre la ayuda dentro de la app; el de **sonido** permite activar o silenciar los efectos. La interfaz respeta la preferencia de movimiento reducido del dispositivo. Si aparece un aviso de que no se pudo guardar, **Reintentar guardado** vuelve a intentar conservar el progreso.

Los nombres, la asistencia y los resultados permanecen en el dispositivo; la app no los envía a servidores del desarrollador. Tampoco escucha ni graba las respuestas orales. Los informes se comparten cuando el docente lo decide.

[Leer la política de datos y privacidad](docs/politica-privacidad.md).
