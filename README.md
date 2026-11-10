# Taller práctico: HDFS y Hadoop MapReduce con Docker

Clúster Hadoop 3.2.1 completo en tu PC con Windows, manejado desde VS Code.

```
taller-hadoop/
├── docker-compose.yml        ← define los 8 contenedores del clúster
├── hadoop.env                ← configuración de Hadoop (replicación, memoria, etc.)
├── nodemanager/Dockerfile    ← NodeManager + Python (para Hadoop Streaming)
├── datos/                    ← datasets (ya generados) + generar_datos.py
│   ├── textos/   texto_01..03.txt  (~3 MB, frases en español)
│   ├── logs/     access.log        (~24 MB, 300.042 líneas, 1 semana de tráfico web)
│   └── ventas/   ventas.csv        (~5 MB, 120.000 ventas en 8 ciudades)
├── jobs/                     ← mappers / reducers en Python
├── scripts/                  ← todo lo que se ejecuta dentro del clúster
│   └── fallas/               ← scripts para las pruebas de tolerancia a fallos
├── evidencias/               ← aquí quedan guardadas las salidas (para el informe)
└── .vscode/tasks.json        ← atajos: Terminal ▸ Ejecutar tarea…
```

## Arquitectura

```
                    ┌──────────────── HDFS (almacenamiento) ───────────────┐
                    │  namenode :9870   ← "índice": qué bloque está dónde   │
                    │     ├── datanode1 :9864   ← guardan los bloques       │
                    │     └── datanode2 :9865      (cada bloque x2 réplicas)│
                    └──────────────────────────────────────────────────────┘
                    ┌──────────────── YARN (cómputo) ──────────────────────┐
                    │  resourcemanager :8088  ← reparte CPU/RAM a los jobs  │
                    │     ├── nodemanager1 :8042  ← ejecutan las tareas     │
                    │     └── nodemanager2 :8043     Map y Reduce           │
                    │  historyserver :19888   ← historial de jobs terminados│
                    └──────────────────────────────────────────────────────┘
```

---

## 0. Requisitos (una sola vez)

1. **Docker Desktop** para Windows, con el motor **WSL 2** (la opción por defecto al instalar).
   En *Settings ▸ Resources* deja al menos **6 GB de RAM** para Docker (8 GB ideal).
2. **VS Code** con la extensión de contenedores de Microsoft (*Container Tools* / *Docker*).
   VS Code te la sugerirá al abrir la carpeta.
3. ~4 GB libres en disco (las imágenes se descargan la primera vez).

Abre **Docker Desktop** y espera a que diga *Engine running*.

## 1. Levantar el clúster

1. Descomprime el zip y en VS Code: **Archivo ▸ Abrir carpeta…** → `taller-hadoop`.
2. Abre una terminal: **Terminal ▸ Nueva terminal** (es PowerShell, está bien).
3. Ejecuta:

```powershell
docker compose up -d --build
```

La primera vez tarda (descarga ~1.5 GB y construye la imagen del NodeManager con Python).
Luego revisa el estado:

```powershell
docker compose ps
```

Espera 1–2 minutos hasta que todos digan **`(healthy)`**. Si alguno dice `Exited`, mira
la sección *Problemas comunes*.

> 💡 Todos los comandos de esta guía también están en **Terminal ▸ Ejecutar tarea…**

### 1.1 Validar servicios

```powershell
docker exec namenode bash /workspace/scripts/00_verificar_cluster.sh
```

Debes ver: `Safe mode is OFF`, `Live datanodes (2)`, dos NodeManagers `RUNNING`
y la prueba de escritura/lectura en HDFS imprimiendo "hola HDFS…".

> `docker exec namenode …` = "ejecuta este comando **dentro** del contenedor namenode".
> La carpeta del proyecto se ve dentro del contenedor como `/workspace`.

### 1.2 Interfaces web (ábrelas en el navegador)

| Servicio | URL | Qué mirar |
|---|---|---|
| HDFS NameNode | http://localhost:9870 | *Overview*: Live/Dead Nodes. *Datanodes*. *Utilities ▸ Browse the file system* |
| YARN ResourceManager | http://localhost:8088 | *Nodes* (los 2 NodeManagers), *Applications* (los jobs y su estado) |
| JobHistory Server | http://localhost:19888 | Jobs terminados, sus tareas Map/Reduce, contadores |
| NodeManager 1 / 2 | http://localhost:8042 · :8043 | Contenedores corriendo en cada nodo |
| DataNode 1 / 2 | http://localhost:9864 · :9865 | Estado de cada DataNode |

