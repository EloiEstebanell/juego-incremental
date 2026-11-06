# Estado del desarrollo

5 de noviembre de 2026. Cuarta entrega local, implementada y comprobada automáticamente; pendiente de valoración del jugador.

Las tres primeras estaciones están conectadas: sellado y envío iniciales; ensobrado comprado tras un hito propio y con venta ×2. Recepción periódica (5 s base), entradas/salidas independientes, transporte parcial y recogida respetando capacidad. R ordena sin reponer ni eliminar material.

Árbol de 25 mejoras Resource/.tres en ocho ramas. Costes, hitos de ventas, requisitos de nivel y contratación alternativa por atributo. Se conservan todos los IDs anteriores. Se compran por separado puesto, tres operarios y tres rutas. Velocidades de tarea, movimiento del papel, jugador y transportistas son efectos distintos.

Sellador, ensobrador y expedidor funcionan automáticamente al contratarse. Transportistas con ida/vuelta, carga persistente, reserva de destino y ruta fija por pasillos. La ruta directa puede pausarse para priorizar la cadena con sobres. Se muestra trabajo y espera. Los personajes son figuras provisionales.

Guardado esquema 3: migración de 1/2, conservación de documentos/carga, colas, tareas, rutas y reservas. Validación de cantidades y capacidades, transacciones revertidas ante escritura fallida. Los temporizadores se guardan también cada 5 segundos. No producción offline.

Comprobaciones: suites de mesa, economía y oficina conservadas; nueva suite de estaciones con primera venta manual real, diez minutos de cadena automática, conservación de cantidades, capacidad, conflictos jugador/repartidor, rollback, recarga real, migración, compra con ratón y reinicio. Capturas reales del árbol, oficina y envío revisadas a 1280×800; prueba gráfica adicional a 960×600.

Pendiente: equilibrio observado jugando por otra persona, arte/animaciones/sonidos, sensibilidad configurable, más rutas y navegación dinámica, exportación optimizada. Las mejoras y trabajadores están implementados; no implica acabado comercial ni valoración externa completada. Publicación v0.4.0 preparada el 6 de noviembre de 2026, con las tres estaciones y el ajuste posterior de proporciones.

Resultado final: 35 + 40 + 44 + 67 = 186 comprobaciones, todas correctas. La suite de estaciones también pasó con renderizado gráfico a 960×600.

## Ajuste de proporciones y galería · 5 de noviembre de 2026

Mesa de sellado en oficina: 2,04 × 1,12 m, altura aproximada 0,77 m. La vista sentada conserva el primer plano para manipular el sello; los papeles guardan las mismas coordenadas locales y no necesitan migración. Oficina compacta, mostradores de 1,90 × 1,00 m, colisiones, interacción y rutas adaptadas. Regresión de dimensiones, pasillo lateral transitable, guardado local y recuperación de cámara de trabajo.

13 capturas reales a 1440×900 en docs/galeria/index.html, obtenidas con tools/capture_gallery.gd sin persistencia. Incluyen golpe de sello, salida marcada, ensobrado en curso/terminado, venta y árbol. En este prototipo el ensobrado sigue siendo panel y temporizador; todavía no se anima la introducción física de la carta.

Resultado tras el ajuste: 35 + 40 + 48 + 67 = 190 comprobaciones. La suite de oficina se comprueba también con renderizador gráfico. Pendiente de valoración de comodidad por el jugador.
