# Verificación de FISCORE 1.6.1

## Código y pruebas

- Análisis Flutter/Dart sin problemas y 70 pruebas automatizadas superadas.
- Se conservan las pruebas de reglas, exclusión, formatos, guardado, plantillas, nombres, dorsales y correcciones.
- Interfaz probada mediante widgets en 14 tamaños: 568 × 320, 844 × 390, 720 × 540, 568 × 280, 960 × 600, 640 × 320, 640 × 360, 700 × 240, 800 × 360, 1366 × 768, 1000 × 450, 1024 × 600, 1280 × 800 y 1920 × 1080. Texto al 130 % y 160 %, nombres largos y teclado simulado de 200 px.
- En los nueve tamaños añadidos se pulsan puntos, faltas, edición de dorsal, configuración, copia de correo y ampliación del QR. Se comprueba que los controles estén accesibles y no haya errores de distribución.
- Inicio solicita únicamente landscapeLeft/landscapeRight. Manifest Android sensorLandscape, con compatibilidad para respetar la restricción al apuntar a API 36. Redimensionamiento entre ventanas horizontales conservando distribución lateral, puntuación y flecha.
- Reloj monotónico controlado en pruebas: el reloj principal y la posesión descuentan exactamente un segundo mientras están abiertos faltas, plantillas, créditos, reglas, ajustes de posesión y confirmación de nuevo partido. Registrar/corregir faltas y cambiar de pestaña o flecha tampoco los pausa.
- Cancelar el ajuste de posesión conserva la cuenta en marcha; guardar aplica el ajuste y ambos relojes siguen avanzando.
- Perder temporalmente el foco no pausa; ocultar la app sí pausa y al volver no se inicia sola. PAUSAR detiene explícitamente la cuenta. El fin de período funciona con un panel abierto.
- Flecha independiente de puntos, faltas y 24/14 s; se conserva al avanzar período y serializar. Guardados antiguos sin flecha siguen siendo válidos. Finalizar bloquea cambios y un nuevo partido borra la flecha.

## Revisión visual y recursos

- Capturas de widgets revisadas en tablet: distribución del tablero y QR completo ampliable. No son capturas de una tablet física.
- La imagen de Yape se copia del archivo entregado por el usuario y se incluye localmente; no se regenera ni se cambia su contenido.
- El contacto visible y copiable es ma.garciavi@unsm.edu.pe. Se retiró el teléfono de la pantalla de créditos y de las instrucciones actuales.

## APK

- Compilación Android release, versión 1.6.1, código 8, paquete pe.marti.score_basquet.
- Se verificó con apksigner la misma firma de desarrollo que en fiscore-v1.5.0.apk.
- FISCORE.apk y fiscore-v1.6.1.apk contienen la misma entrega; SHA-256 en SHA256.txt.
- La actualización conserva el almacenamiento de partido y plantillas al instalar sin desinstalar.

## Límite de la verificación

Esta actualización tiene pruebas automatizadas, revisión visual de widgets y compilación Android. No se ha probado esta versión en la tablet física del usuario ni se ha realizado una donación. La lectura del QR con la cámara de Yape y el tamaño táctil percibido deben confirmarse en la tablet real.
