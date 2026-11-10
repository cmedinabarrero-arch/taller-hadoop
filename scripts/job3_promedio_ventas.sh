#!/usr/bin/env bash
# JOB 3 - Promedio de venta por ciudad (Hadoop Streaming + Python).
#   docker exec namenode bash /workspace/scripts/job3_promedio_ventas.sh
source /workspace/scripts/comun.sh
ENTRADA=/taller/entrada/ventas
SALIDA=/taller/salida/job3_promedio_ciudad

titulo "JOB 3: Promedio de ventas por ciudad (Streaming)"
hdfs dfs -rm -r -f -skipTrash $SALIDA >/dev/null

correr_job job3_promedio_ventas \
  hadoop jar "$STREAMING_JAR" \
    -D mapreduce.job.name=job3-promedio-ciudad \
    -files $JOBS/job3_promedio_ventas/mapper.py,$JOBS/job3_promedio_ventas/reducer.py \
    -mapper "python3 mapper.py" \
    -reducer "python3 reducer.py" \
    -input $ENTRADA \
    -output $SALIDA

titulo "Salida en HDFS"
hdfs dfs -ls $SALIDA
hdfs dfs -cat $SALIDA/part-* > "$EVIDENCIAS/job3_resultado.txt"

titulo "Ciudad | # ventas | total COP | promedio COP | mínimo | máximo  (por promedio)"
sort -t$'\t' -k4,4nr "$EVIDENCIAS/job3_resultado.txt"