> Algunos enlaces dentro de las páginas apuntan a nombres como `nodemanager1:8042`; esos
> no abren desde Windows (son nombres internos de Docker). Cambia el nombre por
> `localhost` y el puerto que corresponde de la tabla, o usa los scripts de logs.

---

## 2. Cargar los datos a HDFS

```powershell
docker exec namenode bash /workspace/scripts/01_cargar_datos.sh
```

Estructura que queda en HDFS:

```
/taller/entrada/textos/   texto_01.txt  texto_02.txt  texto_03.txt
/taller/entrada/logs/     access.log      (3 bloques de 8 MB, cada uno con 2 réplicas)
/taller/entrada/ventas/   ventas.csv
/taller/salida/           (aquí escribe cada job su carpeta de resultados)
```

Comandos HDFS útiles (dentro del namenode: `docker exec -it namenode bash`):

```bash
hdfs dfs -ls /taller/entrada            # listar
hdfs dfs -ls -R /taller                 # listar recursivo
hdfs dfs -cat /taller/entrada/ventas/ventas.csv | head   # ver contenido
hdfs dfs -du -h /taller                 # tamaño
hdfs fsck /taller -files -blocks -locations   # bloques y en qué DataNode están
```

---

## 3. Los trabajos MapReduce

| # | Job | Tipo | Entrada | Salida en HDFS | Qué calcula |
|---|---|---|---|---|---|
| 1 | WordCount | **Nativo (Java)** | `/taller/entrada/textos` | `/taller/salida/job1_wordcount` | Frecuencia de cada palabra |
| 2 | Horas pico | Streaming (Python) | `/taller/entrada/logs` | `/taller/salida/job2_horas_pico` | Peticiones y errores 5xx por hora |
| 3 | Promedio por clave | Streaming (Python) | `/taller/entrada/ventas` | `/taller/salida/job3_promedio_ciudad` | Nº ventas, total, promedio, mín, máx por ciudad |
| 4 | Top N | Streaming + **combiner** | `/taller/entrada/logs` | `/taller/salida/job4_top_urls` | Las 10 URLs más visitadas |
| ✗ | Job fallido | Streaming | ventas | `/taller/salida/job_fallido` | Falla a propósito → estado **FAILED** |

Ejecuta cada uno:

```powershell
docker exec namenode bash /workspace/scripts/job1_wordcount.sh
docker exec namenode bash /workspace/scripts/job2_horas_pico.sh
docker exec namenode bash /workspace/scripts/job3_promedio_ventas.sh
docker exec namenode bash /workspace/scripts/job4_top_urls.sh
docker exec namenode bash /workspace/scripts/job_fallido.sh
```

Cada script: borra la salida anterior (MapReduce **no** sobrescribe carpetas), lanza el
job, guarda toda la consola en `evidencias/jobX_consola.txt`, muestra el ID de la
aplicación YARN y su estado final, y lista la salida con `hdfs dfs -ls` / `-cat`.

**Resultados esperados** (los datos son siempre los mismos):

- Job 2: horas pico **20h** (27.303 peticiones), **19h** (26.387) y **12h** (23.142).
  En 19–21h el % de errores 5xx sube a ~10% (el servidor se satura); en las demás horas ~3,5%.
- Job 3: Bogotá tiene más ventas (35.717) y el ticket promedio más alto (~598.238 COP).
  Se descartan 25 filas inválidas.
- Job 4: `/` con 60.195 visitas, luego `/productos` (28.311) y `/carrito` (18.070).
- En los jobs 2 y 4 se descartan **42 líneas** de log mal formadas (contador `Taller ▸ LineasMalformadas`).

### Cómo leer la consola de un job

```
Submitted application application_1731..._0003     ← ID en YARN
Running job: job_1731..._0003
 map 0% reduce 0%  →  map 100% reduce 100%           ← progreso
Job job_1731..._0003 completed successfully          ← SUCCEEDED
Counters:
   Launched map tasks=3                               ← 1 Map por bloque de 8 MB
   Map input records=300042
   Map output records=300000
   Taller
       LineasMalformadas=42                           ← contadores propios
```

---

## 4. Verificar la ejecución de los jobs

**a) Estados en YARN.** En http://localhost:8088 ▸ *Applications* verás cada job con
`State` y `FinalStatus`. Lanza el job 2 en modo lento y mira la página mientras corre:

```powershell
docker exec namenode bash /workspace/scripts/job2_horas_pico.sh 1
```
`ACCEPTED → RUNNING → FINISHED / SUCCEEDED`. El job fallido termina `FINISHED / FAILED`.

Por línea de comandos (dentro del namenode):
```bash
yarn application -list -appStates ALL     # todos los jobs con su estado
yarn application -status application_XXXX_YYYY
mapred job -status job_XXXX_YYYY          # incluye contadores
```

