# Taller práctico: HDFS y Hadoop MapReduce con Docker

**Autor:** Christian Medina

Clúster Hadoop 3.2.1 (HDFS + YARN + MapReduce) desplegado con Docker Compose sobre
Windows. Sobre él cargué tres datasets, ejecuté cuatro trabajos MapReduce, verifiqué sus
estados, logs y resultados, y probé la tolerancia a fallos apagando nodos y tareas.

> **Uso de IA:** me apoyé en Claude (asistente de IA de Anthropic), sobre todo para generar
> los scripts de Bash y de Python. El montaje del clúster, la ejecución de las pruebas,
> la revisión de los resultados y las observaciones de este documento son mías.

## Cumplimiento del taller

| Punto del taller | Dónde se cumple |
|---|---|
| 1. Clúster con NameNode, ≥ 2 DataNodes, YARN e interfaces web | `docker-compose.yml`, `hadoop.env`, `scripts/00_verificar_cluster.sh` |
| 1. Estructura en HDFS y carga de datos | `scripts/01_cargar_datos.sh` |
| 2. Al menos 3 jobs MapReduce (uno nativo) | Job 1 (Java nativo), jobs 2, 3 y 4 (Python con Hadoop Streaming) |
| 3. Estados, logs y salidas de los jobs | `job_fallido.sh`, `ver_logs_job.sh`, interfaces de YARN y JobHistory |
| 3. Validación manual de resultados | `scripts/validar.sh` |
| 4. Tolerancia a fallos | `scripts/fallas/` (DataNode apagado, tarea fallida, NodeManager apagado) |

## Arquitectura

| Contenedor | Rol | Interfaz web |
|---|---|---|
| `namenode` | Metadatos de HDFS (qué bloque está en qué nodo) | http://localhost:9870 |
| `datanode1`, `datanode2` | Almacenan los bloques (replicación = 2) | :9864, :9865 |
| `resourcemanager` | Asigna CPU y memoria a los jobs en YARN | http://localhost:8088 |
| `nodemanager1`, `nodemanager2` | Ejecutan las tareas Map y Reduce (imagen con Python 3) | :8042, :8043 |
| `historyserver` | Historial de jobs terminados | http://localhost:19888 |
| `datanode3` (opcional) | Tercer DataNode para observar la re-replicación | :9866 |

Configuración relevante (`hadoop.env`):

- Replicación de 2.
- **Bloques de 8 MB** en lugar de 128 MB, para que los archivos de prueba se dividan en varios bloques y se generen varias tareas Map.
- Tiempos de detección reducidos: un DataNode se declara muerto a los ~90 s y un NodeManager se marca como perdido a los ~60 s.

## Estructura del proyecto

```
taller-hadoop/
├── docker-compose.yml, hadoop.env, nodemanager/Dockerfile   ← clúster
├── datos/          ← datasets + generar_datos.py (semilla fija, siempre los mismos datos)
├── jobs/           ← mappers, reducers y combiner en Python
├── scripts/        ← carga, jobs, validación y logs (se ejecutan dentro del namenode)
│   └── fallas/     ← scripts de las pruebas de tolerancia a fallos
├── evidencias/     ← salidas de consola, resultados y logs de mis ejecuciones
└── capturas/       ← capturas de las interfaces web
```

**Datasets** (sintéticos, generados con `datos/generar_datos.py`):

| Archivo | Tamaño | Contenido |
|---|---|---|
| `textos/texto_01..03.txt` | 3 MB, 66.000 líneas | Frases en español |
| `logs/access.log` | 24 MB, 300.042 líneas | Una semana de logs de un servidor web, con 42 líneas dañadas |
| `ventas/ventas.csv` | 5 MB, 120.000 filas | Ventas en 8 ciudades de Colombia, con 25 filas inválidas |

## Cómo ejecutarlo

Requisitos: Docker Desktop (WSL 2, al menos 6 GB de RAM asignados). Los comandos se
ejecutan en PowerShell desde la carpeta del proyecto. También están como tareas de VS Code
(*Terminal ▸ Ejecutar tarea…*).

```powershell
# 1. Levantar y verificar el clúster
docker compose up -d --build
docker exec namenode bash /workspace/scripts/00_verificar_cluster.sh

# 2. Cargar los datos a HDFS
docker exec namenode bash /workspace/scripts/01_cargar_datos.sh

# 3. Jobs MapReduce
docker exec namenode bash /workspace/scripts/job1_wordcount.sh
docker exec namenode bash /workspace/scripts/job2_horas_pico.sh
docker exec namenode bash /workspace/scripts/job3_promedio_ventas.sh
docker exec namenode bash /workspace/scripts/job4_top_urls.sh

# 4. Job que falla a propósito y sus logs
docker exec namenode bash /workspace/scripts/job_fallido.sh
docker exec namenode bash /workspace/scripts/ver_logs_job.sh job_fallido

# 5. Validación manual
docker exec namenode bash /workspace/scripts/validar.sh

# Apagar (agregar -v para borrar también los datos de HDFS)
docker compose down
```

Cada script de job borra la salida anterior (MapReduce no sobrescribe carpetas), lanza el
job, guarda la consola en `evidencias/` y muestra el ID de la aplicación YARN con su
estado final.

## Jobs MapReduce

