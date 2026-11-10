#!/usr/bin/env bash
# JOB 2 - Horas pico y errores 5xx en logs web (Hadoop Streaming + Python).
#   docker exec namenode bash /workspace/scripts/job2_horas_pico.sh
#
# Parámetro opcional: PAUSA en segundos cada 1000 líneas (para hacerlo lento).
#   docker exec namenode bash /workspace/scripts/job2_horas_pico.sh 1
# Con PAUSA=1 cada tarea Map tarda ~1.5 minutos -> tiempo para provocar fallos.
source /workspace/scripts/comun.sh
PAUSA=${1:-0}
ENTRADA=/taller/entrada/logs
SALIDA=/taller/salida/job2_horas_pico

titulo "JOB 2: Horas pico en logs (Streaming, PAUSA=$PAUSA)"
hdfs dfs -rm -r -f -skipTrash $SALIDA >/dev/null

correr_job job2_horas_pico \
  hadoop jar "$STREAMING_JAR" \
    -D mapreduce.job.name=job2-horas-pico \
    -D mapreduce.job.reduces=2 \
    -files $JOBS/job2_horas_pico/mapper.py,$JOBS/job2_horas_pico/reducer.py \
    -mapper "python3 mapper.py" \
    -reducer "python3 reducer.py" \
    -cmdenv PAUSA=$PAUSA \
    -input $ENTRADA \
    -output $SALIDA

titulo "Salida en HDFS (2 reducers = 2 archivos part-)"
hdfs dfs -ls $SALIDA
hdfs dfs -cat $SALIDA/part-* | sort > "$EVIDENCIAS/job2_resultado.txt"

titulo "Peticiones por hora (hora | peticiones | errores 5xx | % error)"
cat "$EVIDENCIAS/job2_resultado.txt"

titulo "Top 3 horas pico"
sort -t$'\t' -k2,2nr "$EVIDENCIAS/job2_resultado.txt" | head -3
