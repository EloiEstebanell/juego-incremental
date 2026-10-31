# Añadir y equilibrar mejoras

Las definiciones son recursos compartidos e inmutables durante la partida. Los niveles comprados se guardan por identificador estable en el estado de la economía, nunca en los recursos.

## Añadir una mejora con efectos existentes

1. Abre el proyecto en Godot 4.7.2.
2. Duplica resources/upgrades/paper_quality.tres desde FileSystem y cambia el nombre del archivo.
3. Cambia id por un identificador único y estable. Configura title, description, initial_cost, cost_growth y max_level.
4. En effects, haz únicos los subrecursos antes de editarlos si duplicaste desde el inspector. Cada UpgradeEffect ofrece Attribute y Operation enumerados, además de amount. Puedes combinar varios efectos.
5. Abre resources/upgrade_catalog.tres y añade el nuevo recurso al array upgrades.
6. Ejecuta el juego, comprueba la ficha y prueba la compra con saldo suficiente.

No hace falta modificar el evaluador ni escribir una condición por identificador. Se ha verificado un recurso adicional serializado a .tres, cargado en un catálogo ampliado y comprado mediante el servicio común. La prueba automatizada no sustituye probar este flujo manualmente en el inspector.

## Efectos que funcionan en esta entrega

| Attribute | Base | ADD | MULTIPLY |
| --- | --- | --- | --- |
| DOCUMENT_VALUE | 100 unidades | Suma amount por nivel | Multiplica por amount elevado al nivel |
| STAMP_MULTIPLIER | 1 | Suma amount por nivel | Multiplica por amount elevado al nivel |
| STROKE_DURATION | 0,27 segundos | Suma segundos por nivel | Multiplica por amount elevado al nivel |
| PAPER_SPEED | 2,5 unidades de espacio por segundo | Suma velocidad por nivel | Multiplica velocidad por amount elevado al nivel |

Fórmula por atributo: (base + suma de aportes aditivos) × producto de factores multiplicativos. La duración se limita a un mínimo de 0,05 s. Los valores monetarios máximos se limitan para evitar desbordamientos en el prototipo.

Pago = valor efectivo del documento × multiplicador efectivo del sello, redondeado una vez a unidades enteras internas. 10.000 unidades equivalen a 1 euro; 100 unidades equivalen a 1 céntimo. Así se conservan fracciones de céntimo. El pago de 675 unidades aparece como 0,0675 euros. La precisión máxima por venta es 0,0001 euros.

El coste usa ceil(initial_cost × cost_growth elevado al nivel actual), expresado en esas mismas unidades. No confundir el factor 1,1 con sumar 1,1. Para un golpe un 20 % más rápido se utiliza factor 0,8 sobre duración.

## Requisitos y validación

prerequisite contiene el identificador estable de otra mejora; prerequisite_level define el nivel exigido. Sin requisito, deja el identificador vacío. La tienda muestra la razón por la que no puede comprarse. El catálogo comprueba IDs duplicados o vacíos, efectos inválidos, costes no positivos, niveles, referencias inexistentes, requisitos inalcanzables y ciclos.

Todos los recursos del catálogo son visibles. Todavía no se implementan requisitos múltiples, ocultación por estación, costes por tabla ni efectos de capacidad/desbloqueo; se incorporarán junto con sus mecánicas. No ofrecer mejoras que no tengan efecto real. icon está disponible en el recurso, pero esta interfaz utiliza fichas de texto.

## Compatibilidad de partidas

No cambies un ID publicado para renombrar una mejora: modifica title. Retirar un recurso cuyo ID ya aparece en una partida bloqueará la carga y la escritura, preservando los archivos para una migración explícita. No se eliminan niveles desconocidos silenciosamente. Ajustar efectos y precios cambia el equilibrio al cargar, porque siempre se recalcula desde las bases.

Referencia de recursos personalizados: https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html .

## Tramitación ágil

resources/upgrades/paper_transport.tres utiliza PAPER_SPEED y MULTIPLY con amount 1,4, coste inicial 300 unidades monetarias, crecimiento 1,8 y seis niveles. El movimiento se calcula como distancia / velocidad efectiva. Afecta a entrada y salida de papeles; la duración de un trayecto ya iniciado no cambia durante ese trayecto. La ficha presenta una comparación temporal usando una distancia de referencia de 3,55.

El movimiento automático básico está disponible desde el inicio por petición del usuario. No es un desbloqueo comprado. La nueva mejora y sus niveles se guardan con el identificador estable paper_transport en el esquema 2; se conservan los IDs anteriores.
