# Catálogo de mejoras

Las 25 definiciones son Resource/.tres inmutables. Niveles por ID estable en Economy. Para añadir una mejora, duplicar una definición, dar un ID nuevo, configurar efectos y requisitos y añadirla a upgrade_catalog.tres. El evaluador y las compras no distinguen IDs concretos.

Fórmula: (base + suma de ADD × nivel) × producto de MULTIPLY elevado a nivel. Coste: ceil(initial_cost × cost_growth^nivel). 10.000 unidades monetarias = 1 €. El pago aplica valor y multiplicador vigentes al despachar; sobres ×2. Cantidades se redondean a enteros; las definiciones actuales suman plazas enteras. No modificar IDs publicados sin migración.

## Atributos y bases

| Índice | Atributo | Base |
| --- | --- | --- |
| 0 | DOCUMENT_VALUE | 100 unidades monetarias |
| 1 | STAMP_MULTIPLIER | 1 |
| 2 | STROKE_DURATION | 0,27 s |
| 3 | PAPER_SPEED | 2,5 m/s |
| 4 | ARRIVAL_TIME | 5 s |
| 5–10 | Entradas/salidas de sello, sobres y envío | 3 plazas por bandeja |
| 11 | CARRY | 3 cartas |
| 12 | WALK_SPEED | 3,6 m/s |
| 13 | ENVELOPES_UNLOCK | 0; se abre al llegar a 1 |
| 14–16 | Operarios de sello, sobres y envío | 0; contratados al llegar a 1 |
| 17–19 | Rutas directa, a sobres y de sobres a envío | 0; contratadas al llegar a 1 |
| 20 | STAMP_WORK_TIME | 2,4 s |
| 21 | ENVELOPE_TIME | 1,5 s |
| 22 | SHIPPING_TIME | 1,2 s |
| 23 | COURIER_SPEED | 2,8 m/s |
| 24 | COURIER_CARRY | 2 cartas |

Los desbloqueos usan ADD=1 y max_level=1. Duraciones y velocidades actuales tienen factores positivos y límites de nivel finitos. Llegada usa ×0,8 por nivel; movimiento en mesa ×1,4; carga jugador +2; bandejas +3. Duración de tarea y duración de viaje se fijan al comenzar; compras afectan el siguiente trabajo.

## Requisitos y árbol

- prerequisite/prerequisite_level: dependencia de nivel por ID.
- required_sales: hito de cartas vendidas, además del coste.
- required_any_effects: basta que uno de esos atributos evaluados desde base 0 alcance 1. Las mejoras de repartidores aceptan cualquiera de las tres contrataciones; required_any_label explica el bloqueo.
- branch: una de Llegadas, Almacenes, Transporte, Valor, Sellado, Ensobrado, Envío, Rutas.
- tree_row: fila de la ficha dentro de su rama. Mantener posiciones distintas. Requisitos entre ramas se indican por texto; dentro de una rama también se dibujan flechas.

El catálogo valida IDs, referencias, ciclos, efectos y costes. La tienda utiliza el mismo evaluador que la simulación, muestra antes/después y permite comprar un nivel si coinciden el nivel esperado, saldo y requisitos. Nueva mecánica puede necesitar nuevo atributo; cambiar magnitudes/costes o combinar efectos existentes no requiere modificar el código.

El límite de guardado corresponde al catálogo actual: manos ≤30, colas ≤100 y papeles en mesa ≤64, además de las capacidades efectivas. Si amplías niveles/capacidades por encima de esos límites, actualiza validación y migración antes de distribuir.
