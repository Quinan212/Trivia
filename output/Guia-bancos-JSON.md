# Bancos de preguntas personalizados

En **Banco de preguntas** hay tres acciones: cargar un JSON, descargar una plantilla y, cuando usás un banco personalizado, volver al banco predeterminado de Unidad IV.

La plantilla descargada toma las preguntas del banco que esté cargado. La plantilla entregada junto a esta guía contiene las 200 preguntas actuales como base editable: guardá una copia con otro nombre y reemplazá su contenido por tus nuevas preguntas.

## Estructura

El archivo se guarda como `.json`, con codificación UTF-8:

```json
{
  "formato": "banco-trivia",
  "version": 1,
  "nombre": "Nombre de mi banco",
  "preguntas": [
    {
      "id": "P001",
      "tema": "Nombre del tema",
      "subtema": "Nombre del subtema",
      "tipo": "Conceptos",
      "pregunta": "Texto completo de la pregunta",
      "opciones": ["Primera opción", "Segunda opción", "Tercera opción", "Cuarta opción"],
      "correcta": "B",
      "explicacion": "Explicación de por qué la segunda opción es correcta."
    }
  ]
}
```

Este fragmento muestra una pregunta; completá la lista con la cantidad necesaria.

| Campo | Qué colocar |
|---|---|
| `nombre` | Nombre del banco, hasta 120 caracteres. |
| `id` | Identificador distinto para cada pregunta. Letras, números, guion o guion bajo; hasta 64 caracteres. Es interno. |
| `tema` | Tema de la pregunta. Los temas del selector se crean automáticamente a partir de estos valores. |
| `subtema` | Subtema. Si se omite, se usa el tema. |
| `tipo` | Categoría. Si se omite, se usa `General`. |
| `pregunta` | Enunciado completo, sin repetir otro enunciado del mismo banco. |
| `opciones` | Cuatro respuestas distintas, en orden A, B, C y D. |
| `correcta` | Letra A, B, C o D que corresponde al orden escrito en el archivo. |
| `explicacion` | Explicación que se podrá consultar al cerrar la pregunta. |

La aplicación baraja las alternativas y conserva automáticamente cuál es la correcta. No cambies `formato` ni `version`.

## Cantidad y carga

- Se admiten entre 10 y 2000 preguntas, en un archivo de hasta 2 MB.
- El banco debe alcanzar para reservar **10 preguntas por estudiante registrado**, incluidos los ausentes. Por ejemplo: 13 estudiantes requieren al menos 130 preguntas; 20 requieren al menos 200.
- Las preguntas restantes se conservan como reserva. La cantidad total no tiene que ser múltiplo de diez.
- Se pueden usar temas nuevos y cantidades diferentes por tema. El reparto intenta distribuirlos entre los estudiantes.
- La carga está disponible antes de iniciar una evaluación o después de finalizarla. Para cambiar durante una evaluación, primero usá **Nueva evaluación**.
- Antes de cargar se muestran el nombre del banco, la cantidad de preguntas y la cantidad de temas. Si el archivo es inválido o no alcanza, el banco actual se conserva.
- El banco cargado queda guardado junto a la evaluación y se recupera al volver a abrir la app. El banco original de Unidad IV permanece disponible.

También se admite el formato anterior de lista de preguntas con campos `theme`, `text`, `options`, `answer` y `explanation`; en ese formato `answer` es un índice de 0 a 3.
