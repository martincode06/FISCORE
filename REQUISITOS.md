# Análisis breve de requisitos — FISCORE

## Objetivo
Crear una aplicación Android instalable mediante APK para que una persona controle el tiempo, el marcador y las faltas de ambos equipos durante un partido, sin conexión a internet.

## Alcance de la primera versión
- Un partido activo con dos equipos cuyos nombres se puedan editar.
- Reloj de cuenta regresiva en minutos y segundos (MM:SS), con controles para iniciar, pausar y reanudar. El tiempo se podrá corregir cuando el reloj esté detenido.
- Reloj de posesión visible, con reinicios manuales a 24 y 14 segundos, pausa independiente, corrección con décimas y apagado. Al pausar el partido se detiene también la posesión; al reanudar se respeta una pausa independiente previa.
- Señal diferenciada al agotarse la posesión, sin asignar automáticamente una infracción. El reloj principal se pausa por decisión del operador cuando corresponda. Si ambos vencen a la vez, tiene prioridad la señal de fin de período.
- Los nuevos períodos y partidos comienzan con posesión de 24 segundos. Al reiniciar con menos tiempo de partido que la cuenta elegida, la posesión queda sin indicación ni señal. No se apaga una cuenta ya en marcha solo porque el período baje de 14 segundos.
- Botones de +1, +2 y +3 puntos por equipo. Un interruptor Corregir transforma esos mismos controles en −1, −2 y −3, con color ámbar y aviso RESTAR. Es independiente por equipo y permanece activo hasta apagarlo. Se bloquean las restas que dejarían puntos negativos. Reabrir la app o iniciar otro partido restablece el modo sumar.
- Registro de faltas por jugador con controles +/− directos, sin selección y confirmación repetidas. El tipo de falta está siempre visible; − quita la última del tipo elegido para ese jugador. Incluye personales, técnicas, antideportivas y descalificantes, guardado automático y deshacer.
- Exclusión al llegar a cinco faltas durante el partido y descalificación por dos técnicas, dos antideportivas, una de cada tipo o una descalificante. Se bloquean nuevas faltas para el jugador excluido; una corrección permite rehabilitarlo si corresponde.
- Penalización del equipo después de cuatro faltas por cuarto, con indicador desde la cuarta y aviso a partir de la quinta. Las faltas siguen contándose después de cinco; no se asignan tiros libres ni puntos automáticamente.
- Indicación del período actual y avance manual al siguiente con el reloj en cero. Se conservan marcador y faltas individuales. Las faltas de equipo se reinician por período reglamentario y las prórrogas acumulan con el último.
- Cantidad de tiempos configurable de 1 a 12; duración de 1 a 99 minutos y prórrogas de 1 a 30 minutos. Accesos a 4 × 10 (base FIBA) y 2 × 10 (personalizado). El reloj, la posesión y el formato se ajustan con +/−. Los dorsales se escriben con dígitos en un panel propio, con 00 y borrar, sin teclado de Android.
- Guardar cambia también el reloj visible conservando el tiempo ya jugado y persiste el formato completo. Se corrigen configuraciones antiguas cuyo reloj excedía la duración declarada.
- Opción de agregar una prórroga con duración configurable y conservando el marcador.
- Al llegar a 00:00, el reloj se detiene y muestra una alerta visual y una chicharra de cancha incorporada. La posesión usa una ráfaga diferenciada; el menú permite probar el sonido con el reloj pausado.
- Confirmación antes de reiniciar o finalizar un partido. Al finalizar, se muestra el resultado final.
- Guardado automático del partido activo para recuperarlo al cerrar y abrir la aplicación.
- Mis equipos: biblioteca persistente de plantillas con nombre, doce jugadores y dorsales. Permite guardar, actualizar por nombre y cargar como local o visitante, siempre sin puntos ni faltas. Pide confirmar si se reemplazan estadísticas de un equipo; al cargar después de finalizar se ofrece iniciar otro partido en cero.
- Jugadores ordenados de más a menos faltas; empates por dorsal. Se recalcula al añadir, corregir o deshacer y no cambia los identificadores de los jugadores.
- Sin pestaña Registro ni franja inferior de estado. Se conservan el guardado en segundo plano y los avisos de error de almacenamiento.

## Requisitos de uso y calidad
- Interfaz en español, exclusivamente horizontal, con números grandes y botones fáciles de pulsar.
- Pantalla principal con equipo local y visitante a los lados; reloj, período y controles en el centro.
- El tablero distribuye el espacio disponible sin escalar toda la interfaz. En alturas extremas permite desplazamiento. Los paneles mantienen cabecera y acciones visibles, indican el desplazamiento de las listas y adaptan el número de columnas. Los nombres se editan en un panel compacto que se mantiene sobre el teclado; se guardan con Guardar o Listo.
- Nombre visible FISCORE. Botón (?) junto al menú para créditos, versión, contacto y licencias. Creado por Martin Villy; consultas, contrataciones y donaciones: 925449100, con copia explícita del número.
- Funcionamiento sin cuenta, anuncios ni internet.
- Mantener la pantalla encendida durante el partido.
- El reloj se pausa al salir de la app o al abrir el registro de una falta. Al reabrir, el partido se recupera pausado en el último estado guardado. Durante el cronometraje se guarda cada segundo.
- Reloj con décimas en el último minuto. Guardado local en Android y pantalla encendida durante el uso.
- Implementación con Flutter, Dart, Java, Gradle y SDK Android ya instalados en la laptop, sin dependencias externas adicionales de ejecución.

## Criterios básicos de aceptación
1. Un reloj configurado en 10:00 disminuye al iniciarlo, se detiene al pausarlo y continúa desde ese valor al reanudarlo.
2. Una pulsación en +2 aumenta exactamente dos puntos al equipo elegido; una corrección nunca deja valores negativos.
3. La quinta falta excluye al jugador y suma al equipo. Los acumulados individuales se conservan durante todos los cuartos y prórrogas; los del equipo cumplen el reinicio descrito arriba.
4. Al llegar a 00:00, el reloj no pasa a valores negativos y se activa la alerta.
5. Al reabrir la aplicación se recuperan nombres, marcador, faltas, período y estado guardado del reloj.
6. Se puede completar un partido en modo avión.

## Fuera del alcance inicial
Técnicas del entrenador y personal del banco, acta oficial completa, asignación automática de sanciones, estadísticas de tiro por jugador, historial de varios partidos, exportaciones y sincronización. Se ofrecen doce posiciones de jugadores editables por equipo.

## Entrega prevista
Código fuente del proyecto Flutter/Android y APK de prueba instalable en la carpeta `entrega`. La firma de desarrollo sirve para instalación directa; la publicación en una tienda requerirá una firma de distribución propia.

## Referencia de reglas
Reglas Oficiales FIBA 2024, edición v1.0a publicada en el portal oficial consultado: artículos 8, 29, 36, 37, 40, 41, 49 y 50.
https://assets.fiba.basketball/image/upload/documents-corporate-fiba-official-rules-2024-v10a.pdf
La aplicación es una herramienta de conteo: el árbitro determina la sanción. Para una falta de un sustituto debe desactivarse «Jugador en cancha» para que no incremente las faltas de equipo.