**b) Logs de los jobs.**
```powershell
docker exec namenode bash /workspace/scripts/ver_logs_job.sh                         # lista los IDs
docker exec namenode bash /workspace/scripts/ver_logs_job.sh application_XXXX_YYYY  # descarga logs
```
Queda el log completo en `evidencias/logs_application_….txt`. Para el job fallido verás
el `Traceback` de Python con `ZeroDivisionError` y los 4 intentos de la tarea.

**c) Logs de los contenedores (servicios).**
```powershell
docker logs namenode --tail 50
docker logs resourcemanager --tail 50
docker logs -f nodemanager1        # -f = en vivo, Ctrl+C para salir
```

**d) Salidas en HDFS.**
```bash
hdfs dfs -ls /taller/salida/job2_horas_pico     # _SUCCESS + part-00000 + part-00001
hdfs dfs -cat /taller/salida/job2_horas_pico/part-*
```
El archivo vacío `_SUCCESS` indica que el job terminó bien. El job 2 usa 2 reducers →
2 archivos `part-`.

**e) Validación manual de resultados.**
```powershell
docker exec namenode bash /workspace/scripts/validar.sh
```
Recalcula cada resultado con `awk` y `sort` sobre los archivos originales (sin Hadoop) y
compara con HDFS. Debe salir `[OK]` en los 4 jobs.

---

## 5. Tolerancia a fallos

Necesitas **dos terminales** en VS Code (botón **+** del panel de terminal). En los
experimentos uno observa y el otro rompe cosas. Para mirar HDFS en vivo:

```powershell
docker exec -it namenode bash /workspace/scripts/fallas/estado_hdfs.sh --seguir
```

### Experimento A — Apagar un DataNode (replicación en HDFS)

1. Estado inicial: `Live datanodes (2)`, `Status: HEALTHY`, cada bloque con 2 réplicas.
2. Terminal 2: `docker stop datanode2`
3. Observa: durante ~90 s el NameNode aún lo cree vivo (*Last contact* crece). Luego:
   `Live datanodes (1)`, `Dead datanodes (1)`; en http://localhost:9870 aparece en *Dead Nodes*.
   `fsck` muestra **Under-replicated blocks** > 0, pero `Status: HEALTHY` y 0 Missing.
4. Prueba que **los datos siguen accesibles**:
   `docker exec namenode hdfs dfs -cat /taller/entrada/ventas/ventas.csv | more`
   Incluso puedes correr un job: funciona leyendo de la réplica que queda.
5. `docker start datanode2` → vuelve a `Live (2)` y los bloques vuelven a 2 réplicas.

**Por qué:** cada bloque está en 2 DataNodes; si uno muere, el otro tiene copia. El
NameNode detecta la muerte por falta de *heartbeats* (latidos cada 3 s).

### Experimento B — Re-replicación con un tercer DataNode (opcional, muy ilustrativo)

```powershell
docker compose --profile extra up -d datanode3
docker stop datanode2
```
Ahora, al morir `datanode2`, el NameNode **copia automáticamente** los bloques
sub-replicados a `datanode3`. Con `estado_hdfs.sh --seguir` verás *Under-replicated*
bajar a 0 sin que nadie haga nada. Luego `docker start datanode2` (quedarán bloques con
3 copias; HDFS borrará las sobrantes: *over-replicated*).

### Experimento C — Reiniciar un DataNode durante una escritura

Terminal 1:
```powershell
docker exec namenode bash /workspace/scripts/fallas/escritura_grande.sh
```
Terminal 2, apenas diga "Subiendo a HDFS…":
```powershell
docker restart datanode1
```
Observa en la terminal 1 avisos tipo `Exception in createBlockOutputStream` /
`Excluding datanode`: el cliente saca al nodo caído de la *pipeline* y sigue escribiendo
en el otro. Al final el checksum local y el de HDFS **coinciden**: no se perdió nada.

### Experimento D — Detener un NodeManager mientras corre un job (reintentos en YARN)

Terminal 1 (job lento, ~2 min):
```powershell
docker exec namenode bash /workspace/scripts/job2_horas_pico.sh 1
```
Terminal 2, a los ~30 s:
```powershell
docker exec namenode bash /workspace/scripts/fallas/ver_contenedores_job.sh
docker stop nodemanager2
```
Observa:
- http://localhost:8088 ▸ *Nodes*: tras ~60 s `nodemanager2` pasa a **LOST**.
- En la consola del job aparecen intentos `KILLED`/`FAILED` y YARN **relanza esas tareas
  en nodemanager1** (verás `attempt_…_m_00000X_1`). El job termina **SUCCEEDED**.
