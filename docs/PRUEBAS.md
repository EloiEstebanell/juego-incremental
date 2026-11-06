# Pruebas de las tres estaciones

5 de noviembre de 2026. Godot 4.7.2, Compatibility, NVIDIA GTX 1060 Max-Q.

## Suites

- run_tests.gd: 35 comprobaciones de mesa.
- economy_tests.gd: 40 de economía, catálogo y guardado.
- office_tests.gd: 44 de movimiento y automatismos anteriores.
- station_tests.gd: integración de las estaciones, árbol y personal. Incluye diez minutos simulados conservando cada carta, primera venta con sellado manual real, recarga de una escena, migración v2→v3, reservas y guardado fallido, límites de bandejas y compras desde botones.

Las primeras tres fixtures desactivan el nuevo sistema para aislar regresiones; la suite de estaciones conecta todos los componentes nuevos. Usan tests/.tmp y no modifican saves/progress.json. Capturas en tools/capture_stations.gd con persistencia desactivada.

## Recorrido del jugador

1. Abrir Jugar.cmd. Coger el sello y sellar. Recoger la salida; comprobar que el saldo no aumenta todavía.
2. E para levantarse. Rodear la mesa hasta ENVÍO, fondo izquierda. E abre panel: depositar, preparar una carta, despachar y cobrar. Comprobar pago único.
3. Volver a sellar. Observar llegada cada cinco segundos; entrada llena detiene recepción. R conserva cartas y no genera otra tanda.
4. M abre árbol. Probar botones de ramas, desplazamiento, compra y bloqueo por requisito. Recepción, entrada/salida y carga cambian por separado.
5. Tras 10 ventas y 0,15 €, comprar ENSOBRADO. Depositar cartas selladas en el fondo derecho, ensobrar, recoger y vender en envío. Precio doble.
6. Llenar una entrada más allá de su capacidad: sobrante en manos. Llenar una salida: proceso espera sin consumir entrada.
7. Contratar operarios y las rutas por separado. Dejar el sello en su soporte para que trabaje el sellador. Observar carga, regreso y espacio reservado de los transportistas.
8. Pausar ruta directa desde envío y comprobar cadena sello→sobres→envío. El viaje ya iniciado termina. M/Esc detienen trabajo en pausa; abrir el panel de una estación deja trabajar a los operarios.
9. Cerrar con carga y transportistas en marcha; reabrir. Conservar inventario, bandejas, reservas y dinero. El jugador aparece sentado.

## Límites de la validación

Pruebas automáticas y capturas reales revisadas. No se ha hecho una sesión externa prolongada ni evaluado el ritmo de las compras con otra persona. No otras GPUs ni sistemas operativos. Personal y rutas usan geometría provisional y caminos predefinidos; sin colisiones entre empleados.

Resultado final: 35 + 40 + 44 + 67 = 186 comprobaciones, todas correctas. La suite de estaciones también pasó con renderizado gráfico a 960×600.

## Ajuste de proporciones y galería · 5 de noviembre de 2026

Mesa de sellado en oficina: 2,04 × 1,12 m, altura aproximada 0,77 m. La vista sentada conserva el primer plano para manipular el sello; los papeles guardan las mismas coordenadas locales y no necesitan migración. Oficina compacta, mostradores de 1,90 × 1,00 m, colisiones, interacción y rutas adaptadas. Regresión de dimensiones, pasillo lateral transitable, guardado local y recuperación de cámara de trabajo.

13 capturas reales a 1440×900 en docs/galeria/index.html, obtenidas con tools/capture_gallery.gd sin persistencia. Incluyen golpe de sello, salida marcada, ensobrado en curso/terminado, venta y árbol. En este prototipo el ensobrado sigue siendo panel y temporizador; todavía no se anima la introducción física de la carta.

Resultado tras el ajuste: 35 + 40 + 48 + 67 = 190 comprobaciones. La suite de oficina se comprueba también con renderizador gráfico. Pendiente de valoración de comodidad por el jugador.
