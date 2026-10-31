# Pruebas de oficina automatización y progreso

Actualizado: 31 de octubre de 2026.

## Suites

- run_tests.gd: 35 comprobaciones del comportamiento manual original. Los componentes nuevos se desactivan en esta fixture para aislar regresiones.
- economy_tests.gd: 40 comprobaciones de economía y guardado. El catálogo ahora contiene cuatro mejoras.
- office_tests.gd: 44 comprobaciones con movimiento, automatismos y progresión conectados.

La suite nueva comprueba reserva de papeles, imposibilidad de agarrar o sellar en tránsito, pausa, centro ocupado, llegada centrada, espera del golpe, retirada automática, siguiente papel con sello cogido, guardado del destino, velocidad ×1,4, reinicio durante traslado, sello apoyado como obstáculo, E para levantarse, movimiento real con colisión de mesa, mirada, cursor y pausa, retorno a la mesa, recogida de lotes, capacidad, persistencia de carga, sobres, pausas del proceso, pago doble, pago único, reversión ante error de escritura, migración v1→v2, cambios repetidos de modo y una tanda completa automática que se vende y se repone.

Godot 4.7.2, renderizador Compatibility. Prueba gráfica a 960 × 600 y capturas revisadas a 1280 × 800 en NVIDIA GTX 1060 Max-Q. Sin otras GPUs ni sistemas operativos verificados.

Los datos de prueba se escriben únicamente en tests/.tmp. Las capturas usan progresión sin persistencia. No se modifica la partida de saves.

## Revisión manual propuesta

1. Abrir Jugar.cmd. Esperar a que el primer papel llegue al centro.
2. Coger el sello, mantenerlo sobre el centro y sellar tres veces, esperando entre golpes. Cada papel debe ir a la derecha y el siguiente llegar solo.
3. Intentar coger un papel que viaja, pausar en mitad del traslado y reanudar. No debe perderse ni duplicarse.
4. Dejar el sello. Cobrar la salida y verificar la reposición de tres papeles.
5. Comprar Tramitación ágil. Comparar la siguiente tanda; el desplazamiento debe ser más rápido. Usar la rueda en la tienda para llegar a la cuarta ficha.
6. Completar otra tanda y pulsar E. Caminar con WASD, mirar con el ratón y comprobar que mesa y paredes bloquean el paso.
7. Acercarse al frente derecho y pulsar E en Recogida. La carga debe mostrar hasta 3; los papeles recogidos ya no deben estar disponibles en la mesa.
8. Rodear la mesa por la derecha y llegar a Sobres. E inicia el proceso; no se puede caminar mientras termina. Pausar y reanudar.
9. Ir a Expedición al fondo izquierdo y pulsar E. La carga desaparece, el saldo sube al doble y repetir E no paga otra vez.
10. Volver al frente central y pulsar E. La cámara fija y el cursor deben recuperarse.
11. Cerrar con carga, abrir y levantarse: la carga debe seguir ahí. Cerrar durante ensobrado conserva los documentos sin convertir, para repetir el proceso.
12. Cargar una partida de la entrega anterior: conservar saldo, niveles y documentos; inventario inicial vacío.

## Límites

Automatismo de mesa activo desde el inicio. Sobres y expedición disponibles sin compra. Capacidad fija de 3; todavía no hay empleados, caminos automáticos, mejoras de carga, saltos, carrera, sensibilidad configurable ni sonidos. Al cargar, el jugador vuelve a la mesa y los traslados se resuelven al destino. La comodidad del paseo y el equilibrio necesitan valoración jugando.