- Si apagaste justo el nodo donde estaba el **ApplicationMaster** (contenedor `_000001`),
  YARN crea un **segundo intento del AM** (`appattempt_…_000002`) que recupera las tareas
  ya terminadas. Vale la pena probar ambos casos.
- Al final: `docker start nodemanager2`.

### Experimento E — Interrumpir una tarea Map en plena ejecución

Terminal 1: `docker exec namenode bash /workspace/scripts/job2_horas_pico.sh 1`

Terminal 2:
```powershell
docker exec namenode bash /workspace/scripts/fallas/fallar_tarea.sh
```
Mata un intento de Map → YARN lo reintenta (`_0 FAILED` → `_1`) y el job termina bien.
Con `--hasta-fallar` se mata la misma tarea 4 veces → se agotan los reintentos
(`mapreduce.map.maxattempts = 4`) → el job entero queda **FAILED**.

Otra forma "física": `docker pause nodemanager1` (congela el nodo) y luego
`docker unpause nodemanager1`.

### Experimento F (para pensar) — Apagar el NameNode

`docker stop namenode` → nada de HDFS funciona (ni `ls`). Es el **punto único de falla**
de esta configuración. En producción se usa *NameNode HA* (dos NameNodes + ZooKeeper).
Al encenderlo (`docker start namenode`) entra un rato en **safe mode** mientras los
DataNodes le reportan sus bloques: `hdfs dfsadmin -safemode get`.

---

## 6. Evidencias sugeridas para el informe

- [ ] `docker compose ps` con todos los contenedores *healthy*
- [ ] Captura de http://localhost:9870 (Live Nodes = 2) y de http://localhost:8088 ▸ Nodes
- [ ] `hdfs dfs -ls -R /taller` y el `fsck` con bloques y réplicas
- [ ] Para cada job: captura de *Applications* en YARN (SUCCEEDED), la salida `-cat` y los contadores
- [ ] Job fallido: estado FAILED + fragmento del log con el error
- [ ] Salida de `validar.sh` con los 4 `[OK]`
- [ ] Cada experimento de fallos: captura **antes / durante / después** (Dead Nodes,
      Under-replicated, nodo LOST, intentos `_1`)
- [ ] La carpeta `evidencias/` ya tiene las consolas y resultados en texto

## 7. Problemas comunes

| Síntoma | Solución |
|---|---|
| `docker: command not found` / error de conexión | Abre Docker Desktop y espera *Engine running* |
| Falla el `build` del NodeManager (apt) | Vuelve a ejecutar `docker compose build --no-cache`; revisa tu internet |
| Un contenedor queda `Exited` | `docker logs <nombre>` y `docker compose up -d` |
| `Name node is in safe mode` | Espera 30 s, o `docker exec namenode hdfs dfsadmin -safemode leave` |
| `Output directory ... already exists` | Los scripts lo borran solos; a mano: `hdfs dfs -rm -r /taller/salida/X` |
| Job se queda en `ACCEPTED` | Falta memoria: ¿están los 2 NodeManagers activos? Sube la RAM de Docker |
| `$'\r': command not found` | Un script quedó con finales de línea de Windows (CRLF). En VS Code, abajo a la derecha cambia `CRLF` por `LF` y guarda |
| Puerto ocupado (ej. 8088) | Cambia el número de la izquierda en `docker-compose.yml` (`"8090:8088"`) |

## 8. Apagar

```powershell
docker compose down               # apaga, conserva los datos de HDFS
docker compose --profile extra down -v   # apaga y BORRA todo (HDFS queda vacío)
```

## Glosario rápido

- **HDFS**: sistema de archivos distribuido. Parte archivos en **bloques** y guarda varias **réplicas** en distintos nodos.
- **NameNode**: guarda los *metadatos* (nombres, carpetas, qué bloque está en qué DataNode). No guarda los datos.
- **DataNode**: guarda los bloques reales y le manda *heartbeats* al NameNode.
- **YARN**: administra los recursos (RAM/CPU) del clúster. **ResourceManager** decide; **NodeManager** ejecuta *contenedores* en cada máquina.
- **ApplicationMaster**: el "jefe" de cada job; pide contenedores y vigila sus tareas.
- **MapReduce**: modelo de programación: *Map* transforma cada registro en pares clave/valor, *Shuffle* agrupa por clave, *Reduce* combina los valores de cada clave.
- **Hadoop Streaming**: permite escribir el Map y el Reduce en cualquier lenguaje (aquí Python) que lea de `stdin` y escriba en `stdout`.
- **Combiner**: un reduce local que corre tras el Map para enviar menos datos por la red.
