#!/usr/bin/env bash
# JOB 1 - WordCount NATIVO (Java), usando el jar de ejemplos que trae Hadoop.
#   docker exec namenode bash /workspace/scripts/job1_wordcount.sh
source /workspace/scripts/comun.sh
ENTRADA=/taller/entrada/textos
SALIDA=/taller/salida/job1_wordcount

titulo "JOB 1: WordCount (MapReduce nativo en Java)"
# MapReduce NO sobrescribe: si la carpeta de salida existe, el job falla.
hdfs dfs -rm -r -f -skipTrash $SALIDA >/dev/null

correr_job job1_wordcount \
  hadoop jar "$EXAMPLES_JAR" wordcount \
    -D mapreduce.job.name=job1-wordcount \
    $ENTRADA $SALIDA

titulo "Salida en HDFS"
hdfs dfs -ls $SALIDA
hdfs dfs -cat $SALIDA/part-* > "$EVIDENCIAS/job1_resultado.txt"

titulo "Las 15 palabras más frecuentes"
sort -t$'\t' -k2,2nr "$EVIDENCIAS/job1_resultado.txt" | head -15
echo
echo "Palabras distintas: $(wc -l < "$EVIDENCIAS/job1_resultado.txt")"
