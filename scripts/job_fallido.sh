#!/usr/bin/env bash
# JOB QUE FALLA A PROPÓSITO -> para observar el estado FAILED, los reintentos
# de tareas y leer el error en los logs.
#   docker exec namenode bash /workspace/scripts/job_fallido.sh
source /workspace/scripts/comun.sh
SALIDA=/taller/salida/job_fallido

titulo "JOB FALLIDO: el mapper divide entre cero a propósito"
hdfs dfs -rm -r -f -skipTrash $SALIDA >/dev/null

correr_job job_fallido \
  hadoop jar "$STREAMING_JAR" \
    -D mapreduce.job.name=job-fallido-a-proposito \
    -D mapreduce.job.reduces=0 \
    -files $JOBS/job_fallido/mapper_con_error.py \
    -mapper "python3 mapper_con_error.py" \
    -input /taller/entrada/ventas \
    -output $SALIDA

echo
echo "Esperado: 'Job not successful' y Final-State = FAILED."
echo "En la consola busca 'Task Id : attempt_..._m_000000_0, Status : FAILED'"
echo "seguido de _1, _2, _3: son los 4 intentos que hace YARN antes de rendirse."