| # | Job | Tipo | Entrada → salida en HDFS |
|---|---|---|---|
| 1 | WordCount | Java nativo (jar de ejemplos de Hadoop) | `/taller/entrada/textos` → `/taller/salida/job1_wordcount` |
| 2 | Peticiones y errores 5xx por hora | Streaming, 2 reducers | `/taller/entrada/logs` → `/taller/salida/job2_horas_pico` |
| 3 | Ventas por ciudad: número, total, promedio, mínimo y máximo | Streaming | `/taller/entrada/ventas` → `/taller/salida/job3_promedio_ciudad` |
| 4 | Top 10 URLs más visitadas | Streaming con combiner y 1 reducer | `/taller/entrada/logs` → `/taller/salida/job4_top_urls` |
| ✗ | Job fallido (división entre cero) | Streaming | Termina en estado FAILED |

Los mappers de los jobs 2, 3 y 4 descartan las líneas mal formadas y las cuentan con
contadores propios de Hadoop (grupo `Taller`).

## Resultados obtenidos

**Job 1.** 133 palabras distintas. Las más frecuentes: *de* (148.154), *la* (71.391),
*el* (46.735), *en* (34.436) e *y* (27.195).

**Job 2.** Las horas pico son las 20h (27.303 peticiones), las 19h (26.387) y las 12h
(23.142). Entre las 19h y las 21h el porcentaje de errores 5xx sube a ~10 %, frente a
~3,5 % en el resto del día: en la hora de más tráfico el servidor se satura.

**Job 3.**

| Ciudad | Ventas | Total (COP) | Promedio (COP) |
|---|---:|---:|---:|
| Bogotá | 35.717 | 21.367.283.800 | 598.238 |
| Cartagena | 9.584 | 5.698.420.800 | 594.576 |
| Medellín | 21.770 | 12.301.687.600 | 565.075 |
| Barranquilla | 11.944 | 6.450.822.000 | 540.089 |
| Cali | 19.133 | 10.160.891.100 | 531.066 |
| Bucaramanga | 8.455 | 4.324.810.900 | 511.509 |
| Pereira | 7.259 | 3.656.141.200 | 503.670 |
| Manizales | 6.113 | 3.025.390.000 | 494.911 |

**Job 4.** `/` (60.195 visitas), `/productos` (28.311), `/carrito` (18.070),
`/buscar?q=cafe` (13.388), `/login` (10.272), `/static/css/main.css` (8.330),
`/static/js/app.js` (7.156), `/static/img/logo.png` (6.231), `/api/v1/productos` (5.363)
y `/checkout` (4.770).

**Job fallido.** YARN intentó la tarea 4 veces (`attempt_…_0` a `_3`) y el job terminó en
FAILED. En los logs aparece el `ZeroDivisionError` del mapper.

**Validación.** `validar.sh` recalcula los cuatro resultados con `awk` y `sort` sobre los
archivos originales, sin Hadoop, y los compara con la salida en HDFS. Los cuatro
coinciden (`[OK]`). Las líneas descartadas (42 de log y 25 de ventas) también coinciden
con los contadores de los jobs.

## Pruebas de tolerancia a fallos

| Prueba | Cómo la hice | Qué observé |
|---|---|---|
| DataNode apagado | `docker stop datanode2` y `fallas/estado_hdfs.sh` | Tras ~90 s: 1 nodo vivo y 1 muerto, bloques sub-replicados, `Status: HEALTHY` y los archivos se seguían leyendo completos. Al encenderlo, volvieron las 2 réplicas |
| Tarea Map interrumpida | Job 2 en modo lento + `fallas/fallar_tarea.sh` | El intento `_0` quedó FAILED, YARN lanzó el `_1` y el job terminó SUCCEEDED (JobHistory: 1 Map fallido) |
| Fallo permanente de una tarea | `job_fallido.sh` | 4 intentos fallidos y el job completo en FAILED |
| NodeManager apagado | Job 2 en modo lento + `docker stop nodemanager2` | El nodo pasó a LOST en YARN y sus tareas se relanzaron en `nodemanager1`. El job terminó bien |
| Reinicio de DataNode durante una escritura (extra) | `fallas/escritura_grande.sh` + `docker restart datanode1` | El cliente excluyó el nodo de la escritura y siguió. El checksum local y el de HDFS coinciden |

## Observaciones

- **El NameNode no detecta la caída de un DataNode de inmediato.** En una de mis pruebas lancé el job 3 justo después de apagar `datanode2` y el job falló sin escribir su salida. Durante ~90 s el NameNode todavía consideraba vivo al nodo y le seguía asignando bloques. Al encender de nuevo el nodo, el mismo job corrió sin problemas. Con el nodo ya declarado muerto, los jobs leen sin error de la réplica que queda.
- **Las páginas de los NodeManagers (`:8042`, `:8043`) solo muestran contenedores mientras se están ejecutando.** Para ver en qué nodo corrió cada tarea es más confiable la página de la aplicación en YARN (`:8088`) o `fallas/ver_contenedores_job.sh`.
- **El NameNode es el punto único de falla de esta configuración.** Si se apaga, HDFS deja de responder por completo. En producción se usa NameNode HA con ZooKeeper.

## Evidencias

- `evidencias/`: consola completa de cada job (`*_consola.txt`), resultados (`*_resultado.txt`), ID de cada aplicación YARN y logs del job fallido.
- `capturas/`: interfaces web de HDFS, YARN y JobHistory durante las pruebas.
