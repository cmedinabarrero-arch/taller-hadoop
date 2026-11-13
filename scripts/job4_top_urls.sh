#!/usr/bin/env bash
# JOB 4 - Top 10 URLs más visitadas (Streaming + combiner + 1 reducer).
#   docker exec namenode bash /workspace/scripts/job4_top_urls.sh
source /workspace/scripts/comun.sh
ENTRADA=/taller/entrada/logs
SALIDA=/taller/salida/job4_top_urls

titulo "JOB 4: Top 10 URLs (Streaming con combiner)"
hdfs dfs -rm -r -f -skipTrash $SALIDA >/dev/null

correr_job job4_top_urls \
  hadoop jar "$STREAMING_JAR" \
    -D mapreduce.job.name=job4-top-urls \
    -D mapreduce.job.reduces=1 \
    -files $JOBS/job4_top_urls/mapper.py,$JOBS/job4_top_urls/combiner.py,$JOBS/job4_top_urls/reducer.py \
    -mapper "python3 mapper.py" \
    -combiner "python3 combiner.py" \
    -reducer "python3 reducer.py" \
    -cmdenv TOP_N=10 \
    -input $ENTRADA \
    -output $SALIDA

titulo "Salida en HDFS"
hdfs dfs -ls $SALIDA
hdfs dfs -cat $SALIDA/part-* > "$EVIDENCIAS/job4_resultado.txt"

titulo "Top 10 URLs (url | visitas)"
cat "$EVIDENCIAS/job4_resultado.txt"
echo
echo "Efecto del combiner: comparar 'Combine input records' y 'Combine output records'"
echo "en los contadores de la consola."
