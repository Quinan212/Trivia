# Trivia

**Preguntas, participación y evaluación en el aula.**

Trivia es una app para docentes que permite organizar una evaluación con preguntas de opción múltiple desde una tableta Android. El docente conduce la actividad: prepara la lista de estudiantes, lee las preguntas, registra las respuestas y consulta los resultados. Los turnos, el tiempo, los robos y los puntajes se gestionan en la app.

Se puede adaptar a distintas materias mediante bancos de preguntas propios. Incluye un banco de **200 preguntas de Antigüedad, Unidad IV**, con cuatro alternativas y una explicación por pregunta.

Es **gratuita y funciona sin conexión**, sin cuentas, anuncios ni compras. Está diseñada para tabletas, tanto en horizontal como en vertical.

## Cómo se usa en clase

### 1. Prepará la evaluación

Configurá la materia, el tema o unidad, la comisión, el docente y, si corresponde, el ayudante de cátedra. Podés elegir entre cinco paletas de colores.

En **Estudiantes**, revisá los nombres y marcá presentes y ausentes. Podés cargar una lista propia y corregir un nombre manteniendo presionada su fila. Antes de comenzar también se pueden eliminar estudiantes.

La app admite **hasta 20 estudiantes** y reserva **10 preguntas distintas para cada uno**. El banco debe alcanzar para todas las personas registradas, incluidos los ausentes: una lista de 15 estudiantes necesita al menos 150 preguntas.

### 2. Iniciá y sorteá un turno

Los turnos se sortean entre quienes están presentes y siguen participando, priorizando a quienes tuvieron menos preguntas. Cada estudiante recibe preguntas de su conjunto reservado.

Leé el enunciado y las cuatro alternativas en voz alta. Después tocá **«Iniciar tiempo»**: hay **60 segundos** para responder, sin descontar el tiempo de lectura. El docente registra la opción elegida, de A a D.

### 3. Resolvé la respuesta y los robos

Si la respuesta es incorrecta, no contesta o se agota el tiempo, podés elegir a otro estudiante habilitado para intentar un **robo**. Hay hasta **dos intentos de robo por pregunta**, con un intento por persona.

La respuesta correcta y la explicación quedan disponibles para revisar al cerrar la pregunta. Después se puede avanzar al siguiente turno. **Deshacer** permite corregir un registro equivocado.

### 4. Consultá los resultados

En **Resultados** podés seguir los puntajes, las notas y la participación de cada estudiante. Desde ahí se abren los informes individuales o todos los informes reunidos en un único PDF.

## Cómo se puntúa

| Resultado | Puntaje |
| --- | --- |
| Respuesta correcta en su pregunta | 1 punto |
| Robo correcto | 2 puntos, hasta alcanzar el máximo de 10 |
| Respuesta incorrecta o sin respuesta | 0 puntos; no se descuentan puntos |

La aprobación es desde **7 puntos**. Al alcanzar ese puntaje, la app permite elegir entre finalizar la evaluación de esa persona o continuar para mejorar la nota. Al llegar a **10**, su participación termina automáticamente.

## Tus preguntas y tus estudiantes

Podés preparar Trivia para otra materia cargando un **banco de preguntas en formato JSON**. Cada pregunta incluye un tema, un enunciado, cuatro opciones, la respuesta correcta y una explicación. El banco se puede consultar y filtrar por tema desde la sección **Banco**.

Se admiten bancos de **10 a 2000 preguntas**, siempre que alcancen para reservar diez por estudiante. La app permite descargar una plantilla y volver al banco incluido cuando lo necesites.

La lista de estudiantes también se puede cargar desde un archivo JSON o descargar como plantilla con los nombres y la asistencia actuales.

| Qué querés preparar | Plantilla | Guía |
| --- | --- | --- |
| Banco de preguntas | [Descargar plantilla](output/Plantilla-banco-preguntas.json) | [Cómo preparar las preguntas](output/Guia-bancos-JSON.md) |
| Lista de estudiantes | [Descargar plantilla](output/Plantilla-estudiantes.json) | [Cómo preparar la lista](output/Guia-estudiantes-JSON.md) |

Si reemplazás el banco o la lista cuando la evaluación ya comenzó, se solicita confirmar una evaluación nueva, con puntajes en cero; la anterior queda guardada. Cancelar la carga o elegir un archivo inválido conserva los datos actuales.

## Informes para revisar y compartir

Los PDF incluyen la identificación de la evaluación, los datos docentes y el registro de cada estudiante: preguntas, alternativas, respuestas, intentos de robo y resultado. Las marcas permiten distinguir aciertos y errores; los informes de una evaluación en curso se identifican como parciales.

Podés **guardar, compartir o imprimir** un informe individual. La opción **«Todos los informes (PDF)»** reúne los informes en un solo documento, con portada y numeración por estudiante.

## Progreso y privacidad

La evaluación y las preferencias se guardan localmente para continuar después. Al recuperar una evaluación, el tiempo queda pausado. Los sonidos se pueden silenciar y la interfaz respeta la preferencia de movimiento reducido.

Los nombres, la asistencia y los resultados permanecen en el dispositivo; la app no los envía a servidores del desarrollador. Tampoco escucha ni graba las respuestas orales. Los informes se comparten cuando el docente lo decide.

[Leer la política de datos y privacidad](docs/politica-privacidad.md).
